local _, ns = ...

-- Profit in item tooltips: hovering an item that a scanned recipe makes adds
-- "Profit Sort: +2g 10s profit (cost 1g 80s)". The last scanned figures are kept
-- per character in ProfitSortCharDB.products, so they show before the profession
-- window is opened again. No line while Auctionator has no price for the item.
ns.MAX_PRODUCTS = 500

local function Products()
  ProfitSortCharDB = ProfitSortCharDB or {}
  ProfitSortCharDB.products = ProfitSortCharDB.products or {}
  return ProfitSortCharDB.products
end

local function Round(amount)
  return math.floor(amount + 0.5)
end

-- Keeps the newest max records (the most profitable first among records of the same scan).
function ns.PruneProducts(max)
  local products = Products()
  local itemIDs = {}
  for itemID in pairs(products) do
    itemIDs[#itemIDs + 1] = itemID
  end
  if #itemIDs <= max then
    return
  end
  table.sort(itemIDs, function(a, b)
    local ra, rb = products[a], products[b]
    local ta, tb = ra.time or 0, rb.time or 0
    if ta ~= tb then
      return ta > tb
    end
    if ra.profit ~= rb.profit then
      return (ra.profit or 0) > (rb.profit or 0)
    end
    return a < b
  end)
  for i = max + 1, #itemIDs do
    products[itemIDs[i]] = nil
  end
end

-- Stores the profit of every evaluated recipe that makes an item with an AH
-- price. Uses the cost without Owned free; skips recipes with unpriced reagents.
-- When several recipes make the same item, the most profitable one is kept.
function ns.RememberProducts(entries)
  local now = time and time() or 0
  local best = {}
  for _, entry in ipairs(entries) do
    local cost = entry.fullCost or entry.cost
    if entry.itemID and entry.value and cost and not entry.fullCostMissing and not entry.missingReagents then
      local profit = Round(entry.value - cost)
      local current = best[entry.itemID]
      if not current or profit > current.profit then
        best[entry.itemID] = {
          profit = profit,
          cost = Round(cost),
          value = Round(entry.value),
          numMade = entry.numMade,
          recipe = entry.name,
          time = now,
        }
      end
    end
  end
  local products = Products()
  for itemID, record in pairs(best) do
    products[itemID] = record
  end
  ns.PruneProducts(ns.MAX_PRODUCTS)
end

-- The tooltip line for an item, with its colour, or nil.
function ns.ProductTooltipLine(itemID, link)
  if not itemID then
    return nil
  end
  local record = Products()[itemID]
  if not (record and record.profit and record.cost) then
    return nil
  end
  local unit = ns.GetAuctionPrice(link, itemID)
  if not unit then
    return nil
  end
  -- The value follows today's auction price; only the reagent cost is from the last scan.
  local profitValue = record.profit
  if record.numMade then
    profitValue = Round(math.floor(unit * record.numMade * ns.AH_CUT) - record.cost)
  end
  local profit = ns.FormatMoney(profitValue, true)
  local text = ("Profit Sort: %s%s profit (cost %s)"):format(profitValue >= 0 and "+" or "", profit,
    ns.FormatMoney(record.cost, true))
  if profitValue >= 0 then
    return text, 0.25, 1, 0.25
  end
  return text, 1, 0.31, 0.31
end

-- Hooks ------------------------------------------------------------------------
-- TooltipDataProcessor where it exists (every item tooltip), otherwise
-- OnTooltipSetItem on GameTooltip and ItemRefTooltip. Shopping (compare)
-- tooltips, hidden scanner tooltips and the profit panel's own rows are skipped.
local added = {}   -- tooltip -> true while it shows the line
local watched = {} -- tooltips whose OnTooltipCleared is hooked

local function IsShoppingTooltip(tooltip)
  if tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2
    or tooltip == ItemRefShoppingTooltip1 or tooltip == ItemRefShoppingTooltip2 then
    return true
  end
  local ok, name = pcall(tooltip.GetName, tooltip)
  return ok and type(name) == "string" and name:find("Shopping") ~= nil
end

-- Hidden scanning tooltips (other addons') are owned with ANCHOR_NONE and have no anchor points; real tooltips
-- are anchored before their item is set, even when they are only shown afterwards.
local function IsOnScreen(tooltip)
  if tooltip == GameTooltip or tooltip == ItemRefTooltip then
    return true
  end
  if tooltip:IsVisible() then
    return true
  end
  return tooltip.GetNumPoints ~= nil and tooltip:GetNumPoints() > 0
end

local function IsPanelRow(tooltip)
  local owner = tooltip.GetOwner and tooltip:GetOwner()
  return type(owner) == "table" and owner.profitSortRow == true
end

local function Watch(tooltip)
  if watched[tooltip] then
    return
  end
  watched[tooltip] = true
  if tooltip.HookScript then
    tooltip:HookScript("OnTooltipCleared", function(self)
      added[self] = nil
    end)
  end
end

local function ItemOf(tooltip, data)
  local link
  if tooltip.GetItem then
    local _, itemLink = tooltip:GetItem()
    link = ns.ItemLinkOrNil(itemLink)
  end
  local itemID = data and type(data.id) == "number" and data.id or ns.ItemIDFromLink(link)
  return itemID, link
end

local function AddLine(tooltip, data)
  if added[tooltip] or not (ProfitSortDB and ProfitSortDB.itemTooltips) then
    return
  end
  if IsShoppingTooltip(tooltip) or not IsOnScreen(tooltip) or IsPanelRow(tooltip) then
    return
  end
  Watch(tooltip)
  local text, r, g, b = ns.ProductTooltipLine(ItemOf(tooltip, data))
  if text then
    added[tooltip] = true
    tooltip:AddLine(text, r, g, b)
    tooltip:Show()
  end
end

function ns.OnItemTooltip(tooltip, data)
  pcall(AddLine, tooltip, data)
end

function ns.HookItemTooltips()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ns.OnItemTooltip)
    return
  end
  for _, tooltip in ipairs({GameTooltip, ItemRefTooltip}) do
    if tooltip and tooltip.HookScript then
      tooltip:HookScript("OnTooltipSetItem", ns.OnItemTooltip)
    end
  end
end

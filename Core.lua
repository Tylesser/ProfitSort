local addonName, ns = ...

ns.CALLER_ID = addonName
-- The auction house keeps 5% of every sale; Auctionator uses the same factor.
ns.AH_CUT = 0.95

ns.defaults = {
  sortKey = "profit",
  ascending = false,
  craftableOnly = false,
  hideUnpriced = false,
  ownedFree = false,
  queue = {},
  vendorFlips = true,
  shown = true,
  position = nil,
}

-- Auctionator public API (Auctionator.API.v1). Only the documented, stable
-- functions are used so Auctionator updates don't break this addon.
local function CallAuctionator(fnName, ...)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  local fn = api and api[fnName]
  if not fn then
    return nil
  end
  local ok, result = pcall(fn, ns.CALLER_ID, ...)
  if ok then
    return result
  end
  return nil
end
ns.CallAuctionator = CallAuctionator

-- Prefer the full item link (handles item level / suffix variants) and fall
-- back to the bare itemID.
local function Lookup(linkFn, idFn, link, itemID)
  local value
  if link then
    value = CallAuctionator(linkFn, link)
  end
  if value == nil and itemID then
    value = CallAuctionator(idFn, itemID)
  end
  return value
end

function ns.GetAuctionPrice(link, itemID)
  return Lookup("GetAuctionPriceByItemLink", "GetAuctionPriceByItemID", link, itemID)
end

function ns.GetVendorPrice(link, itemID)
  return Lookup("GetVendorPriceByItemLink", "GetVendorPriceByItemID", link, itemID)
end

function ns.GetAuctionAge(link, itemID)
  return Lookup("GetAuctionAgeByItemLink", "GetAuctionAgeByItemID", link, itemID)
end

function ns.ItemIDFromLink(link)
  if not link then
    return nil
  end
  return tonumber(link:match("item:(%d+)"))
end

function ns.ItemLinkOrNil(link)
  if type(link) == "string" and link:find("|Hitem:", 1, true) then
    return link
  end
  return nil
end

function ns.ItemName(itemID)
  if not itemID then
    return nil
  end
  if C_Item and C_Item.GetItemNameByID then
    local name = C_Item.GetItemNameByID(itemID)
    if name then
      return name
    end
  end
  if GetItemInfo then
    return (GetItemInfo(itemID))
  end
  return nil
end

-- Same rule Auctionator uses for its own "To Craft" figure: a known vendor
-- price wins over the auction price.
function ns.GetReagentUnitPrice(link, itemID)
  local vendor = ns.GetVendorPrice(link, itemID)
  if vendor then
    return vendor, "vendor"
  end
  local auction = ns.GetAuctionPrice(link, itemID)
  if auction then
    return auction, "auction"
  end
  return nil, "missing"
end

local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

-- How many of a reagent you have in your bags and bank (any of its qualities).
local function OwnedCount(reagent)
  local itemIDs = reagent.alternatives or {reagent.itemID}
  local total = 0
  for _, itemID in ipairs(itemIDs) do
    if itemID then
      total = total + (GetItemCount(itemID, true) or 0)
    end
  end
  return total
end

-- Estimated chance of a skill point by recipe colour. The game uses
-- (gray - skill) / (gray - yellow): 100% while orange, falling from 100% to
-- 50% through yellow and from 50% to 0% through green, so yellow and green
-- use the middle of their range.
ns.SKILL_CHANCE = {
  optimal = 1,
  medium = 0.75,
  easy = 0.25,
  trivial = 0,
}

function ns.OwnedCount(itemID)
  if not itemID then
    return 0
  end
  return GetItemCount(itemID, true) or 0
end

-- Fills in cost/value/profit/margin on a recipe entry produced by a provider.
-- With ownedFree, reagents you already own cost nothing; only the part of a
-- reagent you would still have to buy is counted.
function ns.Evaluate(entry, ownedFree)
  local cost, missing = 0, false

  for _, reagent in ipairs(entry.reagents) do
    local unit, source = ns.GetReagentUnitPrice(reagent.link, reagent.itemID)
    local chosenID = reagent.itemID
    -- Reagents that come in several qualities: use the cheapest one.
    if reagent.alternatives then
      for _, altID in ipairs(reagent.alternatives) do
        local altUnit, altSource = ns.GetReagentUnitPrice(nil, altID)
        if altUnit and (unit == nil or altUnit < unit) then
          unit, source, chosenID = altUnit, altSource, altID
        end
      end
    end
    reagent.unitPrice, reagent.source, reagent.chosenItemID = unit, source, chosenID

    local toBuy = reagent.count
    reagent.owned = nil
    if ownedFree then
      reagent.owned = OwnedCount(reagent)
      toBuy = math.max(0, reagent.count - reagent.owned)
    end
    reagent.toBuy = toBuy

    if toBuy > 0 then
      if unit then
        cost = cost + unit * toBuy
      else
        missing = true
      end
    end
  end

  entry.cost = cost
  entry.missingReagents = missing
  entry.ownedFree = ownedFree and true or false

  local chance = entry.difficulty and ns.SKILL_CHANCE[entry.difficulty]
  entry.skillChance = chance
  if chance and chance > 0 then
    entry.skillCost = cost / (chance * (entry.skillUps or 1))
  else
    entry.skillCost = nil
  end

  local unitAH
  if entry.link or entry.itemID then
    unitAH = ns.GetAuctionPrice(entry.link, entry.itemID)
  end
  entry.unitAH = unitAH

  if unitAH then
    entry.age = ns.GetAuctionAge(entry.link, entry.itemID)
    entry.value = math.floor(unitAH * entry.numMade * ns.AH_CUT)
    entry.profit = entry.value - cost
    entry.margin = cost > 0 and entry.profit / cost or nil
  else
    entry.age, entry.value, entry.profit, entry.margin = nil, nil, nil, nil
  end
end

-- Entries without a value for the sort key always go to the bottom.
function ns.SortEntries(entries, key, ascending)
  table.sort(entries, function(a, b)
    local va, vb = a[key], b[key]
    if va == nil or vb == nil or va == vb then
      if va ~= nil and vb == nil then
        return true
      elseif va == nil and vb ~= nil then
        return false
      end
      return a.name < b.name
    end
    if ascending then
      return va < vb
    end
    return va > vb
  end)
end

local GOLD = "|cffffd700g|r"
local SILVER = "|cffc7c7cfs|r"
local COPPER = "|cffeda55fc|r"

function ns.FormatMoney(amount)
  if amount == nil then
    return "|cff808080--|r"
  end
  local digitColor = amount < 0 and "|cffff5050" or "|cffffffff"
  local sign = amount < 0 and "-" or ""
  amount = math.floor(math.abs(amount) + 0.5)

  local gold = math.floor(amount / 10000)
  local silver = math.floor(amount / 100) % 100
  local copper = amount % 100

  local function Part(n, suffix)
    return digitColor .. n .. "|r" .. suffix
  end

  local text
  if gold > 0 then
    local goldText = BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or tostring(gold)
    text = Part(goldText, GOLD)
    if silver > 0 and gold < 1000 then
      text = text .. " " .. Part(silver, SILVER)
    end
  elseif silver > 0 then
    text = Part(silver, SILVER)
    if copper > 0 then
      text = text .. " " .. Part(copper, COPPER)
    end
  else
    text = Part(copper, COPPER)
  end
  if sign ~= "" then
    text = digitColor .. sign .. "|r" .. text
  end
  return text
end

function ns.FormatMargin(margin)
  if margin == nil then
    return "|cff808080--|r"
  end
  local pct = math.floor(margin * 100 + 0.5)
  if pct >= 0 then
    return ("|cff40ff40%d%%|r"):format(pct)
  end
  return ("|cffff5050%d%%|r"):format(pct)
end

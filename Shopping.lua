local _, ns = ...

-- A small craft queue (right-click recipes) that becomes an Auctionator
-- shopping list of the reagents you still need to buy.
ns.SHOPPING_LIST_NAME = "Profit Sort"
ns.PREFIX = "|cffffd700Tylesser - Auctionator Profit Sort|r: "

local function Queue()
  ProfitSortDB.queue = ProfitSortDB.queue or {}
  return ProfitSortDB.queue
end

function ns.QueuedCount(entry)
  local queued = Queue()[entry.name]
  return queued and queued.count or 0
end

function ns.QueueTotal()
  local total = 0
  for _, queued in pairs(Queue()) do
    total = total + queued.count
  end
  return total
end

-- Adds (delta > 0) or removes crafts of a recipe; the reagent list is stored
-- with it so the queue survives sorting, filtering and reloads.
function ns.ChangeQueue(entry, delta)
  local queue = Queue()
  local queued = queue[entry.name]
  if not queued then
    if delta <= 0 then
      return
    end
    queued = {count = 0, reagents = {}}
    for _, reagent in ipairs(entry.reagents) do
      local itemID = reagent.chosenItemID or reagent.itemID
      table.insert(queued.reagents, {
        name = reagent.name or ns.ItemName(itemID),
        itemID = itemID,
        count = reagent.count,
      })
    end
    queue[entry.name] = queued
  end
  queued.count = queued.count + delta
  if queued.count <= 0 then
    queue[entry.name] = nil
  end
end

function ns.ClearQueue()
  ProfitSortDB.queue = {}
end

-- Total reagents for every queued craft, minus what you already own.
function ns.ReagentsToBuy()
  local needed, order = {}, {}
  for _, queued in pairs(Queue()) do
    for _, reagent in ipairs(queued.reagents) do
      local key = reagent.itemID or reagent.name
      if key then
        if not needed[key] then
          needed[key] = {name = reagent.name, itemID = reagent.itemID, count = 0}
          table.insert(order, key)
        end
        needed[key].count = needed[key].count + reagent.count * queued.count
      end
    end
  end

  local toBuy = {}
  for _, key in ipairs(order) do
    local reagent = needed[key]
    local missing = reagent.count - ns.OwnedCount(reagent.itemID)
    if missing > 0 then
      table.insert(toBuy, {
        name = reagent.name or ns.ItemName(reagent.itemID),
        itemID = reagent.itemID,
        count = missing,
      })
    end
  end
  table.sort(toBuy, function(a, b)
    return (a.name or "") < (b.name or "")
  end)
  return toBuy
end

function ns.CreateShoppingList()
  if ns.QueueTotal() == 0 then
    print(ns.PREFIX .. "right-click recipes to queue them first.")
    return
  end

  local searchStrings, unnamed = {}, 0
  for _, reagent in ipairs(ns.ReagentsToBuy()) do
    if reagent.name then
      local searchString = ns.CallAuctionator("ConvertToSearchString", {
        searchString = reagent.name,
        isExact = true,
        quantity = reagent.count,
      })
      if searchString then
        table.insert(searchStrings, searchString)
      end
    else
      unnamed = unnamed + 1
    end
  end

  if #searchStrings == 0 and unnamed == 0 then
    print(ns.PREFIX .. "you already have every reagent for your queued crafts.")
    return
  end

  ns.CallAuctionator("CreateShoppingList", ns.SHOPPING_LIST_NAME, searchStrings)
  local message = ("shopping list \"%s\" has %d reagent(s) to buy."):format(ns.SHOPPING_LIST_NAME, #searchStrings)
  if unnamed > 0 then
    message = message .. (" %d reagent(s) were skipped because their names haven't loaded yet; try again."):format(unnamed)
  end
  print(ns.PREFIX .. message)
end

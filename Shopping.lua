local _, ns = ...
local L = ns.L

-- A small craft queue (right-click recipes) that becomes an Auctionator
-- shopping list of the reagents you still need to buy.
ns.SHOPPING_LIST_NAME = "Profit Sort"
ns.PREFIX = ns.T.Prefix("Profit Sort")

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

-- One reagent of a queued craft, as saved: { name, itemID, count }, and for a reagent that make or buy chose to
-- craft also { recipe, made = average amount one craft makes, reagents = { ...the same, one level down } }.
-- A plain copy: the scan's tables must not go into the saved variables.
local function Plan(reagent, depth, visiting)
  local itemID = reagent.chosenItemID or reagent.itemID
  local node = {
    name = reagent.name or ns.ItemName(itemID),
    itemID = itemID,
    count = reagent.count,
  }
  local recipe = reagent.craftEntry
  if reagent.source == "craft" and recipe and recipe.reagents and (recipe.numMade or 0) > 0
    and depth <= ns.MAX_CRAFT_DEPTH and itemID and not visiting[itemID] then
    visiting[itemID] = true
    node.recipe, node.made, node.reagents = recipe.name, recipe.numMade, {}
    for _, sub in ipairs(recipe.reagents) do
      table.insert(node.reagents, Plan(sub, depth + 1, visiting))
    end
    visiting[itemID] = nil
  end
  return node
end
ns.PlanReagent = Plan

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
    local visiting = {}
    if entry.itemID then
      visiting[entry.itemID] = true
    end
    for _, reagent in ipairs(entry.reagents) do
      table.insert(queued.reagents, Plan(reagent, 1, visiting))
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

-- Reagents to buy for every queued craft. What you own (bags and bank) is used first; a reagent that make or
-- buy crafts is replaced by what crafting the rest of it takes, one level down at a time (crafts rounded up).
-- Returns the reagents to buy by name and { { name, itemID, count = how many to craft, recipe } } to craft.
function ns.ReagentsToBuy()
  local stock = {}
  local buy, buyOrder, craft, craftOrder = {}, {}, {}, {}
  local function Take(itemID, amount)
    if not itemID then
      return 0
    end
    if stock[itemID] == nil then
      stock[itemID] = ns.OwnedCount(itemID)
    end
    local used = math.min(stock[itemID], amount)
    stock[itemID] = stock[itemID] - used
    return used
  end
  local function Need(node, amount)
    local rest = amount - Take(node.itemID, amount)
    if rest <= 0 then
      return
    end
    local key = node.itemID or node.name
    if not key then
      return
    end
    if node.reagents and (node.made or 0) > 0 then
      local crafts = math.ceil(rest / node.made - 1e-9)
      if not craft[key] then
        craft[key] = {name = node.name, itemID = node.itemID, recipe = node.recipe, count = 0}
        table.insert(craftOrder, key)
      end
      craft[key].count = craft[key].count + crafts
      for _, sub in ipairs(node.reagents) do
        Need(sub, (sub.count or 0) * crafts)
      end
      return
    end
    if not buy[key] then
      buy[key] = {name = node.name, itemID = node.itemID, count = 0}
      table.insert(buyOrder, key)
    end
    buy[key].count = buy[key].count + rest
  end

  -- the same order every time (pairs has none), so what you own goes to the same crafts
  local names = {}
  for name in pairs(Queue()) do
    table.insert(names, name)
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local queued = Queue()[name]
    for _, reagent in ipairs(queued.reagents) do
      Need(reagent, (reagent.count or 0) * queued.count)
    end
  end

  local function List(byKey, order)
    local list = {}
    for _, key in ipairs(order) do
      local item = byKey[key]
      item.name = item.name or ns.ItemName(item.itemID)
      table.insert(list, item)
    end
    table.sort(list, function(a, b)
      return (a.name or "") < (b.name or "")
    end)
    return list
  end
  return List(buy, buyOrder), List(craft, craftOrder)
end

function ns.CreateShoppingList()
  if ns.QueueTotal() == 0 then
    print(ns.PREFIX .. L["right-click recipes to queue them first."])
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
    print(ns.PREFIX .. L["you already have every reagent for your queued crafts."])
    return
  end

  ns.CallAuctionator("CreateShoppingList", ns.SHOPPING_LIST_NAME, searchStrings)
  local message = L["shopping list \"%s\" has %d reagent(s) to buy."]:format(ns.SHOPPING_LIST_NAME, #searchStrings)
  if unnamed > 0 then
    message = message .. " " .. L["%d reagent(s) were skipped because their names haven't loaded yet; try again."]:format(unnamed)
  end
  print(ns.PREFIX .. message)
end

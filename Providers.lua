local _, ns = ...

-- A provider knows how to read recipes from one kind of profession window.
-- Each Scan() returns a list of entries:
--   { key, name, icon, link, itemID, numMade, numAvailable, color,
--     reagents = { { name, link, itemID, count, alternatives } } }
ns.Providers = {}

local function IsHeader(skillType)
  return skillType == "header" or skillType == "subheader"
end

local function TypeColor(skillType)
  local colors = TradeSkillTypeColor
  return colors and colors[skillType]
end

-- Scroll a classic FauxScrollFrame list so that `index` is visible.
local function ScrollClassicList(scrollFrame, index, total, displayed, rowHeight)
  if not (scrollFrame and FauxScrollFrame_SetOffset and FauxScrollFrame_GetOffset
    and displayed and rowHeight) then
    return
  end
  local offset = FauxScrollFrame_GetOffset(scrollFrame)
  if index > offset and index <= offset + displayed then
    return
  end
  offset = math.max(0, math.min(index - 1, total - displayed))
  FauxScrollFrame_SetOffset(scrollFrame, offset)
  local frameName = scrollFrame:GetName()
  local bar = scrollFrame.ScrollBar or (frameName and _G[frameName .. "ScrollBar"])
  if bar then
    bar:SetValue(offset * rowHeight)
  end
end

--------------------------------------------------------------------------------
-- Classic trade skill window (TradeSkillFrame / GetTradeSkillInfo)
--------------------------------------------------------------------------------
ns.Providers.TradeSkill = {
  dockX = -34,
  dockY = -12,

  IsAvailable = function()
    return GetNumTradeSkills ~= nil
  end,

  GetFrame = function()
    return TradeSkillFrame
  end,

  GetTitle = function()
    return GetTradeSkillLine and (GetTradeSkillLine())
  end,

  Scan = function()
    local entries = {}
    for index = 1, GetNumTradeSkills() do
      local name, skillType, numAvailable = GetTradeSkillInfo(index)
      if name and not IsHeader(skillType) then
        local link = ns.ItemLinkOrNil(GetTradeSkillItemLink(index))
        local minMade, maxMade = GetTradeSkillNumMade(index)
        minMade = minMade or 1
        maxMade = maxMade or minMade

        local entry = {
          key = index,
          name = name,
          icon = GetTradeSkillIcon(index),
          link = link,
          itemID = ns.ItemIDFromLink(link),
          numMade = (minMade + maxMade) / 2,
          numAvailable = numAvailable or 0,
          color = TypeColor(skillType),
          difficulty = skillType,
          reagents = {},
        }
        for r = 1, GetTradeSkillNumReagents(index) do
          local reagentName, _, count = GetTradeSkillReagentInfo(index, r)
          local reagentLink = GetTradeSkillReagentItemLink(index, r)
          table.insert(entry.reagents, {
            name = reagentName,
            link = reagentLink,
            itemID = ns.ItemIDFromLink(reagentLink),
            count = count or 1,
          })
        end
        table.insert(entries, entry)
      end
    end
    return entries
  end,

  Select = function(entry)
    if TradeSkillFrame_SetSelection then
      TradeSkillFrame_SetSelection(entry.key)
    end
    ScrollClassicList(TradeSkillListScrollFrame, entry.key, GetNumTradeSkills(),
      TRADE_SKILLS_DISPLAYED, TRADE_SKILL_HEIGHT)
    if TradeSkillFrame_Update then
      TradeSkillFrame_Update()
    end
  end,
}

--------------------------------------------------------------------------------
-- Classic craft window (CraftFrame / GetCraftInfo) - Enchanting in vanilla.
-- Enchants don't create an item, so only the crafting cost is known.
--------------------------------------------------------------------------------
ns.Providers.Craft = {
  dockX = -34,
  dockY = -12,

  IsAvailable = function()
    return GetNumCrafts ~= nil
  end,

  GetFrame = function()
    return CraftFrame
  end,

  GetTitle = function()
    if GetCraftDisplaySkillLine then
      local name = GetCraftDisplaySkillLine()
      if name then
        return name
      end
    end
    return GetCraftName and GetCraftName()
  end,

  Scan = function()
    local entries = {}
    for index = 1, GetNumCrafts() do
      local name, _, craftType, numAvailable = GetCraftInfo(index)
      local numReagents = GetCraftNumReagents(index) or 0
      if name and not IsHeader(craftType) and numReagents > 0 then
        local link = ns.ItemLinkOrNil(GetCraftItemLink and GetCraftItemLink(index))
        local entry = {
          key = index,
          name = name,
          icon = GetCraftIcon(index),
          link = link,
          itemID = ns.ItemIDFromLink(link),
          numMade = 1,
          numAvailable = numAvailable or 0,
          color = TypeColor(craftType),
          difficulty = craftType,
          reagents = {},
        }
        for r = 1, numReagents do
          local reagentName, _, count = GetCraftReagentInfo(index, r)
          local reagentLink = GetCraftReagentItemLink(index, r)
          table.insert(entry.reagents, {
            name = reagentName,
            link = reagentLink,
            itemID = ns.ItemIDFromLink(reagentLink),
            count = count or 1,
          })
        end
        table.insert(entries, entry)
      end
    end
    return entries
  end,

  Select = function(entry)
    if CraftFrame_SetSelection then
      CraftFrame_SetSelection(entry.key)
    end
    ScrollClassicList(CraftListScrollFrame, entry.key, GetNumCrafts(),
      CRAFTS_DISPLAYED, CRAFT_SKILL_HEIGHT)
    if CraftFrame_Update then
      CraftFrame_Update()
    end
  end,
}

--------------------------------------------------------------------------------
-- Modern professions window (ProfessionsFrame / C_TradeSkillUI)
--------------------------------------------------------------------------------
local modernNames
-- Maps the modern difficulty enum to the classic names used everywhere else.
local function ModernDifficulty(relativeDifficulty)
  local difficulty = Enum and Enum.TradeskillRelativeDifficulty
  if not difficulty or relativeDifficulty == nil then
    return nil
  end
  if not modernNames then
    modernNames = {
      [difficulty.Optimal] = "optimal",
      [difficulty.Medium] = "medium",
      [difficulty.Easy] = "easy",
      [difficulty.Trivial] = "trivial",
    }
  end
  return modernNames[relativeDifficulty]
end

local modernColors
local function ModernColor(relativeDifficulty)
  local difficulty = Enum and Enum.TradeskillRelativeDifficulty
  if not difficulty or relativeDifficulty == nil then
    return nil
  end
  if not modernColors then
    modernColors = {
      [difficulty.Optimal] = {r = 1.00, g = 0.50, b = 0.25},
      [difficulty.Medium] = {r = 1.00, g = 1.00, b = 0.00},
      [difficulty.Easy] = {r = 0.25, g = 0.75, b = 0.25},
      [difficulty.Trivial] = {r = 0.50, g = 0.50, b = 0.50},
    }
  end
  return modernColors[relativeDifficulty]
end

local function IsBasicReagentSlot(slot)
  local types = Enum and Enum.CraftingReagentType
  if types and types.Basic and slot.reagentType ~= nil then
    return slot.reagentType == types.Basic
  end
  return slot.required ~= false
end

ns.Providers.Professions = {
  dockX = 2,
  dockY = 0,

  IsAvailable = function()
    return C_TradeSkillUI ~= nil and C_TradeSkillUI.GetAllRecipeIDs ~= nil
      and C_TradeSkillUI.GetRecipeSchematic ~= nil
  end,

  GetFrame = function()
    return ProfessionsFrame
  end,

  GetTitle = function()
    local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    return info and info.professionName
  end,

  Scan = function()
    local entries = {}
    if C_TradeSkillUI.IsTradeSkillReady and not C_TradeSkillUI.IsTradeSkillReady() then
      return entries
    end

    local recipeIDs = (C_TradeSkillUI.GetFilteredRecipeIDs and C_TradeSkillUI.GetFilteredRecipeIDs())
      or C_TradeSkillUI.GetAllRecipeIDs()

    for _, recipeID in ipairs(recipeIDs or {}) do
      local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
      if info and info.learned and not info.isDummyRecipe and not info.isGatheringRecipe
        and not info.isRecraft and not info.isSalvageRecipe then
        local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
        if schematic then
          local output = C_TradeSkillUI.GetRecipeOutputItemData
            and C_TradeSkillUI.GetRecipeOutputItemData(recipeID)
          local link = output and ns.ItemLinkOrNil(output.hyperlink)
          local minMade = schematic.quantityMin or 1
          local maxMade = schematic.quantityMax or minMade

          local entry = {
            key = recipeID,
            name = info.name or schematic.name or "?",
            icon = info.icon,
            link = link,
            itemID = (output and output.itemID) or schematic.outputItemID,
            numMade = (minMade + maxMade) / 2,
            numAvailable = info.numAvailable or 0,
            color = ModernColor(info.relativeDifficulty),
            difficulty = ModernDifficulty(info.relativeDifficulty),
            skillUps = (info.numSkillUps and info.numSkillUps > 1) and info.numSkillUps or 1,
            reagents = {},
          }

          for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
            if IsBasicReagentSlot(slot) and slot.reagents then
              local itemIDs = {}
              for _, reagent in ipairs(slot.reagents) do
                if reagent.itemID then
                  table.insert(itemIDs, reagent.itemID)
                end
              end
              if #itemIDs > 0 then
                table.insert(entry.reagents, {
                  itemID = itemIDs[1],
                  count = slot.quantityRequired or 1,
                  alternatives = #itemIDs > 1 and itemIDs or nil,
                })
              end
            end
          end
          table.insert(entries, entry)
        end
      end
    end
    return entries
  end,

  Select = function(entry)
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local list = page and page.RecipeList
    local info = C_TradeSkillUI.GetRecipeInfo(entry.key)
    if list and list.SelectRecipe and info then
      list:SelectRecipe(info, true)
    elseif C_TradeSkillUI.OpenRecipe then
      C_TradeSkillUI.OpenRecipe(entry.key)
    end
  end,
}

local _, ns = ...

local UI = {}
ns.UI = UI

local ROW_HEIGHT = 18
local NUM_ROWS = 20
local LEFT = 12
local HEADER_Y = -30
local ROWS_Y = HEADER_Y - 20
local COL_GAP = 4
local ICON_SPACE = 20

local COLUMNS = {
  {key = "name", label = "Recipe", width = 168, justify = "LEFT"},
  {key = "cost", label = "Cost", width = 64, justify = "RIGHT"},
  {key = "value", label = "AH Value", width = 64, justify = "RIGHT"},
  {key = "profit", label = "Profit", width = 64, justify = "RIGHT"},
  {key = "margin", label = "Margin", width = 52, justify = "RIGHT"},
}

local CONTENT_WIDTH = -COL_GAP
for _, column in ipairs(COLUMNS) do
  CONTENT_WIDTH = CONTENT_WIDTH + column.width + COL_GAP
end
local PANEL_WIDTH = LEFT + CONTENT_WIDTH + 34
local PANEL_HEIGHT = -ROWS_Y + NUM_ROWS * ROW_HEIGHT + 40

local panel, scrollFrame, toggle, status
local rows, headers = {}, {}
local entries = {}
local provider, dockParent
local selectedKey

local function ApplyPosition()
  panel:ClearAllPoints()
  local pos = ProfitSortDB.position
  if pos then
    panel:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  elseif dockParent then
    panel:SetPoint("TOPLEFT", dockParent, "TOPRIGHT", provider.dockX, provider.dockY)
  else
    panel:SetPoint("CENTER")
  end

  if dockParent then
    toggle:ClearAllPoints()
    toggle:SetPoint("TOPLEFT", dockParent, "TOPRIGHT", provider.dockX, provider.dockY - 4)
  end
end

local function SetSort(key)
  if ProfitSortDB.sortKey == key then
    ProfitSortDB.ascending = not ProfitSortDB.ascending
  else
    ProfitSortDB.sortKey = key
    ProfitSortDB.ascending = key == "name"
  end
  UI:Refresh()
end

local function RowOnClick(self)
  local entry = self.entry
  if not entry then
    return
  end
  if IsModifiedClick("CHATLINK") and entry.link then
    local insertLink = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
    if insertLink and insertLink(entry.link) then
      return
    end
  end
  selectedKey = entry.key
  if provider then
    provider.Select(entry)
  end
  UI:UpdateRows()
end

local function RowOnEnter(self)
  local entry = self.entry
  if not entry then
    return
  end

  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if entry.link then
    GameTooltip:SetHyperlink(entry.link)
  elseif entry.itemID and GameTooltip.SetItemByID then
    GameTooltip:SetItemByID(entry.itemID)
  else
    GameTooltip:SetText(entry.name, 1, 1, 1)
  end

  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Reagents", 1, 0.82, 0)
  for _, reagent in ipairs(entry.reagents) do
    local itemID = reagent.chosenItemID or reagent.itemID
    local name = reagent.name or ns.ItemName(itemID) or ("item:" .. tostring(itemID))
    local toBuy = reagent.toBuy or reagent.count
    local right
    if toBuy == 0 then
      right = "|cff40ff40owned|r"
    elseif reagent.unitPrice then
      right = ns.FormatMoney(reagent.unitPrice * toBuy)
      if reagent.source == "vendor" then
        right = "|cff909090(vendor)|r " .. right
      end
    else
      right = "|cffff5050no price|r"
    end
    local left = ("%dx %s"):format(reagent.count, name)
    if reagent.owned and reagent.owned > 0 then
      left = left .. (" |cff40ff40(have %d)|r"):format(reagent.owned)
    end
    GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
  end

  GameTooltip:AddLine(" ")
  local costLabel = entry.ownedFree and "Cost to buy what you lack" or "Crafting cost"
  GameTooltip:AddDoubleLine(costLabel, ns.FormatMoney(entry.cost), 1, 1, 1, 1, 1, 1)
  if entry.unitAH then
    local made = entry.numMade ~= 1 and (" x%g"):format(entry.numMade) or ""
    GameTooltip:AddDoubleLine("AH value" .. made .. " (after 5% cut)", ns.FormatMoney(entry.value),
      1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Profit", ns.FormatMoney(entry.profit), 1, 1, 1, 1, 1, 1)
    if entry.age then
      local ageText = entry.age == 0 and "today" or (entry.age .. " day(s) ago")
      if entry.age > 10 then
        GameTooltip:AddLine("Price last seen " .. ageText, 1, 0.5, 0.25)
      else
        GameTooltip:AddLine("Price last seen " .. ageText, 0.6, 0.6, 0.6)
      end
    end
  else
    GameTooltip:AddLine("No Auctionator price for the crafted item", 1, 0.5, 0.25)
  end
  if entry.missingReagents then
    GameTooltip:AddLine("Some reagents have no price, so the cost is too low", 1, 0.5, 0)
  end
  GameTooltip:AddLine("Click to select - Shift-click to link", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function RowOnLeave()
  GameTooltip:Hide()
end

local function CreateCheck(label, dbKey, tooltip)
  local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  check:SetSize(22, 22)
  local text = check.Text or check.text
  if not text then
    text = check:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", check, "RIGHT", 2, 0)
  end
  text:SetFontObject("GameFontHighlightSmall")
  text:SetText(label)
  check.label = text

  check:SetScript("OnShow", function(self)
    self:SetChecked(ProfitSortDB[dbKey])
  end)
  check:SetScript("OnClick", function(self)
    ProfitSortDB[dbKey] = self:GetChecked() and true or false
    UI:Refresh()
  end)
  check:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  check:SetScript("OnLeave", RowOnLeave)
  return check
end

local function Create()
  panel = CreateFrame("Frame", "ProfitSortPanel", UIParent, "BasicFrameTemplateWithInset")
  panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
  panel:SetToplevel(true)
  panel:SetClampedToScreen(true)
  panel:EnableMouse(true)
  panel:SetMovable(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    local point, _, relativePoint, x, y = self:GetPoint(1)
    ProfitSortDB.position = {point, relativePoint, x, y}
  end)
  panel:Hide()

  panel.title = panel.TitleText
  if not panel.title then
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.title:SetPoint("TOP", 0, -5)
  end

  local closeButton = panel.CloseButton or _G["ProfitSortPanelCloseButton"]
  if closeButton then
    closeButton:HookScript("OnClick", function()
      ProfitSortDB.shown = false
      UI:UpdateVisibility()
    end)
  end

  -- Column headers (click to sort)
  local x = LEFT
  for _, column in ipairs(COLUMNS) do
    local header = CreateFrame("Button", nil, panel)
    header:SetSize(column.width, 18)
    header:SetPoint("TOPLEFT", x, HEADER_Y)
    header.key = column.key

    local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetJustifyH(column.justify)
    text:SetText(column.label)

    local arrow = header:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    arrow:SetSize(9, 8)
    if column.justify == "LEFT" then
      local indent = column.key == "name" and ICON_SPACE or 0
      text:SetPoint("TOPLEFT", indent, 0)
      text:SetPoint("BOTTOMRIGHT")
      arrow:SetPoint("LEFT", header, "LEFT", indent + text:GetStringWidth() + 3, 0)
    else
      text:SetPoint("TOPLEFT")
      text:SetPoint("BOTTOMRIGHT", -12, 0)
      arrow:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    end
    header.arrow = arrow

    header:SetScript("OnClick", function()
      SetSort(column.key)
    end)
    header:SetScript("OnEnter", function()
      text:SetTextColor(1, 1, 1)
    end)
    header:SetScript("OnLeave", function()
      text:SetTextColor(1, 0.82, 0)
    end)

    table.insert(headers, header)
    x = x + column.width + COL_GAP
  end

  local divider = panel:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(1, 1, 1, 0.15)
  divider:SetHeight(1)
  divider:SetPoint("TOPLEFT", LEFT, ROWS_Y + 1)
  divider:SetWidth(CONTENT_WIDTH)

  -- Scrolling list
  scrollFrame = CreateFrame("ScrollFrame", "ProfitSortScrollFrame", panel, "FauxScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", LEFT, ROWS_Y)
  scrollFrame:SetSize(CONTENT_WIDTH, NUM_ROWS * ROW_HEIGHT)
  scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
      UI:UpdateRows()
    end)
  end)

  for i = 1, NUM_ROWS do
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(CONTENT_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", LEFT, ROWS_Y - (i - 1) * ROW_HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    if i % 2 == 0 then
      local stripe = row:CreateTexture(nil, "BACKGROUND")
      stripe:SetAllPoints()
      stripe:SetColorTexture(1, 1, 1, 0.03)
    end

    row.selected = row:CreateTexture(nil, "BORDER")
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(1, 0.82, 0, 0.18)
    row.selected:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 0, 0)

    row.cells = {}
    local cellX = 0
    for c, column in ipairs(COLUMNS) do
      local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      cell:SetJustifyH(column.justify)
      cell:SetWordWrap(false)
      cell:SetHeight(ROW_HEIGHT)
      if c == 1 then
        cell:SetPoint("LEFT", cellX + ICON_SPACE, 0)
        cell:SetWidth(column.width - ICON_SPACE)
      else
        cell:SetPoint("LEFT", cellX, 0)
        cell:SetWidth(column.width)
      end
      row.cells[column.key] = cell
      cellX = cellX + column.width + COL_GAP
    end

    row:SetScript("OnClick", RowOnClick)
    row:SetScript("OnEnter", RowOnEnter)
    row:SetScript("OnLeave", RowOnLeave)
    rows[i] = row
  end

  -- Footer
  local craftable = CreateCheck("Craftable now", "craftableOnly",
    "Only show recipes you have the reagents for right now.")
  craftable:SetPoint("BOTTOMLEFT", 10, 8)

  local priced = CreateCheck("Has AH price", "hideUnpriced",
    "Hide recipes whose crafted item has no Auctionator price.")
  priced:SetPoint("LEFT", craftable.label, "RIGHT", 12, 0)

  local owned = CreateCheck("Owned free", "ownedFree",
    "Count reagents already in your bags and bank as free, so Cost and Profit show what crafting from your own stock earns.")
  owned:SetPoint("LEFT", priced.label, "RIGHT", 12, 0)

  status = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  status:SetPoint("BOTTOMRIGHT", -14, 14)
  status:SetJustifyH("RIGHT")

  -- Small button that reopens the panel after it was closed
  toggle = CreateFrame("Button", "ProfitSortToggle", UIParent, "UIPanelButtonTemplate")
  toggle:SetSize(64, 22)
  toggle:SetText("Profit")
  toggle:SetScript("OnClick", function()
    ProfitSortDB.shown = true
    UI:UpdateVisibility()
  end)
  toggle:Hide()
end

function UI:UpdateRows()
  if not panel then
    return
  end
  FauxScrollFrame_Update(scrollFrame, #entries, NUM_ROWS, ROW_HEIGHT)
  local offset = FauxScrollFrame_GetOffset(scrollFrame)

  for i, row in ipairs(rows) do
    local entry = entries[offset + i]
    row.entry = entry
    if entry then
      row.icon:SetTexture(entry.icon)

      local name = entry.name
      if entry.numAvailable > 0 then
        name = name .. " |cff80ff80[" .. entry.numAvailable .. "]|r"
      end
      row.cells.name:SetText(name)
      local color = entry.color
      if color then
        row.cells.name:SetTextColor(color.r, color.g, color.b)
      else
        row.cells.name:SetTextColor(1, 1, 1)
      end

      local warning = entry.missingReagents and "|cffff8000*|r" or ""
      row.cells.cost:SetText(ns.FormatMoney(entry.cost) .. warning)
      row.cells.value:SetText(ns.FormatMoney(entry.value))
      row.cells.profit:SetText(ns.FormatMoney(entry.profit))
      row.cells.margin:SetText(ns.FormatMargin(entry.margin))
      row.selected:SetShown(entry.key == selectedKey)
      row:Show()
    else
      row:Hide()
    end
  end
end

function UI:Refresh()
  if not (panel and provider and panel:IsShown()) then
    return
  end

  local all = provider.Scan()
  wipe(entries)
  local pricedCount = 0
  for _, entry in ipairs(all) do
    ns.Evaluate(entry, ProfitSortDB.ownedFree)
    if entry.unitAH then
      pricedCount = pricedCount + 1
    end
    local keep = true
    if ProfitSortDB.craftableOnly and entry.numAvailable <= 0 then
      keep = false
    end
    if ProfitSortDB.hideUnpriced and entry.value == nil then
      keep = false
    end
    if keep then
      table.insert(entries, entry)
    end
  end
  ns.SortEntries(entries, ProfitSortDB.sortKey, ProfitSortDB.ascending)

  panel.title:SetText("Profit - " .. (provider.GetTitle() or "Profession"))
  if #all > 0 and pricedCount == 0 then
    status:SetText("|cffff8000No AH prices yet - scan at the AH|r")
  else
    status:SetText(("%d/%d priced"):format(pricedCount, #all))
  end

  for _, header in ipairs(headers) do
    if header.key == ProfitSortDB.sortKey then
      if ProfitSortDB.ascending then
        header.arrow:SetTexCoord(0, 0.5625, 1, 0)
      else
        header.arrow:SetTexCoord(0, 0.5625, 0, 1)
      end
      header.arrow:Show()
    else
      header.arrow:Hide()
    end
  end

  self:UpdateRows()
end

function UI:UpdateVisibility()
  if not panel then
    return
  end
  local attached = provider ~= nil
  panel:SetShown(attached and ProfitSortDB.shown)
  toggle:SetShown(attached and not ProfitSortDB.shown)
  if panel:IsShown() then
    self:Refresh()
  end
end

function UI:Attach(newProvider)
  if not panel then
    Create()
  end
  provider = newProvider
  dockParent = newProvider.GetFrame()
  selectedKey = nil
  ApplyPosition()
  self:UpdateVisibility()
end

function UI:Detach()
  provider = nil
  dockParent = nil
  if panel then
    panel:Hide()
    toggle:Hide()
  end
end

function UI:ResetPosition()
  ProfitSortDB.position = nil
  if panel then
    ApplyPosition()
  end
end

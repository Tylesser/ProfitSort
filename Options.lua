local addonName, ns = ...
local L = ns.L

-- Options page: Esc > Options > AddOns > Tylesser - Auctionator Profit Sort
local TITLE = "Tylesser - Auctionator Profit Sort"

local function CreateCheck(parent, anchor, label, description, get, set)
  local check = ns.T.Check(parent, label)
  if anchor then
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -26, -14)
  else
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, ns.T.OPTIONS_TOP)
  end

  local help = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  help:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 26, 0)
  help:SetWidth(520)
  help:SetJustifyH("LEFT")
  help:SetText(description)

  check:SetScript("OnShow", function(self)
    self:SetChecked(get())
  end)
  check:SetScript("OnClick", function(self)
    set(self:GetChecked() and true or false)
  end)
  return check, help
end

local function CreateOptions()
  local panel = CreateFrame("Frame")
  panel.name = TITLE

  ns.T.OptionsPage(panel, "Profit Sort",
    L["Profession profits from Auctionator prices."] .. " " .. L["Sort and filter options are in the profit panel itself."])

  local _, help = CreateCheck(panel, nil, L["Highlight vendor flips"],
    L["At a vendor, give items that sell for at least 10% and 1 silver more on the auction house (after the 5% cut) a green border, a \"+profit\" label and a tooltip line."]
      .. " " .. L["Same as /psort flips."],
    function()
      return ProfitSortDB.vendorFlips
    end,
    function(enabled)
      ns.SetVendorFlips(enabled)
    end)

  _, help = CreateCheck(panel, help, L["Show the profit panel with professions"],
    L["Open the profit panel next to the profession window. When off, click the addon icon there to open it."],
    function()
      return ProfitSortDB.shown
    end,
    function(enabled)
      ProfitSortDB.shown = enabled
      ns.UI:UpdateVisibility()
    end)

  _, help = CreateCheck(panel, help, L["Craft reagents when cheaper"],
    L["When a reagent is made by another recipe of the same profession and crafting it costs less than buying it, use the crafting cost."]
      .. " " .. L["The reagent tooltip shows \"crafted\" and what buying would cost."],
    function()
      return ProfitSortDB.craftReagents
    end,
    function(enabled)
      ProfitSortDB.craftReagents = enabled
      ns.RequestRefresh()
    end)

  CreateCheck(panel, help, L["Show profit in item tooltips"],
    L["Items you can craft get a line like \"Profit Sort: +2g 10s profit (cost 1g 80s)\" from your last profession scan on this character."]
      .. " " .. L["Only while Auctionator has a price for the item."],
    function()
      return ProfitSortDB.itemTooltips
    end,
    function(enabled)
      ProfitSortDB.itemTooltips = enabled
    end)

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
  ns.optionsPanel = panel

  ns.T.AddCompartment({
    text = TITLE,
    onClick = ns.OpenOptions,
    tooltip = {L["Profession profits from Auctionator prices."], L["Click to open the options."]},
  })
end

function ns.OpenOptions()
  if ns.optionsCategory and Settings and Settings.OpenToCategory then
    local id = ns.optionsCategory.GetID and ns.optionsCategory:GetID() or ns.optionsCategory.ID
    Settings.OpenToCategory(id)
  elseif ns.optionsPanel and InterfaceOptionsFrame_OpenToCategory then
    -- called twice: the first call only opens the frame on older clients
    InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, loadedName)
  if loadedName == addonName then
    CreateOptions()
    self:UnregisterEvent("ADDON_LOADED")
  end
end)

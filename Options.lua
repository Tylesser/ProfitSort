local addonName, ns = ...

-- Options page: Esc > Options > AddOns > Tylesser - Auctionator Profit Sort
local TITLE = "Tylesser - Auctionator Profit Sort"

local function CreateCheck(parent, anchor, label, description, get, set)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
  local text = check.Text or check.text
  if not text then
    text = check:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", check, "RIGHT", 2, 0)
  end
  text:SetFontObject("GameFontHighlight")
  text:SetText(label)

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

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(TITLE)

  local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  subtitle:SetText("Profession profits from Auctionator prices. Sort and filter options are in the profit panel itself.")

  local _, help = CreateCheck(panel, subtitle, "Highlight vendor flips",
    "At a vendor, give items that sell for at least 10% and 1 silver more on the auction house "
      .. "(after the 5% cut) a green border, a \"+profit\" label and a tooltip line. Same as /psort flips.",
    function()
      return ProfitSortDB.vendorFlips
    end,
    function(enabled)
      ns.SetVendorFlips(enabled)
    end)

  CreateCheck(panel, help, "Show the profit panel with professions",
    "Open the profit panel next to the profession window. When off, click the addon icon there to open it.",
    function()
      return ProfitSortDB.shown
    end,
    function(enabled)
      ProfitSortDB.shown = enabled
      ns.UI:UpdateVisibility()
    end)

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
  ns.optionsPanel = panel
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

local addonName, ns = ...
local L = ns.L

-- Options page: Esc > Options > AddOns > Tylesser - Auctionator Profit Sort
local TITLE = "Tylesser - Auctionator Profit Sort"

local function CreateCheck(parent, anchor, label, description, get, set)
  local check = ns.T.Check(parent, label)
  if anchor then
    -- a line between two options (the user's request, 2026-11-28: the page's sections ran together)
    local divider = ns.T.Divider(parent, 540, 13)
    divider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -26, -6)
    check:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -6)
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

  _, help = CreateCheck(panel, help, L["Show profit in item tooltips"],
    L["Items you can craft get a line like \"Profit Sort: +2g 10s profit (cost 1g 80s)\" from your last profession scan on this character."]
      .. " " .. L["Only while Auctionator has a price for the item."],
    function()
      return ProfitSortDB.itemTooltips
    end,
    function(enabled)
      ProfitSortDB.itemTooltips = enabled
    end)

  _, help = CreateCheck(panel, help, L["Owned free counts your other characters"],
    L["With Owned free ticked in the panel, reagents in your other characters' bags, bank and mail (same realm and faction) count as free too. The reagent tooltip says who has them."]
      .. " " .. L["Needs Syndicator (it comes with Baganator)."],
    function()
      return ProfitSortDB.ownedAlts
    end,
    function(enabled)
      ProfitSortDB.ownedAlts = enabled
      ns.RequestRefresh()
    end)

  CreateCheck(panel, help, L["Tell me when a crafting cooldown is ready"],
    L["A chat line at login, and while you play, when a cooldown of this character (such as a transmute) is over. The clock on the profit panel and /psort cooldowns list every character's cooldowns."],
    function()
      return ProfitSortDB.cooldownNote
    end,
    function(enabled)
      ProfitSortDB.cooldownNote = enabled
      if enabled then
        ns.ScheduleCooldownNote()
      end
    end)

  -- shown in Tylesser's own settings window (Tylesser.lua T.RegisterOptions, 2026-11-28)
  ns.optionsCategory = ns.T.RegisterOptions(panel, TITLE)
  ns.optionsPanel = panel

  ns.T.AddCompartment({
    text = TITLE,
    onClick = ns.OpenOptions,
    tooltip = {L["Profession profits from Auctionator prices."], L["Click to open the options."]},
  })
end

function ns.OpenOptions()
  ns.T.OpenOptions(ns.optionsCategory)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, loadedName)
  if loadedName == addonName then
    CreateOptions()
    self:UnregisterEvent("ADDON_LOADED")
  end
end)

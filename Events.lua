local addonName, ns = ...

local eventFrame = CreateFrame("Frame")
local active
local hookedFrames = {}

local refreshPending = false
function ns.RequestRefresh()
  if refreshPending or not active then
    return
  end
  refreshPending = true
  C_Timer.After(0.2, function()
    refreshPending = false
    if active then
      ns.UI:Refresh()
    end
  end)
end

local function Activate(provider)
  if not provider or not provider.IsAvailable() then
    return
  end
  local parent = provider.GetFrame()
  if not parent then
    return
  end
  if not hookedFrames[parent] then
    hookedFrames[parent] = true
    parent:HookScript("OnHide", function()
      ns.Deactivate(provider)
    end)
  end
  active = provider
  ns.UI:Attach(provider)
end

function ns.Deactivate(provider)
  if active ~= provider then
    return
  end
  active = nil
  ns.UI:Detach()

  -- Another profession window (e.g. Enchanting next to Tailoring) may still be open.
  for _, other in pairs(ns.Providers) do
    if other ~= provider and other.IsAvailable() then
      local frame = other.GetFrame()
      if frame and frame:IsShown() then
        Activate(other)
        return
      end
    end
  end
end

local function DetectTradeSkillProvider()
  local providers = ns.Providers
  if ProfessionsFrame and ProfessionsFrame:IsShown() and providers.Professions.IsAvailable() then
    return providers.Professions
  end
  if TradeSkillFrame and TradeSkillFrame:IsShown() and providers.TradeSkill.IsAvailable() then
    return providers.TradeSkill
  end
  return nil
end

-- The Blizzard window is created/shown by its own TRADE_SKILL_SHOW handler,
-- which may run after ours, so look for it a little later.
local function ActivateTradeSkill(retries)
  local provider = DetectTradeSkillProvider()
  if provider then
    Activate(provider)
  elseif retries > 0 then
    C_Timer.After(0.2, function()
      ActivateTradeSkill(retries - 1)
    end)
  end
end

local function ActivateCraft(retries)
  if CraftFrame and CraftFrame:IsShown() then
    Activate(ns.Providers.Craft)
  elseif retries > 0 then
    C_Timer.After(0.2, function()
      ActivateCraft(retries - 1)
    end)
  end
end

local handlers = {
  ADDON_LOADED = function(loadedName)
    if loadedName ~= addonName then
      return
    end
    ProfitSortDB = ProfitSortDB or {}
    for key, value in pairs(ns.defaults) do
      if ProfitSortDB[key] == nil then
        ProfitSortDB[key] = value
      end
    end
  end,
  PLAYER_LOGIN = function()
    ns.CallAuctionator("RegisterForDBUpdate", ns.RequestRefresh)
  end,
  TRADE_SKILL_SHOW = function()
    C_Timer.After(0, function()
      ActivateTradeSkill(3)
    end)
  end,
  TRADE_SKILL_CLOSE = function()
    ns.Deactivate(ns.Providers.TradeSkill)
    ns.Deactivate(ns.Providers.Professions)
  end,
  CRAFT_SHOW = function()
    C_Timer.After(0, function()
      ActivateCraft(3)
    end)
  end,
  CRAFT_CLOSE = function()
    ns.Deactivate(ns.Providers.Craft)
  end,
}

local refreshEvents = {
  "TRADE_SKILL_UPDATE",
  "TRADE_SKILL_FILTER_UPDATE",
  "TRADE_SKILL_LIST_UPDATE",
  "TRADE_SKILL_DATA_SOURCE_CHANGED",
  "CRAFT_UPDATE",
  "BAG_UPDATE_DELAYED",
  "GET_ITEM_INFO_RECEIVED",
}

-- Some events only exist on some clients; registering an unknown one errors.
local function SafeRegister(event)
  pcall(eventFrame.RegisterEvent, eventFrame, event)
end

for event in pairs(handlers) do
  SafeRegister(event)
end
for _, event in ipairs(refreshEvents) do
  SafeRegister(event)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local handler = handlers[event]
  if handler then
    handler(...)
  else
    ns.RequestRefresh()
  end
end)

SLASH_PROFITSORT1 = "/profitsort"
SLASH_PROFITSORT2 = "/psort"
SlashCmdList.PROFITSORT = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "reset" then
    ns.UI:ResetPosition()
    print("|cffffd700Tylesser - Auctionator Profit Sort|r: panel docked to the profession window again.")
    return
  end
  if msg == "options" or msg == "config" then
    ns.OpenOptions()
    return
  end
  if msg == "flips" then
    ns.SetVendorFlips(not ProfitSortDB.vendorFlips)
    print("|cffffd700Tylesser - Auctionator Profit Sort|r: vendor flip marks " ..
      (ProfitSortDB.vendorFlips and "on." or "off."))
    return
  end
  ProfitSortDB.shown = not ProfitSortDB.shown
  ns.UI:UpdateVisibility()
  if not active then
    print("|cffffd700Tylesser - Auctionator Profit Sort|r: open a profession window to see the profit list.")
  end
end

local addonName, ns = ...

-- Flip finder: at a vendor, items whose Auctionator price (after the 5% AH
-- cut) beats the vendor price by at least 1 silver and 10% get a green
-- border, a "+profit" label and a tooltip line.
--
-- Marks are drawn from whatever item each vendor slot shows (its button ID
-- is the real merchant index), so they stay right when another addon such
-- as Tylesser - Vendor Search refills or filters the vendor pages.
local MIN_FLIP_PROFIT = 100
local MIN_FLIP_RATIO = 0.1
local WATCH_INTERVAL = 0.25

local marks = {}
local flipCache = {}

local function GetMerchantItem(index)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local info = C_MerchantFrame.GetItemInfo(index)
    if info then
      return info.price, info.stackCount, info.hasExtendedCost
    end
    return nil
  end
  local _, _, price, stackCount, _, _, _, hasExtendedCost = GetMerchantItemInfo(index)
  return price, stackCount, hasExtendedCost
end

-- Profit in copper if the vendor item is a flip, otherwise nil.
function ns.VendorFlip(index)
  local cached = flipCache[index]
  if cached ~= nil then
    return cached or nil
  end
  local result = false
  local price, stackCount, hasExtendedCost = GetMerchantItem(index)
  local link = GetMerchantItemLink(index)
  if link and price and price > 0 and not hasExtendedCost then
    local unitAH = ns.GetAuctionPrice(link, ns.ItemIDFromLink(link))
    if unitAH then
      local profit = math.floor(unitAH * (stackCount or 1) * ns.AH_CUT) - price
      if profit >= math.max(MIN_FLIP_PROFIT, price * MIN_FLIP_RATIO) then
        result = profit
      end
    end
  end
  flipCache[index] = result
  return result or nil
end

local function ShortMoney(copper)
  if copper >= 10000 then
    return math.floor(copper / 10000) .. "g"
  elseif copper >= 100 then
    return math.floor(copper / 100) .. "s"
  end
  return copper .. "c"
end

local function Mark(i, merchantButton, itemButton)
  local mark = marks[i]
  if not mark then
    mark = {}
    local width = itemButton:GetWidth()
    if not width or width == 0 then
      width = 37
    end
    mark.border = itemButton:CreateTexture(nil, "OVERLAY")
    mark.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    mark.border:SetBlendMode("ADD")
    mark.border:SetVertexColor(0.2, 1, 0.35)
    mark.border:SetSize(width * 1.8, width * 1.8)
    mark.border:SetPoint("CENTER", itemButton, "CENTER")
    mark.text = merchantButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mark.text:SetPoint("BOTTOMRIGHT", merchantButton, "BOTTOMRIGHT", -2, 3)
    mark.text:SetTextColor(0.25, 1, 0.4)
    marks[i] = mark
  end
  return mark
end

local function SlotCount()
  return MERCHANT_ITEMS_PER_PAGE or 10
end

local function SlotButtons(i)
  local merchantButton = _G["MerchantItem" .. i]
  local itemButton = _G["MerchantItem" .. i .. "ItemButton"] or (merchantButton and merchantButton.ItemButton)
  return merchantButton, itemButton
end

local function IsOnMerchantTab()
  return ProfitSortDB and ProfitSortDB.vendorFlips and MerchantFrame and MerchantFrame:IsShown()
    and MerchantFrame.selectedTab == 1
end

function ns.UpdateVendorFlips()
  local active = IsOnMerchantTab()
  for i = 1, SlotCount() do
    local merchantButton, itemButton = SlotButtons(i)
    local profit
    if active and merchantButton and itemButton and itemButton:IsShown() and itemButton:GetID() then
      profit = ns.VendorFlip(itemButton:GetID())
    end
    if profit then
      local mark = Mark(i, merchantButton, itemButton)
      mark.text:SetText("+" .. ShortMoney(profit))
      mark.border:Show()
      mark.text:Show()
    elseif marks[i] then
      marks[i].border:Hide()
      marks[i].text:Hide()
    end
  end
end

local function Invalidate()
  wipe(flipCache)
  ns.UpdateVendorFlips()
end

-- What every slot shows; when it changes, the marks are redrawn. This catches
-- page turns, filters and other addons refilling the vendor slots.
local function SlotSignature()
  local parts = {tostring(MerchantFrame.selectedTab)}
  for i = 1, SlotCount() do
    local _, itemButton = SlotButtons(i)
    if itemButton and itemButton:IsShown() then
      parts[#parts + 1] = tostring(itemButton:GetID())
    else
      parts[#parts + 1] = "-"
    end
  end
  return table.concat(parts, ",")
end

local watcher = CreateFrame("Frame")
local elapsedSince, lastSignature = 0, nil
local function Watch(_, elapsed)
  elapsedSince = elapsedSince + elapsed
  if elapsedSince < WATCH_INTERVAL then
    return
  end
  elapsedSince = 0
  local signature = SlotSignature()
  if signature ~= lastSignature then
    lastSignature = signature
    ns.UpdateVendorFlips()
  end
end

local function OnMerchantShow()
  wipe(flipCache)
  lastSignature = nil
  elapsedSince = WATCH_INTERVAL
  watcher:SetScript("OnUpdate", Watch)
  ns.UpdateVendorFlips()
end

local function OnMerchantHide()
  watcher:SetScript("OnUpdate", nil)
  wipe(flipCache)
  ns.UpdateVendorFlips()
end

function ns.SetVendorFlips(enabled)
  ProfitSortDB.vendorFlips = enabled
  ns.UpdateVendorFlips()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, loadedName)
  if event == "ADDON_LOADED" then
    if loadedName ~= addonName or not MerchantFrame then
      return
    end
    MerchantFrame:HookScript("OnShow", OnMerchantShow)
    MerchantFrame:HookScript("OnHide", OnMerchantHide)
    if MerchantFrame_UpdateMerchantInfo then
      hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
        -- after every other hook on the same update has run
        C_Timer.After(0, ns.UpdateVendorFlips)
      end)
    end
    if GameTooltip.SetMerchantItem then
      hooksecurefunc(GameTooltip, "SetMerchantItem", function(tooltip, index)
        if not (ProfitSortDB and ProfitSortDB.vendorFlips) then
          return
        end
        local profit = ns.VendorFlip(index)
        if profit then
          local text = GetCoinTextureString and GetCoinTextureString(profit) or ShortMoney(profit)
          tooltip:AddLine("Profit Sort: flip, +" .. text .. " on the AH after the 5% cut", 0.25, 1, 0.4)
          tooltip:Show()
        end
      end)
    end
    ns.CallAuctionator("RegisterForDBUpdate", Invalidate)
    pcall(self.RegisterEvent, self, "MERCHANT_UPDATE")
    self:UnregisterEvent("ADDON_LOADED")
  elseif event == "MERCHANT_UPDATE" then
    Invalidate()
  end
end)

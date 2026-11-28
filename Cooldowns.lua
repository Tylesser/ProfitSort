local _, ns = ...
local L = ns.L

-- Crafting cooldowns (transmutes, Mooncloth and the like) of all your characters. The profession window tells
-- the addon about a recipe's cooldown while it runs (provider.Cooldowns(), Providers.lua), so a recipe shows up
-- here once you have used it with its profession window open. Kept account-wide in ProfitSortDB.cooldowns (see
-- Core.lua) with the time it is ready again (time(), so it holds across sessions and characters).
-- The list is the clock button's tooltip on the panel and /psort cooldowns; a chat line tells you when one of
-- this character's cooldowns is ready (option cooldownNote).

local function Plain(text)
  if type(text) ~= "string" or text == "" or (issecretvalue and issecretvalue(text)) then
    return nil
  end
  return text
end

-- "Name-Realm" of this character. Forever's UnitName gave a surname after a space in some sessions and
-- GetRealmName "" for a whole session, so the first word is used and the last realm seen stands in for "".
function ns.CharacterKey()
  local ok, name = pcall(UnitName, "player")
  name = ok and Plain(name)
  name = name and (name:match("^[^%s]+") or name) or "?"
  local realm = Plain(GetNormalizedRealmName and GetNormalizedRealmName())
    or Plain(GetRealmName and GetRealmName())
  if realm then
    ProfitSortDB.lastRealm = realm
  else
    realm = ProfitSortDB.lastRealm or "?"
  end
  return name .. "-" .. realm, name
end

local function Store()
  ProfitSortDB.cooldowns = ProfitSortDB.cooldowns or {}
  return ProfitSortDB.cooldowns
end

local function Me()
  local key, name = ns.CharacterKey()
  local store = Store()
  local me = store[key]
  if not me then
    me = {recipes = {}}
    store[key] = me
  end
  me.recipes = me.recipes or {}
  me.name = name
  me.class = select(2, UnitClass("player"))
  return me, key
end

local function Number(value)
  if type(value) ~= "number" or (issecretvalue and issecretvalue(value)) then
    return nil
  end
  return value
end

-- Remembers the cooldowns one profession window shows. list = provider.Cooldowns(): { { name, icon, cooldown
-- (seconds left or nil), charges, maxCharges } } for the recipes the window lists. A recipe on cooldown (or with
-- charges) is stored with the time it is ready; a stored recipe the window lists without one is ready now.
function ns.RememberCooldowns(list, prof)
  if type(list) ~= "table" then
    return 0
  end
  local me = Me()
  local now = time()
  local stored = 0
  for _, item in ipairs(list) do
    local name = Plain(item.name)
    if name then
      local left = Number(item.cooldown)
      local charges, maxCharges = Number(item.charges), Number(item.maxCharges)
      local record = me.recipes[name]
      if (left and left > 0) or (maxCharges and maxCharges > 0) then
        local readyAt = now
        if not (charges and charges > 0) then
          readyAt = now + math.floor(left or 0)
        end
        if readyAt <= now and record and record.readyAt and record.readyAt <= now then
          readyAt = record.readyAt -- still ready (charges left): it stays told
        end
        record = record or {}
        -- a new cooldown (used again): tell again once it is over
        if not record.readyAt or math.abs(record.readyAt - readyAt) > 120 then
          record.told = nil
        end
        record.readyAt, record.prof, record.icon = readyAt, prof or record.prof, item.icon or record.icon
        record.charges, record.maxCharges = charges, maxCharges
        me.recipes[name] = record
        stored = stored + 1
      elseif record and record.readyAt and record.readyAt > now then
        record.readyAt = now -- the window shows no cooldown any more (a day cooldown ends at midnight)
      end
    end
  end
  if stored > 0 then
    ns.ScheduleCooldownNote()
  end
  return stored
end

-- "3 hr 12 min" in the client's language (the game's SecondsToTime), else "3h 12m".
function ns.CooldownTime(seconds)
  seconds = math.max(0, math.floor(seconds))
  if SecondsToTime then
    local ok, text = pcall(SecondsToTime, seconds, true, false, 2)
    if ok and type(text) == "string" and text ~= "" then
      return text
    end
  end
  local days, hours, minutes = math.floor(seconds / 86400), math.floor(seconds / 3600) % 24, math.floor(seconds / 60) % 60
  if days > 0 then
    return ("%dd %dh"):format(days, hours)
  elseif hours > 0 then
    return ("%dh %dm"):format(hours, minutes)
  end
  return ("%dm"):format(math.max(1, minutes))
end

-- One character's cooldowns as groups: recipes of one profession ready at the same time (Classic's transmutes
-- share one cooldown) are one group. { { names = { ... }, readyAt, prof, icon }, ... } ready first, then soonest.
local function Groups(char)
  local byTime, groups = {}, {}
  for name, record in pairs(char.recipes or {}) do
    if type(record) == "table" and record.readyAt then
      local key = (record.prof or "") .. ":" .. math.floor(record.readyAt / 60)
      local group = byTime[key]
      if not group then
        group = {names = {}, readyAt = record.readyAt, prof = record.prof, icon = record.icon, records = {}}
        byTime[key] = group
        table.insert(groups, group)
      end
      table.insert(group.names, name)
      table.insert(group.records, record)
    end
  end
  for _, group in ipairs(groups) do
    table.sort(group.names)
  end
  table.sort(groups, function(a, b)
    if a.readyAt ~= b.readyAt then
      return a.readyAt < b.readyAt
    end
    return a.names[1] < b.names[1]
  end)
  return groups
end
ns.CooldownGroups = Groups

-- "Transmute: Arcanite Bar" or "Transmute: Arcanite Bar (+6)" for a group.
local function GroupName(group)
  if #group.names > 1 then
    return L["%s (+%d)"]:format(group.names[1], #group.names - 1)
  end
  return group.names[1]
end

-- { { key, name, class, mine, groups }, ... }: this character first, then by name; characters without
-- cooldowns are left out.
function ns.CooldownCharacters()
  local mine = ns.CharacterKey()
  local list = {}
  for key, char in pairs(Store()) do
    if type(char) == "table" then
      local groups = Groups(char)
      if #groups > 0 then
        table.insert(list, {key = key, name = char.name or key, class = char.class, mine = key == mine, groups = groups})
      end
    end
  end
  table.sort(list, function(a, b)
    if a.mine ~= b.mine then
      return a.mine
    end
    return a.key < b.key
  end)
  return list
end

-- { left text, right text, ready } per line of the list (with a heading line per character: right = nil).
function ns.CooldownLines()
  local now = time()
  local lines = {}
  for _, char in ipairs(ns.CooldownCharacters()) do
    table.insert(lines, {char.name, nil, nil, class = char.class})
    for _, group in ipairs(char.groups) do
      local ready = group.readyAt <= now
      table.insert(lines, {"  " .. GroupName(group),
        ready and L["Ready"] or ns.CooldownTime(group.readyAt - now), ready})
    end
  end
  return lines
end

local function ClassColor(class)
  local colors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
  local color = class and colors and colors[class]
  if color then
    return color.r, color.g, color.b
  end
  return 1, 0.82, 0
end

-- Fills a tooltip with the list (the panel's clock button).
function ns.AddCooldownLines(tooltip)
  local lines = ns.CooldownLines()
  if #lines == 0 then
    tooltip:AddLine(L["No crafting cooldowns yet."], 1, 1, 1, true)
    tooltip:AddLine(L["A recipe with a cooldown (such as a transmute) shows up here after you use it with its profession window open."], 0.6, 0.6, 0.6, true)
    return
  end
  for _, line in ipairs(lines) do
    if line[2] == nil then
      tooltip:AddLine(line[1], ClassColor(line.class))
    elseif line[3] then
      tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 0.25, 1, 0.25)
    else
      tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1)
    end
  end
end

-- How many cooldown groups of this character are ready.
function ns.ReadyCooldowns()
  local me = Store()[ns.CharacterKey()]
  local now, count = time(), 0
  for _, group in ipairs(me and Groups(me) or {}) do
    if group.readyAt <= now then
      count = count + 1
    end
  end
  return count
end

-- /psort cooldowns
function ns.PrintCooldowns()
  local lines = ns.CooldownLines()
  if #lines == 0 then
    print(ns.PREFIX .. L["No crafting cooldowns yet."] .. " "
      .. L["A recipe with a cooldown (such as a transmute) shows up here after you use it with its profession window open."])
    return
  end
  print(ns.PREFIX .. L["Crafting cooldowns:"])
  for _, line in ipairs(lines) do
    if line[2] == nil then
      print(line[1])
    else
      print(line[1] .. ": " .. (line[3] and "|cff40ff40" or "") .. line[2] .. (line[3] and "|r" or ""))
    end
  end
end

-- The chat line: this character's cooldowns that are ready and not told yet ("ready again: A, B."). Each is told
-- once per cooldown. Returns how many were told.
function ns.CooldownNote()
  if not ProfitSortDB.cooldownNote then
    return 0
  end
  local me = Store()[ns.CharacterKey()]
  if not me then
    return 0
  end
  local now = time()
  local names = {}
  for _, group in ipairs(Groups(me)) do
    if group.readyAt <= now then
      local new = false
      for _, record in ipairs(group.records) do
        if not record.told then
          new = true
          record.told = true
        end
      end
      if new then
        table.insert(names, GroupName(group))
      end
    end
  end
  if #names > 0 then
    print(ns.PREFIX .. L["crafting cooldown ready: %s."]:format(table.concat(names, ", ")))
  end
  return #names
end

-- Tells now what is ready, and again when this character's next cooldown is over (within this session).
local noteToken = 0
function ns.ScheduleCooldownNote()
  noteToken = noteToken + 1
  local token = noteToken
  ns.CooldownNote()
  local me = Store()[ns.CharacterKey()]
  local now, soonest = time(), nil
  for _, record in pairs(me and me.recipes or {}) do
    if type(record) == "table" and record.readyAt and record.readyAt > now and not record.told then
      soonest = math.min(soonest or math.huge, record.readyAt)
    end
  end
  if soonest and C_Timer and soonest - now < 2 * 86400 then
    C_Timer.After(soonest - now + 2, function()
      if token == noteToken then
        ns.ScheduleCooldownNote()
      end
    end)
  end
end

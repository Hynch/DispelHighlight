-- Dispel Highlight: minimalist dispel helper.
-- Highlights party/raid frames of units afflicted by a debuff the player can dispel.

local ADDON, ns = ...

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
local defaults = {
    enabled   = true,
    sound     = "alarm",   -- preset name, numeric SoundKit ID, file path, or "off"
    thickness = 2,
    fill      = true,      -- faint colored fill inside the border
    override  = nil,       -- manual list of dispel types, e.g. { Magic = true }
    sounds    = {},        -- per-school overrides: { Magic = "bell", Poison = 8959, ... }
    hideMinimap  = false,  -- hide the minimap button
    minimapAngle = 215,    -- minimap button position (degrees)
}

local COLORS = {
    Magic   = { 0.20, 0.60, 1.00 },
    Curse   = { 0.70, 0.20, 1.00 },
    Disease = { 0.65, 0.45, 0.15 },
    Poison  = { 0.10, 0.85, 0.20 },
    Unknown = { 1.00, 0.55, 0.00 },   -- dispellable, but type hidden by the client
}

local SCHOOLS = { "Magic", "Curse", "Poison", "Disease", "Unknown" }

local function MatchSchool(word)
    if not word or word == "" then return nil end
    local w = word:sub(1, 1):upper() .. word:sub(2):lower()
    if w == "Other" then return "Unknown" end
    return COLORS[w] and w or nil
end

-- Sound presets (numeric SoundKit IDs). Add your own, or use /dh sound <id|path>.
local PRESETS = {
    alarm     = 12889,
    raid      = 8959,
    ready     = 8960,
    bell      = 5274,
    quest     = 618,
}

-- Spell IDs (all ranks) that grant each dispel type. Edit if Forever changes them.
-- If detection ever misses something, use /dh types Magic Poison ... to override.
local DISPEL_SPELLS = {
    PRIEST  = { Magic = { 527, 988 },  Disease = { 528, 552 } },
    PALADIN = { Magic = { 4987 },      Poison = { 1152, 4987 }, Disease = { 1152, 4987 } },
    SHAMAN  = { Poison = { 526 },      Disease = { 2870 } },
    DRUID   = { Curse = { 2782 },      Poison = { 8946, 2893 } },
    MAGE    = { Curse = { 475 } },
}

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local db
local myTypes = {}          -- [dispelType] = true
local overlays = {}         -- [frame] = overlay
local lastSound = 0
local alerted = {}          -- [unit guid] = true while afflicted (sound once per onset)

local function Print(msg) print("|cff33ccffDispelHighlight:|r " .. tostring(msg)) end

----------------------------------------------------------------------
-- What can I dispel?
----------------------------------------------------------------------
local function Known(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return false
end

local function RefreshDispelTypes()
    wipe(myTypes)
    if db.override then
        for t in pairs(db.override) do myTypes[t] = true end
        return
    end
    local _, class = UnitClass("player")
    local map = DISPEL_SPELLS[class]
    if not map then return end
    for dtype, ids in pairs(map) do
        for _, id in ipairs(ids) do
            if Known(id) then myTypes[dtype] = true break end
        end
    end
end

----------------------------------------------------------------------
-- Aura scan: first debuff on unit that I can dispel -> its type
----------------------------------------------------------------------
-- Returns a plain string dispel type, or nil if it can't be read
-- (aura fields can be "secret" values in combat on the modern API).
local function SafeDispelName(d)
    local ok, n = pcall(function()
        local v = d.dispelName
        if issecretvalue and issecretvalue(v) then return nil end
        if type(v) == "string" and COLORS[v] then return v end
        return nil
    end)
    return ok and n or nil
end

local function FindDispellable(unit)
    if not C_UnitAuras then return nil end

    -- Preferred: let the client decide what I can dispel.
    if C_UnitAuras.GetAuraDataByIndex then
        local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, "HARMFUL|RAID_PLAYER_DISPELLABLE")
        if ok then
            if not d then return nil end
            local n = SafeDispelName(d)
            if n then
                -- readable type: also respect my own known dispels / manual override
                if next(myTypes) and not myTypes[n] then return nil end
                return n
            end
            return "Unknown"   -- client says dispellable, but type is hidden
        end
    end

    -- Fallback: scan debuffs and match against the spells I know.
    if not next(myTypes) or not C_UnitAuras.GetDebuffDataByIndex then return nil end
    for i = 1, 40 do
        local d = C_UnitAuras.GetDebuffDataByIndex(unit, i)
        if not d then break end
        local n = SafeDispelName(d)
        if n and myTypes[n] then return n end
    end
    return nil
end

----------------------------------------------------------------------
-- Frames
----------------------------------------------------------------------
local function FrameUnit(f)
    return f and (f.displayedUnit or f.unit)
end

local frameNames = { "PlayerFrame" }
for i = 1, 4 do frameNames[#frameNames + 1] = "PartyMemberFrame" .. i end
for i = 1, 4 do frameNames[#frameNames + 1] = "PartyFrame.MemberFrame" .. i end
for i = 1, 5 do frameNames[#frameNames + 1] = "CompactPartyFrameMember" .. i end
for i = 1, 40 do frameNames[#frameNames + 1] = "CompactRaidFrame" .. i end
for g = 1, 8 do
    for m = 1, 5 do frameNames[#frameNames + 1] = "CompactRaidGroup" .. g .. "Member" .. m end
end

local function GetFrameByName(name)
    local a, b = name:match("^([^.]+)%.(.+)$")
    if a then
        local parent = _G[a]
        return parent and parent[b]
    end
    return _G[name]
end

local function MakeOverlay(f)
    local o = CreateFrame("Frame", nil, f)
    o:SetAllPoints(f)
    o:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
    o:EnableMouse(false)
    o.edges = {}
    for i = 1, 4 do o.edges[i] = o:CreateTexture(nil, "OVERLAY") end
    o.fill = o:CreateTexture(nil, "BACKGROUND")
    o.fill:SetAllPoints(o)
    o:Hide()
    return o
end

local function Layout(o)
    local t = db.thickness
    local e = o.edges
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT");     e[1]:SetPoint("TOPRIGHT");     e[1]:SetHeight(t)
    e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT");  e[2]:SetPoint("BOTTOMRIGHT");  e[2]:SetHeight(t)
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT");     e[3]:SetPoint("BOTTOMLEFT");   e[3]:SetWidth(t)
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT");    e[4]:SetPoint("BOTTOMRIGHT");  e[4]:SetWidth(t)
end

local function Show(f, dtype)
    local o = overlays[f]
    if not o then o = MakeOverlay(f); overlays[f] = o end
    local c = COLORS[dtype]
    Layout(o)
    for i = 1, 4 do o.edges[i]:SetColorTexture(c[1], c[2], c[3], 1) end
    o.fill:SetColorTexture(c[1], c[2], c[3], db.fill and 0.22 or 0)
    o:Show()
end

local function Hide(f)
    local o = overlays[f]
    if o then o:Hide() end
end

----------------------------------------------------------------------
-- Sound
----------------------------------------------------------------------
local function NormalizeSound(text)
    text = strtrim(tostring(text or ""))
    local l = text:lower()
    if PRESETS[l] or l == "off" then return l end
    return tonumber(text) or text
end

-- dtype (optional): use that school's sound, falling back to the default sound.
local function PlayAlert(force, dtype)
    local s = (dtype and db.sounds and db.sounds[dtype]) or db.sound
    if not s or s == "off" then return end
    local now = GetTime()
    if not force and now - lastSound < 1.5 then return end
    lastSound = now
    local id = PRESETS[s] or tonumber(s)
    if id then
        PlaySound(id, "Master")
    else
        PlaySoundFile(s, "Master")   -- e.g. Interface\AddOns\DispelHighlight\ding.ogg
    end
end

----------------------------------------------------------------------
-- Update logic
----------------------------------------------------------------------
local function UpdateFrame(f)
    local unit = FrameUnit(f)
    if not f:IsVisible() and not f:IsShown() then Hide(f) return end
    if not db.enabled or not unit or not UnitExists(unit)
       or not UnitIsFriend("player", unit) or UnitIsDeadOrGhost(unit) then
        Hide(f) return
    end
    local dtype = FindDispellable(unit)
    if dtype then Show(f, dtype) else Hide(f) end
end

local function UpdateUnit(unit)
    local dtype = (db.enabled and UnitExists(unit) and UnitIsFriend("player", unit)) and FindDispellable(unit) or nil
    local guid = UnitGUID(unit)
    if guid then
        if dtype and alerted[guid] ~= dtype then
            alerted[guid] = dtype
            PlayAlert(false, dtype)
        elseif not dtype then
            alerted[guid] = nil
        end
    end
    for _, name in ipairs(frameNames) do
        local f = GetFrameByName(name)
        if f then
            local fu = FrameUnit(f)
            if fu and UnitIsUnit(fu, unit) then UpdateFrame(f) end
        end
    end
end

local function UpdateAll()
    for _, name in ipairs(frameNames) do
        local f = GetFrameByName(name)
        if f then UpdateFrame(f) end
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        DispelHighlightDB = DispelHighlightDB or {}
        db = DispelHighlightDB
        for k, v in pairs(defaults) do
            if db[k] == nil then db[k] = v end
        end
        ns.db = db
        if ns.OnLoad then ns.OnLoad(db) end
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        ev:RegisterEvent("GROUP_ROSTER_UPDATE")
        ev:RegisterEvent("SPELLS_CHANGED")
        ev:RegisterEvent("UNIT_AURA")
        if hooksecurefunc and CompactUnitFrame_SetUnit then
            hooksecurefunc("CompactUnitFrame_SetUnit", function(f)
                if db and overlays[f] or (db and f.unit) then UpdateFrame(f) end
            end)
        end
    elseif event == "UNIT_AURA" then
        local unit = arg1
        if unit and (unit == "player" or unit:find("^party") or unit:find("^raid")) then
            UpdateUnit(unit)
        end
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        RefreshDispelTypes()
        UpdateAll()
    elseif event == "GROUP_ROSTER_UPDATE" then
        wipe(alerted)
        UpdateAll()
    end
end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function TypesString()
    local t = {}
    for k in pairs(myTypes) do t[#t + 1] = k end
    table.sort(t)
    return #t > 0 and table.concat(t, ", ") or "none"
end

-- Shared with UI.lua
ns.Print       = Print
ns.PRESETS     = PRESETS
ns.PlayAlert   = PlayAlert
ns.UpdateAll   = UpdateAll
ns.TypesString = TypesString
ns.COLORS         = COLORS
ns.SCHOOLS        = SCHOOLS
ns.MatchSchool    = MatchSchool
ns.NormalizeSound = NormalizeSound

function ns.Test(dtype)
    dtype = dtype or "Magic"
    PlayAlert(true, dtype)
    local f = _G["PlayerFrame"]
    if f then
        Show(f, dtype)
        C_Timer.After(2, function() UpdateAll() end)
    end
end

function ns.SetEnabled(v)
    db.enabled = v and true or false
    UpdateAll()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

SLASH_DISPELHIGHLIGHT1 = "/dh"
SLASH_DISPELHIGHLIGHT2 = "/dispelhl"
SlashCmdList["DISPELHIGHLIGHT"] = function(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "options" or cmd == "config" then
        if ns.OpenOptions then ns.OpenOptions() end
    elseif cmd == "minimap" then
        if ns.SetMinimapShown then
            ns.SetMinimapShown(db.hideMinimap)   -- flips current state
            Print("minimap button " .. (db.hideMinimap and "hidden" or "shown"))
        end
    elseif cmd == "toggle" then
        ns.SetEnabled(not db.enabled)
        Print(db.enabled and "enabled" or "disabled")
    elseif cmd == "sound" then
        local first, val = rest:match("^(%S+)%s*(.-)$")
        local school = MatchSchool(first)
        if not first then
            Print("default sound: " .. tostring(db.sound))
            for _, s in ipairs(SCHOOLS) do
                Print("  " .. s .. ": " .. tostring(db.sounds[s] or "default"))
            end
        elseif school then
            if val == "" then
                Print(school .. " sound: " .. tostring(db.sounds[school] or "default"))
            elseif val:lower() == "default" then
                db.sounds[school] = nil
                Print(school .. " sound reset to default")
            else
                db.sounds[school] = NormalizeSound(val)
                Print(school .. " sound set to: " .. tostring(db.sounds[school]))
                PlayAlert(true, school)
            end
        else
            db.sound = NormalizeSound(rest)
            Print("default sound set to: " .. tostring(db.sound))
            PlayAlert(true)
        end
        if ns.RefreshOptions then ns.RefreshOptions() end
    elseif cmd == "test" then
        ns.Test(MatchSchool(rest))
    elseif cmd == "thickness" then
        local n = tonumber(rest)
        if n and n >= 1 and n <= 8 then db.thickness = n; UpdateAll() else Print("usage: /dh thickness 1-8") end
    elseif cmd == "fill" then
        db.fill = not db.fill
        Print("fill " .. (db.fill and "on" or "off"))
        UpdateAll()
    elseif cmd == "types" then
        if rest == "" or rest:lower() == "auto" then
            db.override = nil
            RefreshDispelTypes()
            Print("auto-detect on. I can dispel: " .. TypesString())
        else
            db.override = {}
            for word in rest:gmatch("%a+") do
                local w = word:sub(1, 1):upper() .. word:sub(2):lower()
                if COLORS[w] then db.override[w] = true end
            end
            RefreshDispelTypes()
            Print("manual override. I can dispel: " .. TypesString())
        end
        UpdateAll()
    else
        Print("I can dispel: " .. TypesString())
        Print("/dh (options) | minimap | toggle | sound [school] <alarm|raid|ready|bell|quest|id|path|off|default> | test [school] | thickness <1-8> | fill | types [auto | Magic Poison ...]")
    end
end

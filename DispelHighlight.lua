-- Dispel Highlight: minimalist dispel helper.
-- Highlights party/raid frames of units afflicted by a debuff the player can dispel.
--
-- On this client addon code cannot read aura data in combat, so the addon never reads
-- auras. It asks the client's own aura container to track the debuffs the player can
-- dispel, and supplies textures that the client tints in the debuff's school color.

local ADDON, ns = ...

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
local defaults = {
    enabled      = true,
    thickness    = 2,
    fill         = true,      -- colored tint inside the border
    fillAlpha    = 25,        -- tint opacity, percent
    hideMinimap  = false,     -- hide the minimap button
    minimapAngle = 215,       -- minimap button position (degrees)
}

-- Only these four schools are shown. Debuffs with no school, or an unknown one, are ignored.
local COLORS = {
    Magic   = { 0.20, 0.60, 1.00 },
    Curse   = { 0.70, 0.20, 1.00 },
    Disease = { 0.65, 0.45, 0.15 },
    Poison  = { 0.10, 0.85, 0.20 },
}

-- The client decides which debuffs this player can dispel.
local DISPEL_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE"

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local db
local lastErr                -- last container/styling error (shown by /dh debug)
local containers = {}        -- [unit frame] = aura container
local engineButtons = {}     -- every aura button we have styled
local overlays = {}          -- [frame] = preview overlay, used only by /dh test

local function Print(msg) print("|cff33ccffDispelHighlight:|r " .. tostring(msg)) end

local function Str(v)
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    return tostring(v)
end

----------------------------------------------------------------------
-- Frames to decorate
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

----------------------------------------------------------------------
-- Aura container
----------------------------------------------------------------------
local engineOK = false
do
    local ok = pcall(function()
        local probe = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
        engineOK = probe and probe.AddAuraGroup ~= nil
        probe:Hide()
    end)
    engineOK = ok and engineOK
end

local function ColorMap()
    local map = {}
    for name, c in pairs(COLORS) do
        map[name] = CreateColor(c[1], c[2], c[3])
    end
    return map   -- no "None" entry: auras without a school are not tinted
end

local function FillAlpha()
    return db.fill and (db.fillAlpha or 25) / 100 or 0
end

local function LayoutButton(b)
    local t = db.thickness
    local e = b.dhEdges
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT");    e[1]:SetPoint("TOPRIGHT");    e[1]:SetHeight(t)
    e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(t)
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT");    e[3]:SetPoint("BOTTOMLEFT");  e[3]:SetWidth(t)
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT");   e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(t)
    -- The tint's opacity is set on a frame we own. The client controls the textures'
    -- own color, but not the opacity of a frame it did not create.
    if b.dhHolder then b.dhHolder:SetAlpha(FillAlpha()) else b.dhFill:SetAlpha(FillAlpha()) end
end

local function StyleButton(button, host)
    pcall(function()
        button:SetSize(host:GetWidth(), host:GetHeight())
        button:SetFrameLevel(host:GetFrameLevel() + 10)
        if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
        if button.EnableMouse then button:EnableMouse(false) end
    end)

    local style = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
    local opts = {
        style = style and style.PreserveAsset,
        showWhenHarmful = true,
        showWithoutDispelType = false,
        customDispelColorMap = ColorMap(),
    }

    button.dhEdges = {}
    for i = 1, 4 do
        local t = button:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 1, 1, 1)
        button.dhEdges[i] = t
        button:AddDispelTypeTexture(t, opts)
    end

    local parent = button
    local okH, holder = pcall(CreateFrame, "Frame", nil, button)
    if okH and holder then
        holder:SetAllPoints(button)
        holder:EnableMouse(false)
        button.dhHolder = holder
        parent = holder
    end
    local fill = parent:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(parent)
    fill:SetColorTexture(1, 1, 1, 1)
    button.dhFill = fill
    button:AddDispelTypeTexture(fill, opts)

    LayoutButton(button)
    engineButtons[#engineButtons + 1] = button
end

local function EnsureContainer(f)
    if not engineOK then return nil end
    local c = containers[f]
    if c then return c end
    if InCombatLockdown() then return nil end   -- containers can only be created out of combat
    local ok, err = pcall(function()
        c = CreateFrame("AuraContainer", nil, f, "CustomAuraContainerTemplate")
        c:SetAllPoints(f)
        c:SetFrameLevel(f:GetFrameLevel() + 10)
        c:AddAuraGroup("dispel", DISPEL_FILTER, {
            maxFrameCount = 1,
            initializeFrame = function(button)
                local ok2, err2 = pcall(StyleButton, button, f)
                if not ok2 then lastErr = "style: " .. tostring(err2) end
            end,
        })
    end)
    if not ok or not c then
        lastErr = "container: " .. tostring(err)
        return nil
    end
    containers[f] = c
    return c
end

local function UpdateFrame(f)
    local c = EnsureContainer(f)
    if not c then return end
    local unit = FrameUnit(f)
    pcall(function()
        if unit and db.enabled and UnitExists(unit) and UnitIsFriend("player", unit) then
            if c.dhUnit ~= unit then c:SetUnit(unit); c.dhUnit = unit end
            if c.SetEnabled then c:SetEnabled(true) end
            c:Show()
            if c.UpdateAllAuras then c:UpdateAllAuras() end
        else
            c.dhUnit = nil
            if c.SetEnabled then c:SetEnabled(false) end
            c:Hide()
        end
    end)
end

local function UpdateAll()
    for _, b in ipairs(engineButtons) do
        if b.dhEdges then pcall(LayoutButton, b) end
    end
    for _, name in ipairs(frameNames) do
        local f = GetFrameByName(name)
        if f then UpdateFrame(f) end
    end
end

----------------------------------------------------------------------
-- Test preview (a plain overlay on your own frame; does not use the container)
----------------------------------------------------------------------
local function PreviewShow(f)
    local o = overlays[f]
    if not o then
        o = CreateFrame("Frame", nil, f)
        o:SetAllPoints(f)
        o:SetFrameLevel(f:GetFrameLevel() + 12)
        o:EnableMouse(false)
        o.edges = {}
        for i = 1, 4 do o.edges[i] = o:CreateTexture(nil, "OVERLAY") end
        o.fill = o:CreateTexture(nil, "BACKGROUND")
        o.fill:SetAllPoints(o)
        overlays[f] = o
    end
    local c, t, e = COLORS.Magic, db.thickness, o.edges
    for i = 1, 4 do e[i]:SetColorTexture(c[1], c[2], c[3], 1) end
    o.fill:SetColorTexture(c[1], c[2], c[3], FillAlpha())
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT");    e[1]:SetPoint("TOPRIGHT");    e[1]:SetHeight(t)
    e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(t)
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT");    e[3]:SetPoint("BOTTOMLEFT");  e[3]:SetWidth(t)
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT");   e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(t)
    o:Show()
    C_Timer.After(2, function() o:Hide() end)
end

function ns.Test()
    local f = _G["PlayerFrame"]
    if f then PreviewShow(f) end
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
        -- Clean up settings from older versions.
        db.override, db.sounds, db.sound = nil, nil, nil
        ns.db = db
        if ns.OnLoad then ns.OnLoad(db) end
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        ev:RegisterEvent("GROUP_ROSTER_UPDATE")
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")   -- set up frames that were created in combat
        if hooksecurefunc and CompactUnitFrame_SetUnit then
            hooksecurefunc("CompactUnitFrame_SetUnit", function(f)
                local n = db and f and f.GetName and f:GetName()
                if n and (n:find("^CompactParty") or n:find("^CompactRaid")) then UpdateFrame(f) end
            end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not engineOK then
            Print("the client's aura container is not available, so the addon cannot work.")
        end
        UpdateAll()
    else
        UpdateAll()
    end
end)

----------------------------------------------------------------------
-- Shared with Options.lua
----------------------------------------------------------------------
ns.Print          = Print
ns.UpdateAll      = UpdateAll

function ns.SetEnabled(v)
    db.enabled = v and true or false
    UpdateAll()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.Debug()
    local nC = 0
    for _ in pairs(containers) do nC = nC + 1 end
    Print(("debug: inCombat=%s"):format(tostring(InCombatLockdown())))
    Print(("  AuraContainer: %s | containers=%d | styled buttons=%d"):format(
        engineOK and "available" or "NOT available", nC, #engineButtons))
    Print("  tint holder frame: " .. ((engineButtons[1] and engineButtons[1].dhHolder) and "yes" or "no (using texture alpha)"))
    Print("  last error: " .. (lastErr or "none"))
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
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
    elseif cmd == "test" then
        ns.Test()
    elseif cmd == "debug" then
        ns.Debug()
    elseif cmd == "thickness" then
        local n = tonumber(rest)
        if n and n >= 1 and n <= 8 then
            db.thickness = n
            UpdateAll()
            if ns.RefreshOptions then ns.RefreshOptions() end
        else
            Print("usage: /dh thickness 1-8")
        end
    elseif cmd == "opacity" then
        local n = tonumber(rest)
        if n and n >= 5 and n <= 100 then
            db.fillAlpha = math.floor(n)
            UpdateAll()
            if ns.RefreshOptions then ns.RefreshOptions() end
        else
            Print("usage: /dh opacity 5-100  (tint opacity in percent)")
        end
    elseif cmd == "fill" then
        db.fill = not db.fill
        Print("tint " .. (db.fill and "on" or "off"))
        UpdateAll()
        if ns.RefreshOptions then ns.RefreshOptions() end
    else
        Print("/dh (options) | minimap | toggle | test | thickness <1-8> | opacity <5-100> | fill | debug")
    end
end

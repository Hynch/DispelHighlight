-- Dispel Highlight: options panel, minimap button, and addon compartment hooks.

local ADDON, ns = ...
local db

local ICON = "Interface\\Icons\\Spell_Holy_DispelMagic"

----------------------------------------------------------------------
-- Options panel
----------------------------------------------------------------------
local panel = CreateFrame("Frame", "DispelHighlightOptionsPanel")
panel.name = "Dispel Highlight"
local widgets = {}   -- refresh callbacks

local function MakeLabel(parent, text, template, x, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function MakeCheckbox(label, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, panel)
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    local fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    widgets[#widgets + 1] = function() cb:SetChecked(get()) end
    return cb
end

local function MakeSlider(label, x, y, minV, maxV, get, set)
    MakeLabel(panel, label, "GameFontHighlight", x, y)
    local s = CreateFrame("Slider", nil, panel)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(200, 16)
    s:SetPoint("TOPLEFT", x, y - 22)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(1)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local bar = s:CreateTexture(nil, "BACKGROUND")
    bar:SetPoint("LEFT"); bar:SetPoint("RIGHT"); bar:SetHeight(4)
    bar:SetColorTexture(0.3, 0.3, 0.3, 0.9)
    local val = s:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    val:SetPoint("LEFT", s, "RIGHT", 10, 0)
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        val:SetText(v)
        if db and v ~= get() then set(v) end
    end)
    widgets[#widgets + 1] = function() s:SetValue(get()); val:SetText(get()) end
    return s
end

local function MakeButton(label, w, x, y, onClick)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local soundLabel, typesLabel, soundBox

local function BuildPanel()
    MakeLabel(panel, "Dispel Highlight", "GameFontNormalLarge", 16, -16)
    typesLabel = MakeLabel(panel, "", "GameFontHighlightSmall", 16, -42)

    MakeCheckbox("Enable addon", 16, -66,
        function() return db.enabled end,
        function(v) ns.SetEnabled(v) end)

    MakeCheckbox("Tint the frame (faint fill inside the border)", 16, -96,
        function() return db.fill end,
        function(v) db.fill = v; ns.UpdateAll() end)

    MakeCheckbox("Show minimap button", 16, -126,
        function() return not db.hideMinimap end,
        function(v) ns.SetMinimapShown(v) end)

    MakeSlider("Border thickness", 20, -170, 1, 8,
        function() return db.thickness end,
        function(v) db.thickness = v; ns.UpdateAll() end)

    -- Sound
    MakeLabel(panel, "Default sound", "GameFontHighlight", 20, -226)
    soundLabel = MakeLabel(panel, "", "GameFontHighlightSmall", 110, -228)

    local presets = { "alarm", "raid", "ready", "bell", "quest", "off" }
    local x = 16
    for _, name in ipairs(presets) do
        MakeButton(name, 58, x, -248, function()
            db.sound = name
            if name ~= "off" then ns.PlayAlert(true) end
            ns.RefreshOptions()
        end)
        x = x + 62
    end

    MakeLabel(panel, "Custom sound (SoundKit ID or file path):", "GameFontHighlightSmall", 20, -284)
    soundBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    soundBox:SetSize(260, 22)
    soundBox:SetPoint("TOPLEFT", 26, -300)
    soundBox:SetAutoFocus(false)
    soundBox:SetScript("OnEscapePressed", soundBox.ClearFocus)
    local function ApplyCustom()
        local t = strtrim(soundBox:GetText() or "")
        if t ~= "" then
            db.sound = ns.NormalizeSound(t)
            ns.PlayAlert(true)
            ns.RefreshOptions()
        end
        soundBox:ClearFocus()
    end
    soundBox:SetScript("OnEnterPressed", ApplyCustom)
    MakeButton("Apply", 60, 296, -300, ApplyCustom)

    MakeButton("Test", 80, 16, -340, function() ns.Test() end)

    -- Per-school sounds
    MakeLabel(panel, "Per-school sounds", "GameFontHighlight", 20, -384)
    MakeLabel(panel, "Preset name, SoundKit ID, file path, \"off\", or \"default\" to use the default sound.",
        "GameFontHighlightSmall", 20, -402)

    local cycle = { "default", "alarm", "raid", "ready", "bell", "quest", "off" }
    for i, school in ipairs(ns.SCHOOLS) do
        local y = -426 - (i - 1) * 30
        local c = ns.COLORS[school]
        local lbl = MakeLabel(panel, school == "Unknown" and "Other" or school, "GameFontNormal", 20, y - 4)
        lbl:SetTextColor(c[1], c[2], c[3])

        local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        box:SetSize(140, 22)
        box:SetPoint("TOPLEFT", 106, y)
        box:SetAutoFocus(false)
        box:SetScript("OnEscapePressed", box.ClearFocus)

        local function SetSchoolSound(v)
            v = strtrim(tostring(v or ""))
            if v == "" or v:lower() == "default" then
                db.sounds[school] = nil
            else
                db.sounds[school] = ns.NormalizeSound(v)
                ns.PlayAlert(true, school)
            end
            ns.RefreshOptions()
        end

        box:SetScript("OnEnterPressed", function(self)
            SetSchoolSound(self:GetText())
            self:ClearFocus()
        end)

        MakeButton("Next", 50, 258, y, function()
            local cur = tostring(db.sounds[school] or "default")
            local idx = 0
            for k, name in ipairs(cycle) do if name == cur then idx = k break end end
            SetSchoolSound(cycle[(idx % #cycle) + 1])
        end)
        MakeButton("Test", 50, 312, y, function() ns.Test(school) end)

        widgets[#widgets + 1] = function()
            if not box:HasFocus() then box:SetText(tostring(db.sounds[school] or "default")) end
            box:SetCursorPosition(0)
        end
    end
end

function ns.RefreshOptions()
    if not db or not soundLabel then return end
    for _, fn in ipairs(widgets) do fn() end
    soundLabel:SetText("current: " .. tostring(db.sound))
    typesLabel:SetText("You can dispel: " .. ns.TypesString())
end

panel:SetScript("OnShow", function() ns.RefreshOptions() end)

local category
function ns.OpenOptions()
    if Settings and Settings.OpenToCategory and category then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

----------------------------------------------------------------------
-- Minimap button
----------------------------------------------------------------------
local btn = CreateFrame("Button", "DispelHighlightMinimapButton", Minimap)
btn:SetSize(31, 31)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:RegisterForDrag("LeftButton")
btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetSize(20, 20); bg:SetPoint("CENTER", 0, 1)
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetSize(18, 18); icon:SetPoint("CENTER", 0, 1)
icon:SetTexture(ICON)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local border = btn:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53); border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function PlaceButton()
    local a = math.rad(db.minimapAngle or 215)
    local r = (Minimap:GetWidth() / 2) + 5
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function DragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    db.minimapAngle = math.deg(atan2(cy / s - my, cx / s - mx))
    PlaceButton()
end

btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", DragUpdate) end)
btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

local function Tooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:AddLine("Dispel Highlight")
    GameTooltip:AddLine(db.enabled and "|cff00ff00Enabled|r" or "|cffff4040Disabled|r", 1, 1, 1)
    GameTooltip:AddLine("Can dispel: " .. ns.TypesString(), 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: open options", 1, 1, 1)
    GameTooltip:AddLine("Right-click: enable / disable", 1, 1, 1)
    GameTooltip:Show()
end

btn:SetScript("OnEnter", function(self) Tooltip(self) end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        ns.SetEnabled(not db.enabled)
        ns.Print(db.enabled and "enabled" or "disabled")
    else
        ns.OpenOptions()
    end
end)

function ns.SetMinimapShown(show)
    db.hideMinimap = not show
    btn:SetShown(show and true or false)
    if ns.RefreshOptions then ns.RefreshOptions() end
end

----------------------------------------------------------------------
-- Addon compartment (functions are named in the .toc)
----------------------------------------------------------------------
function DispelHighlight_OnAddonCompartmentClick(_, buttonName)
    if not db then return end
    if buttonName == "RightButton" then
        ns.SetEnabled(not db.enabled)
        ns.Print(db.enabled and "enabled" or "disabled")
    else
        ns.OpenOptions()
    end
end

function DispelHighlight_OnAddonCompartmentEnter(_, menuButtonFrame)
    if db and menuButtonFrame then Tooltip(menuButtonFrame, "ANCHOR_LEFT") end
end

function DispelHighlight_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

----------------------------------------------------------------------
-- Init (called from DispelHighlight.lua once saved variables are loaded)
----------------------------------------------------------------------
function ns.OnLoad(savedDb)
    db = savedDb
    BuildPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    PlaceButton()
    btn:SetShown(not db.hideMinimap)
end

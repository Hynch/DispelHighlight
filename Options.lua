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


local function BuildPanel()
    MakeLabel(panel, "Dispel Highlight", "GameFontNormalLarge", 16, -16)

    MakeCheckbox("Enable addon", 16, -66,
        function() return db.enabled end,
        function(v) ns.SetEnabled(v) end)

    MakeCheckbox("Tint the frame (colored fill inside the border)", 16, -96,
        function() return db.fill end,
        function(v) db.fill = v; ns.UpdateAll() end)

    MakeCheckbox("Show minimap button", 16, -126,
        function() return not db.hideMinimap end,
        function(v) ns.SetMinimapShown(v) end)

    MakeSlider("Border thickness", 20, -170, 1, 8,
        function() return db.thickness end,
        function(v) db.thickness = v; ns.UpdateAll() end)

    MakeSlider("Tint opacity (%)", 20, -226, 5, 100,
        function() return db.fillAlpha or 25 end,
        function(v) db.fillAlpha = v; ns.UpdateAll() end)

    MakeButton("Preview", 80, 16, -282, function() ns.Test() end)

    -- Footer: author and version, read from the .toc so they never go out of date.
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local author  = (getMeta and getMeta(ADDON, "Author"))  or "Hynch"
    local version = (getMeta and getMeta(ADDON, "Version")) or ""

    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.12)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 16, 50)
    line:SetPoint("BOTTOMRIGHT", -16, 50)

    local by = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    by:SetPoint("BOTTOMLEFT", 16, 30)
    by:SetText("Created by " .. author)

    local ver = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    ver:SetPoint("BOTTOMLEFT", 16, 16)
    ver:SetText(version ~= "" and ("v" .. version) or "")

    -- Link: WoW can't open web pages, so show a read-only box the user can copy from.
    local URL = "https://www.curseforge.com/wow/addons/hynchs-dispel-highlight"
    local linkLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    linkLabel:SetPoint("BOTTOMLEFT", 180, 34)
    linkLabel:SetText("CurseForge page (click, then Ctrl+C to copy):")

    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(380, 20)
    box:SetPoint("BOTTOMLEFT", 186, 10)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetText(URL)
    box:SetCursorPosition(0)
    box:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(URL); self:HighlightText() end   -- read-only
    end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
end

function ns.RefreshOptions()
    if not db then return end
    for _, fn in ipairs(widgets) do fn() end
end

panel:SetScript("OnShow", function() ns.RefreshOptions() end)

local category
function ns.OpenOptions()
    -- The game's settings window is protected and cannot be opened by addons in combat.
    if InCombatLockdown() then
        ns.Print("the options can't be opened in combat. Try again once combat ends.")
        return
    end
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

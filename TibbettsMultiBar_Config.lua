local addonName, addon = ...
local C = (addon and addon.Compat) or {}

-- ─────────────────────────────────────────────────────────────
-- DB / Refresh wrappers
-- ─────────────────────────────────────────────────────────────
local function DB()
    if addon and addon.GetDB then return addon.GetDB() end
    _G.TibbettsMultiBarDB = _G.TibbettsMultiBarDB or {}
    return _G.TibbettsMultiBarDB
end

local function Refresh()
    if addon and addon.ApplySettings    then addon.ApplySettings()    end
    if addon and addon.UpdateReputation then addon.UpdateReputation() end
    if addon and addon.UpdateXP         then addon.UpdateXP()         end
    if addon and addon.UpdateHonor      then addon.UpdateHonor()      end
end

-- ─────────────────────────────────────────────────────────────
-- Widget helpers
-- ─────────────────────────────────────────────────────────────
local function MakeHeader(parent, text, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", 16, y); fs:SetText(text); return fs
end

local function MakeSep(parent, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetVertexColor(0.3, 0.3, 0.3, 0.6); t:SetHeight(1)
    t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  10, y)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, y)
    return t
end

local function MakeCheckbox(parent, label, tooltip, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x or 16, y)
    local txt = cb.Text or (_G[(cb:GetName() or "") .. "Text"])
    if txt then txt:SetText(label) end
    if tooltip then cb.tooltipText = tooltip end
    return cb
end

local function MakeSlider(parent, label, minV, maxV, step, x, y, width)
    local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x or 16, y)
    s:SetMinMaxValues(minV, maxV); s:SetValueStep(step or 1)
    if C.SafeCall then C.SafeCall(s, "SetObeyStepOnDrag", true) end
    s:SetWidth(width or 260)
    if s.Text then s.Text:SetText(label) end
    if s.Low  then s.Low:SetText(tostring(minV)) end
    if s.High then s.High:SetText(tostring(maxV)) end
    return s
end

local function MakeValueBox(parent, anchor, width)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetAutoFocus(false); eb:SetSize(width or 54, 20)
    eb:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
    eb:SetJustifyH("CENTER"); eb:SetText(""); eb:SetCursorPosition(0)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
end

local function MakeButton(parent, label, w, h, x, y)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 120, h or 22)
    b:SetPoint("TOPLEFT", x or 16, y); b:SetText(label); return b
end

local function MakeEditBox(parent, x, y, width)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetAutoFocus(false); eb:SetSize(width or 300, 20)
    eb:SetPoint("TOPLEFT", x or 16, y)
    eb:SetJustifyH("LEFT"); eb:SetText("")
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
end

local function MakeLabel(parent, text, x, y, width)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x or 16, y)
    if width then fs:SetWidth(width) end
    fs:SetJustifyH("LEFT"); fs:SetText(text or ""); return fs
end

local function ColorToRGBA(c)
    if type(c) ~= "table" then return 1,1,1,1 end
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

local function SetSwatch(tex, c)
    if not tex then return end
    local r,g,b,a = ColorToRGBA(c)
    if C.SetSolidColor then C.SetSolidColor(tex, r, g, b, a or 1)
    elseif tex.SetColorTexture then tex:SetColorTexture(r, g, b, a or 1)
    else
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        if tex.SetVertexColor then tex:SetVertexColor(r, g, b, a or 1) end
    end
end

local function ShowColorPicker(initial, hasAlpha, changed)
    if C.ShowColorPicker then C.ShowColorPicker(initial, hasAlpha, changed) end
end

local function Swatch(parent, anchor)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(16, 16); t:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    return t
end

-- ─────────────────────────────────────────────────────────────
-- Media pickers
-- ─────────────────────────────────────────────────────────────
local function GetTextures()
    local list = {
        ["Blizzard"] = "Interface\\TARGETINGFRAME\\UI-StatusBar",
        ["Flat"]     = "Interface\\BUTTONS\\WHITE8X8",
    }
    if LibStub then
        local ok, lsm = pcall(LibStub, "LibSharedMedia-3.0", true)
        if ok and lsm and lsm.List and lsm.Fetch then
            for _, n in ipairs(lsm:List("statusbar")) do list[n] = lsm:Fetch("statusbar", n) end
        end
    end
    return list
end

local function GetFonts()
    local list = {
        ["Friz"]     = "Fonts\\FRIZQT__.TTF",
        ["ArialN"]   = "Fonts\\ARIALN.TTF",
        ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
        ["Skurri"]   = "Fonts\\SKURRI.TTF",
    }
    if LibStub then
        local ok, lsm = pcall(LibStub, "LibSharedMedia-3.0", true)
        if ok and lsm and lsm.List and lsm.Fetch then
            for _, n in ipairs(lsm:List("font")) do list[n] = lsm:Fetch("font", n) end
        end
    end
    return list
end

local function MapToSorted(map)
    local names = {}
    for k in pairs(map or {}) do names[#names+1] = k end
    table.sort(names, function(a,b) return tostring(a):lower() < tostring(b):lower() end)
    local out = {}
    for i,n in ipairs(names) do out[i] = { name=n, path=map[n] } end
    return out
end

local function PickTexture(anchor, onPick)
    local up = addon and addon.UniversalPicker
    if not (up and up.Show) then return end
    up.Show(anchor, "Select Texture", "texture", MapToSorted(GetTextures()),
        function(it) if it and onPick then onPick(it.path, it.name) end end)
end

local function PickFont(anchor, onPick)
    local up = addon and addon.UniversalPicker
    if not (up and up.Show) then return end
    up.Show(anchor, "Select Font", "font", MapToSorted(GetFonts()),
        function(it) if it and onPick then onPick(it.path, it.name) end end)
end

-- ─────────────────────────────────────────────────────────────
-- Panel registration helpers
-- Creates root + sub-pages as a tree in the Interface Options.
-- On Retail 10.0+ this becomes the collapsible tree.
-- On Classic/older it falls back to a flat list.
-- ─────────────────────────────────────────────────────────────
local registeredCategories = {}

-- InterfaceOptionsFramePanelContainer exists on all Classic clients but may
-- not exist on future builds; fall back to UIParent so frame creation never errors.
local _panelParent = _G.InterfaceOptionsFramePanelContainer or UIParent

local rootPanel = CreateFrame("Frame", "TibbettsMultiBarRootPanel", _panelParent)
rootPanel.name = "TibbettsMultiBar"
do
    local fs = rootPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", 16, -16); fs:SetText("TibbettsMultiBar")
    local d = rootPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    d:SetPoint("TOPLEFT", 16, -44); d:SetWidth(500); d:SetJustifyH("LEFT")
    d:SetText("Select a section from the tree on the left to configure it.")
end

-- Register root
if _G.Settings and _G.Settings.RegisterCanvasLayoutCategory then
    local cat = _G.Settings.RegisterCanvasLayoutCategory(rootPanel, "TibbettsMultiBar")
    if cat then
        if _G.Settings.RegisterAddOnCategory then _G.Settings.RegisterAddOnCategory(cat) end
        registeredCategories["TibbettsMultiBar"] = cat
    end
elseif _G.InterfaceOptions_AddCategory then
    _G.InterfaceOptions_AddCategory(rootPanel)
end

local function MakeSubPanel(name)
    local p = CreateFrame("Frame", "TibbettsMultiBarPanel_" .. name,
                          InterfaceOptionsFramePanelContainer)
    p.name   = name
    p.parent = "TibbettsMultiBar"
    return p
end

local function MakeScrollContent(panel)
    local sf = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, -4); sf:SetPoint("BOTTOMRIGHT", -28, 4)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(560, 1); sf:SetScrollChild(content)
    return sf, content
end

local function RegisterSubPanel(panel)
    if _G.Settings and _G.Settings.RegisterCanvasLayoutSubCategory then
        local parentCat = registeredCategories["TibbettsMultiBar"]
        if parentCat then
            local cat = _G.Settings.RegisterCanvasLayoutSubCategory(parentCat, panel, panel.name)
            if cat then
                if _G.Settings.RegisterAddOnCategory then _G.Settings.RegisterAddOnCategory(cat) end
                registeredCategories[panel.name] = cat
            end
            return
        end
    end
    if _G.InterfaceOptions_AddCategory then
        _G.InterfaceOptions_AddCategory(panel)
    end
end

-- ─────────────────────────────────────────────────────────────
-- Shared state
-- ─────────────────────────────────────────────────────────────
local updating    = false
local UI          = {}
local allRefreshFns = {}

local function SafeRefreshUI()
    for _, fn in ipairs(allRefreshFns) do fn() end
end
addon.RefreshConfig = SafeRefreshUI

local function SetTickPreset(preset)
    local db = DB(); db.tickPreset = preset
    if UI.tickNone then UI.tickNone:SetChecked(preset == "none") end
    if UI.tick10   then UI.tick10:SetChecked(  preset == "10")   end
    if UI.tick20   then UI.tick20:SetChecked(  preset == "20")   end
end

local function GetTypedProfile()
    if not UI.profileNameEB then return "Default" end
    local n = (UI.profileNameEB:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
    return n ~= "" and n or "Default"
end

-- ═════════════════════════════════════════════════════════════
-- PAGE: General
-- ═════════════════════════════════════════════════════════════
local pgGeneral = MakeSubPanel("General")
local _, cgG = MakeScrollContent(pgGeneral)
local y = -8

MakeHeader(cgG, "General", y); y = y - 30
UI.enabled      = MakeCheckbox(cgG, "Enable TibbettsMultiBar",           nil, 16, y); y = y - 26
UI.hideBlizz    = MakeCheckbox(cgG, "Hide Blizzard XP bar",              nil, 16, y); y = y - 26
UI.locked       = MakeCheckbox(cgG, "Lock bars (disable dragging)",      nil, 16, y); y = y - 26
UI.clickThrough = MakeCheckbox(cgG, "Click-through mode",                nil, 16, y); y = y - 26
UI.hideInCombat = MakeCheckbox(cgG, "Hide bars in combat",               nil, 16, y); y = y - 26
UI.mouseoverFade= MakeCheckbox(cgG, "Fade bars on mouseover",            nil, 16, y); y = y - 26
UI.fadeAlpha    = MakeSlider(cgG, "Inactive opacity (%)", 0, 100, 1, 32, y, 260); y = y - 48

MakeSep(cgG, y); y = y - 14
MakeHeader(cgG, "Text Visibility", y); y = y - 30
UI.showXPText    = MakeCheckbox(cgG, "Show text on XP bar",    nil, 16, y); y = y - 26
UI.showRepText   = MakeCheckbox(cgG, "Show text on Rep bar",   nil, 16, y); y = y - 26
UI.showHonorText = MakeCheckbox(cgG, "Show text on Honor bar", nil, 16, y); y = y - 34

MakeSep(cgG, y); y = y - 14
MakeHeader(cgG, "Miscellaneous", y); y = y - 30
UI.showRested = MakeCheckbox(cgG, "Show rested XP overlay",  nil, 16, y); y = y - 26
UI.clamp      = MakeCheckbox(cgG, "Clamp bars to screen",    nil, 16, y); y = y - 26
UI.pixelSnap  = MakeCheckbox(cgG, "Pixel snap (crisp edges)",nil, 16, y); y = y - 34

MakeSep(cgG, y); y = y - 14
UI.flashBtn = MakeButton(cgG, "Flash Bars",        110, 22, 16, y)
UI.resetBtn = MakeButton(cgG, "Reset to Defaults", 150, 22, 136, y); y = y - 10
cgG:SetHeight(-y + 20)

-- ═════════════════════════════════════════════════════════════
-- PAGE: XP Bar
-- ═════════════════════════════════════════════════════════════
local pgXP = MakeSubPanel("XP Bar")
local _, cgX = MakeScrollContent(pgXP)
y = -8

MakeHeader(cgX, "Size", y); y = y - 30
UI.width   = MakeSlider(cgX, "Width",    200, 2000, 1, 16, y, 300)
UI.widthEB = MakeValueBox(cgX, UI.width, 58); y = y - 48
UI.height  = MakeSlider(cgX, "Height",     4,   40, 1, 16, y, 300)
UI.heightEB= MakeValueBox(cgX, UI.height,  58); y = y - 48
UI.scale   = MakeSlider(cgX, "Scale (%)", 50,  200, 1, 16, y, 300); y = y - 50

MakeSep(cgX, y); y = y - 14
MakeHeader(cgX, "Appearance", y); y = y - 30
UI.linkBars = MakeCheckbox(cgX, "Link rep + honor appearance to XP bar", nil, 16, y); y = y - 30

UI.textureBtn   = MakeButton(cgX, "Texture…", 100, 22, 16, y)
UI.textureLabel = MakeLabel(cgX, "", 126, y); y = y - 30
UI.fontBtn      = MakeButton(cgX, "Font…",    100, 22, 16, y)
UI.fontLabel    = MakeLabel(cgX, "",  126, y); y = y - 34

UI.barColorBtn  = MakeButton(cgX, "Bar Color…",  110, 22,  16, y)
UI.barSwatch    = Swatch(cgX, UI.barColorBtn)
UI.textColorBtn = MakeButton(cgX, "Text Color…", 110, 22, 160, y)
UI.textSwatch   = Swatch(cgX, UI.textColorBtn)
UI.bgColorBtn   = MakeButton(cgX, "BG Color…",   100, 22, 306, y)
UI.bgSwatch     = Swatch(cgX, UI.bgColorBtn); y = y - 34

UI.restedColorBtn = MakeButton(cgX, "Rested Color…", 130, 22, 16, y)
UI.restedSwatch   = Swatch(cgX, UI.restedColorBtn); y = y - 34

UI.showBorder = MakeCheckbox(cgX, "Show border", nil, 16, y); y = y - 34

MakeSep(cgX, y); y = y - 14
MakeHeader(cgX, "Ticks", y); y = y - 30
UI.tickNone = MakeCheckbox(cgX, "No ticks",   nil,  16, y)
UI.tick10   = MakeCheckbox(cgX, "Every 10%",  nil, 120, y)
UI.tick20   = MakeCheckbox(cgX, "Every 20%",  nil, 238, y); y = y - 30
UI.tickAlphaSlider = MakeSlider(cgX, "Tick opacity (%)", 0, 100, 1, 16, y, 260); y = y - 50

MakeSep(cgX, y); y = y - 14
MakeHeader(cgX, "Text Format", y); y = y - 22
MakeLabel(cgX, "Tokens: {cur}  {max}  {pct}  {remaining}  {rested}     (leave blank = hide text)", 16, y, 520); y = y - 24
UI.xpTextFormatEB = MakeEditBox(cgX, 16, y, 430); y = y - 30

UI.xpPosLabel = MakeLabel(cgX, "Position: –", 16, y); y = y - 10
cgX:SetHeight(-y + 20)

-- ═════════════════════════════════════════════════════════════
-- PAGE: Reputation Bar
-- ═════════════════════════════════════════════════════════════
local pgRep = MakeSubPanel("Reputation Bar")
local _, cgR = MakeScrollContent(pgRep)
y = -8

MakeHeader(cgR, "Reputation Bar", y); y = y - 30
UI.showRep      = MakeCheckbox(cgR, "Show reputation bar",      nil, 16, y); y = y - 26
UI.autoRepAtMax = MakeCheckbox(cgR, "Hide XP bar at max level", nil, 16, y); y = y - 34

MakeSep(cgR, y); y = y - 14
MakeHeader(cgR, "Position", y); y = y - 30
UI.repSnap  = MakeCheckbox(cgR, "Snap to XP bar",      nil, 16, y); y = y - 26
UI.repAbove = MakeCheckbox(cgR, "Place above XP bar",  nil, 16, y); y = y - 26
UI.repHeight= MakeSlider(cgR, "Bar height", 4, 40, 1, 16, y, 260); y = y - 50
UI.repPosLabel = MakeLabel(cgR, "Position: –", 16, y); y = y - 30

MakeSep(cgR, y); y = y - 14
MakeHeader(cgR, "Appearance", y); y = y - 30
UI.repColorBtn = MakeButton(cgR, "Rep Color…", 120, 22, 16, y)
UI.repSwatch   = Swatch(cgR, UI.repColorBtn); y = y - 34

MakeSep(cgR, y); y = y - 14
MakeHeader(cgR, "Text Format", y); y = y - 22
MakeLabel(cgR, "Tokens: {name}  {cur}  {max}  {pct}  {remaining}     (leave blank = hide text)", 16, y, 520); y = y - 24
UI.repTextFormatEB = MakeEditBox(cgR, 16, y, 430); y = y - 10
cgR:SetHeight(-y + 20)

-- ═════════════════════════════════════════════════════════════
-- PAGE: Honor Bar
-- ═════════════════════════════════════════════════════════════
local pgHonor = MakeSubPanel("Honor Bar")
local _, cgH = MakeScrollContent(pgHonor)
y = -8

MakeHeader(cgH, "Honor Bar", y); y = y - 22
MakeLabel(cgH, "Tracks: honor level (Retail) · GetHonorCurrency (Wrath/TBC) · currency 392 (Cata+)", 16, y, 520); y = y - 28
UI.showHonor = MakeCheckbox(cgH, "Show honor bar", nil, 16, y); y = y - 34

MakeSep(cgH, y); y = y - 14
MakeHeader(cgH, "Position", y); y = y - 30
UI.honorSnap  = MakeCheckbox(cgH, "Snap to bar stack",           nil, 16, y); y = y - 26
UI.honorAbove = MakeCheckbox(cgH, "Place above (when snapped)",  nil, 16, y); y = y - 26
UI.honorHeight= MakeSlider(cgH, "Bar height", 4, 40, 1, 16, y, 260); y = y - 50
UI.honorPosLabel = MakeLabel(cgH, "Position: –", 16, y); y = y - 30

MakeSep(cgH, y); y = y - 14
MakeHeader(cgH, "Appearance", y); y = y - 30
UI.honorColorBtn = MakeButton(cgH, "Honor Color…", 130, 22, 16, y)
UI.honorSwatch   = Swatch(cgH, UI.honorColorBtn); y = y - 34

MakeSep(cgH, y); y = y - 14
MakeHeader(cgH, "Text Format", y); y = y - 22
MakeLabel(cgH, "Tokens: {name}  {cur}  {max}  {pct}  {remaining}     (leave blank = hide text)", 16, y, 520); y = y - 24
UI.honorTextFormatEB = MakeEditBox(cgH, 16, y, 430); y = y - 10
cgH:SetHeight(-y + 20)

-- ═════════════════════════════════════════════════════════════
-- PAGE: Profiles
-- ═════════════════════════════════════════════════════════════
local pgProfiles = MakeSubPanel("Profiles")
local _, cgP = MakeScrollContent(pgProfiles)
y = -8

MakeHeader(cgP, "Profiles", y); y = y - 30
UI.profileCurrent = cgP:CreateFontString(nil, "ARTWORK", "GameFontNormal")
UI.profileCurrent:SetPoint("TOPLEFT", 16, y); y = y - 28

MakeLabel(cgP, "Profile name:", 16, y)
UI.profileNameEB = CreateFrame("EditBox", nil, cgP, "InputBoxTemplate")
UI.profileNameEB:SetAutoFocus(false); UI.profileNameEB:SetSize(200, 20)
UI.profileNameEB:SetPoint("TOPLEFT", 110, y); UI.profileNameEB:SetJustifyH("LEFT")
UI.profileNameEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
y = y - 30

UI.profileSwitch = MakeButton(cgP, "Switch",      90, 22,  16, y)
UI.profileCopy   = MakeButton(cgP, "Copy to New", 110, 22, 112, y)
UI.profileDelete = MakeButton(cgP, "Delete",       90, 22, 228, y); y = y - 36

do
    local note = cgP:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 16, y); note:SetWidth(520); note:SetJustifyH("LEFT")
    note:SetText("Switch activates a profile (creates if new). Copy duplicates the current one into a new name.")
    y = y - 40
end

MakeSep(cgP, y); y = y - 16
MakeHeader(cgP, "Import / Export", y); y = y - 24
do
    local d = cgP:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    d:SetPoint("TOPLEFT", 16, y); d:SetWidth(520); d:SetJustifyH("LEFT")
    d:SetText("Export saves the current profile as a string you can share. Paste a string below and click Import.")
    y = y - 28
end
UI.exportBtn = MakeButton(cgP, "Export", 90, 22,  16, y)
UI.importBtn = MakeButton(cgP, "Import", 90, 22, 114, y); y = y - 32

UI.importExportEB = CreateFrame("EditBox", nil, cgP, "InputBoxTemplate")
UI.importExportEB:SetAutoFocus(false); UI.importExportEB:SetSize(530, 20)
UI.importExportEB:SetPoint("TOPLEFT", 16, y); UI.importExportEB:SetJustifyH("LEFT")
UI.importExportEB:SetText("")
UI.importExportEB:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
y = y - 30

UI.importStatus = MakeLabel(cgP, "", 16, y, 520); y = y - 10
cgP:SetHeight(-y + 20)

-- ─────────────────────────────────────────────────────────────
-- Register all sub-pages
-- ─────────────────────────────────────────────────────────────
for _, p in ipairs({ pgGeneral, pgXP, pgRep, pgHonor, pgProfiles }) do
    RegisterSubPanel(p)
end

-- ─────────────────────────────────────────────────────────────
-- RefreshUI  (one function per page, all called on any change)
-- ─────────────────────────────────────────────────────────────
local function RefreshGeneral()
    updating = true
    local db = DB()
    UI.enabled:SetChecked(       db.enabled ~= false)
    UI.hideBlizz:SetChecked(     db.hideBlizzard and true or false)
    UI.locked:SetChecked(        db.locked and true or false)
    UI.clickThrough:SetChecked(  db.clickThrough and true or false)
    UI.hideInCombat:SetChecked(  db.hideInCombat and true or false)
    UI.mouseoverFade:SetChecked( db.mouseoverFade and true or false)
    UI.fadeAlpha:SetValue(       (tonumber(db.fadeAlpha) or 1) * 100)
    UI.showXPText:SetChecked(    db.showXPText ~= false)
    UI.showRepText:SetChecked(   db.showRepText ~= false)
    UI.showHonorText:SetChecked( db.showHonorText ~= false)
    UI.showRested:SetChecked(    db.showRested and true or false)
    UI.clamp:SetChecked(         db.clamp ~= false)
    UI.pixelSnap:SetChecked(     db.pixelSnap ~= false)
    updating = false
end

local function RefreshXP()
    updating = true
    local db = DB()
    UI.width:SetValue(  tonumber(db.width)  or 1024)
    UI.height:SetValue( tonumber(db.height) or 18)
    UI.scale:SetValue(  (tonumber(db.scale) or 1) * 100)
    -- widthEB/heightEB are updated by OnValueChanged which fires from SetValue above
    UI.linkBars:SetChecked(db.linkBars and true or false)
    if UI.textureLabel then UI.textureLabel:SetText(db.textureName or "") end
    if UI.fontLabel    then UI.fontLabel:SetText(   db.fontName    or "") end
    SetSwatch(UI.barSwatch,    db.barColor)
    SetSwatch(UI.textSwatch,   db.textColor)
    SetSwatch(UI.bgSwatch,     db.bgColor)
    SetSwatch(UI.restedSwatch, db.restedColor)
    UI.showBorder:SetChecked(db.showBorder and true or false)
    SetTickPreset(db.tickPreset or "10")
    UI.tickAlphaSlider:SetValue((tonumber(db.tickAlpha) or 0.55) * 100)
    if UI.xpTextFormatEB then UI.xpTextFormatEB:SetText(db.xpTextFormat or "") end
    if UI.xpPosLabel and addon and addon.GetBarPositionText then
        UI.xpPosLabel:SetText("Position: " .. addon.GetBarPositionText())
    end
    updating = false
end

local function RefreshRep()
    updating = true
    local db = DB()
    UI.showRep:SetChecked(      db.showRep ~= false)
    UI.autoRepAtMax:SetChecked( db.autoRepAtMax ~= false)
    UI.repSnap:SetChecked(      db.repSnap and true or false)
    UI.repAbove:SetChecked(     db.repAbove and true or false)
    UI.repHeight:SetValue(      tonumber(db.repHeight) or 8)
    SetSwatch(UI.repSwatch, db.repColor)
    if UI.repTextFormatEB then UI.repTextFormatEB:SetText(db.repTextFormat or "") end
    if UI.repPosLabel and addon and addon.GetRepPositionText then
        UI.repPosLabel:SetText("Position: " .. addon.GetRepPositionText())
    end
    updating = false
end

local function RefreshHonor()
    updating = true
    local db = DB()
    UI.showHonor:SetChecked(    db.showHonor and true or false)
    UI.honorSnap:SetChecked(    db.honorSnap and true or false)
    UI.honorAbove:SetChecked(   db.honorAbove and true or false)
    UI.honorHeight:SetValue(    tonumber(db.honorHeight) or 8)
    SetSwatch(UI.honorSwatch, db.honorColor)
    if UI.honorTextFormatEB then UI.honorTextFormatEB:SetText(db.honorTextFormat or "") end
    if UI.honorPosLabel and addon and addon.GetHonorPositionText then
        UI.honorPosLabel:SetText("Position: " .. addon.GetHonorPositionText())
    end
    updating = false
end

local function RefreshProfiles()
    updating = true
    local pname = (addon and addon.GetProfileName and addon.GetProfileName()) or "Default"
    if UI.profileCurrent then UI.profileCurrent:SetText("Active: " .. pname) end
    if UI.profileNameEB  then UI.profileNameEB:SetText(pname) end
    updating = false
end

allRefreshFns = { RefreshGeneral, RefreshXP, RefreshRep, RefreshHonor, RefreshProfiles }

for _, p in ipairs({ pgGeneral, pgXP, pgRep, pgHonor, pgProfiles }) do
    p:SetScript("OnShow", SafeRefreshUI)
end

-- ─────────────────────────────────────────────────────────────
-- Wiring – General
-- ─────────────────────────────────────────────────────────────
UI.enabled:SetScript("OnClick", function(self)
    if updating then return end; DB().enabled = self:GetChecked() and true or false; Refresh() end)
UI.hideBlizz:SetScript("OnClick", function(self)
    if updating then return end; DB().hideBlizzard = self:GetChecked() and true or false; Refresh() end)
UI.locked:SetScript("OnClick", function(self)
    if updating then return end; DB().locked = self:GetChecked() and true or false; Refresh() end)
UI.clickThrough:SetScript("OnClick", function(self)
    if updating then return end; DB().clickThrough = self:GetChecked() and true or false; Refresh() end)
UI.hideInCombat:SetScript("OnClick", function(self)
    if updating then return end; DB().hideInCombat = self:GetChecked() and true or false; Refresh() end)
UI.mouseoverFade:SetScript("OnClick", function(self)
    if updating then return end; DB().mouseoverFade = self:GetChecked() and true or false; Refresh() end)
UI.fadeAlpha:SetScript("OnValueChanged", function(self, v)
    if updating then return end; DB().fadeAlpha = (tonumber(v) or 100) / 100; Refresh() end)
UI.showXPText:SetScript("OnClick", function(self)
    if updating then return end; DB().showXPText = self:GetChecked() and true or false; Refresh() end)
UI.showRepText:SetScript("OnClick", function(self)
    if updating then return end; DB().showRepText = self:GetChecked() and true or false; Refresh() end)
UI.showHonorText:SetScript("OnClick", function(self)
    if updating then return end; DB().showHonorText = self:GetChecked() and true or false; Refresh() end)
UI.showRested:SetScript("OnClick", function(self)
    if updating then return end; DB().showRested = self:GetChecked() and true or false; Refresh() end)
UI.clamp:SetScript("OnClick", function(self)
    if updating then return end; DB().clamp = self:GetChecked() and true or false; Refresh() end)
UI.pixelSnap:SetScript("OnClick", function(self)
    if updating then return end; DB().pixelSnap = self:GetChecked() and true or false; Refresh() end)
UI.flashBtn:SetScript("OnClick", function()
    if addon and addon.FlashBars then addon.FlashBars() end end)
UI.resetBtn:SetScript("OnClick", function()
    if addon and addon.ResetToDefaults then addon.ResetToDefaults(); SafeRefreshUI() end end)

-- ─────────────────────────────────────────────────────────────
-- Wiring – XP Bar
-- ─────────────────────────────────────────────────────────────
UI.width:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v + 0.5)
    if UI.widthEB then UI.widthEB:SetText(tostring(v)) end
    if updating then return end; DB().width = v; Refresh() end)
UI.height:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v + 0.5)
    if UI.heightEB then UI.heightEB:SetText(tostring(v)) end
    if updating then return end; DB().height = v; Refresh() end)
UI.scale:SetScript("OnValueChanged", function(self, v)
    if updating then return end; DB().scale = (tonumber(v) or 100) / 100; Refresh() end)
if UI.widthEB then
    UI.widthEB:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText() or ""); if not v then self:ClearFocus(); return end
        v = math.max(200, math.min(2000, math.floor(v+0.5)))
        updating = true; UI.width:SetValue(v); updating = false
        DB().width = v; self:ClearFocus(); Refresh() end)
end
if UI.heightEB then
    UI.heightEB:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText() or ""); if not v then self:ClearFocus(); return end
        v = math.max(4, math.min(40, math.floor(v+0.5)))
        updating = true; UI.height:SetValue(v); updating = false
        DB().height = v; self:ClearFocus(); Refresh() end)
end
UI.linkBars:SetScript("OnClick", function(self)
    if updating then return end; DB().linkBars = self:GetChecked() and true or false; Refresh() end)
UI.textureBtn:SetScript("OnClick", function()
    PickTexture(UI.textureBtn, function(path, name)
        local db = DB(); db.texture = path; db.textureName = name or path
        SafeRefreshUI(); Refresh() end) end)
UI.fontBtn:SetScript("OnClick", function()
    PickFont(UI.fontBtn, function(path, name)
        local db = DB(); db.font = path; db.fontName = name or path
        SafeRefreshUI(); Refresh() end) end)
UI.barColorBtn:SetScript("OnClick", function()
    local db = DB()
    ShowColorPicker(db.barColor, true, function(r,g,b,a)
        db.barColor={r=r,g=g,b=b,a=a}; SetSwatch(UI.barSwatch,db.barColor); Refresh() end) end)
UI.textColorBtn:SetScript("OnClick", function()
    local db = DB()
    ShowColorPicker(db.textColor, true, function(r,g,b,a)
        db.textColor={r=r,g=g,b=b,a=a}; SetSwatch(UI.textSwatch,db.textColor); Refresh() end) end)
UI.bgColorBtn:SetScript("OnClick", function()
    local db = DB()
    local c = {r=db.bgColor.r,g=db.bgColor.g,b=db.bgColor.b,a=db.bgAlpha or db.bgColor.a or 0.5}
    ShowColorPicker(c, true, function(r,g,b,a)
        db.bgColor={r=r,g=g,b=b,a=a}; db.bgAlpha=a; SetSwatch(UI.bgSwatch,db.bgColor); Refresh() end) end)
UI.restedColorBtn:SetScript("OnClick", function()
    local db = DB()
    ShowColorPicker(db.restedColor, true, function(r,g,b,a)
        db.restedColor={r=r,g=g,b=b,a=a}; SetSwatch(UI.restedSwatch,db.restedColor); Refresh() end) end)
UI.showBorder:SetScript("OnClick", function(self)
    if updating then return end; DB().showBorder = self:GetChecked() and true or false; Refresh() end)
UI.tickNone:SetScript("OnClick", function() if updating then return end; SetTickPreset("none"); Refresh() end)
UI.tick10:SetScript(  "OnClick", function() if updating then return end; SetTickPreset("10");   Refresh() end)
UI.tick20:SetScript(  "OnClick", function() if updating then return end; SetTickPreset("20");   Refresh() end)
UI.tickAlphaSlider:SetScript("OnValueChanged", function(self, v)
    if updating then return end; DB().tickAlpha = (tonumber(v) or 55) / 100; Refresh() end)
UI.xpTextFormatEB:SetScript("OnEnterPressed", function(self)
    if updating then return end; DB().xpTextFormat = self:GetText() or ""; self:ClearFocus(); Refresh() end)
UI.xpTextFormatEB:SetScript("OnEditFocusLost", function(self)
    if updating then return end; DB().xpTextFormat = self:GetText() or ""; Refresh() end)

-- ─────────────────────────────────────────────────────────────
-- Wiring – Reputation
-- ─────────────────────────────────────────────────────────────
UI.showRep:SetScript("OnClick", function(self)
    if updating then return end; DB().showRep = self:GetChecked() and true or false; Refresh() end)
UI.autoRepAtMax:SetScript("OnClick", function(self)
    if updating then return end; DB().autoRepAtMax = self:GetChecked() and true or false; Refresh() end)
UI.repSnap:SetScript("OnClick", function(self)
    if updating then return end; DB().repSnap = self:GetChecked() and true or false; Refresh() end)
UI.repAbove:SetScript("OnClick", function(self)
    if updating then return end; DB().repAbove = self:GetChecked() and true or false; Refresh() end)
UI.repHeight:SetScript("OnValueChanged", function(self, v)
    if updating then return end; DB().repHeight = math.floor(v+0.5); Refresh() end)
UI.repColorBtn:SetScript("OnClick", function()
    local db = DB()
    ShowColorPicker(db.repColor, true, function(r,g,b,a)
        db.repColor={r=r,g=g,b=b,a=a}; SetSwatch(UI.repSwatch,db.repColor); Refresh() end) end)
UI.repTextFormatEB:SetScript("OnEnterPressed", function(self)
    if updating then return end; DB().repTextFormat = self:GetText() or ""; self:ClearFocus(); Refresh() end)
UI.repTextFormatEB:SetScript("OnEditFocusLost", function(self)
    if updating then return end; DB().repTextFormat = self:GetText() or ""; Refresh() end)

-- ─────────────────────────────────────────────────────────────
-- Wiring – Honor
-- ─────────────────────────────────────────────────────────────
UI.showHonor:SetScript("OnClick", function(self)
    if updating then return end; DB().showHonor = self:GetChecked() and true or false; Refresh() end)
UI.honorSnap:SetScript("OnClick", function(self)
    if updating then return end; DB().honorSnap = self:GetChecked() and true or false; Refresh() end)
UI.honorAbove:SetScript("OnClick", function(self)
    if updating then return end; DB().honorAbove = self:GetChecked() and true or false; Refresh() end)
UI.honorHeight:SetScript("OnValueChanged", function(self, v)
    if updating then return end; DB().honorHeight = math.floor(v+0.5); Refresh() end)
UI.honorColorBtn:SetScript("OnClick", function()
    local db = DB()
    ShowColorPicker(db.honorColor, true, function(r,g,b,a)
        db.honorColor={r=r,g=g,b=b,a=a}; SetSwatch(UI.honorSwatch,db.honorColor); Refresh() end) end)
UI.honorTextFormatEB:SetScript("OnEnterPressed", function(self)
    if updating then return end; DB().honorTextFormat = self:GetText() or ""; self:ClearFocus(); Refresh() end)
UI.honorTextFormatEB:SetScript("OnEditFocusLost", function(self)
    if updating then return end; DB().honorTextFormat = self:GetText() or ""; Refresh() end)

-- ─────────────────────────────────────────────────────────────
-- Wiring – Profiles
-- ─────────────────────────────────────────────────────────────
UI.profileSwitch:SetScript("OnClick", function()
    if updating then return end
    if addon and addon.SetProfile then addon.SetProfile(GetTypedProfile()) end
    SafeRefreshUI(); Refresh() end)
UI.profileCopy:SetScript("OnClick", function()
    if updating then return end
    if addon and addon.CopyProfile and addon.GetProfileName then
        local from = addon.GetProfileName(); local to = GetTypedProfile()
        if to and to ~= "" then addon.CopyProfile(from, to); addon.SetProfile(to) end
    end
    SafeRefreshUI(); Refresh() end)
UI.profileDelete:SetScript("OnClick", function()
    if updating then return end
    if addon and addon.DeleteProfile then
        addon.DeleteProfile(GetTypedProfile())
        if addon.SetProfile then addon.SetProfile("Default") end
    end
    SafeRefreshUI(); Refresh() end)
UI.exportBtn:SetScript("OnClick", function()
    if not (addon and addon.ExportSetupString) then return end
    local str = addon:ExportSetupString()
    if UI.importExportEB then
        UI.importExportEB:SetText(str); UI.importExportEB:SetFocus()
        UI.importExportEB:HighlightText()
    end
    if UI.importStatus then UI.importStatus:SetText("Exported – copy the string above.") end
    addon:CopyStringToChat(str, "TibbettsMultiBar Export") end)
UI.importBtn:SetScript("OnClick", function()
    if not (addon and addon.ImportSetupString) then return end
    local str = (UI.importExportEB and UI.importExportEB:GetText() or ""):gsub("^%s+",""):gsub("%s+$","")
    if str == "" then
        if UI.importStatus then UI.importStatus:SetText("Paste an export string first.") end; return
    end
    local ok, msg = addon:ImportSetupString(str, false)
    if UI.importStatus then
        UI.importStatus:SetText(ok and "Import successful!" or ("Failed: " .. (msg or "")))
    end
    if ok then SafeRefreshUI() end end)

-- ─────────────────────────────────────────────────────────────
-- Slash command
-- ─────────────────────────────────────────────────────────────
SLASH_TIBBETTSMULTIBAR1 = "/tmb"
SlashCmdList.TIBBETTSMULTIBAR = function()
    SafeRefreshUI()
    if _G.Settings and _G.Settings.OpenToCategory then
        _G.Settings.OpenToCategory("TibbettsMultiBar")
    elseif _G.InterfaceOptionsFrame_OpenToCategory then
        _G.InterfaceOptionsFrame_OpenToCategory(rootPanel)
        _G.InterfaceOptionsFrame_OpenToCategory(rootPanel)
    end
end

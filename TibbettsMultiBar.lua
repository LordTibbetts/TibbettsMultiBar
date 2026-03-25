--=========================================================
-- TibbettsMultiBar.lua  v1.1.0
-- XP / Reputation / Honor bars – all WoW versions
--=========================================================
local addonName, addon = ...
addon = addon or {}

--=========================================================
-- Utility
--=========================================================
local function Clamp01(v)
    v = tonumber(v) or 0
    return v < 0 and 0 or v > 1 and 1 or v
end

local function SetSolidColor(tex, r, g, b, a)
    if not tex then return end
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    if tex.SetVertexColor then
        tex:SetVertexColor(tonumber(r) or 0, tonumber(g) or 0,
                           tonumber(b) or 0, Clamp01(a))
    end
end

local function DeepCopy(src, dst)
    if type(src) ~= "table" then return src end
    dst = dst or {}
    for k, v in pairs(src) do
        dst[k] = type(v) == "table" and DeepCopy(v, {}) or v
    end
    return dst
end

-- Cross-version deferred call (C_Timer.After absent on Vanilla / TBC private servers)
local function SafeAfter(delay, fn)
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(delay, fn)
        return
    end
    local frame, elapsed = CreateFrame("Frame"), 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            fn()
        end
    end)
end

-- Format bar text with {token} substitutions.
-- Tokens: {cur} {max} {pct} {remaining} {rested} {name}
-- Empty/nil format falls back to a sensible default.
local function FormatBarText(fmt, cur, max, name, rested)
    cur, max = tonumber(cur) or 0, tonumber(max) or 0
    rested   = tonumber(rested) or 0
    -- Empty string means "show nothing"
    if fmt == "" then return nil end
    local pct       = max > 0 and math.floor(cur / max * 100 + 0.5) or 0
    local remaining = max - cur
    if not fmt then
        if name and name ~= "" then
            return string.format("%s: %d/%d (%d%%)", name, cur, max, pct)
        end
        return string.format("%d/%d (%d%%)", cur, max, pct)
    end
    local s = fmt
    s = s:gsub("{name}",      name and tostring(name) or "")
    s = s:gsub("{cur}",       tostring(cur))
    s = s:gsub("{max}",       tostring(max))
    s = s:gsub("{pct}",       tostring(pct))
    s = s:gsub("{remaining}", tostring(remaining))
    s = s:gsub("{rested}",    tostring(rested))
    return s
end

--=========================================================
-- Cross-version Honor data
-- Returns name, current, maximum – or nil if unavailable
--=========================================================
local function GetHonorData()
    -- Retail: UnitHonorPoints/UnitHonorMax (toward next honor level)
    if _G.UnitHonorPoints and _G.UnitHonorMax then
        local ok1, cur = pcall(_G.UnitHonorPoints, "player")
        local ok2, mx  = pcall(_G.UnitHonorMax,    "player")
        if ok1 and ok2 and type(cur) == "number" and type(mx) == "number" and mx > 0 then
            return "Honor", cur, mx
        end
    end
    -- Wrath / TBC Classic: GetHonorCurrency()
    if _G.GetHonorCurrency then
        local ok, cur, mx = pcall(_G.GetHonorCurrency)
        if ok and type(cur) == "number" and type(mx) == "number" and mx > 0 then
            return "Honor", cur, mx
        end
    end
    -- Cata+: currency ID 392 = Honor Points
    if _G.GetCurrencyInfo then
        local ok, name, cur, _, _, _, mx = pcall(_G.GetCurrencyInfo, 392)
        if ok and name and type(cur) == "number" and type(mx) == "number" and mx > 0 then
            return name, cur, mx
        end
    end
    return nil
end

--=========================================================
-- Profile system (single canonical implementation)
--=========================================================
local function GetCharKey()
    local name  = (UnitName     and UnitName("player"))  or "Player"
    local realm = (GetRealmName and GetRealmName())      or "Realm"
    return name .. "-" .. realm
end

function addon.GetDB()
    if not _G.TibbettsMultiBarSV or type(_G.TibbettsMultiBarSV) ~= "table" then
        _G.TibbettsMultiBarSV = { current = "Default", profiles = {} }
    end
    local sv = _G.TibbettsMultiBarSV
    sv.profiles = sv.profiles or {}
    if not sv.current or sv.current == "" then sv.current = "Default" end

    -- One-time migration from legacy flat TibbettsMultiBarDB
    if _G.TibbettsMultiBarDB and type(_G.TibbettsMultiBarDB) == "table"
       and not _G.TibbettsMultiBarDB.profileName
       and not sv.profiles["Default"] then
        sv.profiles["Default"] = DeepCopy(_G.TibbettsMultiBarDB, {})
    end

    sv.profiles["Default"]  = sv.profiles["Default"]  or {}
    sv.profiles[sv.current] = sv.profiles[sv.current] or
                              DeepCopy(sv.profiles["Default"], {})
    return sv.profiles[sv.current], sv
end

function addon.GetProfileName()
    local _, sv = addon.GetDB()
    return sv and sv.current or "Default"
end

function addon.GetProfiles()
    local _, sv = addon.GetDB()
    if not sv then return { "Default" } end
    local names = {}
    for k in pairs(sv.profiles or {}) do names[#names + 1] = k end
    table.sort(names, function(a, b)
        return tostring(a):lower() < tostring(b):lower()
    end)
    return names
end

function addon.SetProfile(name)
    if not name or name == "" then return end
    local _, sv = addon.GetDB()
    if not sv then return end
    sv.profiles[name] = sv.profiles[name] or {}
    sv.current = name
end

function addon.CopyProfile(fromName, toName)
    if not fromName or not toName or fromName == "" or toName == "" then return end
    local _, sv = addon.GetDB()
    if not sv or not sv.profiles[fromName] then return end
    sv.profiles[toName] = DeepCopy(sv.profiles[fromName], {})
end

function addon.DeleteProfile(name)
    if not name or name == "" or name == "Default" then return end
    local _, sv = addon.GetDB()
    if not sv then return end
    sv.profiles[name] = nil
    if sv.current == name then sv.current = "Default" end
end

local function ActivateProfile(name)
    local _, sv = addon.GetDB()
    if sv then sv.current = name end
    if addon.ApplySettings then addon.ApplySettings() end
end

--=========================================================
-- Defaults + EnsureDB
--=========================================================
local defaults = {
    enabled          = true,
    hideBlizzard     = true,
    -- XP bar geometry
    width = 1024, height = 18, scale = 1.0,
    locked = false, clamp = true, pixelSnap = true,
    point = "CENTER", relPoint = "CENTER", x = 0, y = 0,
    -- XP bar
    showText         = true,
    showXPText       = true,
    showRepText      = true,
    showHonorText    = true,
    xpTextFormat     = "{cur}/{max} ({pct}%)",
    texture          = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    textureName      = "UI-StatusBar",
    font             = "Fonts\\FRIZQT__.TTF",
    fontName         = "Friz Quadrata",
    fontSize = 12,   fontOutline = "OUTLINE",
    textColor        = { r=1,   g=1,   b=1,   a=1   },
    textShadow       = true,
    textShadowColor  = { r=0,   g=0,   b=0,   a=0.9 },
    textShadowOffset = 1,
    showBorder       = false,
    tickPreset       = "10",
    showTicks        = true, tickCount = 10, tickAlpha = 1.0,
    mouseoverFade    = false, fadeAlpha = 0.25,
    hideInCombat     = false,
    clickThrough     = false,
    barColor         = { r=0.0, g=0.6, b=1.0, a=1.0 },
    bgAlpha          = 0.5,
    bgColor          = { r=0,   g=0,   b=0,   a=0.5 },
    showRested       = true,
    restedColor      = { r=0.6, g=0.0, b=1.0, a=0.6 },
    -- Reputation bar
    showRep          = true,
    repSnap          = true, repAbove = false, repGap = 2,
    repX = 0, repY = -30,
    repPoint = "CENTER", repRelPoint = "CENTER",
    autoRepAtMax     = true,
    repHeight        = 8,
    repColor         = { r=0,   g=0.8, b=0.2, a=1   },
    repBgAlpha       = 0.5,
    repBgColor       = { r=0,   g=0,   b=0,   a=0.5 },
    repTextFormat    = "{name}: {cur}/{max} ({pct}%)",
    -- Honor bar
    showHonor        = false,
    honorSnap        = true, honorAbove = false,
    honorX = 0, honorY = -50,
    honorPoint = "CENTER", honorRelPoint = "CENTER",
    honorHeight      = 8,
    honorColor       = { r=0.9, g=0.1, b=0.1, a=1.0 },
    honorBgAlpha     = 0.5,
    honorBgColor     = { r=0,   g=0,   b=0,   a=0.5 },
    honorTextFormat  = "{name}: {cur}/{max} ({pct}%)",
    -- Shared
    linkBars         = true,
}

local function ApplyDefaultsTo(db)
    if type(db) ~= "table" then return end
    for k, v in pairs(defaults) do
        local cur = db[k]
        if cur == nil then
            db[k] = type(v) == "table" and DeepCopy(v, {}) or v
        elseif type(v) == "table" and type(cur) == "table" then
            for kk, vv in pairs(v) do
                if cur[kk] == nil then cur[kk] = vv end
            end
        end
    end
end

local function EnsureDB()
    local db = addon.GetDB()
    ApplyDefaultsTo(db)
    return db
end

function addon.ResetToDefaults()
    local _, sv = addon.GetDB()
    if not sv then return end
    sv.profiles[sv.current] = {}
    ApplyDefaultsTo(sv.profiles[sv.current])
    addon.ApplySettings()
end

--=========================================================
-- Blizzard XP bar helper
--=========================================================
local function HideBlizzardXP(hide)
    local C = addon.Compat
    -- Retail / Midnight: the XP bar lives inside StatusTrackingBarManager.
    -- Hiding the manager also hides Reputation and Honor tracking bars.
    if C.IsRetail then
        local mgr = _G.StatusTrackingBarManager
        if mgr then
            if hide then mgr:Hide()
            else         mgr:Show() end
        end
        return
    end

    -- Classic clients: individual named frames.
    local frames = {
        "MainMenuExpBar",          -- vanilla/classic XP bar fill
        "ExhaustionTick",          -- rested tick mark (pre-Cata)
        "ExhaustionLevelFillBar",  -- rested overlay (Cata+)
        "MainMenuBarMaxLevelBar",  -- "MAX" overlay at level cap
        "ReputationWatchBar",      -- reputation bar below XP
        "HonorWatchBar",           -- honor bar below XP (TBC/Wrath)
    }
    for _, name in ipairs(frames) do
        local f = _G[name]
        if f and f.IsObjectType and f:IsObjectType("Frame") then
            if hide then
                if f.Hide  then f:Hide()  end
            else
                if f.Show and f:GetParent() and f:GetParent():IsShown() then
                    f:Show()
                end
            end
        end
    end
end

--=========================================================
-- Border / Tick helpers
--=========================================================
local function CreateBorderTextures(parent)
    local t = {}
    for _, k in ipairs({ "top", "bottom", "left", "right" }) do
        t[k] = parent:CreateTexture(nil, "OVERLAY")
        t[k]:SetTexture("Interface\\Buttons\\WHITE8x8")
        t[k]:SetVertexColor(0, 0, 0, 1)
    end
    return t
end

local function LayoutBorderTextures(border, frame, show)
    if not border then return end
    if not show then
        for _, t in pairs(border) do if t then t:Hide() end end
        return
    end
    local px = 1
    border.top:ClearAllPoints()
    border.top:SetPoint("TOPLEFT",  frame, "TOPLEFT",  -px,  px)
    border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT",  px,  px)
    border.top:SetHeight(px)
    border.bottom:ClearAllPoints()
    border.bottom:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  -px, -px)
    border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",  px, -px)
    border.bottom:SetHeight(px)
    border.left:ClearAllPoints()
    border.left:SetPoint("TOPLEFT",    frame, "TOPLEFT",    -px,  px)
    border.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -px, -px)
    border.left:SetWidth(px)
    border.right:ClearAllPoints()
    border.right:SetPoint("TOPRIGHT",    frame, "TOPRIGHT",    px,  px)
    border.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", px, -px)
    border.right:SetWidth(px)
    for _, t in pairs(border) do if t then t:Show() end end
end

-- Returns (or lazily creates) a transparent frame that sits exactly over
-- barFrame but at a higher frame level so its textures are ALWAYS drawn
-- above the StatusBar fill, regardless of draw layer.
local function GetTickOverlay(container, barFrame)
    if container._overlay then return container._overlay end
    local ov = CreateFrame("Frame", nil, barFrame)
    ov:SetAllPoints(barFrame)
    ov:SetFrameLevel(barFrame:GetFrameLevel() + 5)
    container._overlay = ov
    return ov
end

local function LayoutTicks(container, barFrame, count, alpha, show)
    container       = container or {}
    container.ticks = container.ticks or {}
    for i = 1, #container.ticks do container.ticks[i]:Hide() end
    if not show then return end
    count = tonumber(count) or 10
    if count < 2 then return end
    alpha = Clamp01(tonumber(alpha) or 1)
    local width = barFrame:GetWidth()
    if not width or width <= 0 then return end
    -- Parent ticks to a dedicated overlay frame so the bar fill
    -- (which composites in ARTWORK on the StatusBar) can never cover them.
    local ov   = GetTickOverlay(container, barFrame)
    local step = width / count
    for i = 1, count - 1 do
        local tex = container.ticks[i]
        if not tex then
            tex = ov:CreateTexture(nil, "OVERLAY")
            tex:SetTexture("Interface\\Buttons\\WHITE8X8")
            -- Pure black vertex color; the overlay frame guarantees it
            -- is drawn above the bar fill so no blending occurs.
            tex:SetVertexColor(0, 0, 0, 1)
            container.ticks[i] = tex
        end
        local x = math.floor(step * i + 0.5)
        x = math.max(0, math.min(x, math.floor(width - 1 + 0.5)))
        tex:ClearAllPoints()
        tex:SetPoint("TOP",    barFrame, "TOP",    0, 0)
        tex:SetPoint("BOTTOM", barFrame, "BOTTOM", 0, 0)
        tex:SetPoint("LEFT",   barFrame, "LEFT",   x, 0)
        tex:SetWidth(2)  -- 2px wide so they're impossible to miss
        tex:SetAlpha(alpha)
        tex:Show()
    end
end

local function UpdateBorderAndTicks(frame, cfg)
    if not frame then return end
    LayoutBorderTextures(frame._border, frame, cfg.showBorder and true or false)
    LayoutTicks(frame._ticks, frame, cfg.tickCount, cfg.tickAlpha,
                cfg.showTicks and true or false)
end

--=========================================================
-- Frame creation: XP bar
--=========================================================
local bar = CreateFrame("StatusBar", "TibbettsMultiBarFrame", UIParent)
bar:SetFrameStrata("MEDIUM")
bar:SetFrameLevel(10)
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)

bar.bg = bar:CreateTexture(nil, "BACKGROUND")
bar.bg:SetAllPoints(bar)

local rested = CreateFrame("StatusBar", nil, bar)
rested:SetAllPoints(bar)
rested:SetFrameLevel(bar:GetFrameLevel() + 1)
rested:SetMinMaxValues(0, 1)
rested:SetValue(0)
bar.rested = rested

bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
bar.text:SetJustifyH("CENTER")
bar.text:SetJustifyV("MIDDLE")

bar._border = CreateBorderTextures(bar)
bar._ticks  = { ticks = {} }

addon.bar = bar
local xpBar = bar

--=========================================================
-- Frame creation: Reputation bar
--=========================================================
local repFrame = CreateFrame("Frame", "TibbettsMultiBarRepFrame", UIParent)
repFrame:SetFrameStrata("MEDIUM")
repFrame:SetFrameLevel(9)
repFrame:SetClampedToScreen(true)

local repBar = CreateFrame("StatusBar", "TibbettsMultiBarRepBar", repFrame)
repBar:SetAllPoints(repFrame)
repBar:SetMinMaxValues(0, 1)
repBar:SetValue(0)

repBar.bg = repBar:CreateTexture(nil, "BACKGROUND")
repBar.bg:SetAllPoints(repBar)

repBar.text = repBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
repBar.text:SetPoint("CENTER", repBar, "CENTER", 0, 0)
repBar.text:SetJustifyH("CENTER")
repBar.text:SetJustifyV("MIDDLE")

repBar._border = CreateBorderTextures(repBar)
repBar._ticks  = { ticks = {} }
repFrame:Hide()

addon.repFrame = repFrame
addon.repBar   = repBar

--=========================================================
-- Frame creation: Honor bar
--=========================================================
local honorFrame = CreateFrame("Frame", "TibbettsMultiBarHonorFrame", UIParent)
honorFrame:SetFrameStrata("MEDIUM")
honorFrame:SetFrameLevel(9)
honorFrame:SetClampedToScreen(true)

local honorBar = CreateFrame("StatusBar", "TibbettsMultiBarHonorBar", honorFrame)
honorBar:SetAllPoints(honorFrame)
honorBar:SetMinMaxValues(0, 1)
honorBar:SetValue(0)

honorBar.bg = honorBar:CreateTexture(nil, "BACKGROUND")
honorBar.bg:SetAllPoints(honorBar)

honorBar.text = honorBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
honorBar.text:SetPoint("CENTER", honorBar, "CENTER", 0, 0)
honorBar.text:SetJustifyH("CENTER")
honorBar.text:SetJustifyV("MIDDLE")

honorBar._border = CreateBorderTextures(honorBar)
honorBar._ticks  = { ticks = {} }
honorFrame:Hide()

addon.honorFrame = honorFrame
addon.honorBar   = honorBar

--=========================================================
-- Position save helpers
--=========================================================
local function SaveXPPosition()
    local db = EnsureDB()
    local p, _, rp, x, y = bar:GetPoint(1)
    if not p then return end
    db.point = p;  db.relPoint = rp or p
    db.x = math.floor((x or 0) + 0.5)
    db.y = math.floor((y or 0) + 0.5)
end

local function SaveRepPosition()
    local db = EnsureDB()
    local p, _, rp, x, y = repFrame:GetPoint(1)
    if not p then return end
    db.repPoint = p;  db.repRelPoint = rp or p
    db.repX = math.floor((x or 0) + 0.5)
    db.repY = math.floor((y or 0) + 0.5)
end

local function SaveHonorPosition()
    local db = EnsureDB()
    local p, _, rp, x, y = honorFrame:GetPoint(1)
    if not p then return end
    db.honorPoint = p;  db.honorRelPoint = rp or p
    db.honorX = math.floor((x or 0) + 0.5)
    db.honorY = math.floor((y or 0) + 0.5)
end

--=========================================================
-- Drag configuration (all three bars)
--=========================================================
local function ConfigureDragging()
    local db = EnsureDB()
    bar:SetMovable(true)
    bar:SetClampedToScreen(db.clamp ~= false)
    if db.clickThrough then
        bar:EnableMouse(false); bar:RegisterForDrag()
        bar:SetScript("OnDragStart", nil); bar:SetScript("OnDragStop", nil)
        return
    end
    if db.locked then
        bar:EnableMouse(true); bar:RegisterForDrag()
        bar:SetScript("OnDragStart", nil); bar:SetScript("OnDragStop", nil)
        return
    end
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() bar:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        SaveXPPosition()
        if db.repSnap    then addon.LayoutBars() end
        if addon.RefreshConfig then addon.RefreshConfig() end
    end)
end

local function ConfigureRepDragging()
    local db = EnsureDB()
    if db.repSnap or db.clickThrough then
        repFrame:EnableMouse(false); repFrame:RegisterForDrag()
        repFrame:SetScript("OnDragStart", nil); repFrame:SetScript("OnDragStop", nil)
        return
    end
    if db.locked then
        repFrame:EnableMouse(true); repFrame:RegisterForDrag()
        repFrame:SetScript("OnDragStart", nil); repFrame:SetScript("OnDragStop", nil)
        return
    end
    repFrame:SetMovable(true)
    repFrame:SetClampedToScreen(db.clamp ~= false)
    repFrame:EnableMouse(true)
    repFrame:RegisterForDrag("LeftButton")
    repFrame:SetScript("OnDragStart", function() repFrame:StartMoving() end)
    repFrame:SetScript("OnDragStop", function()
        repFrame:StopMovingOrSizing()
        SaveRepPosition()
        if addon.RefreshConfig then addon.RefreshConfig() end
    end)
end

local function ConfigureHonorDragging()
    local db = EnsureDB()
    if db.honorSnap or db.clickThrough then
        honorFrame:EnableMouse(false); honorFrame:RegisterForDrag()
        honorFrame:SetScript("OnDragStart", nil); honorFrame:SetScript("OnDragStop", nil)
        return
    end
    if db.locked then
        honorFrame:EnableMouse(true); honorFrame:RegisterForDrag()
        honorFrame:SetScript("OnDragStart", nil); honorFrame:SetScript("OnDragStop", nil)
        return
    end
    honorFrame:SetMovable(true)
    honorFrame:SetClampedToScreen(db.clamp ~= false)
    honorFrame:EnableMouse(true)
    honorFrame:RegisterForDrag("LeftButton")
    honorFrame:SetScript("OnDragStart", function() honorFrame:StartMoving() end)
    honorFrame:SetScript("OnDragStop", function()
        honorFrame:StopMovingOrSizing()
        SaveHonorPosition()
        if addon.RefreshConfig then addon.RefreshConfig() end
    end)
end

function addon.UpdateDragState()
    ConfigureDragging(); ConfigureRepDragging(); ConfigureHonorDragging()
end

--=========================================================
-- Snap / layout  (rep + honor stack relative to XP bar)
-- Stacking order: rep always closer to XP, honor farther.
--=========================================================
function addon.LayoutBars()
    local db   = EnsureDB()
    local gap  = tonumber(db.repGap) or 2
    local barW = bar:GetWidth()

    local above, below = {}, {}
    local repH  = tonumber(db.repHeight)   or 8
    local honH  = tonumber(db.honorHeight) or 8

    if db.showRep and db.repSnap then
        if db.repAbove then above[#above+1] = { f=repFrame,   h=repH  }
        else                below[#below+1] = { f=repFrame,   h=repH  } end
    end
    if db.showHonor and db.honorSnap then
        if db.honorAbove then above[#above+1] = { f=honorFrame, h=honH }
        else                  below[#below+1] = { f=honorFrame, h=honH } end
    end

    -- Stack above XP: BOTTOM of each bar anchors to TOP of previous
    local prevA = bar
    for _, e in ipairs(above) do
        e.f:SetMovable(false); e.f:ClearAllPoints()
        e.f:SetPoint("BOTTOMLEFT",  prevA, "TOPLEFT",  0,  gap)
        e.f:SetPoint("BOTTOMRIGHT", prevA, "TOPRIGHT", 0,  gap)
        e.f:SetWidth(barW); e.f:SetHeight(e.h); e.f:Show()
        prevA = e.f
    end

    -- Stack below XP: TOP of each bar anchors to BOTTOM of previous
    local prevB = bar
    for _, e in ipairs(below) do
        e.f:SetMovable(false); e.f:ClearAllPoints()
        e.f:SetPoint("TOPLEFT",  prevB, "BOTTOMLEFT",  0, -gap)
        e.f:SetPoint("TOPRIGHT", prevB, "BOTTOMRIGHT", 0, -gap)
        e.f:SetWidth(barW); e.f:SetHeight(e.h); e.f:Show()
        prevB = e.f
    end

    -- Rep detached
    if db.showRep then
        if not db.repSnap then
            repFrame:ClearAllPoints()
            repFrame:SetPoint(db.repPoint or "CENTER", UIParent,
                db.repRelPoint or "CENTER", db.repX or 0, db.repY or 0)
            repFrame:SetWidth(tonumber(db.width) or 1024)
            repFrame:SetHeight(repH)
            repFrame:Show()
        end
    else
        repFrame:Hide()
    end

    -- Honor detached
    if db.showHonor then
        if not db.honorSnap then
            honorFrame:ClearAllPoints()
            honorFrame:SetPoint(db.honorPoint or "CENTER", UIParent,
                db.honorRelPoint or "CENTER", db.honorX or 0, db.honorY or 0)
            honorFrame:SetWidth(tonumber(db.width) or 1024)
            honorFrame:SetHeight(honH)
            honorFrame:Show()
        end
    else
        honorFrame:Hide()
    end
end

--=========================================================
-- Text-style helper (used by ApplySettings for each bar)
--=========================================================
local function ApplyTextStyle(fontStr, db, prefix)
    if not fontStr then return end
    local p = prefix or ""
    local function get(k) return db[p..k] or db[k] end
    local fp   = get("font")        or "Fonts\\FRIZQT__.TTF"
    local fsz  = tonumber(get("fontSize"))   or 12
    local fol  = get("fontOutline") or "OUTLINE"
    fontStr:SetFont(fp, fsz, fol)
    local tc = get("textColor") or { r=1,g=1,b=1,a=1 }
    if type(tc) == "table" then
        fontStr:SetTextColor(tc.r or 1, tc.g or 1, tc.b or 1, tc.a or 1)
    end
    local shadow = get("textShadow")
    if shadow == nil then shadow = db.textShadow end
    if shadow then
        local sc  = get("textShadowColor")  or { r=0,g=0,b=0,a=1 }
        local off = tonumber(get("textShadowOffset")) or 1
        fontStr:SetShadowColor(sc.r or 0, sc.g or 0, sc.b or 0, sc.a or 1)
        fontStr:SetShadowOffset(off, -off)
    else
        fontStr:SetShadowColor(0,0,0,0); fontStr:SetShadowOffset(0,0)
    end
end

--=========================================================
-- Content updates
--=========================================================
function addon.UpdateXP()
    local maxXP = (UnitXPMax and UnitXPMax("player")) or 0
    local curXP = (UnitXP    and UnitXP("player"))    or 0
    if maxXP <= 0 then bar:Hide(); return end
    bar:Show()
    bar:SetMinMaxValues(0, maxXP)
    bar:SetValue(curXP)

    local db       = EnsureDB()
    local restedXP = (GetXPExhaustion and GetXPExhaustion()) or 0

    if bar.rested then
        if db.showRested and restedXP > 0 then
            bar.rested:SetMinMaxValues(0, maxXP)
            bar.rested:SetValue(math.min(curXP + restedXP, maxXP))
            bar.rested:Show()
        else
            bar.rested:Hide()
        end
    end

    local wantText = db.showXPText ~= false and db.showText ~= false
    if wantText and bar.text then
        local txt = FormatBarText(db.xpTextFormat, curXP, maxXP, nil, restedXP)
        if txt then
            bar.text:SetText(txt)
            bar.text:Show()
        else
            bar.text:Hide()
        end
    elseif bar.text then
        bar.text:Hide()
    end
end

function addon.UpdateReputation()
    local db = EnsureDB()
    -- Frame visibility is owned entirely by LayoutBars.
    -- This function only updates the bar's content.
    if not db.showRep then return end

    -- Cross-version reputation API
    local name, barMin, barMax, barValue
    do
        local f = _G.GetWatchedFactionInfo
        if type(f) == "function" then
            local ok, n, _, mn, mx, val = pcall(f)
            if ok then name, barMin, barMax, barValue = n, mn, mx, val end
        end
        if not name and _G.C_Reputation then
            local cr = _G.C_Reputation
            local data
            if     type(cr.GetWatchedFactionData) == "function" then
                data = cr.GetWatchedFactionData()
            elseif type(cr.GetWatchedFactionInfo) == "function" then
                data = cr.GetWatchedFactionInfo()
            end
            if data then
                name = data.name
                -- Retail provides verbose names; some versions also expose barMin/barMax/barValue
                barMin   = data.barMin or data.currentReactionThreshold or 0
                barMax   = data.barMax or data.nextReactionThreshold    or 1
                barValue = data.barValue or data.currentStanding        or 0
            end
        end
    end

    if not name then
        -- No faction tracked: show an empty bar, hide text
        repBar:SetMinMaxValues(0, 1)
        repBar:SetValue(0)
        if repBar.text then repBar.text:Hide() end
        return
    end

    local cur  = (barValue or 0) - (barMin or 0)
    local maxv = (barMax   or 0) - (barMin or 0)
    if maxv <= 0 then maxv = 1 end

    repBar:SetMinMaxValues(0, maxv)
    repBar:SetValue(cur)

    local rc = (type(db.repColor) == "table") and db.repColor or {r=0,g=0.8,b=0.2,a=1}
    repBar:SetStatusBarColor(rc.r or 0, rc.g or 0.8, rc.b or 0.2, rc.a or 1)

    local wantText = db.showRepText ~= false and db.showText ~= false
    if wantText and repBar.text then
        local txt = FormatBarText(db.repTextFormat, cur, maxv, name)
        if txt then
            repBar.text:SetText(txt)
            repBar.text:Show()
        else
            repBar.text:Hide()
        end
    elseif repBar.text then
        repBar.text:Hide()
    end

    -- autoRepAtMax: hide XP bar at max level when rep is showing
    -- (handled in ApplyVisibility so it doesn't fight UpdateXP)
end

function addon.UpdateHonor()
    local db = EnsureDB()
    if not db.showHonor then honorFrame:Hide(); return end

    local name, cur, mx = GetHonorData()
    if not name then honorFrame:Hide(); return end

    honorBar:SetMinMaxValues(0, mx)
    honorBar:SetValue(cur)

    local hc = (type(db.honorColor) == "table") and db.honorColor or {r=0.9,g=0.1,b=0.1,a=1}
    honorBar:SetStatusBarColor(hc.r or 0.9, hc.g or 0.1, hc.b or 0.1, hc.a or 1)

    local wantText = db.showHonorText ~= false and db.showText ~= false
    if wantText and honorBar.text then
        local txt = FormatBarText(db.honorTextFormat, cur, mx, name)
        if txt then
            honorBar.text:SetText(txt)
            honorBar.text:Show()
        else
            honorBar.text:Hide()
        end
    elseif honorBar.text then
        honorBar.text:Hide()
    end
end

local function UpdateAll()
    addon.UpdateXP(); addon.UpdateReputation(); addon.UpdateHonor()
end

--=========================================================
-- Fade / visibility
--=========================================================
function addon.ApplyVisibility()
    if not bar then return end
    local db = EnsureDB()
    if db.enabled == false then bar:Hide(); return end
    if db.hideInCombat and InCombatLockdown and InCombatLockdown() then
        bar:Hide(); return
    end
    -- Hide XP bar at max level when rep bar is enabled
    if db.autoRepAtMax ~= false and db.showRep then
        local maxLvl = addon.Compat and addon.Compat.GetMaxLevel and addon.Compat.GetMaxLevel()
        if maxLvl and UnitLevel then
            local ok, lvl = pcall(UnitLevel, "player")
            if ok and tonumber(lvl) and lvl >= maxLvl then
                bar:Hide(); return
            end
        end
    end
    bar:Show()
end

local function ApplyFadeState(hovered)
    local db = EnsureDB()
    if db.enabled == false then return end
    if db.mouseoverFade then
        bar:SetAlpha(hovered and 1 or Clamp01(tonumber(db.fadeAlpha) or 0.25))
    else
        bar:SetAlpha(1)
    end
end

function addon.UpdateFadeHandlers()
    local db = EnsureDB()
    if db.clickThrough then return end
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", function() ApplyFadeState(true)  end)
    bar:SetScript("OnLeave", function() ApplyFadeState(false) end)
    ApplyFadeState(false)
end

--=========================================================
-- Flash bars  (visual locator button in config)
--=========================================================
function addon.FlashBars()
    local function flash(frame)
        if not frame or not frame.IsShown or not frame:IsShown() then return end
        local orig = frame:GetAlpha()
        local t    = 0
        frame:SetScript("OnUpdate", function(self, dt)
            t = t + dt
            if t >= 2.5 then
                self:SetAlpha(orig); self:SetScript("OnUpdate", nil)
            else
                self:SetAlpha(0.2 + 0.8 * math.abs(math.sin(t * math.pi * 3)))
            end
        end)
    end
    flash(bar); flash(repFrame); flash(honorFrame)
end

--=========================================================
-- ApplySettings  (full style + layout pass)
--=========================================================
function addon.ApplySettings()
    local db = EnsureDB()

    -- Tick preset → showTicks / tickCount (only when a preset is explicitly stored)
    if     db.tickPreset == "none" then db.showTicks = false
    elseif db.tickPreset == "20"   then db.showTicks = true; db.tickCount = 5
    elseif db.tickPreset == "10"   then db.showTicks = true; db.tickCount = 10
    -- nil / unknown: leave showTicks as-is (respects the defaults table value)
    end

    -- linkBars: inherit XP appearance to rep + honor
    if db.linkBars then
        local linked = {
            "texture","textureName","font","fontName","fontSize","fontOutline",
            "bgColor","bgAlpha","textColor","textShadow","textShadowColor",
            "textShadowOffset","showBorder","showTicks","tickCount","tickAlpha",
        }
        for _, k in ipairs(linked) do
            local up = k:sub(1,1):upper() .. k:sub(2)
            db["rep"   .. up] = db[k]
            db["honor" .. up] = db[k]
        end
        db.repWidth   = db.width
        db.honorWidth = db.width
    end

    -- Blizzard XP bar
    HideBlizzardXP(db.hideBlizzard and true or false)

    -- ── XP bar ──────────────────────────────────────────────
    bar:SetScale(tonumber(db.scale)  or 1)
    bar:SetWidth(tonumber(db.width)  or 1024)
    bar:SetHeight(tonumber(db.height) or 18)
    bar:ClearAllPoints()
    bar:SetPoint(db.point or "CENTER", UIParent,
        db.relPoint or db.point or "CENTER",
        tonumber(db.x) or 0, tonumber(db.y) or 0)

    local tex = db.texture or "Interface\\TARGETINGFRAME\\UI-StatusBar"
    bar:SetStatusBarTexture(tex)

    if bar.bg then
        local bgc = db.bgColor or {r=0,g=0,b=0}
        local a   = tonumber(db.bgAlpha) or (type(bgc)=="table" and bgc.a) or 0.5
        SetSolidColor(bar.bg, bgc.r or 0, bgc.g or 0, bgc.b or 0, a)
    end
    if type(db.barColor) == "table" then
        local c = db.barColor
        bar:SetStatusBarColor(c.r or 0, c.g or 0.6, c.b or 1, c.a or 1)
    end
    if bar.rested then
        bar.rested:SetStatusBarTexture(tex)
        if type(db.restedColor) == "table" then
            local c = db.restedColor
            bar.rested:SetStatusBarColor(c.r or 0.6, c.g or 0, c.b or 1, c.a or 0.6)
        end
    end
    if bar.text then
        bar.text:SetShown(db.showText and true or false)
        ApplyTextStyle(bar.text, db, "")
    end
    UpdateBorderAndTicks(bar, {
        showBorder=db.showBorder, showTicks=db.showTicks,
        tickCount=db.tickCount,   tickAlpha=db.tickAlpha,
    })

    -- ── Reputation bar ──────────────────────────────────────
    do
        local repTex = db.repTexture or tex
        local repH   = tonumber(db.repHeight) or 8
        repBar:SetStatusBarTexture(repTex)
        repFrame:SetHeight(repH)
        if repBar.bg then
            local bgc = db.repBgColor or db.bgColor or {r=0,g=0,b=0}
            local a   = tonumber(db.repBgAlpha) or tonumber(db.bgAlpha) or 0.5
            SetSolidColor(repBar.bg, bgc.r or 0, bgc.g or 0, bgc.b or 0, a)
        end
        if repBar.text then
            repBar.text:SetShown(db.showText and true or false)
            ApplyTextStyle(repBar.text, db, "rep")
        end
        UpdateBorderAndTicks(repBar, {
            showBorder = db.repShowBorder or db.showBorder,
            showTicks  = db.repShowTicks  or db.showTicks,
            tickCount  = db.repTickCount  or db.tickCount,
            tickAlpha  = db.repTickAlpha  or db.tickAlpha,
        })
    end

    -- ── Honor bar ───────────────────────────────────────────
    do
        local honTex = db.honorTexture or tex
        local honH   = tonumber(db.honorHeight) or 8
        honorBar:SetStatusBarTexture(honTex)
        honorFrame:SetHeight(honH)
        if honorBar.bg then
            local bgc = db.honorBgColor or db.bgColor or {r=0,g=0,b=0}
            local a   = tonumber(db.honorBgAlpha) or tonumber(db.bgAlpha) or 0.5
            SetSolidColor(honorBar.bg, bgc.r or 0, bgc.g or 0, bgc.b or 0, a)
        end
        if honorBar.text then
            honorBar.text:SetShown(db.showText and true or false)
            ApplyTextStyle(honorBar.text, db, "honor")
        end
        UpdateBorderAndTicks(honorBar, {
            showBorder = db.honorShowBorder or db.showBorder,
            showTicks  = db.honorShowTicks  or db.showTicks,
            tickCount  = db.honorTickCount  or db.tickCount,
            tickAlpha  = db.honorTickAlpha  or db.tickAlpha,
        })
    end

    -- ── Drag + layout ───────────────────────────────────────
    ConfigureDragging(); ConfigureRepDragging(); ConfigureHonorDragging()
    addon.LayoutBars()
    addon.UpdateFadeHandlers()
    addon.ApplyVisibility()
    UpdateAll()
end

--=========================================================
-- Public position helpers (used by Config for live display)
--=========================================================
function addon.GetBarPositionText()
    local db = EnsureDB()
    return string.format("X: %d  Y: %d", tonumber(db.x) or 0, tonumber(db.y) or 0)
end
function addon.GetRepPositionText()
    local db = EnsureDB()
    return string.format("X: %d  Y: %d", tonumber(db.repX) or 0, tonumber(db.repY) or 0)
end
function addon.GetHonorPositionText()
    local db = EnsureDB()
    return string.format("X: %d  Y: %d", tonumber(db.honorX) or 0, tonumber(db.honorY) or 0)
end

--=========================================================
-- OnSizeChanged – relayout ticks when bar resizes
--=========================================================
bar:SetScript("OnSizeChanged", function()
    local db = EnsureDB()
    local cfg = { showBorder=db.showBorder, showTicks=db.showTicks,
                  tickCount=db.tickCount,   tickAlpha=db.tickAlpha }
    UpdateBorderAndTicks(bar,      cfg)
    UpdateBorderAndTicks(repBar,   cfg)
    UpdateBorderAndTicks(honorBar, cfg)
end)

--=========================================================
-- Event handling with debounced XP / Honor updates
--=========================================================
local eventFrame = CreateFrame("Frame")
addon.frame = eventFrame

local xpPending, honorPending = false, false

local function ScheduleXP()
    if xpPending then return end
    xpPending = true
    SafeAfter(0.1, function() xpPending = false; addon.UpdateXP() end)
end

local function ScheduleHonor()
    if honorPending then return end
    honorPending = true
    SafeAfter(0.1, function() honorPending = false; addon.UpdateHonor() end)
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
pcall(function() eventFrame:RegisterEvent("UPDATE_EXHAUSTION") end)
pcall(function() eventFrame:RegisterEvent("UPDATE_FACTION")   end)
for _, ev in ipairs({
    "UPDATE_HONOR", "HONOR_XP_UPDATE",
    "CURRENCY_DISPLAY_UPDATE", "PLAYER_PVP_RANK_CHANGED",
    "PLAYER_FLAGS_CHANGED",  -- fires on honor rank change in Classic Era
}) do
    pcall(function() eventFrame:RegisterEvent(ev) end)
end

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        addon.ApplySettings()
    elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP"
        or event == "UPDATE_EXHAUSTION" then
        ScheduleXP()
    elseif event == "UPDATE_FACTION" then
        addon.UpdateReputation()
    elseif event == "UPDATE_HONOR"    or event == "HONOR_XP_UPDATE"
        or event == "CURRENCY_DISPLAY_UPDATE"
        or event == "PLAYER_PVP_RANK_CHANGED"
        or event == "PLAYER_FLAGS_CHANGED" then
        ScheduleHonor()
    end
end)

-- Hook populated by Config file for live position refresh
addon.RefreshConfig = nil

--=========================================================
-- Serializer / Profile Import-Export
--=========================================================
local function SerializeValue(v, depth)
    depth = (depth or 0) + 1
    if depth > 12 then return "nil" end
    local t = type(v)
    if t == "nil"     then return "nil"
    elseif t == "boolean" then return tostring(v)
    elseif t == "number"  then return tostring(v)
    elseif t == "string"  then return string.format("%q", v)
    elseif t == "table"   then
        local parts, n = {}, #v
        for i = 1, n do parts[#parts+1] = SerializeValue(v[i], depth) end
        for k, val in pairs(v) do
            local isSeq = (type(k)=="number" and k>=1 and k<=n and math.floor(k)==k)
            if not isSeq then
                local ks
                if type(k)=="string" and k:match("^[%a_][%w_]*$") then ks = k
                else ks = "[" .. SerializeValue(k, depth) .. "]" end
                parts[#parts+1] = ks .. "=" .. SerializeValue(val, depth)
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil"
end

local _dangerPatterns = {
    "function%s*%(", "require%s*%(", "load%s*%(", "loadstring%s*%(",
    "dofile%s*%(", "loadfile%s*%(", "rawset%s*%(", "rawget%s*%(",
    "setmetatable%s*%(", "io%s*%.", "os%s*%.", "debug%s*%.", "package%s*%.",
}
local function IsDangerousImportString(s)
    if type(s) ~= "string" then return true end
    local lo = s:lower()
    for _, p in ipairs(_dangerPatterns) do if lo:find(p) then return true end end
    return false
end

function addon:ExportSetupString()
    local db, sv = addon.GetDB()
    local cur    = sv and sv.current or "Default"
    return "XPMBS2:" .. SerializeValue({ v=2, current=cur, profile=DeepCopy(db, {}) })
end

function addon:ImportSetupString(str, overwriteProfile)
    if type(str) ~= "string"     then return false, "No import string." end
    if not str:match("^XPMBS2?:") then return false, "Invalid setup string." end
    if IsDangerousImportString(str) then return false, "Import rejected (unsafe content)." end

    local payload = str:gsub("^XPMBS2?:", "")
    local fn = (loadstring and loadstring("return "..payload))
            or (load        and load("return "..payload))
    if type(fn) ~= "function" then return false, "Import failed (parse error)." end

    local ok, tbl = pcall(fn)
    if not ok or type(tbl)~="table"    then return false, "Import failed (bad data)." end
    if type(tbl.profile) ~= "table"    then return false, "Import failed (missing profile)." end

    local name  = tostring(tbl.current or "Imported")
    local _, sv = addon.GetDB()
    if not sv then return false, "SavedVariables not ready." end

    if sv.profiles[name] and not overwriteProfile then
        local base, i = name, 2
        while sv.profiles[name] do name = base.." "..i; i=i+1 end
    end
    sv.profiles[name] = DeepCopy(tbl.profile, {})
    ActivateProfile(name)
    return true
end

function addon:CopyStringToChat(s, prefix)
    if type(s) ~= "string" or s == "" then return end
    local chat = DEFAULT_CHAT_FRAME
    if not chat or type(chat.AddMessage) ~= "function" then return end
    local maxLen = 240
    local total  = math.ceil(#s / maxLen)
    if total > 1 then
        chat:AddMessage((prefix or "TibbettsMultiBar")..": split into "..total.." parts.")
    end
    local i, part = 1, 1
    while i <= #s do
        local chunk = s:sub(i, i+maxLen-1)
        local tag   = total > 1 and ("["..part.."/"..total.."] ") or ""
        chat:AddMessage(tag..chunk)
        i, part = i+maxLen, part+1
    end
end

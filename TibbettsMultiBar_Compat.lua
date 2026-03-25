local addonName, addon = ...
addon = addon or {}
addon.Compat = addon.Compat or {}
local C = addon.Compat

-- ─────────────────────────────────────────────────────────────
-- Client flavor detection
-- Uses the TOC interface number (4th return of GetBuildInfo).
-- Runs at file-load time so all downstream code can branch on it.
-- ─────────────────────────────────────────────────────────────
do
    local iface = 0
    if GetBuildInfo then
        local ok, _, _, _, n = pcall(GetBuildInfo)
        if ok then iface = tonumber(n) or 0 end
    end
    C.iface     = iface
    C.IsRetail  = iface >= 100000             -- TWW, Midnight, future retail
    C.IsMoP     = iface >= 50000  and iface < 100000
    C.IsCata    = iface >= 40000  and iface < 50000
    C.IsWrath   = iface >= 30000  and iface < 40000
    C.IsTBC     = iface >= 20000  and iface < 30000
    C.IsVanilla = iface > 0       and iface < 20000  -- Classic Era / Anniversary
    C.IsClassic = not C.IsRetail  -- any non-retail client

    -- Safe max-level helper; works on every client including Midnight (12.x)
    -- where GetMaxPlayerLevel was removed.
    function C.GetMaxLevel()
        -- Modern API (Midnight+): MAX_PLAYER_LEVEL global set by the game
        if tonumber(MAX_PLAYER_LEVEL) then return tonumber(MAX_PLAYER_LEVEL) end
        -- Legacy API still present on Classic and pre-Midnight retail
        if GetMaxPlayerLevel then
            local ok, lvl = pcall(GetMaxPlayerLevel)
            if ok and tonumber(lvl) then return tonumber(lvl) end
        end
        -- Use the logged-in character's level as a lower-bound proxy
        if UnitLevel then
            local ok, lvl = pcall(UnitLevel, "player")
            if ok and tonumber(lvl) and lvl > 0 then return tonumber(lvl) end
        end
        -- Hard-coded last resort per flavour
        if C.IsRetail  then return 90  end   -- Midnight launch cap
        if C.IsVanilla then return 60  end
        if C.IsTBC     then return 70  end
        if C.IsWrath   then return 80  end
        if C.IsCata    then return 85  end
        if C.IsMoP     then return 90  end
        return 70
    end
end

-- ─────────────────────────────────────────────────────────────
-- Safely call an object method if it exists
-- ─────────────────────────────────────────────────────────────
function C.SafeCall(obj, method, ...)
    if obj and method and obj[method] then
        return obj[method](obj, ...)
    end
end

-- Cross-client enabled/disabled helper
function C.SetEnabled(frame, enabled)
    if not frame then return end
    enabled = enabled and true or false
    if frame.SetEnabled then frame:SetEnabled(enabled)
    else
        if enabled  and frame.Enable  then frame:Enable()  end
        if not enabled and frame.Disable then frame:Disable() end
    end
    if frame.SetAlpha     then frame:SetAlpha(enabled and 1 or 0.5) end
    if frame.EnableMouse  then frame:EnableMouse(enabled) end
end

-- Cross-client solid-color texture
function C.SetSolidColor(tex, r, g, b, a)
    if not tex then return end
    a = tonumber(a) or 1
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    if tex.SetColorTexture then
        tex:SetColorTexture(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0, a)
        return
    end
    if tex.SetTexture     then tex:SetTexture("Interface\\Buttons\\WHITE8X8") end
    if tex.SetVertexColor then tex:SetVertexColor(tonumber(r) or 0, tonumber(g) or 0,
                                                   tonumber(b) or 0, a) end
end

-- Detect Retail Settings API
function C.HasModernSettings()
    return _G.Settings and _G.Settings.RegisterCanvasLayoutCategory and true or false
end

-- Cross-version color picker  (handles Dragonflight's SetupColorPickerAndShow)
function C.ShowColorPicker(initial, hasAlpha, changed)
    local function unpack_color(c)
        if type(c) ~= "table" then return 1,1,1,1 end
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end
    local r, g, b, a = unpack_color(initial)

    local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na
        if hasAlpha then
            if ColorPickerFrame.GetColorAlpha then
                na = 1 - ColorPickerFrame:GetColorAlpha()
            else
                na = 1 - (ColorPickerFrame.opacity or 0)
            end
        else
            na = 1
        end
        changed(nr, ng, nb, na)
    end

    -- Dragonflight+ API (10.0.2+)
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            swatchFunc  = apply,
            opacityFunc = apply,
            cancelFunc  = function(prev)
                if prev then changed(prev.r, prev.g, prev.b, prev.a) end
            end,
            hasOpacity      = hasAlpha and true or false,
            opacity         = hasAlpha and (1 - a) or 0,
            previousValues  = { r=r, g=g, b=b, a=a },
            r = r, g = g, b = b,
        })
        return
    end

    -- Legacy API (pre-Dragonflight)
    ColorPickerFrame.hasOpacity       = hasAlpha and true or false
    ColorPickerFrame.opacity          = hasAlpha and (1 - a) or 0
    ColorPickerFrame.previousValues   = { r=r, g=g, b=b, a=a }
    ColorPickerFrame.func             = apply
    ColorPickerFrame.swatchFunc       = apply
    ColorPickerFrame.opacityFunc      = apply
    ColorPickerFrame.cancelFunc       = function(prev)
        if prev then changed(prev.r, prev.g, prev.b, prev.a) end
    end
    ColorPickerFrame:SetColorRGB(r, g, b)
    if hasAlpha and _G.OpacitySliderFrame and _G.OpacitySliderFrame.SetValue then
        _G.OpacitySliderFrame:SetValue(ColorPickerFrame.opacity or 0)
    end
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end

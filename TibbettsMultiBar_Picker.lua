local addonName, addon = ...

-- Universal searchable picker (works across TBC/Classic/Retail)
-- Implemented in its own file to avoid Lua upvalue limits on older clients.

addon = addon or {}
addon.UniversalPicker = addon.UniversalPicker or {}

local UniversalPicker = addon.UniversalPicker

local _wipe = wipe or (table and table.wipe)

local pickerFrame

local function Normalize(s)
    return (tostring(s or ""):lower())
end

local function BuildSortedItems(map)
    local names = {}
    for name in pairs(map or {}) do
        names[#names+1] = name
    end
    table.sort(names, function(a,b) return tostring(a):lower() < tostring(b):lower() end)
    local out = {}
    for i=1, #names do
        local n = names[i]
        out[i] = { name = n, path = map[n] }
    end
    return out
end

local function CreatePicker()
    if pickerFrame then return pickerFrame end

    local f = CreateFrame("Frame", "TibbettsMultiBar_UniversalPicker", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:Hide()

    -- click-away catcher to close when clicking outside
    local clickAway = CreateFrame("Frame", nil, UIParent)
    clickAway:SetAllPoints(UIParent)
    clickAway:SetFrameStrata("FULLSCREEN")
    clickAway:EnableMouse(true)
    clickAway:Hide()
    clickAway:SetScript("OnMouseDown", function() f:Hide() end)
    f.clickAway = clickAway

    f:SetScript("OnShow", function()
        if f.clickAway then f.clickAway:Show() end
    end)
    f:SetScript("OnHide", function()
        if f.clickAway then f.clickAway:Hide() end
        f.externalEdit = nil
        if f.searchLabel then f.searchLabel:Show() end
        if f.search then f.search:Show() end
        f.externalOwner = nil
    end)

    -- Backdrop (TBC-safe)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        if f.SetBackdropColor then
            f:SetBackdropColor(0,0,0,1)
        end
    end

    f:SetSize(420, 460)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 16, -14)
    f.title:SetText("Select")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Search box (internal)
    local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("TOPLEFT", 18, -44)
    searchLabel:SetText("Search")
    f.searchLabel = searchLabel

    local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    search:SetAutoFocus(false)
    search:SetSize(260, 20)
    search:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    search:SetScript("OnEscapePressed", function() f:Hide() end)
    search:SetScript("OnEnterPressed", function()
        local it = f.filtered and f.filtered[1]
        if it and f.onSelect then
            f.onSelect(it)
        end
        f:Hide()
    end)
    f.search = search

    -- Faux scroll frame list
    local scrollFrame = CreateFrame("ScrollFrame", "TibbettsMultiBar_UniversalPickerScroll", f, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -72)
    scrollFrame:SetPoint("BOTTOMRIGHT", -36, 16)
    f.scrollFrame = scrollFrame

    -- Solid list background so gaps between rows are not transparent
    f.listBG = f:CreateTexture(nil, "BACKGROUND")
    f.listBG:SetPoint("TOPLEFT", 16, -72)
    f.listBG:SetPoint("BOTTOMRIGHT", -36, 16)
    f.listBG:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.listBG:SetVertexColor(0.10, 0.10, 0.10, 1)


    f.rows = {}
    f.rowHeight = 24
    f.visibleRows = 14
    f.filtered = {}
    f.data = {}
    f.kind = "texture"

    local function CreateRow(i)
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(f.rowHeight)
        b:SetPoint("LEFT", 18, 0)
        b:SetPoint("RIGHT", -44, 0)
        b:RegisterForClicks("AnyUp")
        b:EnableMouse(true)

        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        b.bg:SetVertexColor(0.12, 0.12, 0.12, 1)

        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        b.hl:SetBlendMode("ADD")

        b.preview = b:CreateTexture(nil, "ARTWORK")
        b.preview:SetPoint("LEFT", 6, 0)
        b.preview:SetPoint("RIGHT", -6, 0)
        b.preview:SetHeight(18)

        b.overlay = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.overlay:SetPoint("CENTER", b.preview, "CENTER", 0, 0)
        b.overlay:SetJustifyH("CENTER")
        b.overlay:SetTextColor(1,1,1)
        if b.overlay.SetShadowOffset then b.overlay:SetShadowOffset(1, -1) end
        if b.overlay.SetShadowColor then b.overlay:SetShadowColor(0, 0, 0, 1) end
        if b.overlay.SetFont then
            local font, size = b.overlay:GetFont()
            if font and size then b.overlay:SetFont(font, size, "OUTLINE") end
        end

        return b
    end

    for i=1, f.visibleRows do
        local row = CreateRow(i)
        f.rows[i] = row
        if i == 1 then
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -72)
        else
            row:SetPoint("TOPLEFT", f.rows[i-1], "BOTTOMLEFT", 0, 0)
        end
        row:SetScript("OnClick", function(self)
            local it = self.item
            if it and f.onSelect then f.onSelect(it) end
            f:Hide()
        end)
    end

    function f:SetRowHeight(h)
        h = tonumber(h) or 24
        self.rowHeight = h
        for i=1, #self.rows do
            self.rows[i]:SetHeight(h)
        end
        self:RebuildFilter()
    end

    function f:RebuildFilter()
        if _wipe then _wipe(self.filtered) else for k in pairs(self.filtered) do self.filtered[k]=nil end end
        local q = self.externalEdit and Normalize(self.externalEdit:GetText()) or Normalize(self.search:GetText())
        if q == "" then
            for i=1, #self.data do self.filtered[i] = self.data[i] end
        else
            local n = 0
            for i=1, #self.data do
                local it = self.data[i]
                if Normalize(it.name):find(q, 1, true) then
                    n = n + 1
                    self.filtered[n] = it
                end
            end
        end
        FauxScrollFrame_Update(self.scrollFrame, #self.filtered, self.visibleRows, self.rowHeight + 2)
        self:UpdateRows()
    end

    function f:UpdateRows()
        local offset = FauxScrollFrame_GetOffset(self.scrollFrame) or 0
        for i=1, self.visibleRows do
            local idx = i + offset
            local row = self.rows[i]
            local it = self.filtered[idx]
            if it then
                row:Show()
                row.item = it

                if self.kind == "texture" then
                    row.preview:SetTexture(it.path)
                    row.preview:SetTexCoord(0,1,0,1)
                    if row.preview.SetVertexColor then row.preview:SetVertexColor(1,1,1,1) end

                    row.overlay:SetText(it.name)
                    row.overlay:SetFontObject("GameFontNormalSmall")
                    local font, size = row.overlay:GetFont()
                    if font and size and row.overlay.SetFont then row.overlay:SetFont(font, size, "OUTLINE") end
                else
                    row.preview:SetTexture("Interface\\Buttons\\WHITE8X8")
                    row.preview:SetTexCoord(0,1,0,1)
                    if row.preview.SetVertexColor then row.preview:SetVertexColor(0.08,0.08,0.08,1) end

                    row.overlay:SetText(it.name)
                    local ok = false
                    if row.overlay.SetFont and it.path then
                        local _, sz = row.overlay:GetFont()
                        sz = sz or 12
                        ok = pcall(row.overlay.SetFont, row.overlay, it.path, sz, "OUTLINE")
                    end
                    if not ok then
                        row.overlay:SetFontObject("GameFontNormalSmall")
                        local font, size = row.overlay:GetFont()
                        if font and size and row.overlay.SetFont then row.overlay:SetFont(font, size, "OUTLINE") end
                    end
                end
            else
                row:Hide()
                row.item = nil
            end
        end
    end

    search:SetScript("OnTextChanged", function()
        if not f.externalEdit then f:RebuildFilter() end
    end)

    scrollFrame:SetScript("OnVerticalScroll", function(self2, delta)
        FauxScrollFrame_OnVerticalScroll(self2, delta, f.rowHeight + 2, function() f:UpdateRows() end)
    end)

    if scrollFrame.EnableMouseWheel then
        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(self2, delta)
            local offset = FauxScrollFrame_GetOffset(self2) or 0
            local maxOffset = math.max(0, (#f.filtered - f.visibleRows))
            offset = offset - delta
            if offset < 0 then offset = 0 end
            if offset > maxOffset then offset = maxOffset end
            if FauxScrollFrame_SetOffset then
                FauxScrollFrame_SetOffset(self2, offset)
            else
                self2.offset = offset
            end
            FauxScrollFrame_Update(self2, #f.filtered, f.visibleRows, f.rowHeight + 2)
            f:UpdateRows()
        end)
    end

    pickerFrame = f
    return f
end

function UniversalPicker.Show(anchorFrame, title, kind, items, onSelect, opts)
    local f = CreatePicker()
    f.kind = kind or "texture"
    f.onSelect = onSelect
    f.title:SetText(title or "Select")
    f.data = items or {}
    f.search:SetText("")
    f.externalEdit = opts and opts.externalEdit or nil

    if f.externalEdit then
        if f.searchLabel then f.searchLabel:Hide() end
        if f.search then f.search:Hide() end
    else
        if f.searchLabel then f.searchLabel:Show() end
        if f.search then f.search:Show() end
    end

    -- Match sizing to the dropdown button when possible (with sane minimums)
    local aw = (anchorFrame and anchorFrame.GetWidth and anchorFrame:GetWidth()) or 0
    local ah = (anchorFrame and anchorFrame.GetHeight and anchorFrame:GetHeight()) or 24
    local w = math.max(380, aw + 60)
    f:SetWidth(w)
    f:SetRowHeight(ah)

    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -6)
    f:Show()
    f:RebuildFilter()

    if f.externalEdit then f.externalEdit:SetFocus() else f.search:SetFocus() end
end

function UniversalPicker.AttachToDropDown(dd, title, kind, getMap, onPick, optsProvider)
    local function OpenOrTogglePicker()
        local f = CreatePicker()
        if f:IsShown() and f.externalOwner == dd then
            f:Hide()
            if CloseDropDownMenus then CloseDropDownMenus() end
            return
        end
        if CloseDropDownMenus then CloseDropDownMenus() end

        local map = getMap and getMap() or {}
        local items = BuildSortedItems(map)
        local opts = optsProvider and optsProvider() or nil

        f.externalOwner = dd
        UniversalPicker.Show(dd, title, kind, items, function(it)
            if onPick then onPick(it.name, it.path) end
        end, opts)
    end

    -- Hook the arrow button if present
    local btn = dd and dd.GetName and dd:GetName() and _G[dd:GetName().."Button"]
    if btn then
        btn:SetScript("OnClick", function()
            OpenOrTogglePicker()
        end)
        btn:SetScript("OnMouseDown", function()
            if CloseDropDownMenus then CloseDropDownMenus() end
        end)
    end

    -- Hook clicks on the whole dropdown (not just the arrow)
    if dd then
        dd:EnableMouse(true)
        dd:SetScript("OnMouseDown", function()
            OpenOrTogglePicker()
        end)
    end
end

function UniversalPicker.GetFrame()
    return pickerFrame
end

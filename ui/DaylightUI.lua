local _, TrainerSpells = ...
local integration = {controllers = {}, listenersBound = false}
TrainerSpells.DaylightUI = integration

local ADDON_ICON = 133741
local BUTTON_SIZE = 36
local PANEL_WIDTH = 540
local PANEL_GAP = 6
local HEADER_HEIGHT = 44
local FILTER_TOP = 50
local HOST_TOP = 114

local function GetAPI()
    local dui = _G.DaylightUI
    local api = type(dui) == "table" and dui.API
    if type(api) == "table" and api.major == 1 then return api end
    return nil
end

local function GetColor(colors, key, r, g, b)
    local c = type(colors) == "table" and colors[key]
    if type(c) == "table" and type(c[1]) == "number" then return c[1], c[2], c[3] end
    return r, g, b
end

local function SafeAccent(api)
    if api and type(api.Accent) == "function" then
        local r, g, b = api.Accent()
        if type(r) == "number" and type(g) == "number" and type(b) == "number" then return r, g, b end
    end
    return 1, 0.82, 0
end

local function SafeFont(api)
    local font = api and type(api.Font) == "function" and api.Font()
    if type(font) == "string" and font ~= "" then return font end
    return STANDARD_TEXT_FONT
end

local function HideTooltipIfOwnedBy(root)
    if not GameTooltip or not GameTooltip:IsShown() then return end
    local owner = GameTooltip:GetOwner()
    while owner do
        if owner == root then
            GameTooltip:Hide()
            return
        end
        owner = owner:GetParent()
    end
end

local function CreateBorderLines(frame, parent)
    local lines = {}
    local parentFrame = parent or frame
    local top = parentFrame:CreateTexture(nil, "OVERLAY")
    top:SetTexture("Interface\\Buttons\\WHITE8X8")
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    top:SetHeight(1)
    lines[1] = top

    local bottom = parentFrame:CreateTexture(nil, "OVERLAY")
    bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    bottom:SetHeight(1)
    lines[2] = bottom

    local left = parentFrame:CreateTexture(nil, "OVERLAY")
    left:SetTexture("Interface\\Buttons\\WHITE8X8")
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    left:SetWidth(1)
    lines[3] = left

    local right = parentFrame:CreateTexture(nil, "OVERLAY")
    right:SetTexture("Interface\\Buttons\\WHITE8X8")
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    right:SetWidth(1)
    lines[4] = right

    return lines
end

local function SetBorderColor(lines, r, g, b, a)
    for _, line in ipairs(lines) do line:SetVertexColor(r, g, b, a) end
end

local Controller = {}
Controller.__index = Controller

function Controller:IsEnabled()
    if not TrainerSpells.SettingsReady then return false end
    if self.key == "spellbook" then
        return TrainerSpells:HasClassTrainers() and TrainerSpells:IsTabEnabled("spellbook") and TrainerSpells:HasSpellbookTabs()
    end
    return TrainerSpells:IsTabEnabled("professions") and TrainerSpells:HasProfessionTabs()
end

function Controller:GetAnchorTarget()
    if self.key == "professions" then
        local dui = _G.DaylightUI
        local panes = dui and dui.Craft and dui.Craft.Window and dui.Craft.Window.panes
        if type(panes) == "table" then
            local last = self.window
            for _, entry in ipairs(panes) do
                if entry and entry.frame and entry.frame:IsShown() then last = entry.frame end
            end
            return last
        end
    end
    return self.window
end

function Controller:PositionButton()
    if not self.button or not self.window then return end
    local target = self:GetAnchorTarget()
    self.button:ClearAllPoints()
    self.button:SetPoint("TOPLEFT", target, "TOPRIGHT", PANEL_GAP, 0)
end

function Controller:PaintButton()
    local button = self.button
    if not button then return end
    local api = GetAPI()
    if api and type(api.Skin) == "function" then api.Skin(button, {window = true}) end
    local r, g, b = SafeAccent(api)
    local active = self.panel and self.panel:IsShown()
    local hovered = button.hovered == true
    if active then
        button.topAccent:SetVertexColor(r, g, b, 0.95)
        button.topAccent:Show()
        SetBorderColor(button.borderLines, r, g, b, 0.85)
    elseif hovered then
        button.topAccent:SetVertexColor(r, g, b, 0.65)
        button.topAccent:Show()
        SetBorderColor(button.borderLines, r, g, b, 0.55)
    else
        button.topAccent:Hide()
        SetBorderColor(button.borderLines, 1, 1, 1, 0)
    end
end

function Controller:UpdateButtonVisibility()
    if not self.button then return end
    local enabled = self:IsEnabled()
    self.button:SetShown(enabled)
    if enabled then
        self:PositionButton()
        self:PaintButton()
    else
        self:Close()
    end
end

function Controller:CreateButton()
    local api = GetAPI()
    local button = CreateFrame("Button", nil, self.window)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameLevel(self.window:GetFrameLevel() + 5)
    if api and type(api.Skin) == "function" then api.Skin(button, {window = true}) end

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture(ADDON_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local topAccent = button:CreateTexture(nil, "OVERLAY")
    topAccent:SetTexture("Interface\\Buttons\\WHITE8X8")
    topAccent:SetHeight(2)
    topAccent:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -2)
    topAccent:SetPoint("TOPRIGHT", button, "TOPRIGHT", -4, -2)
    topAccent:Hide()
    button.topAccent = topAccent
    button.borderLines = CreateBorderLines(button)

    button:SetScript("OnEnter", function(btn)
        btn.hovered = true
        self:PaintButton()
        if GameTooltip then
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText("TrainerSpells")
            GameTooltip:AddLine(TrainerSpells:Trans(self.tooltipDescKey), 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(btn)
        btn.hovered = false
        self:PaintButton()
        HideTooltipIfOwnedBy(btn)
    end)
    button:SetScript("OnClick", function()
        self:Toggle()
    end)
    button:SetScript("OnShow", function()
        self:PositionButton()
        self:PaintButton()
        if self.panel and self.panel:IsShown() then self:PositionPanel() end
    end)

    self.button = button
    self:PositionButton()
    self:UpdateButtonVisibility()
end

function Controller:BuildContentAPI(panel)
    local controller = self
    local contentAPI = {}

    function contentAPI.CreateContentTab(host, _, icon, onClick)
        local api = GetAPI()
        local tab = CreateFrame("Button", nil, host)
        tab:SetSize(30, 30)
        if api and type(api.Skin) == "function" then api.Skin(tab, {noBevel = true, bgAlpha = 0.5}) end

        local tex = tab:CreateTexture(nil, "ARTWORK")
        tex:SetSize(22, 22)
        tex:SetPoint("CENTER", tab, "CENTER", 0, 0)
        tex:SetTexture(icon)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tab.Icon = tex

        local bar = tab:CreateTexture(nil, "OVERLAY")
        bar:SetTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetHeight(2)
        bar:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 3, 2)
        bar:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 2)
        bar:Hide()
        tab.selectedBar = bar
        tab.borderLines = CreateBorderLines(tab)
        tab.tsSelected = false

        function tab:PaintStyle()
            local curApi = GetAPI()
            if curApi and type(curApi.Skin) == "function" then curApi.Skin(self, {noBevel = true, bgAlpha = 0.5}) end
            local r, g, b = SafeAccent(curApi)
            if self.tsSelected then
                self.selectedBar:SetVertexColor(r, g, b, 1)
                self.selectedBar:Show()
                SetBorderColor(self.borderLines, r, g, b, 0.85)
            elseif self.tsHovered then
                self.selectedBar:Hide()
                SetBorderColor(self.borderLines, r, g, b, 0.45)
            else
                self.selectedBar:Hide()
                SetBorderColor(self.borderLines, 1, 1, 1, 0)
            end
        end

        function tab:SetTabSelected(selected)
            self.tsSelected = selected and true or false
            self:PaintStyle()
        end

        tab:SetScript("OnClick", function()
            onClick()
            if controller.saveViewKey and TrainerSpells_Character and controller.view and controller.view.mode then
                TrainerSpells_Character[controller.saveViewKey] = controller.view.mode
            end
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            end
        end)
        tab:PaintStyle()
        return tab
    end

    function contentAPI.PositionContentTab(tab, host, previous)
        tab:ClearAllPoints()
        if previous then
            tab:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            tab:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, 5)
        end
    end

    function contentAPI.PositionHeaderSlider(slider)
        slider:SetScale(0.8)
        slider:ClearAllPoints()
        slider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -40 / 0.8, -(FILTER_TOP + 5) / 0.8)
        slider:SetWidth(120)
    end

    return contentAPI
end

function Controller:FlowControl(control, available)
    local view = self.view
    if not view or not control or not control.frame then return end
    local height = TrainerSpells:FlowControls(control.frame, available)
    if not height then return end
    control.height = height + 12
    if control.mode == view.mode then
        view.scrollBox:ClearAllPoints()
        view.scrollBox:SetPoint("TOPLEFT", self.host, "TOPLEFT", 0, -control.height)
        view.scrollBox:SetPoint("BOTTOMRIGHT", self.host, "BOTTOMRIGHT", -24, 0)
    end
end

function Controller:LayoutControls()
    local view = self.view
    if not view or not self.host then return end
    local width = self.host:GetWidth()
    if not width or width <= 0 then return end
    for _, control in ipairs(view.controls or {}) do
        local frame = control.frame
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.host, "TOPLEFT", 4, -4)
        frame:SetPoint("TOPRIGHT", self.host, "TOPRIGHT", -4, -4)
        self:FlowControl(control, width - 8)
    end
end

function Controller:PaintPanel()
    local panel = self.panel
    if not panel then return end
    local api = GetAPI()
    if api and type(api.Skin) == "function" then
        api.Skin(panel, {window = true})
        if self.hostInset then api.Skin(self.hostInset, {noBevel = true, bgAlpha = 0.3}) end
    end
    local r, g, b = SafeAccent(api)
    if panel.topLine then panel.topLine:SetVertexColor(r, g, b, 0.7) end
    local colors = api and type(api.Colors) == "function" and api.Colors() or nil
    local font = SafeFont(api)
    if panel.titleText then
        panel.titleText:SetFont(font, 16, "")
        panel.titleText:SetTextColor(GetColor(colors, "VALUE", 1, 1, 1))
    end
    local view = self.view
    if view then
        if view.title then
            view.title:SetFont(font, 13, "")
            view.title:SetTextColor(GetColor(colors, "VALUE", 1, 1, 1))
        end
        if view.desc then
            view.desc:SetFont(font, 11, "")
            view.desc:SetTextColor(GetColor(colors, "LABEL", 0.75, 0.75, 0.75))
        end
        if view.spoilerFree and view.spoilerFree.text then
            view.spoilerFree.text:SetFont(font, 11, "")
            view.spoilerFree.text:SetTextColor(GetColor(colors, "TEXT", 0.9, 0.9, 0.9))
        end
        for _, tab in ipairs(view.tabs or {}) do
            if tab.PaintStyle then tab:PaintStyle() end
        end
    end
end

function Controller:PositionPanel()
    local panel = self.panel
    if not panel or not self.window or not self.button then return end
    self:PositionButton()
    local target = self:GetAnchorTarget()
    local scale = self.window:GetEffectiveScale() or 1
    local uiScale = UIParent:GetEffectiveScale() or 1
    local uiRight = (UIParent:GetRight() or 1920) * uiScale
    local btnRight = self.button:GetRight() and (self.button:GetRight() * scale) or nil
    local needed = (PANEL_WIDTH + PANEL_GAP * 2) * scale
    local placeLeft = btnRight and (btnRight + needed > uiRight) or false

    panel:ClearAllPoints()
    panel:SetWidth(PANEL_WIDTH)
    if placeLeft then
        panel:SetPoint("TOPRIGHT", self.window, "TOPLEFT", -PANEL_GAP, 0)
        panel:SetPoint("BOTTOMRIGHT", self.window, "BOTTOMLEFT", -PANEL_GAP, 0)
    else
        local offset = PANEL_GAP + BUTTON_SIZE + PANEL_GAP
        panel:SetPoint("TOPLEFT", target, "TOPRIGHT", offset, 0)
        panel:SetPoint("BOTTOMLEFT", target, "BOTTOMRIGHT", offset, 0)
    end
end

function Controller:SyncCraftProfession(skillLine)
    if self.key ~= "professions" or not self.view then return false end
    local api = GetAPI()
    local apiSkillLine, apiName
    if api and type(api.GetCraftProfession) == "function" then
        apiSkillLine, apiName = api.GetCraftProfession()
    end
    local key = TrainerSpells:GetProfessionKey(apiName, skillLine or apiSkillLine)
    if not key or self.view.professionKey == key then return false end
    self.view.professionKey = key
    return true
end

function Controller:CreatePanel()
    if self.panel then return end
    local api = GetAPI()
    local panel = CreateFrame("Frame", self.frameName, self.window)
    panel:SetWidth(PANEL_WIDTH)
    panel:SetFrameLevel(self.window:GetFrameLevel() + 5)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function() end)
    panel:Hide()
    if api and type(api.Skin) == "function" then api.Skin(panel, {window = true}) end

    local topLine = panel:CreateTexture(nil, "ARTWORK")
    topLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    topLine:SetHeight(2)
    topLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -2)
    topLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -2)
    panel.topLine = topLine

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -10)
    icon:SetTexture(ADDON_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    panel.headerIcon = icon

    local titleText
    if api and type(api.Text) == "function" then
        titleText = api.Text(panel, "title", "LEFT")
    else
        titleText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        titleText:SetJustifyH("LEFT")
    end
    titleText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    titleText:SetPoint("RIGHT", panel, "RIGHT", -40, 0)
    titleText:SetWordWrap(false)
    titleText:SetText("TrainerSpells")
    panel.titleText = titleText

    local closeBtn
    if api and type(api.Close) == "function" then
        closeBtn = api.Close(panel, function() self:Close() end)
        closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -9, -11)
    else
        closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() self:Close() end)
    end
    panel.closeButton = closeBtn

    local rule = panel:CreateTexture(nil, "ARTWORK")
    rule:SetTexture("Interface\\Buttons\\WHITE8X8")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -HEADER_HEIGHT)
    rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -HEADER_HEIGHT)
    rule:SetVertexColor(1, 1, 1, 0.06)
    panel.rule = rule

    local hostInset = CreateFrame("Frame", nil, panel)
    hostInset:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -HOST_TOP)
    hostInset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)
    if api and type(api.Skin) == "function" then api.Skin(hostInset, {noBevel = true, bgAlpha = 0.3}) end
    self.hostInset = hostInset

    local host = CreateFrame("Frame", nil, panel)
    host:SetPoint("TOPLEFT", hostInset, "TOPLEFT", 4, -4)
    host:SetPoint("BOTTOMRIGHT", hostInset, "BOTTOMRIGHT", -4, 4)
    host:SetFrameLevel(hostInset:GetFrameLevel() + 2)
    host.contentAPI = self:BuildContentAPI(panel)
    self.host = host
    self.panel = panel

    local search
    if api and type(api.Input) == "function" then
        search = api.Input(panel, {
            search = true,
            height = 24,
            hint = SEARCH or "Search",
            onChange = function(text)
                host.searchText = text
                if self.view then self.view:Refresh() end
            end,
        })
    else
        search = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
        search:SetHeight(22)
        search:SetAutoFocus(false)
        search:SetScript("OnTextChanged", function(box)
            SearchBoxTemplate_OnTextChanged(box)
            host.searchText = box:GetText()
            if self.view then self.view:Refresh() end
        end)
        search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    end
    search:SetWidth(200)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -FILTER_TOP)
    self.search = search

    local view = self.createView(TrainerSpells, host)
    self.view = view

    for _, tab in ipairs(view.tabs or {}) do
        tab:HookScript("OnEnter", function(btn)
            btn.tsHovered = true
            if btn.PaintStyle then btn:PaintStyle() end
        end)
        tab:SetScript("OnLeave", function(btn)
            btn.tsHovered = false
            if btn.PaintStyle then btn:PaintStyle() end
            GameTooltip_Hide()
        end)
    end

    if host.contentBackground then host.contentBackground:Hide() end
    if host.borderFrame then host.borderFrame:Hide() end
    view.scrollBox:SetClipsChildren(true)

    if view.spoilerFree then
        view.spoilerFree:ClearAllPoints()
        view.spoilerFree:SetPoint("LEFT", search, "RIGHT", 10, 0)
    end

    host:HookScript("OnSizeChanged", function()
        self:LayoutControls()
    end)

    for _, control in ipairs(view.controls or {}) do
        control.frame:HookScript("OnShow", function()
            self:FlowControl(control, (host:GetWidth() or 0) - 8)
        end)
        control.frame:HookScript("OnSizeChanged", function(_, width)
            if width ~= control.flowWidth then
                control.flowWidth = width
                self:FlowControl(control, width)
            end
        end)
    end

    panel:SetScript("OnSizeChanged", function()
        local curApi = GetAPI()
        if curApi and type(curApi.Skin) == "function" then
            curApi.Skin(panel, {window = true})
            if self.hostInset then curApi.Skin(self.hostInset, {noBevel = true, bgAlpha = 0.3}) end
        end
    end)

    panel:SetScript("OnShow", function()
        self:SyncCraftProfession()
        self:PositionPanel()
        self:LayoutControls()
        self:PaintPanel()
        self:PaintButton()
    end)

    panel:SetScript("OnHide", function()
        if self.search then self.search:ClearFocus() end
        HideTooltipIfOwnedBy(panel)
        self:PaintButton()
    end)

    self:PaintPanel()
    self:LayoutControls()
end

function Controller:Open()
    if not self:IsEnabled() then return end
    self:CreatePanel()
    self:SyncCraftProfession()
    self:PositionPanel()
    self.panel:Show()
    self:LayoutControls()
    self:PaintPanel()
    if self.view then self.view:ScheduleRefresh() end
    self:PaintButton()
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

function Controller:Close()
    if self.panel and self.panel:IsShown() then
        self.panel:Hide()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        end
    end
    self:PaintButton()
end

function Controller:Toggle()
    if self.panel and self.panel:IsShown() then
        self:Close()
    else
        self:Open()
    end
end

function integration:AttachWindow(key, window, frameName, createView, tooltipDescKey, saveViewKey)
    if not window or self.controllers[key] then return end
    local controller = setmetatable({
        key = key,
        window = window,
        frameName = frameName,
        createView = createView,
        tooltipDescKey = tooltipDescKey,
        saveViewKey = saveViewKey,
    }, Controller)
    self.controllers[key] = controller
    controller:CreateButton()
end

function integration:RefreshShownViews()
    for _, controller in pairs(self.controllers) do
        if controller.panel and controller.panel:IsShown() and controller.view then
            controller.view:Refresh()
        end
    end
end

function integration:ApplySettings()
    for _, controller in pairs(self.controllers) do
        if controller.view then controller.view:ApplyVisibility() end
        controller:UpdateButtonVisibility()
    end
end

function integration:RepaintAll()
    for _, controller in pairs(self.controllers) do
        controller:PaintButton()
        controller:PaintPanel()
    end
end

function integration:BindListeners()
    if self.listenersBound then return end
    local api = GetAPI()
    if not api then return end
    self.listenersBound = true

    if type(api.On) == "function" then
        api.On("Login", function()
            C_Timer.After(0, function() self:AttachAll() end)
        end, "TrainerSpells")
        api.On("SettingChanged", function(scope)
            if scope == "Book" or scope == "Professions" then
                C_Timer.After(0, function() self:AttachAll() end)
            end
        end, "TrainerSpells")
        api.On("StyleChanged", function()
            self:RepaintAll()
        end, "TrainerSpells")
        api.On("CraftShown", function()
            self:AttachAll()
            local craft = self.controllers.professions
            if craft then
                craft:PositionButton()
                if craft.panel and craft.panel:IsShown() then
                    craft:PositionPanel()
                    if craft:SyncCraftProfession() and craft.view then craft.view:Refresh() end
                end
            end
        end, "TrainerSpells")
        api.On("CraftProfessionChanged", function(skillLine)
            local craft = self.controllers.professions
            if craft and craft.panel and craft.panel:IsShown() and craft:SyncCraftProfession(skillLine) and craft.view then
                craft.view:Refresh()
            end
        end, "TrainerSpells")
    end

    TrainerSpells:OnTabSettingsChanged(function()
        self:ApplySettings()
    end)

    for _, name in ipairs({"TrainerSpells_Refresh", "TrainerSpells_ProfessionRefresh"}) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, function()
                self:RefreshShownViews()
            end)
        end
    end
end

function integration:AttachAll()
    if not GetAPI() or not TrainerSpells.SettingsReady then return end
    self:BindListeners()
    if TrainerSpells:HasClassTrainers() and _G.DaylightUIBook then
        self:AttachWindow("spellbook", _G.DaylightUIBook, "TrainerSpellsDaylightBookFrame", TrainerSpells.CreateCompendiumClass, "LID_CLASSVIEW_DESC", "classView")
    end
    if _G.DaylightUICraft then
        self:AttachWindow("professions", _G.DaylightUICraft, "TrainerSpellsDaylightCraftFrame", TrainerSpells.CreateCompendiumProfessions, "LID_PROFESSION_FROMTRAINER_DESC", "professionView")
    end
    self:ApplySettings()
end

integration.loader = CreateFrame("Frame")
integration.loader:RegisterEvent("PLAYER_LOGIN")
integration.loader:RegisterEvent("ADDON_LOADED")
integration.loader:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "DaylightUI" and addonName ~= "TrainerSpells" then return end
    integration:AttachAll()
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0, function() integration:AttachAll() end)
    end
end)

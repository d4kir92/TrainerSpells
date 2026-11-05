local _, TrainerSpells = ...
local integration = {groups = {}, api = {}}
TrainerSpells.ClassicUIForever = integration

function TrainerSpells:IsClassicUIForeverProfessions()
    return C_AddOns.IsAddOnLoaded("ClassicUIForever") and ForeverClassicUIDB and ForeverClassicUIDB.professionsBook ~= false
end

function integration.api.CreateContentTab(host, label, icon, onClick)
    local tab = CreateFrame("Button", nil, host)
    tab:SetSize(26, 26)
    tab:SetNormalTexture(icon)
    tab.Icon = tab:GetNormalTexture()
    tab:SetHighlightTexture(130718, "ADD")
    tab.selected = tab:CreateTexture(nil, "OVERLAY")
    tab.selected:SetAllPoints()
    tab.selected:SetTexture(130724)
    tab.selected:SetBlendMode("ADD")
    tab.selected:Hide()
    function tab:SetTabSelected(selected) self.selected:SetShown(selected) end
    tab:SetScript("OnClick", onClick)
    tab:SetScript("OnLeave", GameTooltip_Hide)
    return tab
end

function integration.api.PositionContentTab(tab, host, previous)
    tab:ClearAllPoints()
    if previous then tab:SetPoint("LEFT", previous, "RIGHT", 4, 0) else tab:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, 7) end
end

function integration.api.PositionHeaderSlider(slider)
    slider:ClearAllPoints()
    slider:SetPoint("BOTTOMLEFT", slider:GetParent(), "TOPLEFT", 0, 94)
    slider:SetWidth(110)
end

function integration:Close()
    self.active = nil
    for _, group in ipairs(self.groups) do group.panel:Hide() end
    for _, tab in ipairs(self.tabs or {}) do tab.selected:Hide() end
    self:ReleaseNativeMouse()
end

function integration:Open(group, mode)
    if InCombatLockdown() then return end
    self:Close()
    self.active = group
    if self.book.Search then self.book.Search:ClearFocus() end
    if mode then group.view.mode = mode end
    GameTooltip:Hide()
    group.panel:SetFrameStrata("DIALOG")
    group.panel:SetFrameLevel(self:GetLevel(self.book.Clicks or self.book) + 10)
    group.panel:Show()
    group.view:Refresh()
    self:Layout()
    self:BlockNativeMouse()
end

function integration:GetLevel(frame)
    local level = frame:GetFrameLevel()
    for _, child in ipairs({frame:GetChildren()}) do
        if not child.trainerSpellsClassicPanel then level = math.max(level, self:GetLevel(child)) end
    end
    return level
end

function integration:CreateGroup(key, create, label, icon)
    local panel = CreateFrame("Button", nil, self.book)
    panel:SetFrameStrata("DIALOG")
    panel:SetFixedFrameStrata(true)
    panel:SetFixedFrameLevel(true)
    panel:SetPropagateMouseClicks(false)
    panel:SetPropagateMouseMotion(false)
    panel:RegisterForClicks("AnyUp", "AnyDown")
    panel:SetScript("OnClick", function() end)
    panel.trainerSpellsClassicPanel = true
    panel:SetPoint("TOPLEFT", self.book, "TOPLEFT", self.professionHost and 4 or 14, self.professionHost and -58 or -65)
    panel:SetPoint("BOTTOMRIGHT", self.book, "BOTTOMRIGHT", self.professionHost and -4 or -36, self.professionHost and 4 or 78)
    panel:EnableMouse(true)
    panel:SetScript("OnEnter", GameTooltip_Hide)
    panel:SetScript("OnMouseDown", function() end)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function() end)
    panel:Hide()
    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.06, 0.05, 0.04, 1)
    local host = CreateFrame("Frame", nil, panel)
    host:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -140)
    host:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 4)
    host.contentAPI = self.api
    local view = create(TrainerSpells, host)
    local group = {key = key, panel = panel, host = host, view = view, label = label, icon = icon, tabs = {}}
    table.insert(self.groups, group)
    view.title:Hide()
    view.desc:Hide()
    if view.dropdown then
        view.dropdown:SetParent(panel)
        view.dropdown:ClearAllPoints()
        view.dropdown:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -4)
    end
    local search = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
    search:SetSize(120, 20)
    search:SetAutoFocus(false)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -7)
    if view.dropdown then
        search:SetPoint("RIGHT", view.dropdown, "LEFT", -8, 0)
    else
        search:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -7)
    end
    search:SetScript("OnTextChanged", function(box)
        SearchBoxTemplate_OnTextChanged(box)
        host.searchText = box:GetText()
        view:Refresh()
    end)
    search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    view.slider:SetScale(1)
    view.slider:ClearAllPoints()
    view.slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -92)
    view.slider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -40, -92)
    if view.spoilerFree then
        view.spoilerFree:ClearAllPoints()
        view.spoilerFree:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -62)
    end
    host:SetScript("OnSizeChanged", function() view:LayoutTabs(); self:LayoutContent(group); self:QueueLayout() end)
    for _, control in ipairs(view.controls or {}) do
        control.frame:HookScript("OnShow", function() self:FlowControl(group, control) end)
        control.frame:HookScript("OnSizeChanged", function(_, width)
            if width ~= control.flowWidth then
                control.flowWidth = width
                self:FlowControl(group, control)
            end
        end)
    end
    for index = 0, #view.entries do
        local entry = view.entries[index]
        local mode = entry and (entry.mode or entry.view)
        local tab = self.api.CreateContentTab(self.book, label, entry and entry.icon or icon, function() self:Open(group, mode) end)
        tab:SetSize(32, 32)
        if entry and entry.classToken then
            tab.Icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[entry.classToken]
            if coords then tab.Icon:SetTexCoord(unpack(coords)) end
        end
        tab.border = tab:CreateTexture(nil, "BACKGROUND")
        tab.border:SetSize(64, 64)
        tab.border:SetTexture(136831)
        tab.group, tab.index, tab.mode = group, index, mode
        tab:SetScript("OnEnter", function(button)
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(index == 0 and label or view:TranslateTitle(entry.title))
            GameTooltip:Show()
        end)
        group.tabs[index] = tab
        table.insert(self.tabs, tab)
    end
end

function integration:BlockMousePassthrough(frame)
    frame:SetPropagateMouseClicks(false)
    frame:SetPropagateMouseMotion(false)
    for _, child in ipairs({frame:GetChildren()}) do self:BlockMousePassthrough(child) end
end

function integration:LayoutContent(group)
    if group.layingOut then return end
    local panel, host, view = group.panel, group.host, group.view
    local width = panel:GetWidth()
    if not width or width <= 0 then return end
    group.layingOut = true
    local split = TrainerSpells:GetTabLayout(group.key == "spellbook" and "spellbookLayout" or "professionLayout") == "tabs"
    local filterTop = 36
    local header = filterTop + (split and 22 or 46)
    host:SetScale(0.85)
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", panel, "TOPLEFT", 8 / 0.85, -header / 0.85)
    host:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8 / 0.85, 12 / 0.85)
    if view.dropdown then view.dropdown:SetWidth(math.min(width - 148, 210)) end
    if view.spoilerFree then
        view.spoilerFree:SetScale(0.85)
        view.spoilerFree:ClearAllPoints()
        view.spoilerFree:SetPoint("TOPLEFT", panel, "TOPLEFT", 8 / 0.85, -filterTop / 0.85)
    end
    local tabsRight = 0
    if not split then
        local count = 0
        for index in ipairs(view.tabs) do if view:IsEntryVisible(index) then count = count + 1 end end
        if count > 0 then tabsRight = 8 + (count * 30 - 4) * 0.85 end
    end
    view.slider:SetScale(0.85)
    view.slider:ClearAllPoints()
    view.slider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -34 / 0.85, -(filterTop + 6) / 0.85)
    view.slider:SetWidth(math.max(40, math.min(width - 185, width - 50 - tabsRight) / 0.85))
    view.scrollBox:SetClipsChildren(true)
    for _, control in ipairs(view.controls or {}) do
        local frame = control.frame
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", host, "TOPLEFT", 4, -4)
        frame:SetPoint("TOPRIGHT", host, "TOPRIGHT", -4, -4)
        self:FlowControl(group, control, (host:GetWidth() or 0) - 8)
    end
    self:BlockMousePassthrough(panel)
    group.layingOut = nil
end

function integration:FlowControl(group, control, available)
    local view = group.view
    local height = TrainerSpells:FlowControls(control.frame, available)
    if not height then return end
    control.height = height + 12
    if control.mode == view.mode then
        view.scrollBox:ClearAllPoints()
        view.scrollBox:SetPoint("TOPLEFT", group.host, "TOPLEFT", 0, -control.height)
        view.scrollBox:SetPoint("BOTTOMRIGHT", group.host, "BOTTOMRIGHT", -24, 0)
    end
end

function integration:Layout()
    if not self.book or not TrainerSpells.SettingsReady then return end
    local visible = {}
    for _, group in ipairs(self.groups) do
        self:LayoutContent(group)
        local enabled = TrainerSpells:IsTabEnabled(group.key) and (not self.professionHost or TrainerSpells:IsClassicUIForeverProfessions())
        local split = TrainerSpells:GetTabLayout(group.key == "spellbook" and "spellbookLayout" or "professionLayout") == "tabs"
        local count = 0
        for index in ipairs(group.view.entries) do if group.view:IsEntryVisible(index) then count = count + 1 end end
        for index = 0, #group.view.entries do
            local tab = group.tabs[index]
            local shown = enabled and count > 0 and ((index == 0 and not split) or (index > 0 and split and group.view:IsEntryVisible(index)))
            tab:SetShown(shown)
            tab:SetEnabled(not InCombatLockdown())
            tab:SetTabSelected(self.active == group and (index == 0 or tab.mode == group.view.mode))
            if shown then table.insert(visible, tab) end
            if index > 0 then group.view.tabs[index]:SetShown(not split and group.view:IsEntryVisible(index)) end
        end
        if self.active == group and (not enabled or count == 0) then self:Close() end
    end
    local last = self.professionHost and self.book.ProfessionsOverviewTab or nil
    for _, tab in ipairs(self.professionHost and self.book.rightProfessionTabs or self.book.SkillTabs or {}) do if tab:IsShown() then last = tab end end
    if self.book.TrainTab and self.book.TrainTab:IsShown() then last = self.book.TrainTab end
    local bookTop, height = self.book:GetTop(), self.book:GetHeight()
    local lastBottom = last and last:GetBottom()
    local start, center = -65, nil
    if lastBottom and bookTop then
        local ratio = last:GetEffectiveScale() / self.book:GetEffectiveScale()
        start = lastBottom * ratio - bookTop - (self.professionHost and 8 or 17)
        local lastLeft, bookRight = last:GetLeft(), self.book:GetRight()
        if lastLeft and bookRight then center = (lastLeft + last:GetWidth() / 2) * ratio - bookRight end
    end
    local y, column = start, 0
    local level = math.min(9000, self.book:GetFrameLevel() + 500)
    for index, tab in ipairs(visible) do
        tab:SetFrameLevel(level)
        tab:ClearAllPoints()
        local size = tab:GetHeight()
        if bookTop and height and height > 0 then
            if index > 1 and y - size < 8 - height then
                column = column + 1
                y = start
            end
            tab:SetPoint("TOPLEFT", self.book, "TOPRIGHT", (center and center - tab:GetWidth() / 2 or -32) + column * 40, y)
            y = y - size - 8
        elseif index > 1 then
            tab:SetPoint("TOPLEFT", visible[index - 1], "BOTTOMLEFT", 0, -8)
        elseif last then
            tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -17)
        else
            tab:SetPoint("TOPLEFT", self.book, "TOPRIGHT", -32, -65)
        end
        tab.border:ClearAllPoints()
        tab.border:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
        tab.border:SetTexCoord(0, 1, 0, 1)
    end
end

function integration:BlockNativeMouse()
    local clicks = self.book and self.book.Clicks
    local panel = self.active and self.active.panel
    if not clicks or not panel or not panel:IsShown() or InCombatLockdown() then return end
    local pl, pb, pw, ph = panel:GetRect()
    if not pl then return end
    local ps = panel:GetEffectiveScale()
    pl, pb, pw, ph = pl * ps, pb * ps, pw * ps, ph * ps
    self.nativeBlocked = self.nativeBlocked or {}
    local function Visit(frame)
        if frame:IsMouseEnabled() then
            local l, b, w, h = frame:GetRect()
            if l then
                local s = frame:GetEffectiveScale()
                local x, y = (l + w / 2) * s, (b + h / 2) * s
                if x > pl and x < pl + pw and y > pb and y < pb + ph then
                    frame:EnableMouse(false)
                    self.nativeBlocked[frame] = true
                end
            end
        end
        for _, child in ipairs({frame:GetChildren()}) do Visit(child) end
    end
    Visit(clicks)
end

function integration:ReleaseNativeMouse()
    if not self.nativeBlocked or InCombatLockdown() then return end
    for frame in pairs(self.nativeBlocked) do frame:EnableMouse(true) end
    self.nativeBlocked = nil
end

function integration:QueueLayout()
    if self.layoutQueued then return end
    self.layoutQueued = true
    C_Timer.After(0, function()
        self.layoutQueued = nil
        self:Layout()
    end)
end

function integration:BindViews()
    TrainerSpells:OnTabSettingsChanged(function()
        for _, group in ipairs(self.groups) do group.view:ApplyVisibility() end
        self:Layout()
    end)
    for _, group in ipairs(self.groups) do
        hooksecurefunc(group.view, "Refresh", function() self:Layout() end)
    end
    for _, name in ipairs({"TrainerSpells_Refresh", "TrainerSpells_ProfessionRefresh"}) do
        hooksecurefunc(name, function()
            for _, group in ipairs(self.groups) do
                if group.panel:IsShown() then group.view:Refresh() end
            end
        end)
    end
    self:Layout()
end

function integration:InstallProfessions()
    if self.professions or InCombatLockdown() or not TrainerSpells.SettingsReady or not TrainerSpells:IsClassicUIForeverProfessions() then return end
    local book = ProfessionsFrame
    if not book or not book.BookPage or not book.rightProfessionTabs then return end
    local controller = setmetatable({book = book, groups = {}, tabs = {}, professionHost = true}, {__index = integration})
    self.professions = controller
    controller:CreateGroup("professions", TrainerSpells.CreateCompendiumProfessions, TrainerSpells:Trans("LID_PROFESSIONS"), 134708)
    book:HookScript("OnHide", function() controller:Close() end)
    book:HookScript("OnShow", function() controller:Layout(); controller:QueueLayout() end)
    book:HookScript("OnSizeChanged", function() controller:QueueLayout() end)
    book.BookPage:HookScript("OnHide", function() controller:Close(); controller:Layout() end)
    book.BookPage:HookScript("OnShow", function() controller:Layout(); controller:QueueLayout() end)
    hooksecurefunc(book, "RefreshRightTabs", function() controller:Layout(); controller:QueueLayout() end)
    hooksecurefunc(book, "RightTabSelected", function() controller:Close(); controller:Layout(); controller:QueueLayout() end)
    local overview = book.ProfessionsOverviewTab
    for _, script in ipairs({"OnClick", "OnMouseUp"}) do
        if overview and overview:HasScript(script) then
            overview:HookScript(script, function() controller:Close(); controller:QueueLayout() end)
            break
        end
    end
    if book.CraftingPage then book.CraftingPage:HookScript("OnShow", function() controller:Close(); controller:Layout(); controller:QueueLayout() end) end
    controller:BindViews()
    TrainerSpells:ApplyTabSettings()
end

function integration:Install()
    self:InstallProfessions()
    if self.book or InCombatLockdown() or not ForeverClassicUISpellBook or not TrainerSpells.SettingsReady then return end
    self.book = ForeverClassicUISpellBook
    self.tabs = {}
    if TrainerSpells:HasClassTrainers() then self:CreateGroup("spellbook", TrainerSpells.CreateCompendiumClass, "TrainerSpells", 133743) end
    for _, tabs in ipairs({self.book.SkillTabs or {}, self.book.BookTabs or {}}) do
        for _, tab in ipairs(tabs) do tab:HookScript("OnClick", function() self:Close() end) end
    end
    if self.book.TrainTab then self.book.TrainTab:HookScript("OnClick", function() self:Close() end) end
    self.book:HookScript("OnHide", function() self:Close() end)
    self.book:HookScript("OnShow", function() self:Layout() end)
    hooksecurefunc(self.book, "Refresh", function()
        if self.active then self.active.panel:SetFrameLevel(self:GetLevel(self.book.Clicks or self.book) + 10) end
        self:Layout()
        self:BlockNativeMouse()
    end)
    if type(self.book.BuildPages) == "function" then
        hooksecurefunc(self.book, "BuildPages", function() self:BlockNativeMouse() end)
    end
    self:BindViews()
end

integration.loader = CreateFrame("Frame")
integration.loader:RegisterEvent("PLAYER_LOGIN")
integration.loader:RegisterEvent("ADDON_LOADED")
integration.loader:RegisterEvent("PLAYER_REGEN_DISABLED")
integration.loader:RegisterEvent("PLAYER_REGEN_ENABLED")
integration.loader:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        integration:Close()
        if integration.professions then integration.professions:Close() end
    end
    integration:Install()
    if event == "PLAYER_REGEN_ENABLED" and not integration.active then integration:ReleaseNativeMouse() end
    integration:Layout()
    if integration.professions then integration.professions:Layout() end
    if not integration.book and C_AddOns.IsAddOnLoaded("ClassicUIForever") and not integration.timer then
        integration.timer = C_Timer.NewTicker(0.5, function(timer)
            integration:Install()
            if integration.book then timer:Cancel(); integration.timer = nil end
        end)
    end
end)

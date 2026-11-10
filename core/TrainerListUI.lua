local _, TrainerSpells = ...
local TRAINER_STATUS_FILTERS = {"available", "unavailable", "used"}

local function GetTrainerStatusSelections()
    local selections = TrainerSpells_Character.trainerStatusFilters
    if type(selections) ~= "table" then
        selections = {}
        for _, filter in ipairs(TRAINER_STATUS_FILTERS) do
            selections[filter] = not GetTrainerServiceTypeFilter or GetTrainerServiceTypeFilter(filter)
        end

        TrainerSpells_Character.trainerStatusFilters = selections
    end
    return selections
end

local function HasSelectedTrainerStatus()
    local selections = GetTrainerStatusSelections()
    for _, filter in ipairs(TRAINER_STATUS_FILTERS) do
        if selections[filter] then return true end
    end
    return false
end

local function ApplyNativeTrainerStatusFilters()
    if not GetTrainerServiceTypeFilter or not SetTrainerServiceTypeFilter then return end
    local selections = GetTrainerStatusSelections()
    local showAllForIgnoredOnly = TrainerSpells_Character.showIgnoredInTrainer and not HasSelectedTrainerStatus()
    for _, filter in ipairs(TRAINER_STATUS_FILTERS) do
        local selected = showAllForIgnoredOnly or selections[filter]
        if GetTrainerServiceTypeFilter(filter) ~= selected then SetTrainerServiceTypeFilter(filter, selected) end
    end
end

local function ServiceMatchesTrainerFilters(serviceType, isIgnored)
    if serviceType == "header" then return true end
    local selections = GetTrainerStatusSelections()
    local hasSelectedStatus = HasSelectedTrainerStatus()
    if isIgnored then
        return selections[serviceType] or (TrainerSpells_Character.showIgnoredInTrainer and not hasSelectedStatus)
    end
    return hasSelectedStatus and selections[serviceType] or false
end

local function BuildCachedSpellIDLookup()
    local _, classToken = UnitClass("player")
    local lookup = {}
    local classData = classToken and TrainerSpells_Data[classToken]
    if not classData then return lookup end
    for _, spells in pairs(classData) do
        for id, data in pairs(spells) do
            local name = TrainerSpells:GetSpellInfo(id)
            if name then
                lookup[name] = lookup[name] or {}
                local rankNum = type(data) == "table" and tonumber(data.rank) or 0
                lookup[name][rankNum or 0] = id
            end
        end
    end
    return lookup
end

local function BuildVisibleTrainerIndexList()
    local total = GetNumTrainerServices()
    local cachedSpellIDs = BuildCachedSpellIDLookup()
    local list, ignored = {}, {}
    for i = 1, total do
        local name, subText, serviceType = GetTrainerServiceInfo(i)
        local keep = serviceType == "header"
        if serviceType and serviceType ~= "header" and name then
            local rankNum = subText and tonumber(subText:match("%d+")) or 0
            local spellID = cachedSpellIDs[name] and cachedSpellIDs[name][rankNum]
            if not spellID then spellID = TrainerSpells:GetSpellIDForService(i) end
            ignored[i] = TrainerSpells_IsIgnored(spellID, name)
            keep = ServiceMatchesTrainerFilters(serviceType, ignored[i])
        end

        if keep then table.insert(list, i) end
    end
    return list, ignored
end

local function TrainerSpells_ClassTrainerFrame_Update()
    SetPortraitTexture(ClassTrainerFramePortrait, "npc")
    ClassTrainerNameText:SetText(UnitName("npc"))
    ClassTrainerGreetingText:SetText(GetTrainerGreetingText())
    local visibleList, ignored = BuildVisibleTrainerIndexList()
    local selected = ClassTrainerFrame.selectedService
    if selected and not TrainerSpells_Character.showIgnoredInTrainer and not tContains(visibleList, selected) then
        local nextService, nextPosition
        for position, index in ipairs(visibleList) do
            if not ignored[index] and select(3, GetTrainerServiceInfo(index)) == "available" then
                nextService, nextPosition = index, position
                if index > selected then break end
            end
        end

        ClassTrainerFrame.showSkillDetails = nextService and true or nil
        if nextService then
            ClassTrainer_SetSelection(nextService)
            local offset = FauxScrollFrame_GetOffset(ClassTrainerListScrollFrame)
            if nextPosition <= offset or nextPosition > offset + CLASS_TRAINER_SKILLS_DISPLAYED then
                ClassTrainerListScrollFrameScrollBar:SetValue(CLASS_TRAINER_SKILL_HEIGHT * math.max(0, nextPosition - CLASS_TRAINER_SKILLS_DISPLAYED))
            end
        else
            ClassTrainerFrame.selectedService = nil
            ClassTrainerFrame.renewSelection = nil
            ClassTrainerTrainButton:Disable()
        end
    end

    local numTrainerServices = #visibleList
    local skillOffset = FauxScrollFrame_GetOffset(ClassTrainerListScrollFrame)
    if numTrainerServices == 0 then
        ClassTrainerCollapseAllButton:Disable()
    else
        ClassTrainerCollapseAllButton:Enable()
    end

    if not ClassTrainerFrame.selectedService then ClassTrainer_HideSkillDetails() end
    if IsTradeskillTrainer() then
        ClassTrainer_SetToTradeSkillTrainer()
    else
        ClassTrainer_SetToClassTrainer()
    end

    FauxScrollFrame_Update(ClassTrainerListScrollFrame, numTrainerServices, CLASS_TRAINER_SKILLS_DISPLAYED, CLASS_TRAINER_SKILL_HEIGHT, nil, nil, nil, ClassTrainerSkillHighlightFrame, 293, 316)
    ClassTrainerMoneyFrame:Show()
    ClassTrainerSkillHighlightFrame:Hide()
    for i = 1, CLASS_TRAINER_SKILLS_DISPLAYED do
        local skillIndex = visibleList[i + skillOffset]
        local skillButton = _G["ClassTrainerSkill" .. i]
        local serviceName, serviceSubText, serviceType, isExpanded
        local moneyCost
        if skillIndex then
            serviceName, serviceSubText, serviceType, isExpanded = GetTrainerServiceInfo(skillIndex)
            if not serviceName then serviceName = UNKNOWN end
            if ClassTrainerListScrollFrame:IsVisible() then
                skillButton:SetWidth(293)
            else
                skillButton:SetWidth(323)
            end

            local skillSubText = _G["ClassTrainerSkill" .. i .. "SubText"]
            if serviceType == "header" then
                local skillText = _G["ClassTrainerSkill" .. i .. "Text"]
                skillText:SetText(serviceName)
                skillText:SetWidth(0)
                skillButton:SetNormalFontObject("GameFontNormal")
                skillSubText:Hide()
                if isExpanded then
                    skillButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                else
                    skillButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                end

                _G["ClassTrainerSkill" .. i .. "Highlight"]:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
            else
                skillButton:ClearNormalTexture()
                _G["ClassTrainerSkill" .. i .. "Highlight"]:SetTexture("")
                local skillText = _G["ClassTrainerSkill" .. i .. "Text"]
                skillText:SetText("  " .. serviceName)
                if serviceSubText and serviceSubText ~= "" then
                    skillSubText:SetText(format(PARENS_TEMPLATE, serviceSubText))
                    skillSubText:SetPoint("LEFT", "ClassTrainerSkill" .. i .. "Text", "RIGHT", 10, 0)
                    skillSubText:Show()
                    skillText:SetWidth(0)
                else
                    skillSubText:Hide()
                    skillText:SetWidth(SKILL_TEXT_WIDTH)
                end

                local _
                moneyCost, _ = GetTrainerServiceCost(skillIndex)
                if serviceType == "available" then
                    skillButton:SetNormalFontObject("GameFontNormalLeftGreen")
                    ClassTrainer_SetSubTextColor(skillButton, 0, 0.6, 0)
                elseif serviceType == "used" then
                    skillButton:SetNormalFontObject("GameFontDisable")
                    ClassTrainer_SetSubTextColor(skillButton, 0.5, 0.5, 0.5)
                else
                    skillButton:SetNormalFontObject("GameFontNormalLeftRed")
                    ClassTrainer_SetSubTextColor(skillButton, 0.6, 0, 0)
                end
            end

            skillButton:SetAlpha(ignored[skillIndex] and not TrainerSpells_Character.showIgnoredInTrainer and 0.25 or 1)
            skillButton:SetID(skillIndex)
            skillButton:Show()
            if ClassTrainerFrame.selectedService and GetTrainerSelectionIndex() == skillIndex then
                ClassTrainerSkillHighlightFrame:SetPoint("TOPLEFT", "ClassTrainerSkill" .. i, "TOPLEFT", 0, 0)
                ClassTrainerSkillHighlightFrame:Show()
                skillButton:LockHighlight()
                ClassTrainer_SetSubTextColor(skillButton, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                if moneyCost and moneyCost > 0 then ClassTrainerCostLabel:Show() end
            else
                skillButton:UnlockHighlight()
            end
        else
            skillButton:Hide()
        end
    end

    local numHeaders = 0
    local notExpanded = 0
    local showDetails = nil
    for i = 1, numTrainerServices do
        local realIndex = visibleList[i]
        local serviceName, _, serviceType, isExpanded = GetTrainerServiceInfo(realIndex)
        if serviceName and serviceType == "header" then
            numHeaders = numHeaders + 1
            if not isExpanded then notExpanded = notExpanded + 1 end
        end

        if ClassTrainerFrame.selectedService and GetTrainerSelectionIndex() == realIndex then showDetails = 1 end
    end

    if showDetails then
        ClassTrainer_ShowSkillDetails()
    else
        ClassTrainer_HideSkillDetails()
    end

    if notExpanded ~= numHeaders then
        ClassTrainerCollapseAllButton.collapsed = nil
        ClassTrainerCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    else
        ClassTrainerCollapseAllButton.collapsed = 1
        ClassTrainerCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    end
end

local trainerUpdateOverrideInstalled = false

function TrainerSpells:EnsureTrainerUpdateOverrideInstalled()
    if trainerUpdateOverrideInstalled then return end
    if not ClassTrainerFrame_Update then return end
    if not TrainerSpells_IsIgnored then return end
    if ClassTrainerFrame and ClassTrainerFrame.ScrollBox then return end
    if not ClassTrainerListScrollFrame then return end
    trainerUpdateOverrideInstalled = true
    ClassTrainerFrame_Update = TrainerSpells_ClassTrainerFrame_Update
    ClassTrainerFrame_Update()
end

local function InstallTrainerSelectionList(trainer)
    if not TrainerSpells.Pricing.IsForever() or not BuyTrainerService then return end

    local nativeScroll, nativeBar = trainer.ScrollBox, trainer.ScrollBar
    local nativeLearn = trainer.TrainButton or ClassTrainerTrainButton
    if not nativeBar or not nativeLearn or not ClassTrainerFrame_InitServiceButton then return end

    local overlay = CreateFrame("Frame", nil, trainer)
    overlay:Hide()
    overlay:SetPoint("TOPLEFT", nativeScroll)
    overlay:SetPoint("BOTTOMRIGHT", nativeBar)
    overlay:SetFrameStrata("DIALOG")
    overlay:EnableMouse(true)

    local scroll = CreateFrame("Frame", nil, overlay, "WowScrollBoxList")
    scroll:SetAllPoints(nativeScroll)
    local scrollbar = CreateFrame("EventFrame", nil, overlay, "MinimalScrollBar")
    scrollbar:SetAllPoints(nativeBar)

    local learn = CreateFrame("Button", nil, overlay, "MagicButtonTemplate")
    learn:SetAllPoints(nativeLearn)
    learn:SetText(TRAIN)
    learn:Disable()

    local learnAll = CreateFrame("Button", nil, overlay, "MagicButtonTemplate")
    learnAll:SetPoint("BOTTOMRIGHT", learn, "BOTTOMLEFT", -4, 0)
    learnAll:SetSize(88, nativeLearn:GetHeight())
    learnAll:SetText(TrainerSpells:Trans("LID_TRAIN_ALL"))
    learnAll:Disable()

    local toggle = CreateFrame("CheckButton", nil, trainer, "UICheckButtonTemplate")
    toggle:SetPoint("BOTTOMLEFT", trainer, "BOTTOMRIGHT", 2, 0)
    toggle:SetSize(24, 24)
    toggle:SetFrameStrata("DIALOG")
    local toggleLabel = toggle:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    toggleLabel:SetPoint("LEFT", toggle, "RIGHT", 1, 0)
    toggleLabel:SetText("TS")
    toggle:Hide()

    local nativeRows = nativeScroll:GetScrollTarget()
    local rowsShown, barAlpha, learnAlpha
    overlay:SetScript("OnShow", function()
        rowsShown = nativeRows:IsShown()
        barAlpha, learnAlpha = nativeBar:GetAlpha(), nativeLearn:GetAlpha()
        nativeRows:Hide()
        nativeBar:SetAlpha(0)
        nativeLearn:SetAlpha(0)
    end)
    overlay:SetScript("OnHide", function()
        nativeRows:SetShown(rowsShown)
        nativeBar:SetAlpha(barAlpha)
        nativeLearn:SetAlpha(learnAlpha)
    end)

    local selected, trainerGUID, batch
    local function CanLearn(entry)
        return entry and entry.status == "available" and entry.cost and entry.cost <= GetMoney()
    end

    local function UpdateSelection()
        learn:SetEnabled(not batch and not not CanLearn(selected))
        scroll:ForEachFrame(function(row)
            row.selectedTex:SetShown(row:GetElementData() == selected)
        end)
    end

    local view = CreateScrollBoxListLinearView()
    local nativeView = nativeScroll:GetView()
    if nativeView and nativeView.padding then
        ScrollBoxListViewMixin.SetPadding(view, nativeView.padding)
    else
        view:SetPadding(1, 0, 1, 0, 0)
    end
    view:SetElementInitializer("ClassTrainerSkillButtonTemplate", function(row, entry)
        ClassTrainerFrame_InitServiceButton(row, entry)
        row.selectedTex:SetShown(entry == selected)
        row:SetScript("OnClick", function(self)
            selected = self:GetElementData()
            UpdateSelection()
        end)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scroll, scrollbar, view)

    local function ReadEntries()
        local list = {}
        local lookup = BuildCachedSpellIDLookup()
        for index = 1, GetNumTrainerServices() do
            local name, rank, status, _, _, category = TrainerSpells:GetTrainerServiceInfo(index)
            if name and status and status ~= "header" then
                local spellID = TrainerSpells:GetSpellIDForService(index, true)
                local ranks = lookup[name]
                local rankNumber = rank and tonumber(rank:match("%d+")) or 0
                local ignored = TrainerSpells_IsIgnored(spellID or (ranks and ranks[rankNumber]), name)
                if not ignored or TrainerSpells_Character.showIgnoredInTrainer then
                    list[#list + 1] = {
                        skillIndex = index,
                        playerMoney = GetMoney(),
                        isTradeSkill = false,
                        name = name,
                        rank = rank or "",
                        category = category,
                        status = status,
                        ignored = ignored,
                        spellID = spellID,
                        cost = GetTrainerServiceCost(index)
                    }
                end
            end
        end
        return list
    end

    local function FindEntry(list, target)
        if not target then return nil end
        local match
        for _, entry in ipairs(list) do
            if entry.name == target.name and entry.rank == target.rank and entry.category == target.category and entry.spellID == target.spellID then
                if match then return nil end
                match = entry
            end
        end
        return match
    end

    local function FindTrainableEntry(entries)
        for _, entry in ipairs(entries) do
            if not entry.ignored and CanLearn(entry) and FindEntry(entries, entry) then return entry end
        end
    end

    local function GetSupportedTrainerGUID()
        if IsTradeskillTrainer and IsTradeskillTrainer() then return nil end
        local petType = Enum and Enum.TrainerType and Enum.TrainerType.Pet
        if petType ~= nil and C_Trainer and C_Trainer.GetTrainerType and C_Trainer.GetTrainerType() == petType then return nil end
        return UnitGUID("npc")
    end

    local function RefreshList(retainScrollPosition)
        if not trainer:IsShown() then return end
        local guid = GetSupportedTrainerGUID()
        local debugEnabled = TrainerSpells.DebugTrainerEnabled
        local enabled = not debugEnabled or not TrainerSpells_Character.useBlizzardTrainerList
        toggle:SetShown(guid ~= nil and debugEnabled)
        toggle:SetChecked(enabled)
        if not guid or not enabled then
            selected, trainerGUID, batch = nil, nil, nil
            overlay:Hide()
            return
        end
        if guid ~= trainerGUID then selected, batch = nil, nil end
        trainerGUID = guid
        local entries = ReadEntries()
        selected = FindEntry(entries, selected)
        overlay:Show()
        local retain = retainScrollPosition ~= false and ScrollBoxConstants.RetainScrollPosition
        scroll:SetDataProvider(CreateDataProvider(entries), retain)
        UpdateSelection()
        learnAll:SetEnabled(not batch and FindTrainableEntry(entries) ~= nil)
    end

    toggle:SetScript("OnClick", function(self)
        TrainerSpells_Character.useBlizzardTrainerList = not self:GetChecked()
        RefreshList()
    end)

    learnAll:SetScript("OnClick", function()
        if batch or not trainerGUID or not overlay:IsVisible() then return end
        local session = {guid = trainerGUID}
        batch = session
        learnAll:Disable()
        UpdateSelection()

        local function TrainNext()
            if batch ~= session then return end
            if not overlay:IsVisible() or session.guid ~= GetSupportedTrainerGUID() then
                batch = nil
                RefreshList()
                return
            end

            local entries = ReadEntries()
            local pending = FindEntry(entries, session.pending)
            if pending and pending.status == "available" then
                if GetTime() < session.deadline then
                    C_Timer.After(0.1, TrainNext)
                    return
                end
            else
                local entry = FindTrainableEntry(entries)
                if entry then
                    session.pending = entry
                    session.deadline = GetTime() + 3
                    BuyTrainerService(entry.skillIndex)
                    C_Timer.After(0.1, TrainNext)
                    return
                end
            end

            batch = nil
            RefreshList()
        end

        TrainNext()
    end)

    learn:SetScript("OnClick", function()
        if batch or not overlay:IsVisible() or not trainer:IsShown() or not trainerGUID or trainerGUID ~= GetSupportedTrainerGUID() then return end
        local entry = FindEntry(ReadEntries(), selected)
        if CanLearn(entry) then
            selected = nil
            learn:Disable()
            BuyTrainerService(entry.skillIndex)
        end
        RefreshList()
    end)
    trainer:HookScript("OnHide", function()
        selected, trainerGUID, batch = nil, nil, nil
        learn:Disable()
    end)
    hooksecurefunc("ClassTrainerFrame_Update", RefreshList)
    overlay:RegisterEvent("PLAYER_MONEY")
    overlay:SetScript("OnEvent", function()
        RefreshList()
    end)
    RefreshList()
    return RefreshList
end

local function InstallScrollBoxTrainerFilter()
    local trainer = ClassTrainerFrame
    local scrollBox = trainer.ScrollBox
    if not Menu or not Menu.ModifyMenu or not scrollBox.ForEachFrame or not scrollBox.GetDataProvider or not scrollBox.Update then return false end
    if not ClassTrainerFrame_Update or not ClassTrainer_SetSelection then return false end
    local dimmedRows = setmetatable({}, {__mode = "k"})
    local provider, cachedSpellIDs, resolvedSpellIDs, professionKey

    local function RefreshRows()
        if not trainer:IsShown() then return end
        local currentProvider = scrollBox:GetDataProvider()
        if currentProvider ~= provider or not cachedSpellIDs then
            provider = currentProvider
            cachedSpellIDs = BuildCachedSpellIDLookup()
            resolvedSpellIDs = {}
            professionKey = IsTradeskillTrainer and IsTradeskillTrainer() and TrainerSpells:DetectTrainerProfession()
        end

        scrollBox:ForEachFrame(function(row, node)
            node = node or row:GetElementData()
            local data = node and (node.GetData and node:GetData() or node.data or node)
            local index = data and data.skillIndex
            local ignored = false
            if index and row ~= trainer.skillStepButton and not TrainerSpells_Character.showIgnoredInTrainer then
                local name, subText, serviceType = TrainerSpells:GetTrainerServiceInfo(index)
                if name and serviceType ~= "header" then
                    local spellID = resolvedSpellIDs[index]
                    if spellID == nil then
                        spellID = TrainerSpells:GetSpellIDForService(index, true)
                        local rank = subText and tonumber(subText:match("%d+")) or 0
                        if not spellID and cachedSpellIDs[name] then spellID = cachedSpellIDs[name][rank] end
                        resolvedSpellIDs[index] = spellID or false
                    end

                    if professionKey then
                        ignored = TrainerSpells_IsProfessionSpellIgnored(spellID, professionKey)
                    else
                        ignored = TrainerSpells_IsIgnored(spellID, name)
                    end
                end
            end

            if ignored then
                dimmedRows[row] = true
                row:SetAlpha(0.25)
            elseif dimmedRows[row] then
                dimmedRows[row] = nil
                row:SetAlpha(1)
            end
        end)
    end

    local refreshSelectionList = InstallTrainerSelectionList(trainer)
    hooksecurefunc(scrollBox, "Update", RefreshRows)
    hooksecurefunc("ClassTrainerFrame_Update", RefreshRows)
    hooksecurefunc("ClassTrainer_SetSelection", RefreshRows)
    Menu.ModifyMenu("MENU_TRAINER_FILTER", function(owner, rootDescription)
        if owner ~= trainer.FilterDropdown then return end
        rootDescription:CreateCheckbox(YELLOW_FONT_COLOR:WrapTextInColorCode(TrainerSpells:Trans("LID_IGNORED")), function()
            return TrainerSpells_Character.showIgnoredInTrainer
        end, function()
            TrainerSpells_Character.showIgnoredInTrainer = not TrainerSpells_Character.showIgnoredInTrainer
            RefreshRows()
            if refreshSelectionList then refreshSelectionList() end
        end)
    end)
    local driver = CreateFrame("Frame")
    local elapsed = 0
    driver:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        elapsed = 0
        RefreshRows()
    end)
    RefreshRows()
    return true
end

local trainerFilterHookInstalled = false
function TrainerSpells:EnsureTrainerFilterHookInstalled()
    if trainerFilterHookInstalled or not ClassTrainerFrame or not ClassTrainerFrame.FilterDropdown then return end
    if ClassTrainerFrame.ScrollBox then
        trainerFilterHookInstalled = InstallScrollBoxTrainerFilter()
        return
    end

    if not trainerUpdateOverrideInstalled then return end
    trainerFilterHookInstalled = true
    local function IsNativeFilterSelected(filter)
        return GetTrainerStatusSelections()[filter]
    end

    local function SetNativeFilterSelected(filter)
        ClassTrainerFrame.filterPending = true
        local selections = GetTrainerStatusSelections()
        selections[filter] = not selections[filter]
        ApplyNativeTrainerStatusFilters()
        if ClassTrainerFrame_Update then ClassTrainerFrame_Update() end
    end

    local function IsIgnoredFilterSelected()
        return TrainerSpells_Character.showIgnoredInTrainer
    end

    local function SetIgnoredFilterSelected()
        TrainerSpells_Character.showIgnoredInTrainer = not TrainerSpells_Character.showIgnoredInTrainer
        ApplyNativeTrainerStatusFilters()
        if ClassTrainerFrame_Update then ClassTrainerFrame_Update() end
    end

    local applyingOwnMenu = false
    local function ApplyOwnMenu()
        applyingOwnMenu = true
        ClassTrainerFrame.FilterDropdown:SetupMenu(function(dropdown, rootDescription)
            rootDescription:SetTag("MENU_TRAINER_FILTER")
            rootDescription:CreateCheckbox(GREEN_FONT_COLOR:WrapTextInColorCode(AVAILABLE), IsNativeFilterSelected, SetNativeFilterSelected, "available")
            rootDescription:CreateCheckbox(RED_FONT_COLOR:WrapTextInColorCode(UNAVAILABLE), IsNativeFilterSelected, SetNativeFilterSelected, "unavailable")
            rootDescription:CreateCheckbox(YELLOW_FONT_COLOR:WrapTextInColorCode(TrainerSpells:Trans("LID_IGNORED")), IsIgnoredFilterSelected, SetIgnoredFilterSelected)
            rootDescription:CreateCheckbox(GRAY_FONT_COLOR:WrapTextInColorCode(USED), IsNativeFilterSelected, SetNativeFilterSelected, "used")
        end)

        applyingOwnMenu = false
    end

    hooksecurefunc(ClassTrainerFrame.FilterDropdown, "SetupMenu", function()
        if applyingOwnMenu then return end
        ApplyOwnMenu()
    end)

    ApplyOwnMenu()
    ApplyNativeTrainerStatusFilters()
end

local function CountRealTrainerServices()
    local total = GetNumTrainerServices()
    local real = 0
    for i = 1, total do
        local _, _, category = GetTrainerServiceInfo(i)
        if category ~= "header" then real = real + 1 end
    end
    return real
end

local function ScanTrainerServicesStep(button, offset, maxOffset, targetCount, visited, visitedCount)
    if visitedCount >= targetCount or offset > maxOffset then
        FauxScrollFrame_SetOffset(ClassTrainerListScrollFrame, 0)
        ClassTrainerFrame_Update()
        TrainerSpells:MSG("|cff33ff99TrainerSpells:|r " .. TrainerSpells:Trans("LID_SCANFINISHED"):format(visitedCount, targetCount))
        return
    end

    FauxScrollFrame_SetOffset(ClassTrainerListScrollFrame, offset)
    ClassTrainerFrame_Update()
    local id = button:GetID()
    if button:IsShown() and id and id >= 1 and not visited[id] then
        local _, _, category = GetTrainerServiceInfo(id)
        if category ~= "header" then
            visited[id] = true
            visitedCount = visitedCount + 1
            button:Click()
        end
    end

    C_Timer.After(0.05, function() ScanTrainerServicesStep(button, offset + 1, maxOffset, targetCount, visited, visitedCount) end)
end

function TrainerSpells:ScanAllTrainerRequirements()
    if not GetNumTrainerServices or not GetTrainerServiceInfo or not ExpandTrainerSkillLine or not ClassTrainerListScrollFrame or not FauxScrollFrame_SetOffset or not ClassTrainerFrame_Update or not C_Timer then
        TrainerSpells:MSG("|cffff5555TrainerSpells:|r " .. TrainerSpells:Trans("LID_SCANNOAPI"))
        return
    end

    local button = _G["ClassTrainerSkill1"]
    if not button then
        TrainerSpells:MSG("|cffff5555TrainerSpells:|r " .. TrainerSpells:Trans("LID_SCANNOBUTTON"))
        return
    end

    TrainerSpells:ExpandAllTrainerHeaders()
    local targetCount = CountRealTrainerServices()
    local maxOffset = GetNumTrainerServices() + 200
    TrainerSpells:MSG("|cff33ff99TrainerSpells:|r " .. TrainerSpells:Trans("LID_SCANSTARTED"):format(targetCount))
    ScanTrainerServicesStep(button, 0, maxOffset, targetCount, {}, 0)
end

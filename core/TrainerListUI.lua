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
        return TrainerSpells_Character.showIgnoredInTrainer and (not hasSelectedStatus or selections[serviceType])
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
    local list = {}
    for i = 1, total do
        local name, subText, serviceType = GetTrainerServiceInfo(i)
        local keep = serviceType == "header"
        if serviceType and serviceType ~= "header" and name then
            local rankNum = subText and tonumber(subText:match("%d+")) or 0
            local spellID = cachedSpellIDs[name] and cachedSpellIDs[name][rankNum]
            if not spellID then spellID = TrainerSpells:GetSpellIDForService(i) end
            keep = ServiceMatchesTrainerFilters(serviceType, TrainerSpells_IsIgnored(spellID, name))
        end

        if keep then table.insert(list, i) end
    end
    return list
end

local function TrainerSpells_ClassTrainerFrame_Update()
    SetPortraitTexture(ClassTrainerFramePortrait, "npc")
    ClassTrainerNameText:SetText(UnitName("npc"))
    ClassTrainerGreetingText:SetText(GetTrainerGreetingText())
    local visibleList = BuildVisibleTrainerIndexList()
    local selected = ClassTrainerFrame.selectedService
    if selected and not TrainerSpells_Character.showIgnoredInTrainer and not tContains(visibleList, selected) then
        local nextService, nextPosition
        for position, index in ipairs(visibleList) do
            if select(3, GetTrainerServiceInfo(index)) == "available" then
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

local function InstallScrollBoxTrainerFilter()
    local scrollBox = ClassTrainerFrame.ScrollBox
    if not Menu or not Menu.ModifyMenu or not scrollBox.ForEachFrame or not scrollBox.Update then return false end
    local view = scrollBox:GetView()
    if not view or not view.SetElementExtentCalculator or not view.SetVirtualized or not scrollBox.FullUpdate then return false end
    local fixedExtent = view:HasElementExtent() and view:GetIdenticalElementExtent()
    local nativeCalculator = view:GetElementExtentCalculator()
    local hiddenRows = setmetatable({}, {__mode = "k"})
    local lookupProvider, cachedSpellIDs, resolvedSpellIDs, professionKey

    local function ShouldHideService(index)
        if TrainerSpells_Character.showIgnoredInTrainer then return false end
        if not index then return false end
        local name, subText, serviceType = TrainerSpells:GetTrainerServiceInfo(index)
        if not name or serviceType == "header" then return false end

        local provider = scrollBox:GetDataProvider()
        if lookupProvider ~= provider or not cachedSpellIDs then
            lookupProvider = provider
            cachedSpellIDs = BuildCachedSpellIDLookup()
            resolvedSpellIDs = {}
            professionKey = IsTradeskillTrainer and IsTradeskillTrainer() and TrainerSpells:DetectTrainerProfession()
        end

        local spellID = resolvedSpellIDs[index]
        if not spellID then
            local rank = subText and tonumber(subText:match("%d+")) or 0
            spellID = TrainerSpells:GetSpellIDForService(index, true)
            if not spellID and cachedSpellIDs[name] then spellID = cachedSpellIDs[name][rank] end
            resolvedSpellIDs[index] = spellID
        end

        if professionKey then return TrainerSpells_IsProfessionSpellIgnored(spellID, professionKey) end
        return TrainerSpells_IsIgnored(spellID, name)
    end

    local function ShouldHide(node)
        local data = node and node.GetData and node:GetData()
        return data and ShouldHideService(data.skillIndex)
    end

    local function RefreshRows()
        if not ClassTrainerFrame:IsShown() then return end
        scrollBox:ForEachFrame(function(row)
            if ShouldHide(row:GetElementData()) then
                hiddenRows[row] = true
                row:Hide()
            elseif hiddenRows[row] then
                hiddenRows[row] = nil
                row:Show()
            end
        end)
    end

    local function FilteredExtent(dataIndex, node)
        if ShouldHide(node) then return 0 end
        if fixedExtent then return fixedExtent end
        if nativeCalculator then return nativeCalculator(dataIndex, node) end
        return view:GetTemplateExtentFromElementData(node)
    end

    view:SetVirtualized(false)

    local function RefreshSelection()
        if not ClassTrainerFrame:IsShown() then return end
        local selected = ClassTrainerFrame.selectedService
        local stepIndex = GetTrainerServiceStepIndex and GetTrainerServiceStepIndex()
        if selected and selected ~= stepIndex and ShouldHideService(selected) then
            local nextService
            for index = 1, GetNumTrainerServices() do
                if index ~= stepIndex and select(3, TrainerSpells:GetTrainerServiceInfo(index)) == "available" and not ShouldHideService(index) then
                    nextService = index
                    if index > selected then break end
                end
            end

            if nextService then
                ClassTrainer_SetSelection(nextService)
                scrollBox:ScrollToElementDataByPredicate(function(data)
                    return data.skillIndex == nextService
                end, ScrollBoxConstants.AlignNearest)
            else
                ClassTrainerFrame.selectedService = nil
                if ClassTrainerFrame_SetTrainButtonEnabled then
                    ClassTrainerFrame_SetTrainButtonEnabled(false)
                else
                    ClassTrainerTrainButton:Disable()
                end
            end
        end
        RefreshRows()
    end

    local function RefreshLayout()
        if not TrainerSpells_Character.showIgnoredInTrainer then
            view:SetElementExtentCalculator(FilteredExtent)
        elseif fixedExtent then
            view:SetElementExtent(fixedExtent)
        else
            view:SetElementExtentCalculator(nativeCalculator)
        end

        scrollBox:ForEachFrame(function(row, node)
            view:ResizeFrame(scrollBox, row, row:GetOrderIndex(), node)
        end)
        scrollBox:FullUpdate(true)
        scrollBox:ScrollToBegin(true)
        RefreshSelection()
    end

    hooksecurefunc(scrollBox, "Update", RefreshRows)
    hooksecurefunc("ClassTrainerFrame_Update", RefreshSelection)
    hooksecurefunc("ClassTrainer_SetSelection", RefreshSelection)
    Menu.ModifyMenu("MENU_TRAINER_FILTER", function(owner, rootDescription)
        if owner ~= ClassTrainerFrame.FilterDropdown then return end
        for _, description in rootDescription:EnumerateElementDescriptions() do
            local iterator, state, first = description:EnumerateElementDescriptions()
            if iterator(state, first) ~= nil then
                description:CreateCheckbox(YELLOW_FONT_COLOR:WrapTextInColorCode(TrainerSpells:Trans("LID_IGNORED")), function()
                    return TrainerSpells_Character.showIgnoredInTrainer
                end, function()
                    TrainerSpells_Character.showIgnoredInTrainer = not TrainerSpells_Character.showIgnoredInTrainer
                    RefreshLayout()
                end)
                break
            end
        end
    end)
    RefreshLayout()
    return true
end

local trainerFilterHookInstalled = false
function TrainerSpells:EnsureTrainerFilterHookInstalled()
    if trainerFilterHookInstalled or not ClassTrainerFrame or not ClassTrainerFrame.FilterDropdown then return end
    if ClassTrainerFrame.ScrollBox and ClassTrainerFrame_Update then
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

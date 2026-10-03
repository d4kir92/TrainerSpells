local _, TrainerSpells = ...
local classFrame = TrainerSpells.ClassFrame
local function GetCurrentProfessionSkill(professionName)
    if ProfessionsFrame then
        local professionInfo = ProfessionsFrame.GetProfessionInfo and ProfessionsFrame:GetProfessionInfo() or ProfessionsFrame.professionInfo
        if type(professionInfo) == "table" and professionInfo.skillLevel then return professionInfo.skillLevel end
    end

    if not GetNumSkillLines or not GetSkillLineInfo or not professionName then return 0 end
    for i = 1, GetNumSkillLines() do
        local skillName, isHeader, _, skillRank = GetSkillLineInfo(i)
        if not isHeader and skillName == professionName then return skillRank or 0 end
    end
    return 0
end

local professionFrame = CreateFrame("Frame", "TrainerSpellsProfessionFrame", UIParent)
professionFrame:SetSize(420, 480)
professionFrame:SetFrameStrata("HIGH")
professionFrame:SetFrameLevel(500)
professionFrame:EnableMouse(true)
professionFrame:Hide()
local professionSearchBox = CreateFrame("EditBox", "TrainerSpellsProfessionSearchBox", professionFrame, "SearchBoxTemplate")
professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -24)
professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -8, -24)
professionSearchBox:SetHeight(20)
professionSearchBox:SetAutoFocus(false)
professionSearchBox:SetScript("OnTextChanged", function(self)
    if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(self) end
    TrainerSpells_ProfessionSearchText = self:GetText() or ""
    TrainerSpells_ProfessionRefresh()
end)

TrainerSpells.ProfessionRowHeight = (TrainerSpells_Character and TrainerSpells_Character.professionRowHeight) or 16
TrainerSpells.ProfessionRowHeight = math.max(TrainerSpells.MinRowHeight, math.min(TrainerSpells.MaxRowHeight, TrainerSpells.ProfessionRowHeight))
local professionRowHeightSlider = CreateFrame("Slider", "TrainerSpellsProfessionRowHeightSlider", professionFrame, "MinimalSliderWithSteppersTemplate")
TrainerSpells.ProfessionRowHeightSlider = professionRowHeightSlider
professionRowHeightSlider:SetPoint("TOPLEFT", professionSearchBox, "BOTTOMLEFT", -8, -9)
professionRowHeightSlider:SetPoint("TOPRIGHT", professionSearchBox, "BOTTOMRIGHT", -24, -14)
professionRowHeightSlider:SetScale(0.75)
professionRowHeightSlider:SetHeight(10)
professionRowHeightSlider:Init(TrainerSpells.ProfessionRowHeight, TrainerSpells.MinRowHeight, TrainerSpells.MaxRowHeight, TrainerSpells.MaxRowHeight - TrainerSpells.MinRowHeight, {
    [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return WHITE_FONT_COLOR:WrapTextInColorCode(tostring(math.floor(value + 0.5))) end)
})

if professionRowHeightSlider.MinText then professionRowHeightSlider.MinText:Hide() end
if professionRowHeightSlider.MaxText then professionRowHeightSlider.MaxText:Hide() end
local professionScrollBox = CreateFrame("Frame", "TrainerSpellsProfessionScrollBox", professionFrame, "WowScrollBoxList")
professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -4)
professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, 12)
local professionListBg = professionFrame:CreateTexture("TrainerSpellsProfessionBackground", "BACKGROUND")
local professionScrollBar = CreateFrame("EventFrame", "TrainerSpellsProfessionScrollBar", professionFrame, "MinimalScrollBar")
professionScrollBar:SetPoint("TOPLEFT", professionScrollBox, "TOPRIGHT", 4, -2)
professionScrollBar:SetPoint("BOTTOMLEFT", professionScrollBox, "BOTTOMRIGHT", 4, 2)
local professionScrollView = CreateScrollBoxListLinearView()
professionScrollView:SetElementExtentCalculator(function(_, elementData)
    if elementData.isHeader then return TrainerSpells.HeaderHeight + TrainerSpells.HeaderExtraGap end
    return TrainerSpells.ProfessionRowHeight
end)

professionScrollView:SetPadding(0, 0, 0, 0, TrainerSpells.RowSpacing)
professionScrollView:SetElementInitializer("Frame", function(rowFrame, elementData) TrainerSpells:InitScrollRow(rowFrame, elementData, TrainerSpells.ProfessionRowHeight) end)
ScrollUtil.InitScrollBoxListWithScrollBar(professionScrollBox, professionScrollBar, professionScrollView)
professionRowHeightSlider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
    value = math.floor(value + 0.5)
    if value == TrainerSpells.ProfessionRowHeight then return end
    TrainerSpells.ProfessionRowHeight = value
    if TrainerSpells_Character then TrainerSpells_Character.professionRowHeight = TrainerSpells.ProfessionRowHeight end
    TrainerSpells_ProfessionRefresh()
end)

local function GetOpenProfession()
    if GetTradeSkillLine then
        local skillLineName = GetTradeSkillLine()
        if skillLineName and skillLineName ~= "" then return TrainerSpells:GetProfessionKey(skillLineName), skillLineName end
    end

    local professionInfo = ProfessionsFrame and (ProfessionsFrame.GetProfessionInfo and ProfessionsFrame:GetProfessionInfo() or ProfessionsFrame.professionInfo)
    if not professionInfo and C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then professionInfo = C_TradeSkillUI.GetBaseProfessionInfo() end
    if type(professionInfo) ~= "table" then return nil, nil end
    local professionName = professionInfo.parentProfessionName
    local professionKey = professionName and TrainerSpells:GetProfessionKey(professionName)
    if professionKey then return professionKey, professionName end
    professionName = professionInfo.professionName
    professionKey = professionName and TrainerSpells:GetProfessionKey(professionName)
    if professionKey then return professionKey, professionName end
    professionName = professionInfo.name
    professionKey = professionName and TrainerSpells:GetProfessionKey(professionName)
    if professionKey then return professionKey, professionName end
    return nil, professionInfo.parentProfessionName or professionInfo.professionName or professionInfo.name
end

local PROFESSION_VIEW_SKILL = "skill"
local PROFESSION_VIEW_RECIPES = "recipes"
local PROFESSION_VIEW_TRAINERS = "trainers"
local PROFESSION_SUB_VIEWS = {
    {mode = PROFESSION_VIEW_SKILL, icon = "Interface\\Icons\\INV_Misc_Book_09", title = "LID_PROFESSION_FROMTRAINER", desc = "LID_PROFESSION_FROMTRAINER_DESC"},
    {mode = PROFESSION_VIEW_RECIPES, icon = "Interface\\Icons\\INV_Scroll_03", title = "LID_PROFESSION_OTHERRECIPES", desc = "LID_PROFESSION_OTHERRECIPES_DESC"},
    {mode = PROFESSION_VIEW_TRAINERS, icon = 134269, title = "LID_PROFESSION_FINDTRAINER", desc = "LID_PROFESSION_FINDTRAINER_DESC"},
}
local professionViewMode = PROFESSION_VIEW_SKILL
function TrainerSpells:IsProfessionRecipeViewActive()
    return professionViewMode == PROFESSION_VIEW_RECIPES
end

local function MarkProfessionEntries(groups, professionKey, isRecipe)
    for _, groupName in ipairs({"available", "soon", "higher", "missingTalents", "ignored", "known"}) do
        for _, entry in ipairs(groups[groupName]) do
            entry.professionKey = professionKey
            entry.isProfessionRecipe = isRecipe
        end
    end
end

local professionPicker = {}
function professionPicker.GetOwned()
    local owned = {}
    if not GetProfessions or not GetProfessionInfo then return owned end
    local professionIndices = {GetProfessions()}
    for slot = 1, 10 do
        local professionIndex = professionIndices[slot]
        if professionIndex then
            local professionName, icon, rank, maxRank = GetProfessionInfo(professionIndex)
            local professionKey = professionName and TrainerSpells:GetProfessionKey(professionName)
            if professionKey then table.insert(owned, {key = professionKey, name = professionName, icon = icon, rank = rank or 0, maxRank = maxRank or 0, owned = true}) end
        end
    end
    return owned
end

function professionPicker.GetSources()
    return {TrainerSpells_ProfessionData, TrainerSpells_RecipeData, TrainerSpellsProfessionTrainers}
end

function professionPicker.HasData(professionKey)
    for _, source in ipairs(professionPicker.GetSources()) do
        local data = source and source[professionKey]
        if type(data) == "table" and next(data) then return true end
    end
    return false
end

function professionPicker.GetLists()
    local owned = {}
    local seen = {}
    for _, info in ipairs(professionPicker.GetOwned()) do
        seen[info.key] = true
        if professionPicker.HasData(info.key) then table.insert(owned, info) end
    end

    local others = {}
    for _, source in ipairs(professionPicker.GetSources()) do
        for professionKey in pairs(source or {}) do
            local professionName = TrainerSpells:GetProfessionName(professionKey)
            if professionName and not seen[professionKey] and professionPicker.HasData(professionKey) then
                seen[professionKey] = true
                table.insert(others, {key = professionKey, name = professionName, icon = TrainerSpells:GetProfessionIcon(professionKey), rank = 0, maxRank = 0})
            end
        end
    end

    table.sort(others, function(a, b) return a.name < b.name end)
    return owned, others
end

function professionPicker.GetInfo(professionKey)
    for _, info in ipairs(professionPicker.GetOwned()) do
        if info.key == professionKey then return info end
    end
    return {key = professionKey, name = TrainerSpells:GetProfessionName(professionKey) or professionKey, icon = TrainerSpells:GetProfessionIcon(professionKey), rank = 0, maxRank = 0}
end

function professionPicker.GetLabel(info)
    local icon = info.icon and ("|T" .. info.icon .. ":16:16|t ") or ""
    if info.owned then return icon .. info.name .. "  |cffaaaaaa" .. info.rank .. "/" .. info.maxRank .. "|r" end
    return icon .. "|cff9d9d9d" .. info.name .. "|r"
end

function professionPicker.GetActive()
    if not professionPicker.dropdown or not professionPicker.key then
        local professionKey, skillLineName = GetOpenProfession()
        return professionKey, skillLineName, GetCurrentProfessionSkill(skillLineName)
    end

    local info = professionPicker.GetInfo(professionPicker.key)
    return info.key, info.name, info.rank
end

function professionPicker.UpdateText()
    if professionPicker.dropdown and professionPicker.key then professionPicker.dropdown:SetText(professionPicker.GetLabel(professionPicker.GetInfo(professionPicker.key))) end
end

function professionPicker.Reset()
    local openKey = GetOpenProfession()
    local owned = professionPicker.GetLists()
    professionPicker.key = openKey or (owned[1] and owned[1].key)
    professionPicker.UpdateText()
end

function professionPicker.Select(professionKey)
    professionPicker.key = professionKey
    TrainerSpells_ProfessionRefresh()
end

function professionPicker.Create()
    if professionPicker.dropdown or not (MenuUtil and MenuUtil.CreateRootMenuDescription) then return end
    local dropdown = CreateFrame("DropdownButton", "TrainerSpellsProfessionPicker", professionFrame, "WowStyle1DropdownTemplate")
    dropdown:SetSize(180, 26)
    dropdown:SetupMenu(function(_, rootDescription)
        for groupIndex, group in ipairs({professionPicker.GetLists()}) do
            if #group > 0 then
                rootDescription:CreateTitle(TrainerSpells:Trans(groupIndex == 1 and "LID_YOURPROFESSIONS" or "LID_OTHERPROFESSIONS"))
                for _, info in ipairs(group) do
                    local professionKey = info.key
                    rootDescription:CreateRadio(professionPicker.GetLabel(info), function() return professionPicker.key == professionKey end, function() professionPicker.Select(professionKey) end)
                end
            end
        end
    end)

    professionPicker.dropdown = dropdown
end

function TrainerSpells_ProfessionRefresh()
    local searchText = (TrainerSpells_ProfessionSearchText or ""):lower()
    local professionKey, skillLineName, currentSkill = professionPicker.GetActive()
    local items = {}
    if professionViewMode == PROFESSION_VIEW_RECIPES then
        local data = professionKey and TrainerSpells_RecipeData and TrainerSpells_RecipeData[professionKey]
        if data and next(data) then
            local groups = TrainerSpells:ClassifyEntries(data, searchText, currentSkill, true, professionKey)
            MarkProfessionEntries(groups, professionKey, true)
            TrainerSpells:AppendGroupItems(items, groups, "tradeskillrecipe_", nil, TrainerSpells:Trans("LID_SKILL"), nil, nil, "skill")
        end

        if #items == 0 then TrainerSpells:AddHeaderItem(items, skillLineName and TrainerSpells:Trans("LID_NORECIPEDATAFOR"):format(skillLineName) or TrainerSpells:Trans("LID_NOPROFESSIONDETECTED"), "|cffaaaaaa") end
    elseif professionViewMode == PROFESSION_VIEW_TRAINERS then
        local trainers = professionKey and TrainerSpellsProfessionTrainers and TrainerSpellsProfessionTrainers[professionKey]
        if trainers and TrainerSpells.AddTrainerLocationItems then TrainerSpells:AddTrainerLocationItems(items, TrainerSpells:GetTrainerLocationEntries(trainers, searchText), "profession_trainer_" .. professionKey .. "_") end
        if #items == 0 then TrainerSpells:AddHeaderItem(items, skillLineName and TrainerSpells:Trans("LID_NOTRAINERDATAFOR"):format(skillLineName) or TrainerSpells:Trans("LID_NOPROFESSIONDETECTED"), "|cffaaaaaa") end
    else
        local data = professionKey and TrainerSpells_ProfessionData and TrainerSpells_ProfessionData[professionKey]
        if data and next(data) then
            local groups = TrainerSpells:ClassifyEntries(data, searchText, currentSkill, true, professionKey)
            MarkProfessionEntries(groups, professionKey, false)
            TrainerSpells:AppendGroupItems(items, groups, "tradeskillprofession_", nil, TrainerSpells:Trans("LID_SKILL"), nil, nil, "skill")
        end

        if #items == 0 then TrainerSpells:AddHeaderItem(items, skillLineName and TrainerSpells:Trans("LID_NODATAFOR"):format(skillLineName) or TrainerSpells:Trans("LID_NOPROFESSIONDETECTED"), "|cffaaaaaa") end
    end

    TrainerSpells:AddCostColumn(items)
    professionScrollBox:SetDataProvider(CreateDataProvider(items), ScrollBoxConstants.RetainScrollPosition)
    professionPicker.UpdateText()
end

local professionSubTabs = {}
function professionSubTabs.GetSavedView()
    local saved = TrainerSpells_Character and TrainerSpells_Character.professionView
    for _, view in ipairs(PROFESSION_SUB_VIEWS) do
        if view.mode == saved then return saved end
    end
    return PROFESSION_VIEW_SKILL
end

function professionSubTabs.Update()
    if not professionSubTabs.bar then return end
    for index, view in ipairs(PROFESSION_SUB_VIEWS) do
        if view.mode == professionViewMode then
            professionSubTabs.bar:SetTabVisuallySelected(index)
            professionSubTabs.title:SetText(TrainerSpells:Trans(view.title))
            professionSubTabs.desc:SetText(TrainerSpells:Trans(view.desc))
        end
    end
end

function professionSubTabs.Select(mode)
    professionViewMode = mode
    if TrainerSpells_Character then TrainerSpells_Character.professionView = mode end
    professionSubTabs.Update()
    TrainerSpells_ProfessionRefresh()
end

function professionSubTabs.Create()
    if professionSubTabs.bar then return end
    local bar = CreateFrame("Frame", "TrainerSpellsProfessionSubTabs", professionFrame, "TabSystemTemplate")
    professionSubTabs.bar = bar
    bar:SetTabSelectedCallback(function(tabID)
        local view = PROFESSION_SUB_VIEWS[tabID]
        if view then professionSubTabs.Select(view.mode) end
        return true
    end)

    for index, view in ipairs(PROFESSION_SUB_VIEWS) do
        bar:AddTab(nil, view.icon)
        bar:GetTabButton(index):SetTooltipText(TrainerSpells:Trans(view.title))
    end

    bar:Layout()
    local title = professionFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    professionSubTabs.title = title
    local desc = professionFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetWordWrap(true)
    desc:SetMaxLines(2)
    desc:SetTextColor(0.75, 0.75, 0.75)
    professionSubTabs.desc = desc
    professionSubTabs.Update()
end

local function PositionProfessionFrame()
    professionFrame:ClearAllPoints()
    if ProfessionsFrame and ProfessionsFrame:IsShown() then
        professionFrame:SetScale(1)
        professionFrame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPLEFT", 3, -21)
        professionFrame:SetPoint("BOTTOMRIGHT", ProfessionsFrame, "BOTTOMRIGHT", -3, 3)
    elseif TradeSkillFrame and TradeSkillFrame:IsShown() then
        if TrainerSpells:IsDragonflightUIEnabled() and DragonflightUIProfessionFrame and DragonflightUIProfessionFrame:IsShown() then
            professionFrame:SetScale(DragonflightUIProfessionFrame:GetScale())
            professionFrame:SetPoint("TOPLEFT", DragonflightUIProfessionFrame, "TOPLEFT", -4, -24)
            professionFrame:SetPoint("BOTTOMRIGHT", DragonflightUIProfessionFrame, "BOTTOMRIGHT", -4, 4)
        elseif TrainerSpells:IsLeatrixWideProfessionEnabled() then
            professionFrame:SetScale(TradeSkillFrame:GetScale())
            professionFrame:SetPoint("TOPLEFT", TradeSkillFrame, "TOPLEFT", 14, -70)
            professionFrame:SetPoint("BOTTOMRIGHT", TradeSkillFrame, "BOTTOMRIGHT", -36, 70)
        else
            professionFrame:SetScale(TradeSkillFrame:GetScale())
            professionFrame:SetPoint("TOPLEFT", TradeSkillFrame, "TOPLEFT", 14, -70)
            professionFrame:SetPoint("BOTTOMRIGHT", TradeSkillFrame, "BOTTOMRIGHT", -36, 70)
        end
    else
        professionFrame:SetScale(1)
        professionFrame:SetPoint("CENTER")
    end

    professionSearchBox:ClearAllPoints()
    professionScrollBox:ClearAllPoints()
    if ProfessionsFrame and ProfessionsFrame:IsShown() then
        local searchTop = -6
        if professionSubTabs.bar then
            searchTop = -52
            professionSubTabs.bar:ClearAllPoints()
            professionSubTabs.bar:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 64, -8)
            professionSubTabs.title:ClearAllPoints()
            professionSubTabs.title:SetPoint("TOPLEFT", professionSubTabs.bar, "TOPRIGHT", 12, -2)
            if professionPicker.dropdown then
                professionPicker.dropdown:ClearAllPoints()
                professionPicker.dropdown:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -10, -11)
                professionSubTabs.title:SetPoint("TOPRIGHT", professionPicker.dropdown, "TOPLEFT", -12, 1)
            else
                professionSubTabs.title:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -10, -10)
            end
            professionSubTabs.desc:ClearAllPoints()
            professionSubTabs.desc:SetPoint("TOPLEFT", professionSubTabs.title, "BOTTOMLEFT", 0, -3)
            professionSubTabs.desc:SetPoint("TOPRIGHT", professionSubTabs.title, "BOTTOMRIGHT", 0, -3)
        end

        professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 64, searchTop)
        professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -10, searchTop)
        professionRowHeightSlider:ClearAllPoints()
        professionRowHeightSlider:SetPoint("TOPLEFT", professionSearchBox, "BOTTOMLEFT", 0, -9)
        professionRowHeightSlider:SetPoint("TOPRIGHT", professionSearchBox, "BOTTOMRIGHT", -24, -14)
        professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, searchTop - 48)
        professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, 12)
    elseif TrainerSpells:IsDragonflightUIEnabled() and DragonflightUIProfessionFrame and DragonflightUIProfessionFrame:IsShown() then
        professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 80, 0)
        professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -10, 0)
        professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -64)
        professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, 12)
    elseif TrainerSpells:IsLeatrixWideProfessionEnabled() then
        local titleText = TradeSkillFrame and _G["TradeSkillFrameTitleText"]
        if titleText and professionFrame:GetTop() and titleText:GetBottom() then
            local topOffset = titleText:GetBottom() - professionFrame:GetTop() - 4
            professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 66, topOffset)
            professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -4, topOffset)
        else
            professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 10, -6)
            professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -30, -10)
        end

        professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 0, -4)
        professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, -12)
    else
        local titleText = TradeSkillFrame and _G["TradeSkillFrameTitleText"]
        if titleText and professionFrame:GetTop() and titleText:GetBottom() then
            local topOffset = titleText:GetBottom() - professionFrame:GetTop() - 4
            professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 66, topOffset)
            professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -4, topOffset)
        else
            professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 10, -6)
            professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -30, -6)
        end

        professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -4)
        professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, 12)
    end
end

if TradeSkillFrame then hooksecurefunc(TradeSkillFrame, "SetScale", function() if classFrame:IsShown() then PositionProfessionFrame() end end) end
local function CreateTradeSkillTab(name, icon)
    local tab = CreateFrame("Button", name, UIParent)
    tab:SetSize(32, 32)
    tab:SetNormalTexture(icon)
    tab:SetHighlightTexture(130718, "ADD")
    tab:SetFrameStrata("HIGH")
    tab:SetFrameLevel(500)
    tab:Hide()
    local border = tab:CreateTexture(name .. "Border", "BACKGROUND")
    border:SetSize(64, 64)
    border:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
    border:SetTexture(136831)
    local glow = tab:CreateTexture(nil, "OVERLAY")
    glow:SetSize(32, 32)
    glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    glow:SetTexture(130724)
    glow:SetBlendMode("ADD")
    glow:Hide()
    return tab, glow
end

local nativeTab, nativeTabGlow = CreateTradeSkillTab("TrainerSpellsTradeSkillNativeTab", "Interface\\Icons\\ability_kick")
local professionTab, professionTabGlow = CreateTradeSkillTab("TrainerSpellsTradeSkillProfessionTab", "Interface\\Icons\\INV_Misc_Book_09")
local recipeTab, recipeTabGlow = CreateTradeSkillTab("TrainerSpellsTradeSkillRecipeTab", "Interface\\Icons\\INV_Scroll_03")
local function PositionTradeSkillTabs()
    C_Timer.After(TrainerSpells:IsDragonflightUIEnabled() and 0.1 or 0, function()
        if TrainerSpells:IsDragonflightUIEnabled() and DragonflightUIProfessionFrame and DragonflightUIProfessionFrame:IsShown() then
            local scale = DragonflightUIProfessionFrame:GetScale()
            nativeTab:SetScale(scale)
            professionTab:SetScale(scale)
            recipeTab:SetScale(scale)
            nativeTab:ClearAllPoints()
            nativeTab:SetPoint("TOPLEFT", DragonflightUIProfessionFrame, "TOPRIGHT", 0, -60)
            professionTab:ClearAllPoints()
            professionTab:SetPoint("TOPLEFT", nativeTab, "BOTTOMLEFT", 0, -36)
            recipeTab:ClearAllPoints()
            recipeTab:SetPoint("TOPLEFT", professionTab, "BOTTOMLEFT", 0, -36)
        else
            if TradeSkillFrame then
                local scale = TradeSkillFrame:GetScale()
                nativeTab:SetScale(scale)
                professionTab:SetScale(scale)
                recipeTab:SetScale(scale)
                nativeTab:ClearAllPoints()
                nativeTab:SetPoint("TOPLEFT", TradeSkillFrame, "TOPRIGHT", -33, -60)
                professionTab:ClearAllPoints()
                professionTab:SetPoint("TOPLEFT", nativeTab, "BOTTOMLEFT", 0, -36)
                recipeTab:ClearAllPoints()
                recipeTab:SetPoint("TOPLEFT", professionTab, "BOTTOMLEFT", 0, -36)
            end
        end
    end)
end

local NATIVE_TRADESKILL_WIDGETS = {"TradeSkillSubClassDropdown", "TradeSkillInvSlotDropdown", "TradeSkillRankFrame", "TradeSkillRankFrameBorder"}
local function HideNativeTradeSkillWidgets()
    for _, name in ipairs(NATIVE_TRADESKILL_WIDGETS) do
        local widget = _G[name]
        if widget then widget:Hide() end
    end
end

local function ShowNativeTradeSkillWidgets()
    for _, name in ipairs(NATIVE_TRADESKILL_WIDGETS) do
        local widget = _G[name]
        if widget then widget:Show() end
    end
end

local function SetTradeSkillView(mode)
    if mode == PROFESSION_VIEW_SKILL or mode == PROFESSION_VIEW_RECIPES then
        professionViewMode = mode
        C_Timer.After(TrainerSpells:IsDragonflightUIEnabled() and 0.1 or 0, function()
            if TrainerSpells:IsDragonflightUIEnabled() and DragonflightUIProfessionFrame and DragonflightUIProfessionFrame:IsShown() then
                professionListBg:ClearAllPoints()
                professionListBg:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 4, -32)
                professionListBg:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", 4, -2)
                professionListBg:SetColorTexture(0, 0, 0, 1)
                if DragonflightUIProfessionRankFrame then DragonflightUIProfessionRankFrame:Hide() end
            elseif TrainerSpells:IsLeatrixWideProfessionEnabled() then
                professionListBg:ClearAllPoints()
                professionListBg:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 0, -2)
                professionListBg:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -2, -16)
                professionListBg:SetColorTexture(0, 0, 0, 1)
            else
                professionListBg:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 4, -2)
                professionListBg:SetTexture("Interface\\AddOns\\TrainerSpells\\media\\inset")
                if TradeSkillFrameAvailableFilterCheckButton then TradeSkillFrameAvailableFilterCheckButton:Hide() end
                if TradeSearchInputBox then TradeSearchInputBox:Hide() end
            end

            PositionProfessionFrame()
            professionFrame:Show()
            nativeTabGlow:Hide()
            if mode == PROFESSION_VIEW_RECIPES then
                recipeTabGlow:Show()
                professionTabGlow:Hide()
            else
                professionTabGlow:Show()
                recipeTabGlow:Hide()
            end

            HideNativeTradeSkillWidgets()
            TrainerSpells_ProfessionRefresh()
        end)
    else
        professionFrame:Hide()
        professionTabGlow:Hide()
        recipeTabGlow:Hide()
        nativeTabGlow:Show()
        ShowNativeTradeSkillWidgets()
    end
end

nativeTab:SetScript("OnClick", function() SetTradeSkillView("native") end)
nativeTab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText((GetTradeSkillLine and GetTradeSkillLine()) or TrainerSpells:Trans("LID_PROFESSIONS"))
    GameTooltip:Show()
end)

nativeTab:SetScript("OnLeave", GameTooltip_Hide)
professionTab:SetScript("OnClick", function() SetTradeSkillView(PROFESSION_VIEW_SKILL) end)
professionTab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TrainerSpells:Trans("LID_SKILL"))
    GameTooltip:Show()
end)

professionTab:SetScript("OnLeave", GameTooltip_Hide)
recipeTab:SetScript("OnClick", function() SetTradeSkillView(PROFESSION_VIEW_RECIPES) end)
recipeTab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TrainerSpells:Trans("LID_RECIPES"))
    GameTooltip:Show()
end)

recipeTab:SetScript("OnLeave", GameTooltip_Hide)
local tradeSkillHooksInstalled = false
local function EnsureTradeSkillHooksInstalled()
    if tradeSkillHooksInstalled then return end
    if not TradeSkillFrame then return end
    tradeSkillHooksInstalled = true
    TradeSkillFrame:HookScript("OnShow", function()
        PositionTradeSkillTabs()
        nativeTab:Show()
        professionTab:Show()
        recipeTab:Show()
        SetTradeSkillView("native")
    end)

    TradeSkillFrame:HookScript("OnHide", function()
        professionFrame:Hide()
        professionTabGlow:Hide()
        recipeTabGlow:Hide()
        nativeTabGlow:Hide()
        nativeTab:Hide()
        professionTab:Hide()
        recipeTab:Hide()
        ShowNativeTradeSkillWidgets()
    end)

    hooksecurefunc(TradeSkillFrame, "SetScale", function()
        PositionTradeSkillTabs()
        if professionFrame:IsShown() then PositionProfessionFrame() end
    end)

    if TradeSkillFrame:IsShown() then
        PositionTradeSkillTabs()
        nativeTab:Show()
        professionTab:Show()
        recipeTab:Show()
        SetTradeSkillView("native")
    end

    C_Timer.After(4, function()
        for i = 1, 4 do
            local t = _G["DragonflightUIProfessionFrameTabButton" .. i]
            if t then t:HookScript("OnClick", function() SetTradeSkillView("native") end) end
        end

        if DragonflightUIProfessionFrame then hooksecurefunc(DragonflightUIProfessionFrame, "SetScale", function() if professionFrame:IsShown() then PositionProfessionFrame() end end) end
    end)
end

local professionsFrameHooksInstalled = false
local professionsModeTabContainer
local professionsModeTabs = {}
local professionsModeActive = false
local professionsFrameUsesSideTabs = false
local professionsClosePending = false
local professionsRestorePending = false
local function IsProfessionsCombatLocked()
    return InCombatLockdown and InCombatLockdown()
end

local function UpdateProfessionsTabsCombatState()
    local locked = IsProfessionsCombatLocked()
    for _, tab in pairs(professionsModeTabs) do
        tab.combatLocked = locked
        tab:SetAlpha(locked and 0.5 or 1)
        if tab.Icon and tab.Icon.SetDesaturated then tab.Icon:SetDesaturated(locked) end
    end
end

local function PositionProfessionsFrameModeTabs()
    if not ProfessionsFrame then return end
    local addonTab = professionsModeTabs.addon
    if not addonTab then return end
    addonTab:ClearAllPoints()
    if professionsFrameUsesSideTabs then
        local lastTab = ProfessionsFrame.ProfessionsOverviewTab
        for _, tab in ipairs(ProfessionsFrame.rightProfessionTabs) do
            if tab:IsShown() then lastTab = tab end
        end

        addonTab:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, -16)
    else
        professionsModeTabContainer:ClearAllPoints()
        professionsModeTabContainer:SetPoint("LEFT", ProfessionsFrame.TabSystem, "RIGHT", 20, 0)
        addonTab:SetPoint("LEFT", professionsModeTabContainer, "LEFT", 0, 0)
    end
end

local function SetProfessionsModeTabSelected(tab, selected)
    if tab.SetTabSelected then
        tab:SetTabSelected(selected)
    else
        tab:SetChecked(selected)
    end
end

local function CloseProfessionsFrameView()
    if IsProfessionsCombatLocked() then
        if professionsModeActive or professionFrame:IsShown() then professionsClosePending = true end
        return
    end

    professionsClosePending = false
    professionsModeActive = false
    professionFrame:Hide()
    for _, tab in pairs(professionsModeTabs) do
        SetProfessionsModeTabSelected(tab, false)
    end
end

local function RestoreProfessionsFramePage()
    if not professionsModeActive then return end
    if IsProfessionsCombatLocked() then
        professionsRestorePending = true
        return
    end

    professionsRestorePending = false
    if professionsFrameUsesSideTabs then
        if ProfessionsFrame.BookPage then ProfessionsFrame.BookPage:Hide() end
        if ProfessionsFrame.CraftingPage then ProfessionsFrame.CraftingPage:Show() end
    elseif ProfessionsFrame.GetTab and ProfessionsFrame.GetElementsForTab then
        local tabID = ProfessionsFrame:GetTab()
        for _, page in ipairs(tabID and ProfessionsFrame:GetElementsForTab(tabID) or {}) do
            page:Show()
        end
    end
end

local professionsCombatWatcher = CreateFrame("Frame")
professionsCombatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
professionsCombatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
professionsCombatWatcher:SetScript("OnEvent", function(_, event)
    UpdateProfessionsTabsCombatState()
    if event ~= "PLAYER_REGEN_ENABLED" then return end
    if professionsRestorePending then RestoreProfessionsFramePage() end
    if professionsClosePending then CloseProfessionsFrameView() end
end)

local function OpenProfessionsFrameView()
    if IsProfessionsCombatLocked() then
        if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
        return
    end

    professionViewMode = professionSubTabs.GetSavedView()
    professionPicker.Reset()
    professionsModeActive = true
    if ProfessionsFrame.Pages then
        for _, page in ipairs(ProfessionsFrame.Pages) do
            page:Hide()
        end
    else
        if ProfessionsFrame.BookPage then ProfessionsFrame.BookPage:Hide() end
        if ProfessionsFrame.CraftingPage then ProfessionsFrame.CraftingPage:Hide() end
    end

    if professionsFrameUsesSideTabs then
        professionListBg:Hide()
    else
        professionListBg:ClearAllPoints()
        professionListBg:SetAllPoints(professionFrame)
        professionListBg:SetColorTexture(0, 0, 0, 1)
        professionListBg:Show()
    end

    PositionProfessionFrame()
    professionFrame:Show()
    for _, tab in pairs(professionsModeTabs) do
        SetProfessionsModeTabSelected(tab, true)
    end

    if professionsFrameUsesSideTabs then
        ProfessionsFrame.ProfessionsOverviewTab:SetChecked(false)
        for _, tab in ipairs(ProfessionsFrame.rightProfessionTabs) do
            tab:SetChecked(false)
        end
    elseif ProfessionsFrame.TabSystem.SetTabVisuallySelected then
        ProfessionsFrame.TabSystem:SetTabVisuallySelected(0)
    end

    professionSubTabs.Update()
    TrainerSpells_ProfessionRefresh()
end

local function CreateProfessionsFrameSystemTab(tabID, text, icon)
    local tab = CreateFrame("Button", nil, professionsModeTabContainer, "TabSystemButtonTemplate")
    tab.GetTabSystem = function() return ProfessionsFrame.TabSystem end
    tab:Init(tabID, nil, icon)
    tab:SetTooltipText(text)
    tab:SetScript("OnClick", function(self) if not self.combatLocked then OpenProfessionsFrameView() end end)
    tab:Show()
    professionsModeTabs.addon = tab
    return tab
end

local function CreateProfessionsFrameSideTab(name, text, icon)
    local tab = CreateFrame("Frame", name, ProfessionsFrame, "LargeSideTabButtonTemplate")
    tab:SetFrameLevel(ProfessionsFrame:GetFrameLevel() + 200)
    tab:EnableMouse(true)
    tab.Icon:SetTexture(icon)
    tab.Icon:SetSize(30, 30)
    tab.Icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
    tab.tooltipText = text
    tab:SetFillToInterior(true)
    tab:SetChecked(false)
    tab:SetCustomOnMouseUpHandler(function(self, button, upInside) if button == "LeftButton" and upInside and not self.combatLocked then OpenProfessionsFrameView() end end)
    tab:Show()
    professionsModeTabs.addon = tab
    return tab
end

local function InstallProfessionsFrameIntegration()
    if professionsFrameHooksInstalled or not ProfessionsFrame then return end
    professionsFrameUsesSideTabs = ProfessionsFrame.ProfessionsOverviewTab and ProfessionsFrame.rightProfessionTabs and true or false
    if not professionsFrameUsesSideTabs and not ProfessionsFrame.TabSystem then return end
    professionsFrameHooksInstalled = true
    professionFrame:SetParent(ProfessionsFrame)
    professionFrame:SetFrameStrata(ProfessionsFrame:GetFrameStrata())
    professionFrame:SetFrameLevel(ProfessionsFrame:GetFrameLevel() + 300)
    professionSubTabs.Create()
    professionPicker.Create()
    if professionsFrameUsesSideTabs then
        CreateProfessionsFrameSideTab("TrainerSpellsProfessionsTab", "TrainerSpells", 133741)
        hooksecurefunc(ProfessionsFrame, "RefreshRightTabs", PositionProfessionsFrameModeTabs)
        hooksecurefunc(ProfessionsFrame, "RightTabSelected", CloseProfessionsFrameView)
    else
        professionsModeTabContainer = CreateFrame("Frame", "TrainerSpellsProfessionsModeTabs", ProfessionsFrame)
        professionsModeTabContainer:SetSize(260, math.max(32, ProfessionsFrame.TabSystem:GetHeight()))
        professionsModeTabContainer:SetFrameLevel(ProfessionsFrame.TabSystem:GetFrameLevel() + 200)
        CreateProfessionsFrameSystemTab(1001, "TrainerSpells", 133741)
        hooksecurefunc(ProfessionsFrame, "SetTab", CloseProfessionsFrameView)
        if ProfessionsFrame.UpdateTabs then hooksecurefunc(ProfessionsFrame, "UpdateTabs", PositionProfessionsFrameModeTabs) end
    end

    UpdateProfessionsTabsCombatState()
    PositionProfessionsFrameModeTabs()
    ProfessionsFrame:HookScript("OnShow", function()
        RestoreProfessionsFramePage()
        PositionProfessionsFrameModeTabs()
        for _, tab in pairs(professionsModeTabs) do
            tab:Show()
        end

        CloseProfessionsFrameView()
        C_Timer.After(0, PositionProfessionsFrameModeTabs)
    end)

    ProfessionsFrame:HookScript("OnHide", function()
        RestoreProfessionsFramePage()
        CloseProfessionsFrameView()
    end)

    hooksecurefunc(ProfessionsFrame, "SetScale", function() if professionFrame:IsShown() then PositionProfessionFrame() end end)
end

if ProfessionsFrame then
    InstallProfessionsFrameIntegration()
else
    local professionsFrameLoader = CreateFrame("Frame")
    professionsFrameLoader:RegisterEvent("ADDON_LOADED")
    professionsFrameLoader:SetScript("OnEvent", function(self, _, addonName)
        if addonName ~= "Blizzard_Professions" then return end
        self:UnregisterEvent("ADDON_LOADED")
        InstallProfessionsFrameIntegration()
    end)
end

local tradeSkillWatcher = CreateFrame("Frame")
for _, event in ipairs({"TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "PLAYER_MONEY"}) do
    TrainerSpells:RegisterEvent(tradeSkillWatcher, event)
end

tradeSkillWatcher:SetScript("OnEvent", function(_, event)
    EnsureTradeSkillHooksInstalled()
    InstallProfessionsFrameIntegration()
    if (event == "TRADE_SKILL_UPDATE" or event == "TRADE_SKILL_LIST_UPDATE") and professionFrame:IsShown() then
        TrainerSpells_ProfessionRefresh()
        HideNativeTradeSkillWidgets()
    elseif event == "PLAYER_MONEY" and professionFrame:IsShown() then
        TrainerSpells_ProfessionRefresh()
    end
end)

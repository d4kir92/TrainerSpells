local _, TrainerSpells = ...
local classFrame = TrainerSpells.ClassFrame
local function GetCurrentProfessionSkill(professionName)
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
professionScrollView:SetElementExtentCalculator(function(index, elementData)
    if elementData.isHeader then return index > 1 and (TrainerSpells.HeaderHeight + TrainerSpells.HeaderExtraGap) or TrainerSpells.HeaderHeight end
    return TrainerSpells.ProfessionRowHeight
end)

professionScrollView:SetPadding(0, 0, 0, 0, TrainerSpells.RowSpacing)
professionScrollView:SetElementInitializer("Frame", function(rowFrame, elementData) TrainerSpells:InitScrollRow(rowFrame, elementData) end)
ScrollUtil.InitScrollBoxListWithScrollBar(professionScrollBox, professionScrollBar, professionScrollView)
professionRowHeightSlider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
    value = math.floor(value + 0.5)
    if value == TrainerSpells.ProfessionRowHeight then return end
    TrainerSpells.ProfessionRowHeight = value
    if TrainerSpells_Character then TrainerSpells_Character.professionRowHeight = TrainerSpells.ProfessionRowHeight end
    TrainerSpells_ProfessionRefresh()
end)

local function GetOpenProfession()
    if not GetTradeSkillLine then return nil, nil end
    local skillLineName = GetTradeSkillLine()
    if not skillLineName or skillLineName == "" then return nil, nil end
    return TrainerSpells:GetProfessionKey(skillLineName), skillLineName
end

local PROFESSION_VIEW_SKILL = "skill"
local PROFESSION_VIEW_RECIPES = "recipes"
local professionViewMode = PROFESSION_VIEW_SKILL
function TrainerSpells_ProfessionRefresh()
    local searchText = (TrainerSpells_ProfessionSearchText or ""):lower()
    local professionKey, skillLineName = GetOpenProfession()
    local items = {}
    if professionViewMode == PROFESSION_VIEW_RECIPES then
        local data = professionKey and TrainerSpells_RecipeData and TrainerSpells_RecipeData[professionKey]
        if data and next(data) then
            local currentSkill = GetCurrentProfessionSkill(skillLineName)
            local groups = TrainerSpells:ClassifyEntries(data, searchText, currentSkill, true, professionKey)
            TrainerSpells:AppendGroupItems(items, groups, "tradeskillrecipe_", nil, TrainerSpells:Trans("LID_SKILL"))
        end

        if #items == 0 then TrainerSpells:AddHeaderItem(items, skillLineName and ("Keine Rezept-Daten für " .. skillLineName .. " gesammelt.") or "Kein Beruf erkannt.", "|cffaaaaaa") end
    else
        local data = professionKey and TrainerSpells_ProfessionData and TrainerSpells_ProfessionData[professionKey]
        if data and next(data) then
            local currentSkill = GetCurrentProfessionSkill(skillLineName)
            local groups = TrainerSpells:ClassifyEntries(data, searchText, currentSkill, true, professionKey)
            TrainerSpells:AppendGroupItems(items, groups, "tradeskillprofession_", nil, TrainerSpells:Trans("LID_SKILL"))
        end

        if #items == 0 then TrainerSpells:AddHeaderItem(items, skillLineName and ("Keine Daten für " .. skillLineName .. " gesammelt.") or "Kein Beruf erkannt.", "|cffaaaaaa") end
    end

    professionScrollBox:SetDataProvider(CreateDataProvider(items))
end

local function PositionProfessionFrame()
    professionFrame:ClearAllPoints()
    if TradeSkillFrame and TradeSkillFrame:IsShown() then
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
    if TrainerSpells:IsDragonflightUIEnabled() and DragonflightUIProfessionFrame and DragonflightUIProfessionFrame:IsShown() then
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

local tradeSkillWatcher = CreateFrame("Frame")
tradeSkillWatcher:RegisterEvent("TRADE_SKILL_SHOW")
tradeSkillWatcher:RegisterEvent("TRADE_SKILL_UPDATE")
tradeSkillWatcher:SetScript("OnEvent", function(_, event)
    EnsureTradeSkillHooksInstalled()
    if event == "TRADE_SKILL_UPDATE" and professionFrame:IsShown() then
        TrainerSpells_ProfessionRefresh()
        HideNativeTradeSkillWidgets()
    end
end)

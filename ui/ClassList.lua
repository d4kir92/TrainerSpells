local _, TrainerSpells = ...
local classFrame = TrainerSpells.ClassFrame
local searchBox = CreateFrame("EditBox", "TrainerSpellsSearchBox", classFrame, "SearchBoxTemplate")
TrainerSpells.SearchBox = searchBox
searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", -60, -6)
searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -10, -6)
searchBox:SetHeight(20)
searchBox:SetAutoFocus(false)
searchBox:SetScript("OnTextChanged", function(self)
    if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(self) end
    TrainerSpells_SearchText = self:GetText() or ""
    TrainerSpells_Refresh()
end)

local rowHeightSlider = CreateFrame("Slider", "TrainerSpellsRowHeightSlider", classFrame, "MinimalSliderWithSteppersTemplate")
TrainerSpells.RowHeightSlider = rowHeightSlider
rowHeightSlider:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -8, -5)
rowHeightSlider:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", -24, -14)
rowHeightSlider:SetScale(0.75)
rowHeightSlider:SetHeight(10)
rowHeightSlider:Init(TrainerSpells.RowHeight, TrainerSpells.MinRowHeight, TrainerSpells.MaxRowHeight, TrainerSpells.MaxRowHeight - TrainerSpells.MinRowHeight, {
    [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return WHITE_FONT_COLOR:WrapTextInColorCode(tostring(math.floor(value + 0.5))) end)
})

if rowHeightSlider.MinText then rowHeightSlider.MinText:Hide() end
if rowHeightSlider.MaxText then rowHeightSlider.MaxText:Hide() end
local scrollBox = CreateFrame("Frame", "TrainerSpellsScrollBox", classFrame, "WowScrollBoxList")
scrollBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 6, -4)
scrollBox:SetPoint("BOTTOMRIGHT", classFrame, "BOTTOMRIGHT", -24, 13)
local listBg = classFrame:CreateTexture("TrainerSpellsFrameBackground", "BACKGROUND")
TrainerSpells.ClassListBackground = listBg
local scrollBar = CreateFrame("EventFrame", "TrainerSpellsScrollBar", classFrame, "MinimalScrollBar")
scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, -2)
scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 2)

local scrollView = CreateScrollBoxListLinearView()
scrollView:SetElementExtentCalculator(function(index, elementData)
    if elementData.isHeader then return index > 1 and (TrainerSpells.HeaderHeight + TrainerSpells.HeaderExtraGap) or TrainerSpells.HeaderHeight end
    return TrainerSpells.RowHeight
end)

scrollView:SetPadding(0, 0, 0, 0, TrainerSpells.RowSpacing)
scrollView:SetElementInitializer("Frame", function(rowFrame, elementData) TrainerSpells:InitScrollRow(rowFrame, elementData) end)
ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, scrollView)
rowHeightSlider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
    value = math.floor(value + 0.5)
    if value == TrainerSpells.RowHeight then return end
    TrainerSpells.RowHeight = value
    if TrainerSpells_Character then TrainerSpells_Character.rowHeight = TrainerSpells.RowHeight end
    if TrainerSpells_Refresh then TrainerSpells_Refresh() end
end)

function TrainerSpells_Refresh()
    local searchText = (TrainerSpells_SearchText or ""):lower()
    local selectedLevel = UnitLevel("player") or 1
    local selectedClass = select(2, UnitClass("player"))
    local classData = selectedClass and TrainerSpells_Data and TrainerSpells_Data[selectedClass]
    local items = {}
    if classData then
        local groups = TrainerSpells:ClassifyEntries(classData, searchText, selectedLevel)
        TrainerSpells:AppendGroupItems(items, groups, "")
    end

    if selectedClass == "WARLOCK" then TrainerSpells:AppendPetAbilities(items, searchText, selectedLevel) end
    if selectedClass == "HUNTER" then TrainerSpells:AppendPetTrainerAbilities(items, searchText, selectedLevel, selectedClass) end
    if #items == 0 then
        if not classData then
            TrainerSpells:AddHeaderItem(items, "Keine Daten für " .. tostring(selectedClass) .. " gesammelt. Lehrer besuchen!", "|cffff5555")
        else
            TrainerSpells:AddHeaderItem(items, "Keine Einträge vorhanden.", "|cffaaaaaa")
        end
    end

    scrollBox:SetDataProvider(CreateDataProvider(items), ScrollBoxConstants.RetainScrollPosition)
end

classFrame:SetScript("OnShow", function()
    if TrainerSpells_SyncPetSpells then TrainerSpells_SyncPetSpells() end
    TrainerSpells_Refresh()
end)

classFrame:RegisterEvent("PLAYER_LEVEL_UP")
classFrame:RegisterEvent("SPELLS_CHANGED")
classFrame:HookScript("OnEvent", function(self, event) if event == "PLAYER_LEVEL_UP" or event == "SPELLS_CHANGED" then TrainerSpells_Refresh() end end)

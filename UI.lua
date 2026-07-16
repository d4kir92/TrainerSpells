local _, TrainerSpells = ...
local classFrame = CreateFrame("Frame", "TrainerSpellsFrame", UIParent)
classFrame:SetSize(420, 480)
classFrame:SetPoint("CENTER")
classFrame:SetFrameStrata("HIGH")
classFrame:SetFrameLevel(500)
classFrame:Hide()
local ROW_SPACING = 0.5
local HEADER_EXTRA_GAP = 12
local MIN_ROW_HEIGHT, MAX_ROW_HEIGHT = 10, 32
local MAX_ICON_SIZE = 32
local HEADER_HEIGHT = 16
local ROW_HEIGHT = (TrainerSpells_Character and TrainerSpells_Character.rowHeight) or 16
ROW_HEIGHT = math.max(MIN_ROW_HEIGHT, math.min(MAX_ROW_HEIGHT, ROW_HEIGHT))
local AVAILABLE_COLOR = "|cff30d030"
local SOON_COLOR = "|cff4db8ff"
local NOTYET_COLOR = "|cffff4444"
local TALENT_COLOR = "|cffff9933"
local KNOWN_COLOR = "|cff888888"
local IGNORED_COLOR = "|cff666666"
local PET_HEADER_COLOR = "|cffcc66ff"
local SPELL_NAME_COLOR = "|cffffffff"
local DIM_NAME_COLOR = "|cff999999"
local RANK_COLOR = "|cffaaaaaa"
local COLLAPSE_EXPANDED_ICON = "|cffffffff-|r "
local COLLAPSE_COLLAPSED_ICON = "|cffffffff+|r "
local PET_GROUPS = {
    {
        label = TrainerSpells:GetPetNameById(688),
        keys = {"Imp"}
    },
    {
        label = TrainerSpells:GetPetNameById(697),
        keys = {"Voidwalker"}
    },
    {
        label = TrainerSpells:GetPetNameById(712),
        keys = {"Succubus", "Incubus"}
    },
    {
        label = TrainerSpells:GetPetNameById(691),
        keys = {"Felhunter"}
    },
    {
        label = TrainerSpells:GetPetNameById(30146),
        keys = {"Felguard"}
    },
}

local function DragonfligthUIEnabled()
    return TrainerSpells:IsAddonLoaded("DragonflightUI")
end

local function IsGroupCollapsed(groupKey)
    return groupKey and TrainerSpells_Character and TrainerSpells_Character.collapsedGroups[groupKey] or false
end

local function ToggleGroup(groupKey)
    if not groupKey or not TrainerSpells_Character then return end
    TrainerSpells_Character.collapsedGroups[groupKey] = not TrainerSpells_Character.collapsedGroups[groupKey] or nil
end

local function GetLevelDiffColorCode(level)
    if GetQuestDifficultyColor then
        local r, g, b = GetQuestDifficultyColor(level)
        if type(r) == "table" then
            r, g, b = r.r, r.g, r.b
        end

        if r then return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255) end
    end

    return RANK_COLOR
end

local function GetTalentNameSet()
    local names, learned = {}, {}
    if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
        for tab = 1, GetNumTalentTabs() do
            for i = 1, GetNumTalents(tab) do
                local talentName, _, _, _, rank = GetTalentInfo(tab, i)
                if talentName then
                    names[talentName] = true
                    if (rank or 0) > 0 then
                        learned[talentName] = true
                    end
                end
            end
        end
    end

    return names, learned
end

local function GetPlayerFaction()
    return UnitFactionGroup and UnitFactionGroup("player")
end

local function IsReqSpellKnown(spellID)
    if not IsSpellKnown or type(spellID) ~= "number" then return false end
    local ok, known = pcall(IsSpellKnown, spellID)

    return ok and known or false
end

local function RequiresUnknownTalent(entry, talentNames, learnedTalents)
    if not entry.requires then return false end
    for _, reqSpellID in ipairs(entry.requires) do
        local reqName = GetSpellInfo(reqSpellID)
        if reqName and talentNames[reqName] and not learnedTalents[reqName] and not IsReqSpellKnown(reqSpellID) then return true end
    end

    return false
end

local function FormatCost(copper)
    if not copper or copper == 0 then return "kostenlos" end

    return GetMoneyString(copper, true)
end

local function GetLocalizedRankText(spellID)
    local subtext = GetSpellSubtext and spellID and GetSpellSubtext(spellID)

    return (subtext and subtext ~= "") and subtext or nil
end

local function EntryMatchesSearch(entry, search)
    if not search or search == "" then return true end
    if entry.name and entry.name:lower():find(search, 1, true) then return true end
    if entry.level and tostring(entry.level):find(search, 1, true) then return true end
    if entry.levelReq and tostring(entry.levelReq):find(search, 1, true) then return true end

    return false
end

local function SortEntries(list)
    table.sort(
        list,
        function(a, b)
            if a.level ~= b.level then return a.level < b.level end

            return a.key < b.key
        end
    )
end

local ignoreMenuFrame = CreateFrame("Frame", "TrainerSpellsIgnoreMenu", UIParent, "UIDropDownMenuTemplate")
local ignoreMenuEntry
local function IgnoreMenu_Initialize(self, level)
    local entry = ignoreMenuEntry
    if not entry then return end
    local spellIgnored = TrainerSpells_IsSpellIgnored and TrainerSpells_IsSpellIgnored(entry.spellID)
    local nameIgnored = TrainerSpells_IsNameIgnored and TrainerSpells_IsNameIgnored(entry.name)
    local rankSubtext = GetLocalizedRankText(entry.spellID)
    local rankText = rankSubtext and (" " .. rankSubtext) or ""
    local info = UIDropDownMenu_CreateInfo()
    info.text = entry.name .. rankText
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
    info = UIDropDownMenu_CreateInfo()
    info.text = spellIgnored and TrainerSpells:Trans("LID_STOPIGNORINGTHISRANK") or TrainerSpells:Trans("LID_IGNORINGTHISRANK")
    info.notCheckable = true
    info.func = function()
        TrainerSpells_ToggleIgnoreSpell(entry.spellID)
        TrainerSpells_Refresh()
    end

    UIDropDownMenu_AddButton(info, level)
    info = UIDropDownMenu_CreateInfo()
    info.text = nameIgnored and TrainerSpells:Trans("LID_STOPIGNOREINGALLRANKS") or TrainerSpells:Trans("LID_IGNOREALLRANKS")
    info.notCheckable = true
    info.func = function()
        TrainerSpells_ToggleIgnoreName(entry.name)
        TrainerSpells_Refresh()
    end

    UIDropDownMenu_AddButton(info, level)
    info = UIDropDownMenu_CreateInfo()
    info.text = TrainerSpells:Trans("LID_CANCEL")
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
end

UIDropDownMenu_Initialize(ignoreMenuFrame, IgnoreMenu_Initialize, "MENU")
local function ShowIgnoreMenu(anchor, entry)
    ignoreMenuEntry = entry
    ToggleDropDownMenu(1, nil, ignoreMenuFrame, "cursor", 0, 0)
    if DropDownList1 then
        DropDownList1:SetFrameStrata("TOOLTIP")
        DropDownList1:SetFrameLevel(600)
    end
end

local searchBox = CreateFrame("EditBox", "TrainerSpellsSearchBox", classFrame, "SearchBoxTemplate")
searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", -60, -6)
searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -10, -6)
searchBox:SetHeight(20)
searchBox:SetAutoFocus(false)
searchBox:SetScript(
    "OnTextChanged",
    function(self)
        if SearchBoxTemplate_OnTextChanged then
            SearchBoxTemplate_OnTextChanged(self)
        end

        TrainerSpells_SearchText = self:GetText() or ""
        TrainerSpells_Refresh()
    end
)

local rowHeightSlider = CreateFrame("Slider", "TrainerSpellsRowHeightSlider", classFrame, "MinimalSliderWithSteppersTemplate")
rowHeightSlider:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -8, -4)
rowHeightSlider:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", -24, -14)
rowHeightSlider:SetScale(0.75)
rowHeightSlider:SetHeight(10)
rowHeightSlider:Init(
    ROW_HEIGHT,
    MIN_ROW_HEIGHT,
    MAX_ROW_HEIGHT,
    MAX_ROW_HEIGHT - MIN_ROW_HEIGHT,
    {
        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return WHITE_FONT_COLOR:WrapTextInColorCode(tostring(math.floor(value + 0.5))) end)
    }
)

if rowHeightSlider.MinText then
    rowHeightSlider.MinText:Hide()
end

if rowHeightSlider.MaxText then
    rowHeightSlider.MaxText:Hide()
end

local scrollBox = CreateFrame("Frame", "TrainerSpellsScrollBox", classFrame, "WowScrollBoxList")
scrollBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 6, -4)
scrollBox:SetPoint("BOTTOMRIGHT", classFrame, "BOTTOMRIGHT", -24, 13)
local listBg = classFrame:CreateTexture(nil, "BACKGROUND")
local scrollBar = CreateFrame("EventFrame", "TrainerSpellsScrollBar", classFrame, "MinimalScrollBar")
scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, -2)
scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 2)
local function InitScrollRow(rowFrame, elementData)
    if not rowFrame.icon then
        local icon = rowFrame:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", rowFrame, "LEFT", 4, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        rowFrame.icon = icon
        local nameFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFS:SetJustifyH("LEFT")
        nameFS:SetWordWrap(false)
        rowFrame.nameFS = nameFS
        local levelFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        levelFS:SetPoint("RIGHT", rowFrame, "RIGHT", -4, 0)
        levelFS:SetJustifyH("RIGHT")
        rowFrame.levelFS = levelFS
    end

    local icon, nameFS, levelFS = rowFrame.icon, rowFrame.nameFS, rowFrame.levelFS
    local iconSize = math.max(8, math.min(MAX_ICON_SIZE, (rowFrame:GetHeight() or ROW_HEIGHT) - 4))
    icon:SetSize(iconSize, iconSize)
    rowFrame:EnableMouse(false)
    rowFrame:SetScript("OnEnter", nil)
    rowFrame:SetScript("OnLeave", nil)
    rowFrame:SetScript("OnMouseUp", nil)
    icon:Show()
    icon:SetTexture(nil)
    nameFS:ClearAllPoints()
    nameFS:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    nameFS:SetPoint("RIGHT", levelFS, "LEFT", -4, 0)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetText("")
    levelFS:SetText("")
    if elementData.isHeader then
        icon:Hide()
        nameFS:ClearAllPoints()
        nameFS:SetPoint("BOTTOMLEFT", rowFrame, "BOTTOMLEFT", 4, 5)
        nameFS:SetPoint("BOTTOMRIGHT", rowFrame, "BOTTOMRIGHT", -4, 5)
        nameFS:SetJustifyH("CENTER")
        local collapseIcon = elementData.groupKey and (elementData.collapsed and COLLAPSE_COLLAPSED_ICON or COLLAPSE_EXPANDED_ICON) or ""
        local prefix = elementData.prefixText and (PET_HEADER_COLOR .. "[" .. elementData.prefixText .. "] |r") or ""
        nameFS:SetText(collapseIcon .. prefix .. elementData.color .. elementData.text .. "|r")
        if elementData.totalCost or elementData.groupKey then
            rowFrame:EnableMouse(true)
            rowFrame:SetScript(
                "OnEnter",
                function(sel)
                    if not elementData.totalCost then return end
                    GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(elementData.text)
                    local canAfford = elementData.totalCost == 0 or (GetMoney() or 0) >= elementData.totalCost
                    local costColor = canAfford and "|cffffffff" or "|cffff3333"
                    GameTooltip:AddLine(TrainerSpells:Trans("LID_TOTALCOST") .. ": " .. costColor .. FormatCost(elementData.totalCost) .. "|r", 1, 1, 1)
                    GameTooltip:AddLine(TrainerSpells:Trans("LID_OWNGOLD") .. ": " .. GetMoneyString(GetMoney() or 0, true), 1, 1, 1)
                    GameTooltip:Show()
                end
            )

            rowFrame:SetScript("OnLeave", GameTooltip_Hide)
            rowFrame:SetScript(
                "OnMouseUp",
                function(self, button)
                    if button == "LeftButton" and elementData.groupKey then
                        ToggleGroup(elementData.groupKey)
                        -- This row initializer is shared by the spellbook list and the
                        -- profession panel, so refresh whichever one(s) exist.
                        if TrainerSpells_Refresh then
                            TrainerSpells_Refresh()
                        end

                        if TrainerSpells_ProfessionRefresh then
                            TrainerSpells_ProfessionRefresh()
                        end
                    end
                end
            )
        end
    else
        local entry = elementData.entry
        icon:SetTexture(entry.icon)
        local rankSubtext = GetLocalizedRankText(entry.spellID)
        local rankText = rankSubtext and (" " .. RANK_COLOR .. "(" .. rankSubtext .. ")|r") or ""
        local nameColor = elementData.dimName and DIM_NAME_COLOR or SPELL_NAME_COLOR
        nameFS:SetText(nameColor .. entry.name .. "|r" .. rankText)
        if elementData.showLevel then
            if elementData.levelLabel then
                local levelPrefix = entry.levelReq and (TrainerSpells:Trans("LID_LVL") .. " " .. entry.levelReq .. " ") or ""
                levelFS:SetText(RANK_COLOR .. levelPrefix .. elementData.levelLabel .. " " .. entry.level .. "|r")
            else
                levelFS:SetText(GetLevelDiffColorCode(entry.level) .. "Level " .. entry.level .. "|r")
            end
        end

        rowFrame:EnableMouse(true)
        rowFrame:SetScript(
            "OnEnter",
            function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if entry.spellID then
                    GameTooltip:SetSpellByID(entry.spellID)
                else
                    GameTooltip:SetText(entry.name)
                end

                if elementData.showCostTooltip then
                    local canAfford = not entry.cost or entry.cost == 0 or (GetMoney() or 0) >= entry.cost
                    local costColor = canAfford and "|cffffffff" or "|cffff3333"
                    GameTooltip:AddLine(TrainerSpells:Trans("LID_COSTS") .. ": " .. costColor .. FormatCost(entry.cost) .. "|r", 1, 1, 1)
                    GameTooltip:AddLine(TrainerSpells:Trans("LID_OWNGOLD") .. ": " .. GetMoneyString(GetMoney() or 0, true), 1, 1, 1)
                end

                GameTooltip:Show()
            end
        )

        rowFrame:SetScript("OnLeave", GameTooltip_Hide)
        rowFrame:SetScript(
            "OnMouseUp",
            function(self, button)
                if button == "RightButton" then
                    ShowIgnoreMenu(self, entry)
                end
            end
        )
    end
end

local scrollView = CreateScrollBoxListLinearView()
scrollView:SetElementExtentCalculator(
    function(index, elementData)
        if elementData.isHeader then return index > 1 and (HEADER_HEIGHT + HEADER_EXTRA_GAP) or HEADER_HEIGHT end

        return ROW_HEIGHT
    end
)

scrollView:SetPadding(0, 0, 0, 0, ROW_SPACING)
scrollView:SetElementInitializer("Frame", InitScrollRow)
ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, scrollView)
rowHeightSlider:RegisterCallback(
    MinimalSliderWithSteppersMixin.Event.OnValueChanged,
    function(_, value)
        value = math.floor(value + 0.5)
        if value == ROW_HEIGHT then return end
        ROW_HEIGHT = value
        if TrainerSpells_Character then
            TrainerSpells_Character.rowHeight = ROW_HEIGHT
        end

        if TrainerSpells_Refresh then
            TrainerSpells_Refresh()
        end
    end
)

local function AddHeaderItem(items, text, colorCode, totalCost, groupKey, prefixText)
    table.insert(
        items,
        {
            isHeader = true,
            text = text,
            color = colorCode,
            totalCost = totalCost,
            groupKey = groupKey,
            collapsed = IsGroupCollapsed(groupKey),
            prefixText = prefixText
        }
    )
end

local function AddEntryItems(items, list, colorCode, showLevel, showCostTooltip, dimName, levelLabel)
    for _, entry in ipairs(list) do
        table.insert(
            items,
            {
                isHeader = false,
                entry = entry,
                color = colorCode,
                showLevel = showLevel,
                showCostTooltip = showCostTooltip,
                dimName = dimName,
                levelLabel = levelLabel,
            }
        )
    end
end

local function SumCost(list)
    local total = 0
    for _, entry in ipairs(list) do
        total = total + (entry.cost or 0)
    end

    return total
end

local function BuildEntriesFromData(dataTable)
    local allEntries = {}
    local knownMaxRank = {}
    local playerFaction = GetPlayerFaction()
    for lvl, spells in pairs(dataTable) do
        for key, data in pairs(spells) do
            local cost, rank, status, requires, faction, spellID, icon, levelReq
            if type(data) == "table" then
                cost, rank, status, requires, faction = data.cost, data.rank, data.status, data.requires, data.faction
                spellID, icon, levelReq = data.spellID, data.icon, data.levelReq
            else
                cost = data
            end

            if not faction or not playerFaction or faction == playerFaction then
                local name
                if type(key) == "number" then
                    spellID = spellID or key
                    name, _, icon = GetSpellInfo(key)
                else
                    name = key
                end

                name = name or ("SpellID " .. tostring(key))
                icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
                local hasRealRank = (type(rank) == "number") or (type(rank) == "string" and rank:match("%d+") ~= nil)
                local rankNum = (type(rank) == "number" and rank) or (type(rank) == "string" and tonumber(rank:match("%d+"))) or 1
                local isLearnedPetSpell = spellID and TrainerSpells:IsPetSpellKnown(spellID)
                local directlyKnown = (spellID and IsSpellKnown and IsSpellKnown(spellID)) or isLearnedPetSpell or status == "used"
                local entry = {
                    level = lvl,
                    key = key,
                    spellID = spellID,
                    cost = cost,
                    name = name,
                    icon = icon,
                    rankNum = rankNum,
                    hasRealRank = hasRealRank,
                    directlyKnown = directlyKnown,
                    requires = requires,
                    levelReq = levelReq,
                }

                table.insert(allEntries, entry)
                if directlyKnown and hasRealRank then
                    knownMaxRank[name] = math.max(knownMaxRank[name] or 0, rankNum)
                end
            end
        end
    end

    return allEntries, knownMaxRank
end

local function ClassifyEntries(dataTable, searchText, selectedLevel, skipTalentCheck)
    local allEntries, knownMaxRank = BuildEntriesFromData(dataTable)
    local talentNames, learnedTalents
    if not skipTalentCheck then
        talentNames, learnedTalents = GetTalentNameSet()
    end

    local ignored, known, remaining = {}, {}, {}
    for _, entry in ipairs(allEntries) do
        if EntryMatchesSearch(entry, searchText) then
            if TrainerSpells_IsIgnored and TrainerSpells_IsIgnored(entry.spellID, entry.name) then
                table.insert(ignored, entry)
            else
                local maxKnown = knownMaxRank[entry.name] or 0
                local isKnown = entry.directlyKnown or (entry.hasRealRank and entry.rankNum <= maxKnown)
                if isKnown then
                    table.insert(known, entry)
                else
                    table.insert(remaining, entry)
                end
            end
        end
    end

    local available, missingTalents, future = {}, {}, {}
    for _, entry in ipairs(remaining) do
        local looksTalentGated = talentNames and ((talentNames[entry.name] and not learnedTalents[entry.name]) or RequiresUnknownTalent(entry, talentNames, learnedTalents))
        if looksTalentGated then
            table.insert(missingTalents, entry)
        elseif entry.level > selectedLevel then
            table.insert(future, entry)
        else
            table.insert(available, entry)
        end
    end

    local nextLevel
    for _, entry in ipairs(future) do
        if not nextLevel or entry.level < nextLevel then
            nextLevel = entry.level
        end
    end

    local soon, higher = {}, {}
    for _, entry in ipairs(future) do
        if entry.level == nextLevel then
            table.insert(soon, entry)
        else
            table.insert(higher, entry)
        end
    end

    SortEntries(available)
    SortEntries(missingTalents)
    SortEntries(ignored)
    SortEntries(soon)
    SortEntries(higher)
    SortEntries(known)

    return {
        available = available,
        soon = soon,
        higher = higher,
        missingTalents = missingTalents,
        ignored = ignored,
        known = known,
        nextLevel = nextLevel,
    }
end

local function AppendGroupItems(items, groups, keyPrefix, labelPrefix, unitLabel)
    local entryLevelLabel = unitLabel and unitLabel ~= TrainerSpells:Trans("LID_LVL") and unitLabel or nil
    unitLabel = unitLabel or TrainerSpells:Trans("LID_LVL")
    if #groups.available > 0 then
        AddHeaderItem(items, TrainerSpells:Trans("LID_AVAILABLENOW"), AVAILABLE_COLOR, SumCost(groups.available), keyPrefix .. "available", labelPrefix)
        if not IsGroupCollapsed(keyPrefix .. "available") then
            AddEntryItems(items, groups.available, AVAILABLE_COLOR, true, true, false, entryLevelLabel)
        end
    end

    if #groups.soon > 0 then
        AddHeaderItem(items, ("%s (%s %d)"):format(TrainerSpells:Trans("LID_COMINGSOON"), unitLabel, groups.nextLevel), SOON_COLOR, SumCost(groups.soon), keyPrefix .. "soon", labelPrefix)
        if not IsGroupCollapsed(keyPrefix .. "soon") then
            AddEntryItems(items, groups.soon, SOON_COLOR, true, true, false, entryLevelLabel)
        end
    end

    if #groups.higher > 0 then
        AddHeaderItem(items, TrainerSpells:Trans("LID_NOTYETAVAILABLE"), NOTYET_COLOR, SumCost(groups.higher), keyPrefix .. "higher", labelPrefix)
        if not IsGroupCollapsed(keyPrefix .. "higher") then
            AddEntryItems(items, groups.higher, NOTYET_COLOR, true, true, false, entryLevelLabel)
        end
    end

    if #groups.missingTalents > 0 then
        AddHeaderItem(items, TrainerSpells:Trans("LID_MISSINGREQUIREDTALENTS"), TALENT_COLOR, SumCost(groups.missingTalents), keyPrefix .. "missingTalents", labelPrefix)
        if not IsGroupCollapsed(keyPrefix .. "missingTalents") then
            AddEntryItems(items, groups.missingTalents, TALENT_COLOR, true, true, false, entryLevelLabel)
        end
    end

    if #groups.ignored > 0 then
        AddHeaderItem(items, TrainerSpells:Trans("LID_IGNORED"), IGNORED_COLOR, nil, keyPrefix .. "ignored", labelPrefix)
        if not IsGroupCollapsed(keyPrefix .. "ignored") then
            AddEntryItems(items, groups.ignored, IGNORED_COLOR, true, true, true, entryLevelLabel)
        end
    end

    if #groups.known > 0 then
        AddHeaderItem(items, TrainerSpells:Trans("LID_ALREADYKNOWN"), KNOWN_COLOR, SumCost(groups.known), keyPrefix .. "known", labelPrefix)
        if not IsGroupCollapsed(keyPrefix .. "known") then
            AddEntryItems(items, groups.known, KNOWN_COLOR, true, true, true, entryLevelLabel)
        end
    end
end

local function MergePetData(keys)
    local merged = {}
    for _, key in ipairs(keys) do
        local data = TrainerSpells_PetData and TrainerSpells_PetData[key]
        if data then
            for lvl, spells in pairs(data) do
                merged[lvl] = merged[lvl] or {}
                for spellID, entryData in pairs(spells) do
                    merged[lvl][spellID] = entryData
                end
            end
        end
    end

    return merged
end

local function AppendPetAbilities(items, searchText, selectedLevel)
    local petItems = {}
    for _, petGroup in ipairs(PET_GROUPS) do
        local merged = MergePetData(petGroup.keys)
        if next(merged) then
            local groupKey = "pet_" .. table.concat(petGroup.keys, "_")
            local groups = ClassifyEntries(merged, searchText, selectedLevel, true)
            local subItems = {}
            AppendGroupItems(subItems, groups, groupKey .. "_", petGroup.label)
            if #subItems > 0 then
                AddHeaderItem(petItems, petGroup.label, PET_HEADER_COLOR, nil, groupKey)
                if not IsGroupCollapsed(groupKey) then
                    for _, item in ipairs(subItems) do
                        table.insert(petItems, item)
                    end
                end
            end
        end
    end

    if #petItems > 0 then
        AddHeaderItem(items, TrainerSpells:Trans("LID_PETTRAINING"), PET_HEADER_COLOR, nil, "petAbilities")
        if not IsGroupCollapsed("petAbilities") then
            for _, item in ipairs(petItems) do
                table.insert(items, item)
            end
        end
    end
end

local function AppendPetTrainerAbilities(items, searchText, selectedLevel, classToken)
    local petTrainerData = TrainerSpells_PetTrainerData and TrainerSpells_PetTrainerData[classToken]
    if not petTrainerData or not next(petTrainerData) then return end
    local groups = ClassifyEntries(petTrainerData, searchText, selectedLevel, true)
    local subItems = {}
    AppendGroupItems(subItems, groups, "pettrainer_")
    if #subItems == 0 then return end
    AddHeaderItem(items, TrainerSpells:Trans("LID_PETTRAINING"), PET_HEADER_COLOR, nil, "petTraining")
    if not IsGroupCollapsed("petTraining") then
        for _, item in ipairs(subItems) do
            table.insert(items, item)
        end
    end
end

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
professionSearchBox:SetScript(
    "OnTextChanged",
    function(self)
        if SearchBoxTemplate_OnTextChanged then
            SearchBoxTemplate_OnTextChanged(self)
        end

        TrainerSpells_ProfessionSearchText = self:GetText() or ""
        TrainerSpells_ProfessionRefresh()
    end
)

local PROFESSION_ROW_HEIGHT = (TrainerSpells_Character and TrainerSpells_Character.professionRowHeight) or 16
PROFESSION_ROW_HEIGHT = math.max(MIN_ROW_HEIGHT, math.min(MAX_ROW_HEIGHT, PROFESSION_ROW_HEIGHT))
local professionRowHeightSlider = CreateFrame("Slider", "TrainerSpellsProfessionRowHeightSlider", professionFrame, "MinimalSliderWithSteppersTemplate")
professionRowHeightSlider:SetPoint("TOPLEFT", professionSearchBox, "BOTTOMLEFT", -8, -4)
professionRowHeightSlider:SetPoint("TOPRIGHT", professionSearchBox, "BOTTOMRIGHT", -24, -14)
professionRowHeightSlider:SetScale(0.75)
professionRowHeightSlider:SetHeight(10)
professionRowHeightSlider:Init(
    PROFESSION_ROW_HEIGHT,
    MIN_ROW_HEIGHT,
    MAX_ROW_HEIGHT,
    MAX_ROW_HEIGHT - MIN_ROW_HEIGHT,
    {
        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return WHITE_FONT_COLOR:WrapTextInColorCode(tostring(math.floor(value + 0.5))) end)
    }
)

if professionRowHeightSlider.MinText then
    professionRowHeightSlider.MinText:Hide()
end

if professionRowHeightSlider.MaxText then
    professionRowHeightSlider.MaxText:Hide()
end

local professionScrollBox = CreateFrame("Frame", "TrainerSpellsProfessionScrollBox", professionFrame, "WowScrollBoxList")
professionScrollBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 8, -58)
professionScrollBox:SetPoint("BOTTOMRIGHT", professionFrame, "BOTTOMRIGHT", -26, 11)
local professionListBg = professionFrame:CreateTexture(nil, "BACKGROUND")
local professionScrollBar = CreateFrame("EventFrame", "TrainerSpellsProfessionScrollBar", professionFrame, "MinimalScrollBar")
professionScrollBar:SetPoint("TOPLEFT", professionScrollBox, "TOPRIGHT", 4, -2)
professionScrollBar:SetPoint("BOTTOMLEFT", professionScrollBox, "BOTTOMRIGHT", 4, 2)
local professionScrollView = CreateScrollBoxListLinearView()
professionScrollView:SetElementExtentCalculator(
    function(index, elementData)
        if elementData.isHeader then return index > 1 and (HEADER_HEIGHT + HEADER_EXTRA_GAP) or HEADER_HEIGHT end

        return PROFESSION_ROW_HEIGHT
    end
)

professionScrollView:SetPadding(0, 0, 0, 0, ROW_SPACING)
professionScrollView:SetElementInitializer("Frame", InitScrollRow)
ScrollUtil.InitScrollBoxListWithScrollBar(professionScrollBox, professionScrollBar, professionScrollView)
professionRowHeightSlider:RegisterCallback(
    MinimalSliderWithSteppersMixin.Event.OnValueChanged,
    function(_, value)
        value = math.floor(value + 0.5)
        if value == PROFESSION_ROW_HEIGHT then return end
        PROFESSION_ROW_HEIGHT = value
        if TrainerSpells_Character then
            TrainerSpells_Character.professionRowHeight = PROFESSION_ROW_HEIGHT
        end

        TrainerSpells_ProfessionRefresh()
    end
)

local function GetOpenProfession()
    if not GetTradeSkillLine then return nil, nil end
    local skillLineName = GetTradeSkillLine()
    if not skillLineName or skillLineName == "" then return nil, nil end

    return TrainerSpells:GetProfessionKey(skillLineName), skillLineName
end

function TrainerSpells_ProfessionRefresh()
    local searchText = (TrainerSpells_ProfessionSearchText or ""):lower()
    local professionKey, skillLineName = GetOpenProfession()
    local items = {}
    local data = professionKey and TrainerSpells_ProfessionData and TrainerSpells_ProfessionData[professionKey]
    if data and next(data) then
        local currentSkill = GetCurrentProfessionSkill(skillLineName)
        local groups = ClassifyEntries(data, searchText, currentSkill, true)
        AppendGroupItems(items, groups, "tradeskillprofession_", nil, TrainerSpells:Trans("LID_SKILL"))
    end

    if #items == 0 then
        AddHeaderItem(items, skillLineName and ("Keine Daten für " .. skillLineName .. " gesammelt.") or "Kein Beruf erkannt.", "|cffaaaaaa")
    end

    professionScrollBox:SetDataProvider(CreateDataProvider(items))
end

local function PositionProfessionFrame()
    professionFrame:ClearAllPoints()
    if TradeSkillFrame and TradeSkillFrame:IsShown() then
        professionFrame:SetScale(TradeSkillFrame:GetScale())
        if DragonfligthUIEnabled() then
            professionFrame:SetPoint("TOPLEFT", TradeSkillFrame, "TOPLEFT", 4, -50)
            professionFrame:SetPoint("BOTTOMRIGHT", TradeSkillFrame, "BOTTOMRIGHT", -4, 4)
        else
            professionFrame:SetPoint("TOPLEFT", TradeSkillFrame, "TOPLEFT", 14, -70)
            professionFrame:SetPoint("BOTTOMRIGHT", TradeSkillFrame, "BOTTOMRIGHT", -36, 70)
        end
    else
        professionFrame:SetScale(1)
        professionFrame:SetPoint("CENTER")
    end

    professionSearchBox:ClearAllPoints()
    local titleText = TradeSkillFrame and _G["TradeSkillFrameTitleText"]
    if titleText and professionFrame:GetTop() and titleText:GetBottom() then
        local topOffset = titleText:GetBottom() - professionFrame:GetTop() - 4
        professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 66, topOffset)
        professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -4, topOffset)
    else
        professionSearchBox:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 10, -6)
        professionSearchBox:SetPoint("TOPRIGHT", professionFrame, "TOPRIGHT", -30, -6)
    end
end

if TradeSkillFrame then
    hooksecurefunc(
        TradeSkillFrame,
        "SetScale",
        function()
            if classFrame:IsShown() then
                PositionProfessionFrame()
            end
        end
    )
end

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

local nativeTab, nativeTabGlow = CreateTradeSkillTab("TrainerSpellsTradeSkillNativeTab", "Interface\\Icons\\INV_Hammer_01")
local professionTab, professionTabGlow = CreateTradeSkillTab("TrainerSpellsTradeSkillProfessionTab", "Interface\\Icons\\INV_Misc_Book_09")
local function PositionTradeSkillTabs()
    if not TradeSkillFrame then return end
    local scale = TradeSkillFrame:GetScale()
    nativeTab:SetScale(scale)
    professionTab:SetScale(scale)
    nativeTab:ClearAllPoints()
    nativeTab:SetPoint("TOPLEFT", TradeSkillFrame, "TOPRIGHT", -33, -60)
    professionTab:ClearAllPoints()
    professionTab:SetPoint("TOPLEFT", nativeTab, "BOTTOMLEFT", 0, -36)
end

local function SetTradeSkillView(showOurs)
    if showOurs then
        if DragonfligthUIEnabled() then
            professionListBg:SetPoint("CENTER", professionFrame, "CENTER", 0, 0)
            if DragonflightUISpellBookInsetBg then
                local shortHeight = 30
                professionListBg:ClearAllPoints()
                professionListBg:SetPoint("TOPLEFT", DragonflightUISpellBookInsetBg, "TOPLEFT", 0, -shortHeight)
                professionListBg:SetPoint("BOTTOMRIGHT", DragonflightUISpellBookInsetBg, "BOTTOMRIGHT", 0, 0)
                professionListBg:SetTexture(DragonflightUISpellBookInsetBg:GetTexture())
                local fullHeight = DragonflightUISpellBookInsetBg:GetHeight()
                local cropTop = shortHeight / fullHeight
                professionListBg:SetTexCoord(0, 1, cropTop, 1)
                professionListBg:SetVertexColor(0, 0, 0)
            end
        else
            professionListBg:SetPoint("TOPLEFT", professionFrame, "TOPLEFT", 4, -2)
            professionListBg:SetTexture("Interface\\AddOns\\TrainerSpells\\media\\inset")
        end

        PositionProfessionFrame()
        professionFrame:Show()
        professionTabGlow:Show()
        nativeTabGlow:Hide()
        TrainerSpells_ProfessionRefresh()
    else
        professionFrame:Hide()
        professionTabGlow:Hide()
        nativeTabGlow:Show()
    end
end

nativeTab:SetScript(
    "OnClick",
    function()
        SetTradeSkillView(false)
    end
)

nativeTab:SetScript(
    "OnEnter",
    function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText((GetTradeSkillLine and GetTradeSkillLine()) or TrainerSpells:Trans("LID_PROFESSIONS"))
        GameTooltip:Show()
    end
)

nativeTab:SetScript("OnLeave", GameTooltip_Hide)
professionTab:SetScript(
    "OnClick",
    function()
        SetTradeSkillView(true)
    end
)

professionTab:SetScript(
    "OnEnter",
    function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TrainerSpells:Trans("LID_PROFESSIONS"))
        GameTooltip:Show()
    end
)

professionTab:SetScript("OnLeave", GameTooltip_Hide)
local tradeSkillHooksInstalled = false
local function EnsureTradeSkillHooksInstalled()
    if tradeSkillHooksInstalled then return end
    if not TradeSkillFrame then return end
    tradeSkillHooksInstalled = true
    TradeSkillFrame:HookScript(
        "OnShow",
        function()
            PositionTradeSkillTabs()
            nativeTab:Show()
            professionTab:Show()
            SetTradeSkillView(false)
        end
    )

    TradeSkillFrame:HookScript(
        "OnHide",
        function()
            professionFrame:Hide()
            professionTabGlow:Hide()
            nativeTabGlow:Hide()
            nativeTab:Hide()
            professionTab:Hide()
        end
    )

    hooksecurefunc(
        TradeSkillFrame,
        "SetScale",
        function()
            PositionTradeSkillTabs()
            if professionFrame:IsShown() then
                PositionProfessionFrame()
            end
        end
    )

    if TradeSkillFrame:IsShown() then
        PositionTradeSkillTabs()
        nativeTab:Show()
        professionTab:Show()
        SetTradeSkillView(false)
    end
end

local tradeSkillWatcher = CreateFrame("Frame")
tradeSkillWatcher:RegisterEvent("TRADE_SKILL_SHOW")
tradeSkillWatcher:RegisterEvent("TRADE_SKILL_UPDATE")
tradeSkillWatcher:SetScript(
    "OnEvent",
    function(_, event)
        EnsureTradeSkillHooksInstalled()
        if event == "TRADE_SKILL_UPDATE" and professionFrame:IsShown() then
            TrainerSpells_ProfessionRefresh()
        end
    end
)

function TrainerSpells_Refresh()
    local searchText = (TrainerSpells_SearchText or ""):lower()
    local selectedLevel = UnitLevel("player") or 1
    local selectedClass = select(2, UnitClass("player"))
    local classData = selectedClass and TrainerSpells_Data and TrainerSpells_Data[selectedClass]
    local items = {}
    if classData then
        local groups = ClassifyEntries(classData, searchText, selectedLevel)
        AppendGroupItems(items, groups, "")
    end

    if selectedClass == "WARLOCK" then
        AppendPetAbilities(items, searchText, selectedLevel)
    end

    if selectedClass == "HUNTER" then
        AppendPetTrainerAbilities(items, searchText, selectedLevel, selectedClass)
    end

    if #items == 0 then
        if not classData then
            AddHeaderItem(items, "Keine Daten für " .. tostring(selectedClass) .. " gesammelt. Lehrer besuchen!", "|cffff5555")
        else
            AddHeaderItem(items, "Keine Einträge vorhanden.", "|cffaaaaaa")
        end
    end

    scrollBox:SetDataProvider(CreateDataProvider(items))
end

classFrame:SetScript(
    "OnShow",
    function()
        if TrainerSpells_SyncPetSpells then
            TrainerSpells_SyncPetSpells()
        end

        TrainerSpells_Refresh()
    end
)

classFrame:RegisterEvent("PLAYER_LEVEL_UP")
classFrame:RegisterEvent("SPELLS_CHANGED")
classFrame:HookScript(
    "OnEvent",
    function(self, event)
        if event == "PLAYER_LEVEL_UP" or event == "SPELLS_CHANGED" then
            TrainerSpells_Refresh()
        end
    end
)

local function PositionFrame()
    classFrame:ClearAllPoints()
    if SpellBookFrame and SpellBookFrame:IsShown() then
        classFrame:SetScale(SpellBookFrame:GetScale())
        if DragonfligthUIEnabled() then
            classFrame:SetPoint("TOPLEFT", SpellBookFrame, "TOPLEFT", 4, -50)
            classFrame:SetPoint("BOTTOMRIGHT", SpellBookFrame, "BOTTOMRIGHT", -4, 4)
        else
            classFrame:SetPoint("TOPLEFT", SpellBookFrame, "TOPLEFT", 14, -70)
            classFrame:SetPoint("BOTTOMRIGHT", SpellBookFrame, "BOTTOMRIGHT", -36, 70)
        end
    else
        classFrame:SetScale(1)
        classFrame:SetPoint("CENTER")
    end

    searchBox:ClearAllPoints()
    local titleText = SpellBookFrame and _G["SpellBookTitleText"]
    if titleText and classFrame:GetTop() and titleText:GetBottom() then
        local topOffset = titleText:GetBottom() - classFrame:GetTop() - 4
        searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 66, topOffset)
        searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -4, topOffset)
    else
        searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 10, -6)
        searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -30, -6)
    end
end

if SpellBookFrame then
    hooksecurefunc(
        SpellBookFrame,
        "SetScale",
        function()
            if classFrame:IsShown() then
                PositionFrame()
            end
        end
    )
end

local NATIVE_EXTRA_WIDGETS = {"SpellBookPageNavigationFrame", "SpellBookFrameShowAllSpellRanksCheckbox", "ShowAllSpellRanksCheckbox",}
local spellButtonsHidden = false
local hiddenPageRegions = {}
local function HideNativeSpellButtons()
    if spellButtonsHidden then return end
    spellButtonsHidden = true
    for _, name in ipairs(NATIVE_EXTRA_WIDGETS) do
        local widget = _G[name]
        if widget then
            widget:Hide()
        end
    end

    wipe(hiddenPageRegions)
    if SpellBookFrame then
        for _, region in ipairs({SpellBookFrame:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then
                local text = region:GetText()
                if text and text:find("^Page ") then
                    region:Hide()
                    table.insert(hiddenPageRegions, region)
                end
            end
        end
    end
end

local function ShowNativeSpellButtons()
    if not spellButtonsHidden then return end
    spellButtonsHidden = false
    for _, name in ipairs(NATIVE_EXTRA_WIDGETS) do
        local widget = _G[name]
        if widget then
            widget:Show()
        end
    end

    for _, region in ipairs(hiddenPageRegions) do
        region:Show()
    end

    wipe(hiddenPageRegions)
    if SpellBookFrame_Update then
        SpellBookFrame_Update()
    end
end

local ourTabGlow
local function GetTabGlow(tabFrame)
    if not tabFrame then return nil end
    for _, region in ipairs({tabFrame:GetRegions()}) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and region.GetDrawLayer and region:GetDrawLayer() == "OVERLAY" then return region end
    end
end

local function HideNativeSkillTabGlows()
    for i = 1, 8 do
        local glow = GetTabGlow(_G["SpellBookSkillLineTab" .. i])
        if glow then
            glow:Hide()
        end
    end
end

local function OpenFrame()
    if DragonfligthUIEnabled() then
        listBg:SetPoint("CENTER", classFrame, "CENTER", 0, 0)
        if DragonflightUISpellBookInsetBg then
            local shortHeight = 30
            listBg:ClearAllPoints()
            listBg:SetPoint("TOPLEFT", DragonflightUISpellBookInsetBg, "TOPLEFT", 0, -shortHeight)
            listBg:SetPoint("BOTTOMRIGHT", DragonflightUISpellBookInsetBg, "BOTTOMRIGHT", 0, 0)
            listBg:SetTexture(DragonflightUISpellBookInsetBg:GetTexture())
            local fullHeight = DragonflightUISpellBookInsetBg:GetHeight()
            local cropTop = shortHeight / fullHeight
            listBg:SetTexCoord(0, 1, cropTop, 1)
            listBg:SetVertexColor(0, 0, 0)
        end
    else
        listBg:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 4, -2)
        listBg:SetTexture("Interface\\AddOns\\TrainerSpells\\media\\inset")
    end

    PositionFrame()
    classFrame:Show()
    HideNativeSpellButtons()
    HideNativeSkillTabGlows()
    if ourTabGlow then
        ourTabGlow:Show()
    end
end

if SpellBookFrame then
    local tab = CreateFrame("Button", "TrainerSpellsSpellbookTab", SpellBookFrame)
    tab:SetSize(32, 32)
    tab:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09")
    tab:SetHighlightTexture(130718, "ADD")
    local border = tab:CreateTexture("TrainerSpellsSpellbookTabBorder", "BACKGROUND")
    border:SetSize(64, 64)
    border:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
    border:SetTexture(136831)
    ourTabGlow = tab:CreateTexture(nil, "OVERLAY")
    ourTabGlow:SetSize(32, 32)
    ourTabGlow:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    ourTabGlow:SetTexture(130724)
    ourTabGlow:SetBlendMode("ADD")
    ourTabGlow:Hide()
    local lastTab = _G["SpellBookSkillLineTab5"] or _G["SpellBookSkillLineTab4"] or _G["SpellBookSkillLineTab1"] or SpellBookFrame
    tab:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, -34)
    tab:Hide()
    tab:SetScript("OnClick", OpenFrame)
    tab:SetScript(
        "OnEnter",
        function(sel)
            GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
            GameTooltip:SetText(TrainerSpells:Trans("LID_CLASSTRAINER"))
            GameTooltip:Show()
        end
    )

    tab:SetScript("OnLeave", GameTooltip_Hide)
    SpellBookFrame:HookScript(
        "OnShow",
        function()
            tab:Show()
        end
    )

    SpellBookFrame:HookScript(
        "OnHide",
        function()
            tab:Hide()
            classFrame:Hide()
            ShowNativeSpellButtons()
            if ourTabGlow then
                ourTabGlow:Hide()
            end
        end
    )

    local function OnNativeTabClicked()
        if classFrame:IsShown() then
            classFrame:Hide()
            ShowNativeSpellButtons()
            if ourTabGlow then
                ourTabGlow:Hide()
            end
        end
    end

    for i = 1, 8 do
        local t = _G["SpellBookSkillLineTab" .. i]
        if t then
            t:HookScript("OnClick", OnNativeTabClicked)
        end
    end

    for i = 1, 3 do
        local t = _G["SpellBookFrameTabButton" .. i]
        if t then
            t:HookScript("OnClick", OnNativeTabClicked)
        end
    end

    C_Timer.After(
        4,
        function()
            for i = 1, 4 do
                local t = _G["DragonflightUISpellBookFrameTabButton" .. i]
                if t then
                    t:HookScript("OnClick", OnNativeTabClicked)
                end
            end
        end
    )
end

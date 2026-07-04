local frame = CreateFrame("Frame", "TrainerSpellsFrame", UIParent)
frame:SetSize(420, 480)
frame:SetPoint("CENTER")
frame:SetFrameStrata("HIGH")
frame:SetFrameLevel(500)
frame:Hide()
local ROW_HEIGHT = 22
local ICON_SIZE = 20
local AVAILABLE_COLOR = "|cff30d030"
local SOON_COLOR = "|cff4db8ff"
local NOTYET_COLOR = "|cffff4444"
local TALENT_COLOR = "|cffff9933"
local KNOWN_COLOR = "|cff888888"
local IGNORED_COLOR = "|cff666666"
local SPELL_NAME_COLOR = "|cffffffff"
local DIM_NAME_COLOR = "|cff999999"
local RANK_COLOR = "|cffaaaaaa"
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

local function IsBaseRankKnownByName(name)
    if not name or not GetSpellInfo then return false end
    local _, _, _, _, _, _, spellID = GetSpellInfo(name)

    return spellID and IsSpellKnown and IsSpellKnown(spellID) or false
end

local function FormatCost(copper)
    if not copper or copper == 0 then return "kostenlos" end

    return GetMoneyString(copper, true)
end

local function EntryMatchesSearch(entry, search)
    if not search or search == "" then return true end
    if entry.name and entry.name:lower():find(search, 1, true) then return true end
    if entry.level and tostring(entry.level):find(search, 1, true) then return true end

    return false
end

local function SortEntries(list)
    table.sort(
        list,
        function(a, b)
            if a.level ~= b.level then return a.level < b.level end

            return a.spellID < b.spellID
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
    local rankText = (entry.rank and entry.rank ~= "") and (" " .. entry.rank) or ""
    local info = UIDropDownMenu_CreateInfo()
    info.text = entry.name .. rankText
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
    info = UIDropDownMenu_CreateInfo()
    info.text = spellIgnored and "Diesen Rang nicht mehr ignorieren" or "Diesen Rang ignorieren"
    info.notCheckable = true
    info.func = function()
        TrainerSpells_ToggleIgnoreSpell(entry.spellID)
        TrainerSpells_Refresh()
    end

    UIDropDownMenu_AddButton(info, level)
    info = UIDropDownMenu_CreateInfo()
    info.text = nameIgnored and "Alle Ränge nicht mehr ignorieren" or "Alle Ränge ignorieren"
    info.notCheckable = true
    info.func = function()
        TrainerSpells_ToggleIgnoreName(entry.name)
        TrainerSpells_Refresh()
    end

    UIDropDownMenu_AddButton(info, level)
    info = UIDropDownMenu_CreateInfo()
    info.text = "Abbrechen"
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

local searchBox = CreateFrame("EditBox", "TrainerSpellsSearchBox", frame, "SearchBoxTemplate")
searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", -60, -6)
searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -6)
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

local scrollBox = CreateFrame("Frame", "TrainerSpellsScrollBox", frame, "WowScrollBoxList")
scrollBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -4)
scrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 4)
local listBg = frame:CreateTexture(nil, "BACKGROUND")
listBg:SetTexture("Interface\\AddOns\\TrainerSpells\\media\\inset")
listBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -2)
local scrollBar = CreateFrame("EventFrame", "TrainerSpellsScrollBar", frame, "MinimalScrollBar")
scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, -2)
scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 2)
local function InitScrollRow(rowFrame, elementData)
    if not rowFrame.icon then
        local icon = rowFrame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON_SIZE, ICON_SIZE)
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
        nameFS:SetPoint("LEFT", rowFrame, "LEFT", 4, 0)
        nameFS:SetPoint("RIGHT", rowFrame, "RIGHT", -4, 0)
        nameFS:SetJustifyH("CENTER")
        nameFS:SetText(elementData.color .. elementData.text .. "|r")
        if elementData.totalCost then
            rowFrame:EnableMouse(true)
            rowFrame:SetScript(
                "OnEnter",
                function(sel)
                    GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(elementData.text)
                    local canAfford = elementData.totalCost == 0 or (GetMoney() or 0) >= elementData.totalCost
                    local costColor = canAfford and "|cffffffff" or "|cffff3333"
                    GameTooltip:AddLine("Gesamtkosten: " .. costColor .. FormatCost(elementData.totalCost) .. "|r", 1, 1, 1)
                    GameTooltip:Show()
                end
            )

            rowFrame:SetScript("OnLeave", GameTooltip_Hide)
        end
    else
        local entry = elementData.entry
        icon:SetTexture(entry.icon)
        local rankText = (entry.rank and entry.rank ~= "") and (" " .. RANK_COLOR .. "(" .. entry.rank .. ")|r") or ""
        local nameColor = elementData.dimName and DIM_NAME_COLOR or SPELL_NAME_COLOR
        nameFS:SetText(nameColor .. entry.name .. "|r" .. rankText)
        if elementData.showLevel then
            levelFS:SetText(GetLevelDiffColorCode(entry.level) .. "Level " .. entry.level .. "|r")
        end

        rowFrame:EnableMouse(true)
        rowFrame:SetScript(
            "OnEnter",
            function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(entry.spellID)
                if elementData.showCostTooltip then
                    local canAfford = not entry.cost or entry.cost == 0 or (GetMoney() or 0) >= entry.cost
                    local costColor = canAfford and "|cffffffff" or "|cffff3333"
                    GameTooltip:AddLine("Kosten: " .. costColor .. FormatCost(entry.cost) .. "|r", 1, 1, 1)
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
scrollView:SetElementExtent(ROW_HEIGHT)
scrollView:SetElementInitializer("Frame", InitScrollRow)
ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, scrollView)
function TrainerSpells_Refresh()
    local searchText = (TrainerSpells_SearchText or ""):lower()
    local selectedLevel = UnitLevel("player") or 1
    local selectedClass = select(2, UnitClass("player"))
    local classData = selectedClass and TrainerSpells_Data and TrainerSpells_Data[selectedClass]
    if not classData then
        local items = {
            {
                isHeader = true,
                color = "|cffff5555",
                text = "Keine Daten für " .. tostring(selectedClass) .. " gesammelt. Lehrer besuchen!"
            },
        }

        scrollBox:SetDataProvider(CreateDataProvider(items))

        return
    end

    local allEntries = {}
    local knownMaxRank = {}
    local minRankByName = {}
    for lvl, spells in pairs(classData) do
        for spellID, data in pairs(spells) do
            local cost, rank, status
            if type(data) == "table" then
                cost, rank, status = data.cost, data.rank, data.status
            else
                cost = data
            end

            local name, _, icon = GetSpellInfo(spellID)
            name = name or ("SpellID " .. spellID)
            icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
            local rankNum = (rank and tonumber(rank:match("%d+"))) or 1
            local entry = {
                level = lvl,
                spellID = spellID,
                cost = cost,
                rank = rank,
                name = name,
                icon = icon,
                rankNum = rankNum,
                status = status,
            }

            table.insert(allEntries, entry)
            if IsSpellKnown and IsSpellKnown(spellID) then
                knownMaxRank[name] = math.max(knownMaxRank[name] or 0, rankNum)
            end

            minRankByName[name] = math.min(minRankByName[name] or rankNum, rankNum)
        end
    end

    local ignored, known, remaining = {}, {}, {}
    for _, entry in ipairs(allEntries) do
        if not EntryMatchesSearch(entry, searchText) then
        elseif TrainerSpells_IsIgnored and TrainerSpells_IsIgnored(entry.spellID, entry.name) then
            table.insert(ignored, entry)
        else
            local maxKnown = knownMaxRank[entry.name] or 0
            if entry.rankNum <= maxKnown then
                table.insert(known, entry)
            else
                table.insert(remaining, entry)
            end
        end
    end

    local available, missingTalents, future = {}, {}, {}
    for _, entry in ipairs(remaining) do
        local baseRank = minRankByName[entry.name]
        local looksTalentGated = baseRank > 1 and not IsBaseRankKnownByName(entry.name)
        if looksTalentGated then
            table.insert(missingTalents, entry)
        elseif entry.level > selectedLevel then
            table.insert(future, entry)
        elseif entry.status == "unavailable" then
            table.insert(missingTalents, entry)
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
    local items = {}
    local function AddHeader(text, colorCode, totalCost)
        table.insert(
            items,
            {
                isHeader = true,
                text = text,
                color = colorCode,
                totalCost = totalCost
            }
        )
    end

    local function AddEntries(list, colorCode, showLevel, showCostTooltip, dimName)
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

    if #available > 0 then
        AddHeader("Available Now", AVAILABLE_COLOR, SumCost(available))
        AddEntries(available, AVAILABLE_COLOR, true, true, false)
    end

    if #soon > 0 then
        AddHeader(("Coming Soon (Lvl %d)"):format(nextLevel), SOON_COLOR, SumCost(soon))
        AddEntries(soon, SOON_COLOR, true, true, false)
    end

    if #higher > 0 then
        AddHeader("Not Yet Available", NOTYET_COLOR, SumCost(higher))
        AddEntries(higher, NOTYET_COLOR, true, true, false)
    end

    if #missingTalents > 0 then
        AddHeader("Missing Required Talents", TALENT_COLOR, SumCost(missingTalents))
        AddEntries(missingTalents, TALENT_COLOR, true, true, false)
    end

    if #ignored > 0 then
        AddHeader("Ignored", IGNORED_COLOR)
        AddEntries(ignored, IGNORED_COLOR, true, true, true)
    end

    if #known > 0 then
        AddHeader("Already Known", KNOWN_COLOR, SumCost(known))
        AddEntries(known, KNOWN_COLOR, true, false, true)
    end

    if #items == 0 then
        AddHeader("Keine Einträge vorhanden.", "|cffaaaaaa")
    end

    scrollBox:SetDataProvider(CreateDataProvider(items))
end

frame:SetScript("OnShow", TrainerSpells_Refresh)
local function PositionFrame()
    frame:ClearAllPoints()
    if SpellBookFrame and SpellBookFrame:IsShown() then
        frame:SetScale(SpellBookFrame:GetScale())
        frame:SetPoint("TOPLEFT", SpellBookFrame, "TOPLEFT", 14, -70)
        frame:SetPoint("BOTTOMRIGHT", SpellBookFrame, "BOTTOMRIGHT", -36, 78)
    else
        frame:SetScale(1)
        frame:SetPoint("CENTER")
    end

    searchBox:ClearAllPoints()
    local titleText = SpellBookFrame and _G["SpellBookTitleText"]
    if titleText and frame:GetTop() and titleText:GetBottom() then
        local topOffset = titleText:GetBottom() - frame:GetTop() - 4
        searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 66, topOffset)
        searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, topOffset)
    else
        searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -6)
        searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -6)
    end
end

if SpellBookFrame then
    hooksecurefunc(
        SpellBookFrame,
        "SetScale",
        function()
            if frame:IsShown() then
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
    for i = 1, 6 do
        local glow = GetTabGlow(_G["SpellBookSkillLineTab" .. i])
        if glow then
            glow:Hide()
        end
    end
end

local function RestoreNativeSkillTabGlow()
    local idx = SpellBookFrame and SpellBookFrame.selectedSkillLine
    local glow = idx and GetTabGlow(_G["SpellBookSkillLineTab" .. idx])
    if glow then
        glow:Show()
    end
end

local function OpenFrame()
    PositionFrame()
    frame:Show()
    HideNativeSpellButtons()
    HideNativeSkillTabGlows()
    if ourTabGlow then
        ourTabGlow:Show()
    end
end

local function ToggleFrame()
    if frame:IsShown() then
        frame:Hide()
        ShowNativeSpellButtons()
        if ourTabGlow then
            ourTabGlow:Hide()
        end

        RestoreNativeSkillTabGlow()
    else
        OpenFrame()
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
    local lastTab = _G["SpellBookSkillLineTab4"] or _G["SpellBookSkillLineTab1"] or SpellBookFrame
    tab:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, -51)
    tab:Hide()
    tab:SetScript("OnClick", OpenFrame)
    tab:SetScript(
        "OnEnter",
        function(sel)
            GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
            GameTooltip:SetText("TrainerSpells")
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
            frame:Hide()
            ShowNativeSpellButtons()
            if ourTabGlow then
                ourTabGlow:Hide()
            end
        end
    )

    local function OnNativeTabClicked()
        if frame:IsShown() then
            frame:Hide()
            ShowNativeSpellButtons()
            if ourTabGlow then
                ourTabGlow:Hide()
            end
        end
    end

    for i = 1, 6 do
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
end

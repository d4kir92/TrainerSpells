local frame = CreateFrame("Frame", "TrainerSpellsFrame", UIParent)
frame:SetSize(420, 480)
frame:SetPoint("CENTER")
frame:SetFrameStrata("TOOLTIP")
frame:SetFrameLevel(500)
frame:Hide()
local ROW_HEIGHT = 20
local AVAILABLE_COLOR = "|cff30d030"
local SOON_COLOR = "|cff4db8ff"
local NOTYET_COLOR = "|cffff4444"
local TALENT_COLOR = "|cffff9933"
local KNOWN_COLOR = "|cff888888"
local IGNORED_COLOR = "|cff666666"
local SPELL_NAME_COLOR = "|cff71d5ff"
local DIM_NAME_COLOR = "|cff999999"
local RANK_COLOR = "|cffaaaaaa"
local function FormatCost(copper)
    if not copper or copper == 0 then return "kostenlos" end

    return GetMoneyString(copper, true)
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

local scrollBox = CreateFrame("Frame", "TrainerSpellsScrollBox", frame, "WowScrollBoxList")
scrollBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -12)
scrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 15)
local listBg = frame:CreateTexture(nil, "BACKGROUND")
listBg:SetTexture("Interface\\AddOns\\TrainerSpells\\media\\inset")
listBg:SetPoint("TOPLEFT", scrollBox, "TOPLEFT", -4, 4)
listBg:SetPoint("BOTTOMRIGHT", scrollBox, "BOTTOMRIGHT", 4, -4)
local scrollBar = CreateFrame("EventFrame", "TrainerSpellsScrollBar", frame, "MinimalScrollBar")
scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
local function InitScrollRow(rowFrame, elementData)
    if not rowFrame.icon then
        local icon = rowFrame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
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
                function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(elementData.text)
                    GameTooltip:AddLine("Gesamtkosten: " .. FormatCost(elementData.totalCost), 1, 1, 1)
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
            levelFS:SetText(elementData.color .. "Level " .. entry.level .. "|r")
        end

        rowFrame:EnableMouse(true)
        rowFrame:SetScript(
            "OnEnter",
            function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(entry.spellID)
                if elementData.showCostTooltip then
                    GameTooltip:AddLine("Kosten: " .. FormatCost(entry.cost), 1, 1, 1)
                end

                GameTooltip:AddLine("Rechtsklick: ignorieren", 0.6, 0.6, 0.6)
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
        end
    end

    local ignored, known, remaining = {}, {}, {}
    for _, entry in ipairs(allEntries) do
        if TrainerSpells_IsIgnored and TrainerSpells_IsIgnored(entry.spellID, entry.name) then
            table.insert(ignored, entry)
        else
            local maxKnown = knownMaxRank[entry.name] or 0
            if entry.rankNum == maxKnown then
                table.insert(known, entry)
            elseif entry.rankNum < maxKnown then
            else
                table.insert(remaining, entry)
            end
        end
    end

    local available, missingTalents, future = {}, {}, {}
    for _, entry in ipairs(remaining) do
        if entry.level <= selectedLevel then
            if entry.status == "unavailable" then
                table.insert(missingTalents, entry)
            else
                table.insert(available, entry)
            end
        else
            table.insert(future, entry)
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
        AddEntries(available, AVAILABLE_COLOR, false, true, false)
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
        AddEntries(missingTalents, TALENT_COLOR, false, true, false)
    end

    if #ignored > 0 then
        AddHeader("Ignored", IGNORED_COLOR)
        AddEntries(ignored, IGNORED_COLOR, false, true, true)
    end

    if #known > 0 then
        AddHeader("Already Known", KNOWN_COLOR)
        AddEntries(known, KNOWN_COLOR, false, false, true)
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
        frame:SetPoint("TOPLEFT", SpellBookFrame, "TOPLEFT", 14, -70)
        frame:SetPoint("BOTTOMRIGHT", SpellBookFrame, "BOTTOMRIGHT", -36, 78)
    else
        frame:SetPoint("CENTER")
    end
end

local NATIVE_EXTRA_WIDGETS = {"SpellBookPageNavigationFrame",}
local spellButtonsHidden = false
local hiddenPageRegions = {}
local function HideNativeSpellButtons()
    if spellButtonsHidden then return end
    spellButtonsHidden = true
    for i = 1, 12 do
        local btn = _G["SpellButton" .. i]
        if btn then
            btn:Hide()
        end
    end

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
    for i = 1, 12 do
        local btn = _G["SpellButton" .. i]
        if btn then
            btn:Show()
        end
    end

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

SLASH_TRAINERSPELLS1 = "/ts"
SlashCmdList["TRAINERSPELLS"] = ToggleFrame
local function PrintFrameDebug()
    if not SpellBookFrame then
        print("TrainerSpells Debug: SpellBookFrame existiert nicht.")

        return
    end

    if not SpellBookFrame:IsShown() then
        print("TrainerSpells Debug: Bitte zuerst das Spellbook öffnen.")

        return
    end

    local f = SpellBookFrame
    print(("MTD SBF %.0fx%.0f  L%.0f R%.0f T%.0f B%.0f"):format(f:GetWidth(), f:GetHeight(), f:GetLeft() or -1, f:GetRight() or -1, f:GetTop() or -1, f:GetBottom() or -1))
    if f.Inset then
        local i = f.Inset
        print(("MTD Inset %.0fx%.0f  L%.0f R%.0f T%.0f B%.0f"):format(i:GetWidth(), i:GetHeight(), i:GetLeft() or -1, i:GetRight() or -1, i:GetTop() or -1, i:GetBottom() or -1))
    else
        print("MTD: kein f.Inset")
    end

    local t1 = _G["SpellBookSkillLineTab1"]
    if t1 then
        print(("MTD Tab1 L%.0f R%.0f T%.0f B%.0f W%.0f H%.0f"):format(t1:GetLeft() or -1, t1:GetRight() or -1, t1:GetTop() or -1, t1:GetBottom() or -1, t1:GetWidth() or -1, t1:GetHeight() or -1))
        local function texOf(getter)
            local tx = t1[getter] and t1[getter](t1)

            return tx and tx:GetTexture()
        end

        print(("MTD SkillTab1 Normal=%s Pushed=%s Highlight=%s Disabled=%s"):format(tostring(texOf("GetNormalTexture")), tostring(texOf("GetPushedTexture")), tostring(texOf("GetHighlightTexture")), tostring(texOf("GetDisabledTexture"))))
        print(("MTD Tab1 selected=%s  SetSkillLineTab existiert=%s"):format(tostring(SpellBookFrame.selectedSkillLine), tostring(SpellBookFrame_SetSkillLineTab ~= nil)))
        for ridx, region in ipairs({t1:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType() == "Texture" then
                print(("MTD SkillTab1 region#%d tex=%s shown=%s alpha=%.2f"):format(ridx, tostring(region:GetTexture()), tostring(region:IsShown()), region:GetAlpha() or -1))
            end
        end
    else
        print("MTD: kein SpellBookSkillLineTab1")
    end

    for i = 1, 6 do
        local t = _G["SpellBookSkillLineTab" .. i]
        if t then
            print(("MTD SkillTab%d exists=true shown=%s  L%.0f R%.0f T%.0f B%.0f"):format(i, tostring(t:IsShown()), t:GetLeft() or -1, t:GetRight() or -1, t:GetTop() or -1, t:GetBottom() or -1))
        else
            print(("MTD SkillTab%d exists=false"):format(i))
        end
    end

    local close = f.CloseButton or _G["SpellBookFrameCloseButton"]
    if close then
        print(("MTD Close T%.0f B%.0f  (Abstand von SBF-Top: %.0f)"):format(close:GetTop() or -1, close:GetBottom() or -1, (f:GetTop() or 0) - (close:GetBottom() or 0)))
    else
        print("MTD: kein CloseButton gefunden")
    end

    local sbfTop = f:GetTop() or 0
    for _, child in ipairs({f:GetChildren()}) do
        local name = child.GetName and child:GetName()
        if name then
            print(("MTD child %s  T%.0f B%.0f  (dTop %.0f)"):format(name, child:GetTop() or -1, child:GetBottom() or -1, sbfTop - (child:GetTop() or sbfTop)))
        end
    end

    for i = 1, 3 do
        local tab = _G["SpellBookFrameTabButton" .. i]
        if tab then
            print(("MTD Tab%d L%.0f R%.0f W%.0f H%.0f T%.0f B%.0f"):format(i, tab:GetLeft() or -1, tab:GetRight() or -1, tab:GetWidth() or -1, tab:GetHeight() or -1, tab:GetTop() or -1, tab:GetBottom() or -1))
            if i == 1 then
                local function texOf(getter)
                    local t = tab[getter] and tab[getter](tab)

                    return t and t:GetTexture()
                end

                print(("MTD Tab1 Normal=%s Pushed=%s Highlight=%s Disabled=%s"):format(tostring(texOf("GetNormalTexture")), tostring(texOf("GetPushedTexture")), tostring(texOf("GetHighlightTexture")), tostring(texOf("GetDisabledTexture"))))
            end
        end
    end

    for _, region in ipairs({f:GetRegions()}) do
        if region.GetObjectType and region:GetObjectType() == "FontString" and region:GetText() then
            print(("MTD text '%s'  T%.0f B%.0f  (dTop %.0f)"):format(region:GetText(), region:GetTop() or -1, region:GetBottom() or -1, sbfTop - (region:GetTop() or sbfTop)))
        end
    end

    local sbfBottom = f:GetBottom() or 0
    for idx, region in ipairs({f:GetRegions()}) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            local w, h = region:GetWidth() or 0, region:GetHeight() or 0
            if w > 100 and h > 100 then
                print(("MTD texture #%d %s  %.0fx%.0f  T%.0f B%.0f  (dBottom %.0f)"):format(idx, tostring(region:GetTexture()), w, h, region:GetTop() or -1, region:GetBottom() or -1, (region:GetBottom() or sbfBottom) - sbfBottom))
            end
        end
    end

    local title = f.TitleText or _G["SpellBookFrameTitleText"]
    if title then
        print(("MTD Title T%.0f B%.0f  (Abstand von SBF-Top: %.0f)"):format(title:GetTop() or -1, title:GetBottom() or -1, (f:GetTop() or 0) - (title:GetBottom() or 0)))
    else
        print("MTD: kein TitleText gefunden")
    end
end

SLASH_TRAINERSPELLSDEBUG1 = "/tsdebug"
SlashCmdList["TRAINERSPELLSDEBUG"] = PrintFrameDebug
if SpellBookFrame then
    local tab = CreateFrame("Button", "TrainerSpellsSpellbookTab", SpellBookFrame)
    tab:SetSize(32, 32)
    tab:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09")
    tab:SetHighlightTexture(130718, "ADD")
    local border = tab:CreateTexture(nil, "BACKGROUND")
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
    tab:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, -17)
    tab:Hide()
    tab:SetScript("OnClick", OpenFrame)
    tab:SetScript(
        "OnEnter",
        function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
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

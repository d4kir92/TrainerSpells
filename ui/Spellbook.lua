local _, TrainerSpells = ...
local classFrame = TrainerSpells.ClassFrame
local listBg = TrainerSpells.ClassListBackground
local searchBox = TrainerSpells.SearchBox
local SPELLBOOK_TAB_NAMES = {"TrainerSpellsSpellbookTab", "TrainerSpellsPetSpellbookTab", "TrainerSpellsClassTrainerMapTab", "TrainerSpellsWeaponSpellbookTab"}
for i = 1, 8 do
    table.insert(SPELLBOOK_TAB_NAMES, "SpellBookSkillLineTab" .. i)
end

local function GetSearchLeftOffset(defaultOffset, topOffset)
    local frameScale = classFrame:GetEffectiveScale()
    local frameLeft = classFrame:GetLeft()
    local frameRight = classFrame:GetRight()
    local frameTop = classFrame:GetTop()
    if not frameLeft or not frameRight or not frameTop then return defaultOffset end
    local rowTop = frameTop + topOffset
    local rowBottom = rowTop - 40
    local offset = defaultOffset
    for _, name in ipairs(SPELLBOOK_TAB_NAMES) do
        local tab = _G[name]
        if tab and tab:IsShown() and tab:GetLeft() then
            local scale = tab:GetEffectiveScale() / frameScale
            local left, right = tab:GetLeft() * scale, tab:GetRight() * scale
            local top, bottom = tab:GetTop() * scale, tab:GetBottom() * scale
            if left < frameRight - 4 and bottom < rowTop and top > rowBottom then offset = math.max(offset, right - frameLeft + 8) end
        end
    end
    return offset
end

local function PositionFrame()
    if classFrame.compendiumHost then TrainerSpells:PositionCompendiumClass(); return end
    classFrame:ClearAllPoints()
    if TrainerSpells:IsDragonflightUIEnabled() and DragonflightUISpellBookBG and DragonflightUISpellBookBG:IsShown() then
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

    if SpellBookFrame and SpellBookFrame:IsShown() then
        classFrame:SetScale(SpellBookFrame:GetScale())
        if TrainerSpells:IsDragonflightUIEnabled() and DragonflightUISpellBookBG and DragonflightUISpellBookBG:IsShown() then
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
        searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", GetSearchLeftOffset(66, topOffset), topOffset)
        searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -4, topOffset)
    else
        searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 10, -6)
        searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -30, -6)
    end

    local showWeaponControls = TrainerSpells.ClassView == "weapons" and TrainerSpells.WeaponControls
    local showClassTrainerControls = TrainerSpells.ClassView == "trainers" and TrainerSpells.ClassTrainerControls
    if TrainerSpells.WeaponControls then
        TrainerSpells.WeaponControls:ClearAllPoints()
        TrainerSpells.WeaponControls:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 4, -4)
        TrainerSpells.WeaponControls:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -4, -4)
        TrainerSpells.WeaponControls:SetShown(showWeaponControls and true or false)
    end

    if TrainerSpells.ClassTrainerControls then
        TrainerSpells.ClassTrainerControls:ClearAllPoints()
        TrainerSpells.ClassTrainerControls:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 4, -4)
        TrainerSpells.ClassTrainerControls:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -4, -4)
        TrainerSpells.ClassTrainerControls:SetShown(showClassTrainerControls and true or false)
    end

    if TrainerSpells.ClassScrollBox then
        TrainerSpells.ClassScrollBox:ClearAllPoints()
        local controlsOffset = showClassTrainerControls and -44 or showWeaponControls and -36 or -4
        TrainerSpells.ClassScrollBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 6, controlsOffset)
        TrainerSpells.ClassScrollBox:SetPoint("BOTTOMRIGHT", classFrame, "BOTTOMRIGHT", -24, 13)
    end
end

if SpellBookFrame then hooksecurefunc(SpellBookFrame, "SetScale", function() if classFrame:IsShown() then PositionFrame() end end) end
local repositionQueued = false
local function QueuePositionFrame()
    if repositionQueued or not classFrame:IsShown() then return end
    repositionQueued = true
    C_Timer.After(0, function()
        repositionQueued = false
        if classFrame:IsShown() then PositionFrame() end
    end)
end

if SpellBookFrame then
    for _, funcName in ipairs({"SpellBookFrame_Update", "SpellBookFrame_UpdateSkillLineTabs"}) do
        if _G[funcName] then hooksecurefunc(funcName, QueuePositionFrame) end
    end

    for i = 1, 8 do
        local tab = _G["SpellBookSkillLineTab" .. i]
        if tab then
            tab:HookScript("OnShow", QueuePositionFrame)
            tab:HookScript("OnHide", QueuePositionFrame)
        end
    end

    local tabWatcher = CreateFrame("Frame")
    for _, event in ipairs({"SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "UNIT_PET"}) do
        TrainerSpells:RegisterEvent(tabWatcher, event)
    end

    tabWatcher:SetScript("OnEvent", QueuePositionFrame)
end

local NATIVE_EXTRA_WIDGETS = {"SpellBookPageNavigationFrame", "SpellBookFrameShowAllSpellRanksCheckbox", "ShowAllSpellRanksCheckbox",}
local spellButtonsHidden = false
local hiddenPageRegions = {}
local function HideNativeSpellButtons()
    if classFrame.compendiumHost or spellButtonsHidden then return end
    spellButtonsHidden = true
    for _, name in ipairs(NATIVE_EXTRA_WIDGETS) do
        local widget = _G[name]
        if widget then widget:Hide() end
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
        if widget then widget:Show() end
    end

    for _, region in ipairs(hiddenPageRegions) do
        region:Show()
    end

    wipe(hiddenPageRegions)
    if SpellBookFrame_Update then SpellBookFrame_Update() end
end

local classicModeTabs = {}
local classicModeTabGlows = {}
local function GetTabGlow(tabFrame)
    if not tabFrame then return nil end
    for _, region in ipairs({tabFrame:GetRegions()}) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and region.GetDrawLayer and region:GetDrawLayer() == "OVERLAY" then return region end
    end
end

local function HideNativeSkillTabGlows()
    for i = 1, 8 do
        local glow = GetTabGlow(_G["SpellBookSkillLineTab" .. i])
        if glow then glow:Hide() end
    end
end

local function HideClassicModeTabGlows()
    for _, glow in pairs(classicModeTabGlows) do
        glow:Hide()
    end
end

local function OpenFrame(view)
    if classFrame.compendiumHost then TrainerSpells:UndockCompendiumFrame(classFrame) end
    TrainerSpells:SetClassView(view)
    PositionFrame()
    classFrame:Show()
    HideNativeSpellButtons()
    HideNativeSkillTabGlows()
    HideClassicModeTabGlows()
    if classicModeTabGlows[view] then classicModeTabGlows[view]:Show() end
end

if SpellBookFrame and TrainerSpells:HasClassTrainers() then
    local lastTab = _G["SpellBookSkillLineTab5"] or _G["SpellBookSkillLineTab4"] or _G["SpellBookSkillLineTab1"] or SpellBookFrame
    local function CreateClassicModeTab(name, view, icon, tooltip, previousTab)
        local tab = CreateFrame("Button", name, SpellBookFrame)
        tab:SetSize(32, 32)
        tab:SetNormalTexture(icon)
        tab:SetHighlightTexture(130718, "ADD")
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
        if previousTab then
            tab:SetPoint("TOPLEFT", previousTab, "BOTTOMLEFT", 0, -16)
        else
            tab:SetPoint("TOPLEFT", lastTab, "BOTTOMLEFT", 0, 0)
        end

        tab:Hide()
        tab:SetScript("OnClick", function() OpenFrame(view) end)
        tab:SetScript("OnEnter", function(sel)
            GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip)
            GameTooltip:Show()
        end)

        tab:SetScript("OnLeave", GameTooltip_Hide)
        classicModeTabs[view] = tab
        classicModeTabGlows[view] = glow
        return tab
    end

    local className, classToken = UnitClass("player")
    local previousTab = CreateClassicModeTab("TrainerSpellsSpellbookTab", "class", "Interface\\Icons\\INV_Misc_Book_09", className or TrainerSpells:Trans("LID_CLASSTRAINER"))
    if TrainerSpells:HasPetClassData(classToken) then previousTab = CreateClassicModeTab("TrainerSpellsPetSpellbookTab", "pet", "Interface\\Icons\\Ability_Hunter_BeastCall", TrainerSpells:Trans("LID_PETTRAINING"), previousTab) end
    if TrainerSpells.BuildClassTrainerItems then previousTab = CreateClassicModeTab("TrainerSpellsClassTrainerMapTab", "trainers", 134269, TrainerSpells:Trans("LID_CLASSTRAINERS"), previousTab) end
    if TrainerSpells.BuildWeaponSkillItems then CreateClassicModeTab("TrainerSpellsWeaponSpellbookTab", "weapons", "Interface\\Icons\\INV_Sword_04", _G.WEAPON_SKILLS or "Weapon Skills", previousTab) end
    SpellBookFrame:HookScript("OnShow", function()
        for _, tab in pairs(classicModeTabs) do
            tab:Show()
        end
    end)

    SpellBookFrame:HookScript("OnHide", function()
        if classFrame.compendiumHost then return end
        for _, tab in pairs(classicModeTabs) do
            tab:Hide()
        end

        classFrame:Hide()
        ShowNativeSpellButtons()
        HideClassicModeTabGlows()
    end)

    local function OnNativeTabClicked()
        if classFrame.compendiumHost then return end
        if classFrame:IsShown() then
            classFrame:Hide()
            ShowNativeSpellButtons()
            HideClassicModeTabGlows()
        end
    end

    for i = 1, 8 do
        local t = _G["SpellBookSkillLineTab" .. i]
        if t then t:HookScript("OnClick", OnNativeTabClicked) end
    end

    for i = 1, 3 do
        local t = _G["SpellBookFrameTabButton" .. i]
        if t then t:HookScript("OnClick", OnNativeTabClicked) end
    end

    C_Timer.After(4, function()
        for i = 1, 4 do
            local t = _G["DragonflightUISpellBookFrameTabButton" .. i]
            if t then t:HookScript("OnClick", OnNativeTabClicked) end
        end
    end)
end

local playerSpellsModeTabs = {}
local playerSpellsModeTabContainer
local playerSpellsModeDivider
local playerSpellsModeLastTab
local playerSpellsContentHidden = false
local playerSpellsSubTabs = {}
function playerSpellsSubTabs.GetSavedView()
    local saved = TrainerSpells_Character and TrainerSpells_Character.classView
    for _, entry in ipairs(playerSpellsSubTabs.views or {}) do
        if entry.view == saved then return saved end
    end
    return "class"
end

function playerSpellsSubTabs.Update()
    if not playerSpellsSubTabs.bar then return end
    for index, entry in ipairs(playerSpellsSubTabs.views) do
        if entry.view == TrainerSpells.ClassView then
            playerSpellsSubTabs.bar:SetTabVisuallySelected(index)
            playerSpellsSubTabs.title:SetText(entry.title)
            playerSpellsSubTabs.desc:SetText(TrainerSpells:Trans(entry.desc))
        end
    end
end

local function GetPlayerSpellsBook()
    return PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
end

local function GetMaxDescendantFrameLevel(frame)
    local level = frame:GetFrameLevel()
    for _, child in ipairs({frame:GetChildren()}) do
        level = math.max(level, GetMaxDescendantFrameLevel(child))
    end
    return level
end

local function PositionPlayerSpellsFrame()
    if classFrame.compendiumHost then TrainerSpells:PositionCompendiumClass(); return end
    local book = GetPlayerSpellsBook()
    if not book then return end
    local content = book.PagedSpellsFrame or book
    local frameLevel = GetMaxDescendantFrameLevel(content)
    if playerSpellsModeTabContainer then frameLevel = math.max(frameLevel, playerSpellsModeTabContainer:GetFrameLevel()) end
    classFrame:SetParent(book)
    classFrame:SetFrameStrata(book:GetFrameStrata())
    classFrame:SetFrameLevel(frameLevel + 1)
    classFrame:ClearAllPoints()
    classFrame:SetScale(1)
    classFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -50)
    classFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, -8)
    listBg:ClearAllPoints()
    listBg:Hide()
    local showWeaponControls = TrainerSpells.ClassView == "weapons" and TrainerSpells.WeaponControls
    local showClassTrainerControls = TrainerSpells.ClassView == "trainers" and TrainerSpells.ClassTrainerControls
    local panel = playerSpellsSubTabs.panel
    local anchor, left, right, top = classFrame, 48, -100, -2
    if panel then
        panel:Show()
        playerSpellsSubTabs.bar:Show()
        playerSpellsSubTabs.title:Show()
        playerSpellsSubTabs.desc:Show()
        anchor, left, right, top = panel, 8, -90, -8
        panel:ClearAllPoints()
        if content.View1 then
            panel:SetPoint("TOPLEFT", content.View1, "TOPLEFT", -37, -46)
            panel:SetPoint("BOTTOMRIGHT", content.View1, "BOTTOMRIGHT", 0, 4)
        else
            panel:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 44, -61)
            panel:SetPoint("BOTTOMRIGHT", classFrame, "BOTTOMRIGHT", -10, 24)
        end

        local bar, slider = playerSpellsSubTabs.bar, TrainerSpells.RowHeightSlider
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 33, 3)
        local sliderScale = slider:GetScale()
        slider:ClearAllPoints()
        slider:SetPoint("RIGHT", panel, "TOPRIGHT", -86 / sliderScale, 20 / sliderScale)
        slider:SetWidth(168 / sliderScale)
        local spoilerFree = playerSpellsSubTabs.spoilerFree
        spoilerFree:ClearAllPoints()
        spoilerFree:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 0)
        spoilerFree:SetChecked(TrainerSpells_Character.spoilerFree and true or false)
        spoilerFree:Show()
        playerSpellsSubTabs.title:ClearAllPoints()
        playerSpellsSubTabs.title:SetPoint("TOPLEFT", bar, "TOPRIGHT", 12, 0)
        playerSpellsSubTabs.title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -266, 35)
        playerSpellsSubTabs.desc:ClearAllPoints()
        playerSpellsSubTabs.desc:SetPoint("TOPLEFT", playerSpellsSubTabs.title, "BOTTOMLEFT", 0, -3)
        playerSpellsSubTabs.desc:SetPoint("TOPRIGHT", playerSpellsSubTabs.title, "BOTTOMRIGHT", 0, -3)
    end

    for _, controls in ipairs({TrainerSpells.WeaponControls or false, TrainerSpells.ClassTrainerControls or false}) do
        if controls then
            controls:ClearAllPoints()
            controls:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, top)
            controls:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", right, top)
        end
    end

    if TrainerSpells.WeaponControls then TrainerSpells.WeaponControls:SetShown(showWeaponControls and true or false) end
    if TrainerSpells.ClassTrainerControls then TrainerSpells.ClassTrainerControls:SetShown(showClassTrainerControls and true or false) end
    local dividerOffset = top + 1 + (showClassTrainerControls and -42 or showWeaponControls and -34 or 0)
    if playerSpellsModeDivider then
        playerSpellsModeDivider:ClearAllPoints()
        if panel then
            playerSpellsModeDivider:GetParent():SetFrameLevel(playerSpellsSubTabs.bar:GetFrameLevel() + 10)
            playerSpellsModeDivider:SetPoint("TOPLEFT", panel, "TOPLEFT", 5, 6)
            playerSpellsModeDivider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -60, 6)
        else
            playerSpellsModeDivider:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, dividerOffset)
            playerSpellsModeDivider:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", right, dividerOffset)
        end

        playerSpellsModeDivider:Show()
    end

    if TrainerSpells.ClassScrollBox and playerSpellsModeDivider then
        TrainerSpells.ClassScrollBox:ClearAllPoints()
        if panel then
            local scrollBar = _G.TrainerSpellsScrollBar
            TrainerSpells.ClassScrollBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, dividerOffset - 13)
            TrainerSpells.ClassScrollBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 0)
            if scrollBar then
                scrollBar:ClearAllPoints()
                scrollBar:SetPoint("TOPLEFT", TrainerSpells.ClassScrollBox, "TOPRIGHT", 4, -2)
                scrollBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", -18, 8)
            end
        else
            TrainerSpells.ClassScrollBox:SetPoint("TOPLEFT", playerSpellsModeDivider, "BOTTOMLEFT", 0, -2)
            TrainerSpells.ClassScrollBox:SetPoint("BOTTOMRIGHT", classFrame, "BOTTOMRIGHT", -84, 30)
        end
    end

    searchBox:ClearAllPoints()
    if book.SearchBox then
        searchBox:SetPoint("TOPLEFT", book.SearchBox, "TOPLEFT")
        searchBox:SetPoint("BOTTOMRIGHT", book.SearchBox, "BOTTOMRIGHT")
    else
        searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 60, 34)
        searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -10, 34)
    end
end

local PLAYER_SPELLS_CONTENT_KEYS = {"PagedSpellsFrame", "SearchBox"}
local playerSpellsContentAlpha = {}
local playerSpellsContentBlocker
local function GetPlayerSpellsContentBlocker()
    if not playerSpellsContentBlocker then
        playerSpellsContentBlocker = CreateFrame("Frame", nil, classFrame)
        playerSpellsContentBlocker:SetFrameLevel(classFrame:GetFrameLevel())
        playerSpellsContentBlocker:EnableMouse(true)
        playerSpellsContentBlocker:EnableMouseWheel(true)
        playerSpellsContentBlocker:SetScript("OnMouseWheel", function() end)
    end
    return playerSpellsContentBlocker
end

local function SetNativeCategoryTabsVisual(book, showSelection)
    local tabSystem = book and book.CategoryTabSystem
    if not tabSystem or not tabSystem.tabs then return end
    for _, tab in ipairs(tabSystem.tabs) do
        local isSelected = showSelection and tab.isSelected and true or false
        local active = tab.squareMode and {"SquareBackgroundActive", "SquareBackgroundActiveGlow"} or {"LeftActive", "MiddleActive", "RightActive"}
        local inactive = tab.squareMode and {"SquareBackground"} or {"Left", "Middle", "Right"}
        for _, key in ipairs(active) do
            if tab[key] then tab[key]:SetShown(isSelected) end
        end

        for _, key in ipairs(inactive) do
            if tab[key] then tab[key]:SetShown(not isSelected) end
        end

        tab:SetNormalFontObject(isSelected and (tab.selectedFontObject or GameFontHighlightSmall) or (tab.unselectedFontObject or GameFontNormalSmall))
        tab:SetEnabled(not isSelected and not (tab.IsForceDisabled and tab:IsForceDisabled()))
        if tab.Text and tab.GetTextYOffset then tab.Text:SetPoint("CENTER", tab, "CENTER", 0, tab:GetTextYOffset(isSelected)) end
        if tab.Icon and tab.GetIconYOffset then tab.Icon:SetPoint("CENTER", tab, "CENTER", 0, tab:GetIconYOffset(isSelected)) end
    end
end

local function HidePlayerSpellsContent()
    if classFrame.compendiumHost then return end
    local book = GetPlayerSpellsBook()
    if playerSpellsContentHidden or not book then return end
    playerSpellsContentHidden = true
    for _, key in ipairs(PLAYER_SPELLS_CONTENT_KEYS) do
        local content = book[key]
        if content then
            playerSpellsContentAlpha[content] = content:GetAlpha()
            content:SetAlpha(0)
        end
    end

    if book.PagedSpellsFrame then
        local blocker = GetPlayerSpellsContentBlocker()
        blocker:SetFrameLevel(classFrame:GetFrameLevel())
        blocker:ClearAllPoints()
        blocker:SetAllPoints(book.PagedSpellsFrame)
        blocker:Show()
    end
end

local function ShowPlayerSpellsContent()
    if not playerSpellsContentHidden then return end
    playerSpellsContentHidden = false
    if playerSpellsContentBlocker then playerSpellsContentBlocker:Hide() end
    for content, alpha in pairs(playerSpellsContentAlpha) do
        content:SetAlpha(alpha)
    end

    wipe(playerSpellsContentAlpha)
end

local function ClosePlayerSpellsPanel()
    if classFrame.compendiumHost then ShowPlayerSpellsContent(); SetNativeCategoryTabsVisual(GetPlayerSpellsBook(), true); return end
    local wasOpen = playerSpellsContentHidden
    classFrame:Hide()
    ShowPlayerSpellsContent()
    for _, tab in pairs(playerSpellsModeTabs) do
        tab:SetTabSelected(false)
    end

    if wasOpen then SetNativeCategoryTabsVisual(GetPlayerSpellsBook(), true) end
end

local function OpenPlayerSpellsPanel()
    if classFrame.compendiumHost then TrainerSpells:UndockCompendiumFrame(classFrame) end
    local book = GetPlayerSpellsBook()
    if not book then return end
    PositionPlayerSpellsFrame()
    HidePlayerSpellsContent()
    classFrame:Show()
    SetNativeCategoryTabsVisual(book, false)
    TrainerSpells:UpdateClassViewTabs()
end

function TrainerSpells:UpdateClassViewTabs()
    if classFrame.compendiumHost then TrainerSpells:PositionCompendiumClass(); return end
    for view, glow in pairs(classicModeTabGlows) do
        glow:SetShown(classFrame:IsShown() and TrainerSpells.ClassView == view)
    end

    if playerSpellsModeTabs.addon then playerSpellsModeTabs.addon:SetTabSelected(classFrame:IsShown()) end
    playerSpellsSubTabs.Update()
end

function playerSpellsSubTabs.SetClassIcon(icon, classToken)
    local classAtlas = GetClassAtlas and GetClassAtlas(classToken)
    if icon and classAtlas then
        icon:SetAtlas(classAtlas)
    elseif icon and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken] then
        local coords = CLASS_ICON_TCOORDS[classToken]
        icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
end

function playerSpellsSubTabs.Create()
    if playerSpellsSubTabs.bar then return end
    local className, classToken = UnitClass("player")
    local views = {
        {
            view = "class",
            icon = 133741,
            title = className,
            desc = "LID_CLASSVIEW_DESC",
            classToken = classToken
        }
    }

    if TrainerSpells:HasPetClassData(classToken) then
        table.insert(views, {
            view = "pet",
            icon = "Interface\\Icons\\Ability_Hunter_BeastCall",
            title = TrainerSpells:Trans("LID_PETTRAINING"),
            desc = "LID_PETVIEW_DESC"
        })
    end

    table.insert(views, {
        view = "trainers",
        icon = 134269,
        title = TrainerSpells:Trans("LID_CLASSTRAINERS"),
        desc = "LID_TRAINERSVIEW_DESC"
    })

    table.insert(views, {
        view = "weapons",
        icon = "Interface\\Icons\\INV_Sword_04",
        title = _G.WEAPON_SKILLS or "Weapon Skills",
        desc = "LID_WEAPONVIEW_DESC"
    })

    playerSpellsSubTabs.views = views
    local bar = CreateFrame("Frame", "TrainerSpellsPlayerSpellsSubTabs", classFrame, "TabSystemTemplate")
    bar:SetTabSelectedCallback(function(tabID)
        local entry = views[tabID]
        if entry then
            TrainerSpells:SetClassView(entry.view)
            OpenPlayerSpellsPanel()
        end
        return true
    end)

    for index, entry in ipairs(views) do
        bar:AddTab(nil, entry.icon)
        local button = bar:GetTabButton(index)
        button:SetTooltipText(entry.title .. "\n|cffffffff" .. TrainerSpells:Trans(entry.desc) .. "|r")
        if entry.classToken then playerSpellsSubTabs.SetClassIcon(button.Icon, entry.classToken) end
    end

    bar:Layout()
    local panel = CreateFrame("Frame", nil, classFrame)
    playerSpellsSubTabs.panel = panel
    local title = classFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    local desc = classFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(false)
    desc:SetTextColor(0.75, 0.75, 0.75)
    local spoilerFree = CreateFrame("CheckButton", nil, classFrame, "UICheckButtonTemplate")
    spoilerFree:SetSize(20, 20)
    local spoilerFreeText = spoilerFree:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    spoilerFreeText:SetPoint("LEFT", spoilerFree, "RIGHT", 2, 0)
    spoilerFreeText:SetText(TrainerSpells:Trans("LID_SPOILERFREE"))
    spoilerFree:SetScript("OnClick", function(self)
        TrainerSpells_Character.spoilerFree = self:GetChecked() and true or false
        TrainerSpells_Refresh()
    end)
    spoilerFree:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TrainerSpells:Trans("LID_SPOILERFREE"))
        GameTooltip:AddLine(TrainerSpells:Trans("LID_SPOILERFREE_DESC"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    spoilerFree:SetScript("OnLeave", GameTooltip_Hide)
    playerSpellsSubTabs.spoilerFree = spoilerFree
    playerSpellsSubTabs.title = title
    playerSpellsSubTabs.desc = desc
    playerSpellsSubTabs.bar = bar
    playerSpellsSubTabs.Update()
end

local function CreatePlayerSpellsModeTabs(book, tabSystem)
    local container = CreateFrame("Frame", "TrainerSpellsPlayerSpellsModeTabs", book)
    playerSpellsModeTabContainer = container
    container:SetSize(48, 32)
    container:SetPoint("LEFT", tabSystem, "RIGHT", 8, 0)
    local dividerFrame = CreateFrame("Frame", nil, classFrame)
    dividerFrame:SetAllPoints(classFrame)
    local divider = dividerFrame:CreateTexture(nil, "OVERLAY")
    playerSpellsModeDivider = divider
    divider:SetAtlas("spellbook-divider")
    divider:SetHeight(11)
    local tab = CreateFrame("Button", nil, container, "TabSystemButtonTemplate")
    tab.GetTabSystem = function() return tabSystem end
    tab:Init(1, nil, 133741)
    tab:SetTooltipText("TrainerSpells")
    tab:SetPoint("LEFT", container, "LEFT", 0, 0)
    tab:SetScript("OnClick", function()
        TrainerSpells:SetClassView(playerSpellsSubTabs.GetSavedView())
        OpenPlayerSpellsPanel()
    end)

    playerSpellsModeTabs.addon = tab
    playerSpellsModeLastTab = tab
    playerSpellsSubTabs.Create()
end

local function FitNativeSearchBox()
    local book = GetPlayerSpellsBook()
    local nativeSearchBox = book and book.SearchBox
    if not nativeSearchBox or not playerSpellsModeLastTab then return end
    local tabRight = playerSpellsModeLastTab:GetRight()
    local left, right, top = nativeSearchBox:GetLeft(), nativeSearchBox:GetRight(), nativeSearchBox:GetTop()
    local bookLeft, bookRight, bookTop = book:GetLeft(), book:GetRight(), book:GetTop()
    if not tabRight or not left or not right or not top or not bookLeft or not bookRight or not bookTop then return end
    tabRight = tabRight * playerSpellsModeLastTab:GetEffectiveScale() / book:GetEffectiveScale()
    if left >= tabRight + 8 or right <= tabRight + 60 then return end
    nativeSearchBox:ClearAllPoints()
    nativeSearchBox:SetPoint("TOPLEFT", book, "TOPLEFT", tabRight - bookLeft + 12, top - bookTop)
    nativeSearchBox:SetPoint("TOPRIGHT", book, "TOPRIGHT", right - bookRight, top - bookTop)
    if classFrame:IsShown() then PositionPlayerSpellsFrame() end
end

local function QueueFitNativeSearchBox()
    C_Timer.After(0, FitNativeSearchBox)
end

local function InstallPlayerSpellsIntegration()
    local book = GetPlayerSpellsBook()
    if playerSpellsModeTabContainer or not book then return end
    local tabSystem = book.CategoryTabSystem
    if not tabSystem then return end
    CreatePlayerSpellsModeTabs(book, tabSystem)
    book:HookScript("OnHide", ClosePlayerSpellsPanel)
    hooksecurefunc(tabSystem, "SetTab", ClosePlayerSpellsPanel)
    PlayerSpellsFrame:HookScript("OnHide", ClosePlayerSpellsPanel)
    book:HookScript("OnShow", QueueFitNativeSearchBox)
    book:HookScript("OnSizeChanged", QueueFitNativeSearchBox)
    if book:IsShown() then QueueFitNativeSearchBox() end
end

if not SpellBookFrame and TrainerSpells:HasClassTrainers() then
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
        InstallPlayerSpellsIntegration()
    else
        local playerSpellsLoader = CreateFrame("Frame")
        playerSpellsLoader:RegisterEvent("ADDON_LOADED")
        playerSpellsLoader:SetScript("OnEvent", function(self, _, addonName)
            if addonName ~= "Blizzard_PlayerSpells" then return end
            self:UnregisterEvent("ADDON_LOADED")
            InstallPlayerSpellsIntegration()
        end)
    end
end

function TrainerSpells:DockCompendiumFrame(frame, host, widgets)
    local saved = {}
    for _, widget in ipairs(widgets) do
        local state = {widget = widget, parent = widget:GetParent(), shown = widget:IsShown(), points = {}}
        if widget.GetScale then state.scale = widget:GetScale() end
        if widget.GetFrameStrata then state.strata = widget:GetFrameStrata(); state.level = widget:GetFrameLevel() end
        for index = 1, widget:GetNumPoints() do state.points[index] = {widget:GetPoint(index)} end
        table.insert(saved, state)
    end
    frame.compendiumState = saved
    frame.compendiumHost = host
    frame:SetParent(host)
    frame:SetScale(1)
    frame:SetFrameStrata(host:GetFrameStrata())
    frame:SetFrameLevel(host:GetFrameLevel() + 2)
    frame:ClearAllPoints()
    frame:SetAllPoints(host)
end

function TrainerSpells:UndockCompendiumFrame(frame)
    if not frame.compendiumHost then return end
    frame:Hide()
    frame.compendiumHost = nil
    for _, state in ipairs(frame.compendiumState) do state.widget:ClearAllPoints() end
    for _, state in ipairs(frame.compendiumState) do
        local widget = state.widget
        widget:SetParent(state.parent)
        if state.scale then widget:SetScale(state.scale) end
        if state.strata then widget:SetFrameStrata(state.strata); widget:SetFrameLevel(state.level) end
        widget:ClearAllPoints()
        for _, point in ipairs(state.points) do widget:SetPoint(unpack(point)) end
        widget:SetShown(state.shown)
    end
    frame.compendiumState = nil
    frame:Hide()
end

function TrainerSpells:PositionCompendiumClass()
    local host = classFrame.compendiumHost
    if not host then return end
    local panel = playerSpellsSubTabs.panel
    panel:ClearAllPoints()
    panel:SetAllPoints(classFrame)
    for index, tab in ipairs(host.classTabs) do
        tab:SetTabSelected(tab.view == TrainerSpells.ClassView)
        AzerothCompendiumAPI.PositionContentTab(tab, host, host.classTabs[index - 1])
    end
    searchBox:Hide()
    AzerothCompendiumAPI.PositionHeaderSlider(TrainerSpells.RowHeightSlider)
    local offset = -4
    for _, entry in ipairs({{TrainerSpells.ClassTrainerControls, "trainers", -48}, {TrainerSpells.WeaponControls, "weapons", -40}}) do
        local controls = entry[1]
        if controls then
            controls:ClearAllPoints()
            controls:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
            controls:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
            controls:SetShown(TrainerSpells.ClassView == entry[2])
            if TrainerSpells.ClassView == entry[2] then offset = entry[3] end
        end
    end
    TrainerSpells.ClassScrollBox:ClearAllPoints()
    TrainerSpells.ClassScrollBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, offset)
    TrainerSpells.ClassScrollBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 0)
    local scrollBar = _G.TrainerSpellsScrollBar
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", TrainerSpells.ClassScrollBox, "TOPRIGHT", 4, -2)
    scrollBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", -18, 8)
    listBg:Hide()
    if playerSpellsModeDivider then playerSpellsModeDivider:Hide() end
    panel:Show()
    playerSpellsSubTabs.bar:Hide()
    playerSpellsSubTabs.spoilerFree:Hide()
    playerSpellsSubTabs.title:ClearAllPoints()
    playerSpellsSubTabs.title:SetPoint("BOTTOMLEFT", host.classTabs[#host.classTabs], "BOTTOMRIGHT", 12, 17)
    playerSpellsSubTabs.title:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, 17)
    playerSpellsSubTabs.desc:ClearAllPoints()
    playerSpellsSubTabs.desc:SetPoint("TOPLEFT", playerSpellsSubTabs.title, "BOTTOMLEFT", 0, -3)
    playerSpellsSubTabs.desc:SetPoint("TOPRIGHT", playerSpellsSubTabs.title, "BOTTOMRIGHT", 0, -3)
    playerSpellsSubTabs.title:Show()
    playerSpellsSubTabs.desc:Show()
    playerSpellsSubTabs.Update()
end

function TrainerSpells:CreateCompendiumListView(host, entries, mode, rowHeight)
    local view = {host = host, mode = mode, rowHeight = rowHeight, tabs = {}, entries = entries}
    function view:TranslateTitle(text)
        if type(text) == "string" and text:find("LID_", 1, true) == 1 then return TrainerSpells:Trans(text) end
        return text
    end
    view.title = host:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    view.title:SetJustifyH("LEFT")
    view.title:SetWordWrap(false)
    view.desc = host:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    view.desc:SetJustifyH("LEFT")
    view.desc:SetWordWrap(false)
    view.desc:SetTextColor(0.75, 0.75, 0.75)
    view.desc:SetPoint("TOPLEFT", view.title, "BOTTOMLEFT", 0, -3)
    view.desc:SetPoint("TOPRIGHT", view.title, "BOTTOMRIGHT", 0, -3)
    for _, entry in ipairs(entries) do
        local tab = AzerothCompendiumAPI.CreateContentTab(host, view:TranslateTitle(entry.title), entry.icon, function() view.mode = entry.mode or entry.view; view:Refresh() end)
        tab.mode = entry.mode or entry.view
        if entry.classToken then playerSpellsSubTabs.SetClassIcon(tab.Icon, entry.classToken) end
        tab:SetScript("OnEnter", function(button)
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(view:TranslateTitle(entry.title))
            GameTooltip:AddLine(TrainerSpells:Trans(entry.desc), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        table.insert(view.tabs, tab)
        AzerothCompendiumAPI.PositionContentTab(tab, host, view.tabs[#view.tabs - 1])
    end
    view.title:SetPoint("BOTTOMLEFT", view.tabs[#view.tabs], "BOTTOMRIGHT", 12, 17)
    view.title:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, 17)
    view.scrollBox = CreateFrame("Frame", nil, host, "WowScrollBoxList")
    view.scrollBox:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -4)
    view.scrollBox:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -22, 0)
    view.scrollBar = CreateFrame("EventFrame", nil, host, "MinimalScrollBar")
    view.scrollBar:SetPoint("TOPLEFT", view.scrollBox, "TOPRIGHT", 4, -2)
    view.scrollBar:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", -18, 8)
    local list = CreateScrollBoxListLinearView()
    list:SetElementExtentCalculator(function(_, item) return item.isHeader and TrainerSpells.HeaderHeight + TrainerSpells.HeaderExtraGap or view.rowHeight end)
    list:SetPadding(0, 0, 0, 0, TrainerSpells.RowSpacing)
    list:SetElementInitializer("Frame", function(row, item) TrainerSpells:InitScrollRow(row, item, view.rowHeight) end)
    ScrollUtil.InitScrollBoxListWithScrollBar(view.scrollBox, view.scrollBar, list)
    TrainerSpells:AddContentBorder(host)
    host.borderFrame:SetFrameLevel(view.scrollBox:GetFrameLevel() + 20)
    host.borderFrame:EnableMouse(false)
    view.scrollBar:SetFrameLevel(host.borderFrame:GetFrameLevel() + 1)
    view.slider = CreateFrame("Slider", nil, host, "MinimalSliderWithSteppersTemplate")
    view.slider:SetScale(0.75)
    view.slider:SetHeight(10)
    view.slider:Init(rowHeight, TrainerSpells.MinRowHeight, TrainerSpells.MaxRowHeight, TrainerSpells.MaxRowHeight - TrainerSpells.MinRowHeight, {
        [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return WHITE_FONT_COLOR:WrapTextInColorCode(tostring(math.floor(value + 0.5))) end)
    })
    if view.slider.MinText then view.slider.MinText:Hide() end
    if view.slider.MaxText then view.slider.MaxText:Hide() end
    view.slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value) view.rowHeight = math.floor(value + 0.5); if view.BuildItems then view:Refresh() end end)
    function view:Refresh()
        for index, tab in ipairs(self.tabs) do
            tab:SetTabSelected(tab.mode == self.mode)
            if tab.mode == self.mode then
                self.title:SetText(self:TranslateTitle(self.entries[index].title))
                self.desc:SetText(TrainerSpells:Trans(self.entries[index].desc))
            end
        end
        local offset = -4
        for _, control in ipairs(self.controls or {}) do
            local active = control.mode == self.mode
            control.frame:SetShown(active)
            if active then offset = -control.height end
        end
        self.scrollBox:ClearAllPoints()
        self.scrollBox:SetPoint("TOPLEFT", host, "TOPLEFT", 0, offset)
        self.scrollBox:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -22, 0)
        if self.BuildItems then self.scrollBox:SetDataProvider(CreateDataProvider(self:BuildItems()), ScrollBoxConstants.RetainScrollPosition) end
    end
    host.OnSearchChanged = function() view:Refresh() end
    host:SetScript("OnSizeChanged", function()
        AzerothCompendiumAPI.PositionHeaderSlider(view.slider)
        for index, tab in ipairs(view.tabs) do AzerothCompendiumAPI.PositionContentTab(tab, host, view.tabs[index - 1]) end
    end)
    AzerothCompendiumAPI.PositionHeaderSlider(view.slider)
    host:RegisterEvent("PLAYER_LEVEL_UP")
    host:RegisterEvent("SPELLS_CHANGED")
    host:RegisterEvent("PLAYER_MONEY")
    if TrainerSpells.TrainerLocations then TrainerSpells.TrainerLocations.AddResolveListener(function() if host:IsShown() then view:Refresh() end end) end
    host:SetScript("OnEvent", function() if host:IsShown() then view:Refresh() end end)
    return view
end

function TrainerSpells:CreateCompendiumClass(host)
    playerSpellsSubTabs.Create()
    local view = self:CreateCompendiumListView(host, playerSpellsSubTabs.views, playerSpellsSubTabs.GetSavedView(), self.RowHeight)
    self.CompendiumClassView = view
    view.BuildItems = function(current) return TrainerSpells:BuildClassViewItems(current.mode, host.searchText) end
    view.controls = {}
    for _, entry in ipairs({{self.CreateClassTrainerControls, "trainers", 48}, {self.CreateWeaponControls, "weapons", 40}}) do
        if entry[1] then
            local controls = entry[1](self, host)
            controls:SetPoint("TOPLEFT", host, "TOPLEFT", 4, -4)
            controls:SetPoint("TOPRIGHT", host, "TOPRIGHT", -4, -4)
            table.insert(view.controls, {frame = controls, mode = entry[2], height = entry[3]})
        end
    end
    host:SetScript("OnShow", function() view:Refresh() end)
end
function TrainerSpells:RegisterCompendiumTabs()
    local api = _G["AzerothCompendiumAPI"]
    if type(api) ~= "table" or type(api.RegisterTab) ~= "function" then return end
    api.RegisterTab("TrainerSpells:professions", {
        label = function() return TrainerSpells:Trans("LID_PROFESSIONS") end,
        icon = 134708,
        insertBefore = "wishlist",
        createPanel = function(host) TrainerSpells:CreateCompendiumProfessions(host) end
    })
    if not self:HasClassTrainers() then return end
    api.RegisterTab("TrainerSpells:class", {
        label = function() return _G.CLASSES or (GetLocale() == "deDE" and "Klassen") or "Classes" end,
        icon = 133743,
        insertBefore = "wishlist",
        createPanel = function(host) TrainerSpells:CreateCompendiumClass(host) end
    })
end

TrainerSpells.CompendiumLoader = CreateFrame("Frame")
TrainerSpells.CompendiumLoader:RegisterEvent("ADDON_LOADED")
TrainerSpells.CompendiumLoader:RegisterEvent("PLAYER_LOGIN")
TrainerSpells.CompendiumLoader:SetScript("OnEvent", function(_, event, name) if event == "PLAYER_LOGIN" or name == "AzerothCompendium" then TrainerSpells:RegisterCompendiumTabs() end end)
TrainerSpells:RegisterCompendiumTabs()

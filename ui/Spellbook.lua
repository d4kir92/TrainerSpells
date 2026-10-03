local _, TrainerSpells = ...
local classFrame = TrainerSpells.ClassFrame
local listBg = TrainerSpells.ClassListBackground
local searchBox = TrainerSpells.SearchBox
local SPELLBOOK_TAB_NAMES = {"TrainerSpellsSpellbookTab", "TrainerSpellsPetSpellbookTab", "TrainerSpellsClassTrainerMapTab", "TrainerSpellsWeaponSpellbookTab"}
for i = 1, 8 do table.insert(SPELLBOOK_TAB_NAMES, "SpellBookSkillLineTab" .. i) end

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
            if left < frameRight - 4 and bottom < rowTop and top > rowBottom then
                offset = math.max(offset, right - frameLeft + 8)
            end
        end
    end
    return offset
end

local function PositionFrame()
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
    if spellButtonsHidden then return end
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
    if TrainerSpells:HasPetClassData(classToken) then
        previousTab = CreateClassicModeTab("TrainerSpellsPetSpellbookTab", "pet", "Interface\\Icons\\Ability_Hunter_BeastCall", TrainerSpells:Trans("LID_PETTRAINING"), previousTab)
    end
    if TrainerSpells.BuildClassTrainerItems then
        previousTab = CreateClassicModeTab("TrainerSpellsClassTrainerMapTab", "trainers", 134269, TrainerSpells:Trans("LID_CLASSTRAINERS"), previousTab)
    end
    if TrainerSpells.BuildWeaponSkillItems then CreateClassicModeTab("TrainerSpellsWeaponSpellbookTab", "weapons", "Interface\\Icons\\INV_Sword_04", _G.WEAPON_SKILLS or "Weapon Skills", previousTab) end

    SpellBookFrame:HookScript("OnShow", function()
        for _, tab in pairs(classicModeTabs) do
            tab:Show()
        end
    end)
    SpellBookFrame:HookScript("OnHide", function()
        for _, tab in pairs(classicModeTabs) do
            tab:Hide()
        end
        classFrame:Hide()
        ShowNativeSpellButtons()
        HideClassicModeTabGlows()
    end)

    local function OnNativeTabClicked()
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

local function PositionPlayerSpellsFrame()
    local book = GetPlayerSpellsBook()
    if not book then return end
    local content = book.PagedSpellsFrame or book
    local frameLevel = content:GetFrameLevel()
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
        anchor, left, right, top = panel, 8, -34, -8
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 44, -48)
        panel:SetPoint("BOTTOMRIGHT", classFrame, "BOTTOMRIGHT", -66, 24)
        playerSpellsSubTabs.bar:ClearAllPoints()
        playerSpellsSubTabs.bar:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 6)
        playerSpellsSubTabs.title:ClearAllPoints()
        playerSpellsSubTabs.title:SetPoint("TOPLEFT", playerSpellsSubTabs.bar, "TOPRIGHT", 12, -2)
        playerSpellsSubTabs.title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, 36)
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
        playerSpellsModeDivider:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, dividerOffset)
        playerSpellsModeDivider:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", right, dividerOffset)
        playerSpellsModeDivider:SetShown((not panel or showWeaponControls or showClassTrainerControls) and true or false)
    end

    if TrainerSpells.ClassScrollBox and playerSpellsModeDivider then
        TrainerSpells.ClassScrollBox:ClearAllPoints()
        if panel then
            local scrollBar = _G.TrainerSpellsScrollBar
            TrainerSpells.ClassScrollBox:SetPoint("TOPLEFT", playerSpellsModeDivider, "BOTTOMLEFT", -left, -2)
            TrainerSpells.ClassScrollBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 0)
            panel.borderFrame:SetFrameLevel(TrainerSpells.ClassScrollBox:GetFrameLevel() + 20)
            if scrollBar then
                scrollBar:ClearAllPoints()
                scrollBar:SetPoint("TOPLEFT", TrainerSpells.ClassScrollBox, "TOPRIGHT", 4, -2)
                scrollBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", -18, 8)
                scrollBar:SetFrameLevel(panel.borderFrame:GetFrameLevel() + 1)
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
local NATIVE_TAB_TEXTURES = {Left = false, Middle = false, Right = false, LeftActive = true, MiddleActive = true, RightActive = true}
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
        local isSelected = showSelection and tab.IsSelected and tab:IsSelected() or false
        for key, activeTexture in pairs(NATIVE_TAB_TEXTURES) do
            if tab[key] then tab[key]:SetShown(activeTexture == isSelected) end
        end
        tab:SetNormalFontObject(isSelected and (tab.selectedFontObject or GameFontHighlightSmall) or (tab.unselectedFontObject or GameFontNormalSmall))
        tab:SetEnabled(not isSelected and not (tab.IsForceDisabled and tab:IsForceDisabled()))
        if tab.Text and tab.GetTextYOffset then tab.Text:SetPoint("CENTER", tab, "CENTER", 0, tab:GetTextYOffset(isSelected)) end
    end
end

local function HidePlayerSpellsContent()
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
    local wasOpen = playerSpellsContentHidden
    classFrame:Hide()
    ShowPlayerSpellsContent()
    for _, tab in pairs(playerSpellsModeTabs) do
        tab:SetTabSelected(false)
    end

    if wasOpen then SetNativeCategoryTabsVisual(GetPlayerSpellsBook(), true) end
end

local function OpenPlayerSpellsPanel()
    local book = GetPlayerSpellsBook()
    if not book then return end
    PositionPlayerSpellsFrame()
    HidePlayerSpellsContent()
    classFrame:Show()
    SetNativeCategoryTabsVisual(book, false)
    TrainerSpells:UpdateClassViewTabs()
end

function TrainerSpells:UpdateClassViewTabs()
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
    local views = {{view = "class", icon = 133741, title = className, desc = "LID_CLASSVIEW_DESC", classToken = classToken}}
    if TrainerSpells:HasPetClassData(classToken) then table.insert(views, {view = "pet", icon = "Interface\\Icons\\Ability_Hunter_BeastCall", title = TrainerSpells:Trans("LID_PETTRAINING"), desc = "LID_PETVIEW_DESC"}) end
    table.insert(views, {view = "trainers", icon = 134269, title = TrainerSpells:Trans("LID_CLASSTRAINERS"), desc = "LID_TRAINERSVIEW_DESC"})
    table.insert(views, {view = "weapons", icon = "Interface\\Icons\\INV_Sword_04", title = _G.WEAPON_SKILLS or "Weapon Skills", desc = "LID_WEAPONVIEW_DESC"})
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
    TrainerSpells:AddContentBorder(panel, classFrame)
    playerSpellsSubTabs.panel = panel
    local title = classFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    local desc = classFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(false)
    desc:SetTextColor(0.75, 0.75, 0.75)
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
    local divider = classFrame:CreateTexture(nil, "ARTWORK")
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

function TrainerSpells:OpenCompendiumView(view)
    if InCombatLockdown and InCombatLockdown() then return end
    if SpellBookFrame then
        if not SpellBookFrame:IsShown() then ShowUIPanel(SpellBookFrame) end
        OpenFrame(view)
        return
    end
    if not PlayerSpellsFrame then
        if C_AddOns and C_AddOns.LoadAddOn then
            C_AddOns.LoadAddOn("Blizzard_PlayerSpells")
        elseif LoadAddOn then
            LoadAddOn("Blizzard_PlayerSpells")
        end
    end
    if not PlayerSpellsFrame then return end
    ShowUIPanel(PlayerSpellsFrame)
    local book = GetPlayerSpellsBook()
    if not book then return end
    if PlayerSpellsFrame.SetTab and PlayerSpellsFrame.spellBookTabID then
        PlayerSpellsFrame:SetTab(PlayerSpellsFrame.spellBookTabID)
    end
    TrainerSpells:SetClassView(view)
    OpenPlayerSpellsPanel()
end

function TrainerSpells:RegisterCompendiumTabs()
    local api = _G["AzerothCompendiumAPI"]
    if type(api) ~= "table" or type(api.RegisterTab) ~= "function" or not self:HasClassTrainers() then return end
    for _, definition in ipairs({
        {"class", "LID_CLASSTRAINER", 133743},
        {"trainers", "LID_CLASSTRAINERS", 135933},
        {"weapons", "LID_WEAPON", 135328}
    }) do
        local view, label = definition[1], definition[2]
        api.RegisterTab("TrainerSpells:" .. view, {
            label = function() return "TrainerSpells: " .. TrainerSpells:Trans(label) end,
            icon = definition[3],
            onClick = function() TrainerSpells:OpenCompendiumView(view) end
        })
    end
end

TrainerSpells.CompendiumLoader = CreateFrame("Frame")
TrainerSpells.CompendiumLoader:RegisterEvent("ADDON_LOADED")
TrainerSpells.CompendiumLoader:RegisterEvent("PLAYER_LOGIN")
TrainerSpells.CompendiumLoader:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == "AzerothCompendium" then TrainerSpells:RegisterCompendiumTabs() end
end)
TrainerSpells:RegisterCompendiumTabs()
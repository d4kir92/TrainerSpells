local _, TrainerSpells = ...
local classFrame = TrainerSpells.ClassFrame
local listBg = TrainerSpells.ClassListBackground
local searchBox = TrainerSpells.SearchBox
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
        searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 66, topOffset)
        searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -4, topOffset)
    else
        searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 10, -6)
        searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -30, -6)
    end
end

if SpellBookFrame then hooksecurefunc(SpellBookFrame, "SetScale", function() if classFrame:IsShown() then PositionFrame() end end) end
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
        if glow then glow:Hide() end
    end
end

local function OpenFrame()
    PositionFrame()
    classFrame:Show()
    HideNativeSpellButtons()
    HideNativeSkillTabGlows()
    if ourTabGlow then ourTabGlow:Show() end
end

if SpellBookFrame and TrainerSpells:HasClassTrainers() then
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
    tab:SetScript("OnEnter", function(sel)
        GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
        GameTooltip:SetText(TrainerSpells:Trans("LID_CLASSTRAINER"))
        GameTooltip:Show()
    end)

    tab:SetScript("OnLeave", GameTooltip_Hide)
    SpellBookFrame:HookScript("OnShow", function() tab:Show() end)
    SpellBookFrame:HookScript("OnHide", function()
        tab:Hide()
        classFrame:Hide()
        ShowNativeSpellButtons()
        if ourTabGlow then ourTabGlow:Hide() end
    end)

    local function OnNativeTabClicked()
        if classFrame:IsShown() then
            classFrame:Hide()
            ShowNativeSpellButtons()
            if ourTabGlow then ourTabGlow:Hide() end
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
local playerSpellsContentHidden = false
local function GetPlayerSpellsBook()
    return PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
end

local function PositionPlayerSpellsFrame()
    local book = GetPlayerSpellsBook()
    if not book then return end
    local content = book.PagedSpellsFrame or book
    classFrame:ClearAllPoints()
    classFrame:SetScale(book:GetScale())
    classFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -50)
    classFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, -8)
    listBg:ClearAllPoints()
    listBg:Hide()
    local showWeaponControls = TrainerSpells.ClassView == "weapons" and TrainerSpells.WeaponControls
    if TrainerSpells.WeaponControls then
        TrainerSpells.WeaponControls:ClearAllPoints()
        TrainerSpells.WeaponControls:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 48, -2)
        TrainerSpells.WeaponControls:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -100, -2)
        TrainerSpells.WeaponControls:SetShown(showWeaponControls and true or false)
    end

    local dividerOffset = showWeaponControls and -35 or -1
    if playerSpellsModeDivider then
        playerSpellsModeDivider:ClearAllPoints()
        playerSpellsModeDivider:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 48, dividerOffset)
        playerSpellsModeDivider:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -100, dividerOffset)
    end

    if TrainerSpells.ClassScrollBox and playerSpellsModeDivider then
        TrainerSpells.ClassScrollBox:ClearAllPoints()
        TrainerSpells.ClassScrollBox:SetPoint("TOPLEFT", playerSpellsModeDivider, "BOTTOMLEFT", 0, -2)
        TrainerSpells.ClassScrollBox:SetPoint("BOTTOMRIGHT", classFrame, "BOTTOMRIGHT", -84, 30)
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

local function HidePlayerSpellsContent()
    local book = GetPlayerSpellsBook()
    if playerSpellsContentHidden or not book then return end
    playerSpellsContentHidden = true
    if book.PagedSpellsFrame then book.PagedSpellsFrame:Hide() end
    if book.SearchBox then book.SearchBox:Hide() end
end

local function ShowPlayerSpellsContent()
    local book = GetPlayerSpellsBook()
    if not playerSpellsContentHidden then return end
    playerSpellsContentHidden = false
    if not book then return end
    if book.PagedSpellsFrame then book.PagedSpellsFrame:Show() end
    if book.SearchBox then book.SearchBox:Show() end
end

local function ClosePlayerSpellsPanel()
    local book = GetPlayerSpellsBook()
    classFrame:Hide()
    ShowPlayerSpellsContent()
    for _, tab in pairs(playerSpellsModeTabs) do
        tab:SetTabSelected(false)
    end

    local tabID = book and book.GetTab and book:GetTab()
    if tabID and book.CategoryTabSystem then book.CategoryTabSystem:SetTabVisuallySelected(tabID) end
end

local function OpenPlayerSpellsPanel()
    if not GetPlayerSpellsBook() then return end
    PositionPlayerSpellsFrame()
    HidePlayerSpellsContent()
    classFrame:Show()
    GetPlayerSpellsBook().CategoryTabSystem:SetTabVisuallySelected(0)
    TrainerSpells:UpdateClassViewTabs()
end

function TrainerSpells:UpdateClassViewTabs()
    for view, tab in pairs(playerSpellsModeTabs) do
        tab:SetTabSelected(TrainerSpells.ClassView == view)
    end
end

local function CreatePlayerSpellsModeTab(container, tabSystem, tabID, view, icon, tooltip, previousTab)
    local tab = CreateFrame("Button", nil, container, "TabSystemButtonTemplate")
    tab.GetTabSystem = function() return tabSystem end
    tab:Init(tabID, nil, icon)
    tab:SetTooltipText(tooltip)
    if previousTab then
        tab:SetPoint("LEFT", previousTab, "RIGHT", 1, 0)
    else
        tab:SetPoint("LEFT", container, "LEFT", 0, 0)
    end

    tab:SetScript("OnClick", function()
        TrainerSpells:SetClassView(view)
        OpenPlayerSpellsPanel()
    end)
    playerSpellsModeTabs[view] = tab
    return tab
end

local function CreatePlayerSpellsModeTabs(book, tabSystem)
    local className, classToken = UnitClass("player")
    local container = CreateFrame("Frame", "TrainerSpellsPlayerSpellsModeTabs", book)
    playerSpellsModeTabContainer = container
    container:SetSize(120, 32)
    container:SetPoint("LEFT", tabSystem, "RIGHT", 8, 0)
    local divider = classFrame:CreateTexture(nil, "ARTWORK")
    playerSpellsModeDivider = divider
    divider:SetAtlas("spellbook-divider")
    divider:SetHeight(11)
    local classTab = CreatePlayerSpellsModeTab(container, tabSystem, 1, "class", 133741, className, nil)
    local classIcon = classTab.Icon or classTab.icon
    local classAtlas = GetClassAtlas and GetClassAtlas(classToken)
    if classIcon and classAtlas then
        classIcon:SetAtlas(classAtlas)
    elseif classIcon and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken] then
        local coords = CLASS_ICON_TCOORDS[classToken]
        classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end

    local previousTab = classTab
    if TrainerSpells:HasPetClassData(classToken) then previousTab = CreatePlayerSpellsModeTab(container, tabSystem, 2, "pet", "Interface\\Icons\\Ability_Hunter_BeastCall", TrainerSpells:Trans("LID_PETTRAINING"), previousTab) end
    CreatePlayerSpellsModeTab(container, tabSystem, 3, "weapons", "Interface\\Icons\\INV_Sword_04", _G.WEAPON_SKILLS or "Weapon Skills", previousTab)
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

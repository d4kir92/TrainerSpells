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

local playerSpellsTab
local playerSpellsTabGlow
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
    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPLEFT", classFrame, "TOPLEFT", 60, 34)
    searchBox:SetPoint("TOPRIGHT", classFrame, "TOPRIGHT", -10, 34)
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
    classFrame:Hide()
    ShowPlayerSpellsContent()
    if playerSpellsTabGlow then playerSpellsTabGlow:Hide() end
end

local function OpenPlayerSpellsPanel()
    if not GetPlayerSpellsBook() then return end
    PositionPlayerSpellsFrame()
    HidePlayerSpellsContent()
    classFrame:Show()
    if playerSpellsTabGlow then playerSpellsTabGlow:Show() end
end

local function InstallPlayerSpellsIntegration()
    local book = GetPlayerSpellsBook()
    if playerSpellsTab or not book then return end
    local tab = CreateFrame("Button", "TrainerSpellsPlayerSpellsTab", book)
    playerSpellsTab = tab
    tab:SetSize(32, 32)
    tab:SetNormalTexture(133741)
    tab:SetHighlightTexture(130718, "ADD")
    playerSpellsTabGlow = tab:CreateTexture(nil, "OVERLAY")
    playerSpellsTabGlow:SetSize(32, 32)
    playerSpellsTabGlow:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    playerSpellsTabGlow:SetTexture(130724)
    playerSpellsTabGlow:SetBlendMode("ADD")
    playerSpellsTabGlow:Hide()
    tab:SetPoint("LEFT", book.CategoryTabSystem or book, "RIGHT", 10, 0)
    tab:SetScript("OnClick", function()
        if classFrame:IsShown() then
            ClosePlayerSpellsPanel()
        else
            OpenPlayerSpellsPanel()
        end
    end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TrainerSpells:Trans("LID_CLASSTRAINER"))
        GameTooltip:Show()
    end)

    tab:SetScript("OnLeave", GameTooltip_Hide)
    book:HookScript("OnHide", ClosePlayerSpellsPanel)
    if book.CategoryTabSystem then hooksecurefunc(book.CategoryTabSystem, "SetTab", ClosePlayerSpellsPanel) end
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

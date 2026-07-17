local _, TrainerSpells = ...
local debug_trainer = false
local function DebugTrainer(fmt, ...)
    if not debug_trainer then return end
    TrainerSpells:MSG(("|cff3399ffTrainerSpells Debug:|r " .. fmt):format(...))
end

TrainerSpells_Data = TrainerSpells_Data or {}
TrainerSpells_Ignored = TrainerSpells_Ignored or {}
TrainerSpells_IgnoredNames = TrainerSpells_IgnoredNames or {}
TrainerSpells_Character = TrainerSpells_Character or {}
TrainerSpells_Character.collapsedGroups = TrainerSpells_Character.collapsedGroups or {}
TrainerSpells_Character.learnedSpellsPet = TrainerSpells_Character.learnedSpellsPet or {}
if TrainerSpells_Character.showIgnoredInTrainer == nil then
    TrainerSpells_Character.showIgnoredInTrainer = false
end

TrainerSpells_Character.rowHeight = TrainerSpells_Character.rowHeight or 16
TrainerSpells_PetData = TrainerSpells_PetData or {}
TrainerSpells_PetTrainerData = TrainerSpells_PetTrainerData or {}
TrainerSpells_ProfessionData = TrainerSpells_ProfessionData or {}
TrainerSpells:SetAddonOutput("TrainerSpells", 133741)
local BEAST_TRAINING_SPELL_ID = 5149
local PET_TRAINER_SKILL_LINE = ""
local trainingSpellInfo = C_Spell.GetSpellInfo(BEAST_TRAINING_SPELL_ID)
if trainingSpellInfo and trainingSpellInfo.name then
    PET_TRAINER_SKILL_LINE = trainingSpellInfo.name
end

local PROFESSION_SKILL_LINES = {}
local PROFESSION_NAME_TO_KEY = {}
local PROFESSION_KEY_TO_NAME = {}
local PROFESSION_SPELLS = {
    ["Alchemy"] = 3101,
    ["Blacksmithing"] = 9785,
    ["Cooking"] = 18260,
    ["Enchanting"] = 7413,
    ["Engineering"] = 4036,
    ["First Aid"] = 7924,
    ["Fishing"] = 7620,
    ["Herbalism"] = 13614,
    ["Leatherworking"] = 10662,
    ["Mining"] = 2575,
    ["Skinning"] = 10768,
    ["Tailoring"] = 3910,
    ["Jewelcrafting"] = 28897,
}

for key, spellID in pairs(PROFESSION_SPELLS) do
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if spellInfo and spellInfo.name then
        PROFESSION_SKILL_LINES[spellInfo.name] = true
        PROFESSION_NAME_TO_KEY[spellInfo.name] = key
        PROFESSION_KEY_TO_NAME[key] = spellInfo.name
    end
end

function TrainerSpells:GetProfessionName(key)
    return PROFESSION_KEY_TO_NAME[key]
end

function TrainerSpells:GetProfessionKey(name)
    return PROFESSION_NAME_TO_KEY[name]
end

local function DetectTrainerProfession()
    if not GetNumTrainerServices or not GetTrainerServiceSkillLine then return nil end
    for i = 1, GetNumTrainerServices() do
        local skillLine = GetTrainerServiceSkillLine(i)
        if skillLine and PROFESSION_SKILL_LINES[skillLine] then return PROFESSION_NAME_TO_KEY[skillLine] or skillLine, skillLine end
    end

    return nil
end

local impId = 688
local voidwalkerId = 697
local succubusId = 712
local incubusId = 101822
local felhunterId = 691
local felguardId = 30146
local PET_SUMMON_SPELL_IDS = {impId, voidwalkerId, succubusId, incubusId, felhunterId, felguardId}
local function CommonAffixLength(a, b, fromEnd)
    local maxLen = math.min(#a, #b)
    local len = 0
    while len < maxLen do
        local posA = fromEnd and (#a - len) or (len + 1)
        local posB = fromEnd and (#b - len) or (len + 1)
        if a:sub(posA, posA) ~= b:sub(posB, posB) then break end
        len = len + 1
    end

    return len
end

local function GetMapLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

local function StripCommonAffixes(names)
    if GetMapLength(names) < 2 then return names end
    local prefixLen, suffixLen = nil, nil
    local firstElement = nil
    for i, v in pairs(names) do
        if firstElement == nil then
            firstElement = v
            prefixLen, suffixLen = #v, #v
        else
            prefixLen = math.min(prefixLen, CommonAffixLength(firstElement, v, false))
            suffixLen = math.min(suffixLen, CommonAffixLength(firstElement, v, true))
        end
    end

    local result = {}
    for i, name in pairs(names) do
        local suffixStart = math.max(prefixLen, #name - suffixLen)
        result[i] = name:sub(prefixLen + 1, suffixStart)
    end

    return result
end

local rawPetSummonNames = {}
for _, spellID in ipairs(PET_SUMMON_SPELL_IDS) do
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if spellInfo and spellInfo.name then
        rawPetSummonNames[spellID] = spellInfo.name
    end
end

local PET_NAMES = StripCommonAffixes(rawPetSummonNames)
function TrainerSpells:GetPetNameById(id)
    return PET_NAMES[id]
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("TRAINER_SHOW")
f:RegisterEvent("TRAINER_UPDATE")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_UPDATE")
f:RegisterEvent("UNIT_PET")
f:RegisterEvent("SPELLS_CHANGED")
local scanTooltip = CreateFrame("GameTooltip", "TrainerSpellsScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
local function GetSpellIDForService(i)
    scanTooltip:ClearLines()
    scanTooltip:SetTrainerService(i)
    local _, spellID = scanTooltip:GetSpell()
    if not spellID then
        local name = GetTrainerServiceInfo(i)
        if name then
            local _, _, _, _, _, _, foundSpellID = GetSpellInfo(name)
            if type(foundSpellID) == "number" and foundSpellID > 0 then
                spellID = foundSpellID
            end
        end
    end

    return spellID
end

local function GetSkillReqForService(i)
    if not GetTrainerServiceSkillReq then return 0 end
    local _, skillReq = GetTrainerServiceSkillReq(i)

    return skillReq or 0
end

local function IsSaneSpellID(spellID)
    return type(spellID) == "number" and spellID > 0 and spellID < 2000000
end

local function ResolveTalentSpellIDByName(name)
    if not GetNumTalentTabs or not GetNumTalents or not GetTalentInfo or not GetTalentLink then return nil end
    for tab = 1, GetNumTalentTabs() do
        for i = 1, GetNumTalents(tab) do
            local talentName = GetTalentInfo(tab, i)
            if talentName == name then
                local link = GetTalentLink(tab, i)
                if link then
                    scanTooltip:ClearLines()
                    scanTooltip:SetHyperlink(link)
                    local _, spellID = scanTooltip:GetSpell()
                    if IsSaneSpellID(spellID) then return spellID end
                end

                return nil
            end
        end
    end
end

local function ResolveRequirementSpellID(name)
    local _, _, _, _, _, _, spellID = GetSpellInfo(name)
    if IsSaneSpellID(spellID) then return spellID end
    spellID = ResolveTalentSpellIDByName(name)
    if IsSaneSpellID(spellID) then return spellID end
    local baseName = name:match("^(.-)%s*%b()$")
    if baseName then
        _, _, _, _, _, _, spellID = GetSpellInfo(baseName)
        if IsSaneSpellID(spellID) then return spellID end
        spellID = ResolveTalentSpellIDByName(baseName)
        if IsSaneSpellID(spellID) then return spellID end
    end
end

local function ParseRequirementText(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local colonPos = text:find(":")
    local reqText = colonPos and text:sub(colonPos + 1) or text
    local spellIDs = {}
    for part in reqText:gmatch("[^,]+") do
        part = part:match("^%s*(.-)%s*$")
        if part ~= "" then
            local spellID = ResolveRequirementSpellID(part)
            if spellID then
                table.insert(spellIDs, spellID)
            end
        end
    end

    if #spellIDs == 0 then return nil end

    return spellIDs
end

local function EnsurePath(class, level)
    TrainerSpells_Data[class] = TrainerSpells_Data[class] or {}
    TrainerSpells_Data[class][level] = TrainerSpells_Data[class][level] or {}

    return TrainerSpells_Data[class][level]
end

local function EnsurePetTrainerPath(class, level)
    TrainerSpells_PetTrainerData[class] = TrainerSpells_PetTrainerData[class] or {}
    TrainerSpells_PetTrainerData[class][level] = TrainerSpells_PetTrainerData[class][level] or {}

    return TrainerSpells_PetTrainerData[class][level]
end

local function EnsureProfessionPath(profession, skillReq)
    TrainerSpells_ProfessionData[profession] = TrainerSpells_ProfessionData[profession] or {}
    TrainerSpells_ProfessionData[profession][skillReq] = TrainerSpells_ProfessionData[profession][skillReq] or {}

    return TrainerSpells_ProfessionData[profession][skillReq]
end

local function ExpandAllTrainerHeaders()
    if not GetNumTrainerServices or not GetTrainerServiceInfo or not ExpandTrainerSkillLine then return end
    local i = 1
    while i <= GetNumTrainerServices() do
        local _, _, category, expanded = GetTrainerServiceInfo(i)
        if category == "header" and not expanded then
            ExpandTrainerSkillLine(i)
        end

        i = i + 1
    end
end

local function CaptureTrainerInner()
    local _, classToken = UnitClass("player")
    local isTradeskill = IsTradeskillTrainer and IsTradeskillTrainer()
    local professionKey, professionSkillLine
    if isTradeskill then
        professionKey, professionSkillLine = DetectTrainerProfession()
    end

    DebugTrainer("CaptureTrainerInner: npcName=%s npcGUID=%s classToken=%s isTradeskill=%s professionKey=%s professionSkillLine=%s", tostring(UnitName("npc")), tostring(UnitGUID and UnitGUID("npc")), tostring(classToken), tostring(isTradeskill), tostring(professionKey), tostring(professionSkillLine))
    if not classToken then
        TrainerSpells:MSG("UnitClass(\"player\") lieferte keinen Klassen-Token.")

        return
    end

    if not GetNumTrainerServices then
        TrainerSpells:ERR("GetNumTrainerServices existiert nicht (API in dieser Client-Version anders).")

        return
    end

    ExpandAllTrainerHeaders()
    local numServices = GetNumTrainerServices()
    DebugTrainer("CaptureTrainerInner: numServices=%d", numServices)
    local neu = 0
    local neuPet = 0
    local neuProf = 0
    local rankFound = false
    local lastDebugSkillLine
    for i = 1, numServices do
        local _, _, sType = GetTrainerServiceInfo(i)
        if sType == "available" or sType == "unavailable" or sType == "used" then
            rankFound = true
            break
        end
    end

    DebugTrainer("CaptureTrainerInner: rankFound=%s", tostring(rankFound))
    if not rankFound then return end
    for i = 1, numServices do
        local name, rankText, sType = GetTrainerServiceInfo(i)
        local rank = rankText and tonumber(rankText:match("%d+"))
        local levelReq = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
        if (rank ~= nil or levelReq ~= nil) and (sType == "available" or sType == "unavailable" or sType == "used") then
            local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
            local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(i)
            if name and professionKey then
                local spellID = GetSpellIDForService(i)
                local icon = GetTrainerServiceIcon and GetTrainerServiceIcon(i)
                local skillReq = GetSkillReqForService(i)
                local bucket = EnsureProfessionPath(professionKey, skillReq)
                local existing = bucket[name]
                if existing == nil then
                    neuProf = neuProf + 1
                end

                bucket[name] = {
                    spellID = spellID,
                    icon = icon,
                    cost = cost,
                    rank = rank,
                    status = sType,
                    levelReq = (levelReq and levelReq > 0) and levelReq or nil,
                    requires = existing and existing.requires,
                    faction = existing and existing.faction
                }
            else
                local spellID = GetSpellIDForService(i)
                if spellID then
                    local isPetTraining = skillLine == PET_TRAINER_SKILL_LINE
                    if skillLine ~= lastDebugSkillLine then
                        lastDebugSkillLine = skillLine
                        DebugTrainer("CaptureTrainerInner: skillLine=%s isPetTraining=%s classToken=%s", tostring(skillLine), tostring(isPetTraining), tostring(classToken))
                    end

                    if isPetTraining then
                        local oldBucket = TrainerSpells_Data[classToken] and TrainerSpells_Data[classToken][levelReq or 0]
                        if oldBucket then
                            oldBucket[spellID] = nil
                        end
                    end

                    local bucket = isPetTraining and EnsurePetTrainerPath(classToken, levelReq or 0) or EnsurePath(classToken, levelReq or 0)
                    local existing = bucket[spellID]
                    if existing == nil then
                        if isPetTraining then
                            neuPet = neuPet + 1
                        else
                            neu = neu + 1
                        end
                    end

                    bucket[spellID] = {
                        cost = cost,
                        rank = rank,
                        status = sType,
                        requires = existing and existing.requires,
                        faction = existing and existing.faction
                    }
                end
            end
        end
    end

    if debug_trainer then
        if neu > 0 then
            TrainerSpells:MSG(("|cff33ff99TrainerSpells:|r %d neue Spell(s) für %s erfasst."):format(neu, classToken))
        end

        if neuPet > 0 then
            TrainerSpells:MSG(("|cff33ff99TrainerSpells:|r %d neue Pet-Trainer-Fähigkeit(en) für %s erfasst."):format(neuPet, classToken))
        end

        if neuProf > 0 then
            TrainerSpells:MSG(("|cff33ff99TrainerSpells:|r %d neue Rezept(e) für %s erfasst."):format(neuProf, professionSkillLine or "Beruf"))
        end
    end
end

local function CaptureTrainer()
    local ok, err = pcall(CaptureTrainerInner)
    if not ok then
        TrainerSpells:ERR("|cffff5555TrainerSpells Fehler:|r " .. tostring(err))
    end
end

local function OnTrainerServiceSelectedInner(id)
    local _, classToken = UnitClass("player")
    if not classToken or not id then return end
    local fs = _G["ClassTrainerSkillRequirements"]
    local text = fs and fs:GetText()
    local requires = text and ParseRequirementText(text)
    if not requires then return end
    local isTradeskill = IsTradeskillTrainer and IsTradeskillTrainer()
    local professionKey
    if isTradeskill then
        professionKey = DetectTrainerProfession()
    end

    local bucket, key
    if professionKey then
        local name = GetTrainerServiceInfo(id)
        local skillReq = GetSkillReqForService(id)
        local profession = TrainerSpells_ProfessionData[professionKey]
        bucket = profession and profession[skillReq]
        key = name
    else
        local spellID = GetSpellIDForService(id)
        if not spellID then return end
        local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(id)
        local levelReq = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(id) or 0
        local isPetTraining = skillLine == PET_TRAINER_SKILL_LINE
        local levels = isPetTraining and TrainerSpells_PetTrainerData[classToken] or TrainerSpells_Data[classToken]
        bucket = levels and levels[levelReq]
        key = spellID
    end

    if bucket and key and bucket[key] then
        bucket[key].requires = requires
        if TrainerSpells_Refresh then
            TrainerSpells_Refresh()
        end

        if TrainerSpells_ProfessionRefresh then
            TrainerSpells_ProfessionRefresh()
        end
    end
end

local function OnTrainerServiceButtonClicked(self)
    local id = self:GetID()
    local ok, err = pcall(OnTrainerServiceSelectedInner, id)
    if not ok then
        TrainerSpells:MSG("|cffff5555TrainerSpells Fehler:|r " .. tostring(err))
    end
end

local hookedTrainerButtons = {}
local function CaptureTrainerRequirements()
    local i = 1
    while _G["ClassTrainerSkill" .. i] do
        local button = _G["ClassTrainerSkill" .. i]
        if not hookedTrainerButtons[button] then
            hookedTrainerButtons[button] = true
            button:HookScript("OnClick", OnTrainerServiceButtonClicked)
        end

        i = i + 1
    end
end

local function BuildCachedSpellIDLookup()
    local _, classToken = UnitClass("player")
    local lookup = {}
    local classData = classToken and TrainerSpells_Data[classToken]
    if not classData then return lookup end
    for _, spells in pairs(classData) do
        for id, data in pairs(spells) do
            local name = GetSpellInfo(id)
            if name then
                lookup[name] = lookup[name] or {}
                local rankNum = type(data) == "table" and tonumber(data.rank) or 0
                lookup[name][rankNum or 0] = id
            end
        end
    end

    return lookup
end

local function BuildVisibleTrainerIndexList()
    local total = GetNumTrainerServices()
    if TrainerSpells_Character.showIgnoredInTrainer then
        local list = {}
        for i = 1, total do
            table.insert(list, i)
        end

        return list
    end

    local cachedSpellIDs = BuildCachedSpellIDLookup()
    local list = {}
    for i = 1, total do
        local name, subText, category = GetTrainerServiceInfo(i)
        local keep = true
        if category and category ~= "header" and name then
            local rankNum = subText and tonumber(subText:match("%d+")) or 0
            local spellID = cachedSpellIDs[name] and cachedSpellIDs[name][rankNum]
            if not spellID then
                spellID = GetSpellIDForService(i)
            end

            if TrainerSpells_IsIgnored(spellID, name) then
                keep = false
            end
        end

        if keep then
            table.insert(list, i)
        end
    end

    return list
end

local function TrainerSpells_ClassTrainerFrame_Update()
    SetPortraitTexture(ClassTrainerFramePortrait, "npc")
    ClassTrainerNameText:SetText(UnitName("npc"))
    ClassTrainerGreetingText:SetText(GetTrainerGreetingText())
    local visibleList = BuildVisibleTrainerIndexList()
    local numTrainerServices = #visibleList
    local skillOffset = FauxScrollFrame_GetOffset(ClassTrainerListScrollFrame)
    if numTrainerServices == 0 then
        ClassTrainerCollapseAllButton:Disable()
    else
        ClassTrainerCollapseAllButton:Enable()
    end

    if not ClassTrainerFrame.selectedService then
        ClassTrainer_HideSkillDetails()
    end

    if IsTradeskillTrainer() then
        ClassTrainer_SetToTradeSkillTrainer()
    else
        ClassTrainer_SetToClassTrainer()
    end

    FauxScrollFrame_Update(ClassTrainerListScrollFrame, numTrainerServices, CLASS_TRAINER_SKILLS_DISPLAYED, CLASS_TRAINER_SKILL_HEIGHT, nil, nil, nil, ClassTrainerSkillHighlightFrame, 293, 316)
    ClassTrainerMoneyFrame:Show()
    ClassTrainerSkillHighlightFrame:Hide()
    for i = 1, CLASS_TRAINER_SKILLS_DISPLAYED do
        local skillIndex = visibleList[i + skillOffset]
        local skillButton = _G["ClassTrainerSkill" .. i]
        local serviceName, serviceSubText, serviceType, isExpanded
        local moneyCost
        if skillIndex then
            serviceName, serviceSubText, serviceType, isExpanded = GetTrainerServiceInfo(skillIndex)
            if not serviceName then
                serviceName = UNKNOWN
            end

            if ClassTrainerListScrollFrame:IsVisible() then
                skillButton:SetWidth(293)
            else
                skillButton:SetWidth(323)
            end

            local skillSubText = _G["ClassTrainerSkill" .. i .. "SubText"]
            if serviceType == "header" then
                local skillText = _G["ClassTrainerSkill" .. i .. "Text"]
                skillText:SetText(serviceName)
                skillText:SetWidth(0)
                skillButton:SetNormalFontObject("GameFontNormal")
                skillSubText:Hide()
                if isExpanded then
                    skillButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                else
                    skillButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                end

                _G["ClassTrainerSkill" .. i .. "Highlight"]:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
            else
                skillButton:ClearNormalTexture()
                _G["ClassTrainerSkill" .. i .. "Highlight"]:SetTexture("")
                local skillText = _G["ClassTrainerSkill" .. i .. "Text"]
                skillText:SetText("  " .. serviceName)
                if serviceSubText and serviceSubText ~= "" then
                    skillSubText:SetText(format(PARENS_TEMPLATE, serviceSubText))
                    skillSubText:SetPoint("LEFT", "ClassTrainerSkill" .. i .. "Text", "RIGHT", 10, 0)
                    skillSubText:Show()
                    skillText:SetWidth(0)
                else
                    skillSubText:Hide()
                    skillText:SetWidth(SKILL_TEXT_WIDTH)
                end

                local _
                moneyCost, _ = GetTrainerServiceCost(skillIndex)
                if serviceType == "available" then
                    skillButton:SetNormalFontObject("GameFontNormalLeftGreen")
                    ClassTrainer_SetSubTextColor(skillButton, 0, 0.6, 0)
                elseif serviceType == "used" then
                    skillButton:SetNormalFontObject("GameFontDisable")
                    ClassTrainer_SetSubTextColor(skillButton, 0.5, 0.5, 0.5)
                else
                    skillButton:SetNormalFontObject("GameFontNormalLeftRed")
                    ClassTrainer_SetSubTextColor(skillButton, 0.6, 0, 0)
                end
            end

            skillButton:SetID(skillIndex)
            skillButton:Show()
            if ClassTrainerFrame.selectedService and GetTrainerSelectionIndex() == skillIndex then
                ClassTrainerSkillHighlightFrame:SetPoint("TOPLEFT", "ClassTrainerSkill" .. i, "TOPLEFT", 0, 0)
                ClassTrainerSkillHighlightFrame:Show()
                skillButton:LockHighlight()
                ClassTrainer_SetSubTextColor(skillButton, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                if moneyCost and moneyCost > 0 then
                    ClassTrainerCostLabel:Show()
                end
            else
                skillButton:UnlockHighlight()
            end
        else
            skillButton:Hide()
        end
    end

    local numHeaders = 0
    local notExpanded = 0
    local showDetails = nil
    for i = 1, numTrainerServices do
        local realIndex = visibleList[i]
        local serviceName, _, serviceType, isExpanded = GetTrainerServiceInfo(realIndex)
        if serviceName and serviceType == "header" then
            numHeaders = numHeaders + 1
            if not isExpanded then
                notExpanded = notExpanded + 1
            end
        end

        if ClassTrainerFrame.selectedService and GetTrainerSelectionIndex() == realIndex then
            showDetails = 1
        end
    end

    if showDetails then
        ClassTrainer_ShowSkillDetails()
    else
        ClassTrainer_HideSkillDetails()
    end

    if notExpanded ~= numHeaders then
        ClassTrainerCollapseAllButton.collapsed = nil
        ClassTrainerCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    else
        ClassTrainerCollapseAllButton.collapsed = 1
        ClassTrainerCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    end
end

local trainerUpdateOverrideInstalled = false
local function EnsureTrainerUpdateOverrideInstalled()
    if trainerUpdateOverrideInstalled then return end
    if not ClassTrainerFrame_Update then return end
    if not TrainerSpells_IsIgnored then return end
    trainerUpdateOverrideInstalled = true
    ClassTrainerFrame_Update = TrainerSpells_ClassTrainerFrame_Update
    ClassTrainerFrame_Update()
end

local trainerFilterHookInstalled = false
local function EnsureTrainerFilterHookInstalled()
    if trainerFilterHookInstalled then return end
    if not ClassTrainerFrame or not ClassTrainerFrame.FilterDropdown then return end
    trainerFilterHookInstalled = true
    local function IsNativeFilterSelected(filter)
        return GetTrainerServiceTypeFilter(filter)
    end

    local function SetNativeFilterSelected(filter)
        ClassTrainerFrame.filterPending = true
        SetTrainerServiceTypeFilter(filter, not GetTrainerServiceTypeFilter(filter))
    end

    local function IsIgnoredFilterSelected()
        return TrainerSpells_Character.showIgnoredInTrainer
    end

    local function SetIgnoredFilterSelected()
        TrainerSpells_Character.showIgnoredInTrainer = not TrainerSpells_Character.showIgnoredInTrainer
        if ClassTrainerFrame_Update then
            ClassTrainerFrame_Update()
        end
    end

    local applyingOwnMenu = false
    local function ApplyOwnMenu()
        applyingOwnMenu = true
        ClassTrainerFrame.FilterDropdown:SetupMenu(
            function(dropdown, rootDescription)
                rootDescription:SetTag("MENU_TRAINER_FILTER")
                rootDescription:CreateCheckbox(GREEN_FONT_COLOR:WrapTextInColorCode(AVAILABLE), IsNativeFilterSelected, SetNativeFilterSelected, "available")
                rootDescription:CreateCheckbox(RED_FONT_COLOR:WrapTextInColorCode(UNAVAILABLE), IsNativeFilterSelected, SetNativeFilterSelected, "unavailable")
                rootDescription:CreateCheckbox(YELLOW_FONT_COLOR:WrapTextInColorCode(TrainerSpells:Trans("LID_IGNORED")), IsIgnoredFilterSelected, SetIgnoredFilterSelected)
                rootDescription:CreateCheckbox(GRAY_FONT_COLOR:WrapTextInColorCode(USED), IsNativeFilterSelected, SetNativeFilterSelected, "used")
            end
        )

        applyingOwnMenu = false
    end

    hooksecurefunc(
        ClassTrainerFrame.FilterDropdown,
        "SetupMenu",
        function()
            if applyingOwnMenu then return end
            ApplyOwnMenu()
        end
    )

    ApplyOwnMenu()
end

local function CountRealTrainerServices()
    local total = GetNumTrainerServices()
    local real = 0
    for i = 1, total do
        local _, _, category = GetTrainerServiceInfo(i)
        if category ~= "header" then
            real = real + 1
        end
    end

    return real
end

local function ScanTrainerServicesStep(button, offset, maxOffset, targetCount, visited, visitedCount)
    if visitedCount >= targetCount or offset > maxOffset then
        FauxScrollFrame_SetOffset(ClassTrainerListScrollFrame, 0)
        ClassTrainerFrame_Update()
        TrainerSpells:MSG(("|cff33ff99TrainerSpells:|r Scan abgeschlossen (%d/%d erfasst)."):format(visitedCount, targetCount))

        return
    end

    FauxScrollFrame_SetOffset(ClassTrainerListScrollFrame, offset)
    ClassTrainerFrame_Update()
    local id = button:GetID()
    if button:IsShown() and id and id >= 1 and not visited[id] then
        local _, _, category = GetTrainerServiceInfo(id)
        if category ~= "header" then
            visited[id] = true
            visitedCount = visitedCount + 1
            button:Click()
        end
    end

    C_Timer.After(
        0.05,
        function()
            ScanTrainerServicesStep(button, offset + 1, maxOffset, targetCount, visited, visitedCount)
        end
    )
end

local function ScanAllTrainerRequirements()
    if not GetNumTrainerServices or not GetTrainerServiceInfo or not ExpandTrainerSkillLine or not ClassTrainerListScrollFrame or not FauxScrollFrame_SetOffset or not ClassTrainerFrame_Update or not C_Timer then
        TrainerSpells:MSG("|cffff5555TrainerSpells:|r Scan nicht möglich, benötigte API fehlt.")

        return
    end

    local button = _G["ClassTrainerSkill1"]
    if not button then
        TrainerSpells:MSG("|cffff5555TrainerSpells:|r Scan nicht möglich, Trainer-Button nicht gefunden.")

        return
    end

    ExpandAllTrainerHeaders()
    local targetCount = CountRealTrainerServices()
    local maxOffset = GetNumTrainerServices() + 200
    TrainerSpells:MSG(("|cff33ff99TrainerSpells:|r Scan gestartet (%d Einträge, das dauert einen Moment)..."):format(targetCount))
    ScanTrainerServicesStep(button, 0, maxOffset, targetCount, {}, 0)
end

local function EnsurePetPath(pet, level)
    TrainerSpells_PetData[pet] = TrainerSpells_PetData[pet] or {}
    TrainerSpells_PetData[pet][level] = TrainerSpells_PetData[pet][level] or {}

    return TrainerSpells_PetData[pet][level]
end

local function MergeBuiltinData()
    if TrainerSpellsBuiltin then
        for class, levels in pairs(TrainerSpellsBuiltin) do
            for level, spells in pairs(levels) do
                local bucket = EnsurePath(class, level)
                for spellID, data in pairs(spells) do
                    if bucket[spellID] == nil then
                        bucket[spellID] = {
                            cost = data.cost or 0,
                            rank = data.rank,
                            faction = data.faction
                        }
                    else
                        if data.cost then
                            bucket[spellID].cost = data.cost
                        end

                        if data.faction and bucket[spellID].faction == nil then
                            bucket[spellID].faction = data.faction
                        end
                    end
                end
            end
        end
    end

    if TrainerSpellsBuiltin_WarlockPet then
        for pet, levels in pairs(TrainerSpellsBuiltin_WarlockPet) do
            for level, spells in pairs(levels) do
                local bucket = EnsurePetPath(pet, level)
                for spellID, data in pairs(spells) do
                    if bucket[spellID] == nil then
                        bucket[spellID] = {
                            cost = data.cost or 0,
                            rank = data.rank,
                            faction = data.faction
                        }
                    else
                        if data.cost then
                            bucket[spellID].cost = data.cost
                        end

                        if data.faction and bucket[spellID].faction == nil then
                            bucket[spellID].faction = data.faction
                        end
                    end
                end
            end
        end
    end

    if TrainerSpellsBuiltin_HunterPet then
        for level, spells in pairs(TrainerSpellsBuiltin_HunterPet) do
            local bucket = EnsurePetTrainerPath("HUNTER", level)
            for spellID, data in pairs(spells) do
                if bucket[spellID] == nil then
                    bucket[spellID] = {
                        cost = data.cost or 0,
                        rank = data.rank,
                        faction = data.faction
                    }
                else
                    if data.cost then
                        bucket[spellID].cost = data.cost
                    end

                    if data.faction and bucket[spellID].faction == nil then
                        bucket[spellID].faction = data.faction
                    end
                end
            end
        end
    end

    if TrainerSpellsBuiltin_Profession then
        for profession, skillLevels in pairs(TrainerSpellsBuiltin_Profession) do
            for skillReq, recipes in pairs(skillLevels) do
                local bucket = EnsureProfessionPath(profession, skillReq)
                for spellID, data in pairs(recipes) do
                    local spellInfo = C_Spell.GetSpellInfo(spellID)
                    local name = spellInfo and spellInfo.name
                    if name then
                        if bucket[name] == nil then
                            bucket[name] = {
                                cost = data.cost or 0,
                                spellID = spellID,
                                icon = data.icon,
                                requires = data.requires,
                                faction = data.faction
                            }
                        else
                            if data.cost then
                                bucket[name].cost = data.cost
                            end

                            if bucket[name].spellID == nil then
                                bucket[name].spellID = spellID
                            end

                            if data.icon and bucket[name].icon == nil then
                                bucket[name].icon = data.icon
                            end

                            if data.requires and bucket[name].requires == nil then
                                bucket[name].requires = data.requires
                            end

                            if data.faction and bucket[name].faction == nil then
                                bucket[name].faction = data.faction
                            end
                        end
                    end
                end
            end
        end
    end
end

local function DetectPetFromTooltip(tooltip)
    for i = 1, tooltip:NumLines() do
        local fs = _G[tooltip:GetName() .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        local petWord = text and text:match("Teaches%s+(%S+)") or text and text:match("Lehrt%s+(%S+)")
        if petWord then
            for _, pet in pairs(PET_NAMES) do
                if petWord:lower() == pet:lower() then return pet end
            end
        end
    end
end

local function CaptureMerchantInner()
    if not GetMerchantNumItems then return end
    local numItems = GetMerchantNumItems()
    local neu = 0
    for i = 1, numItems do
        local itemLink = GetMerchantItemLink(i)
        if itemLink then
            local itemName, _, _, _, itemMinLevel = GetItemInfo(itemLink)
            if itemMinLevel then
                scanTooltip:ClearLines()
                scanTooltip:SetMerchantItem(i)
                local pet = DetectPetFromTooltip(scanTooltip)
                if pet then
                    local _, spellID = scanTooltip:GetSpell()
                    if IsSaneSpellID(spellID) then
                        local _, _, price = GetMerchantItemInfo(i)
                        local rankNum = itemName and tonumber(itemName:match("%(.-(%d+)%)"))
                        local bucket = EnsurePetPath(pet, itemMinLevel)
                        if bucket[spellID] == nil then
                            neu = neu + 1
                        end

                        bucket[spellID] = {
                            cost = price or 0,
                            rank = rankNum,
                        }
                    end
                end
            end
        end
    end

    if neu > 0 then
        TrainerSpells:MSG(("|cff33ff99TrainerSpells:|r %d neue Pet-Fähigkeit(en) erfasst."):format(neu))
    end
end

local function CaptureMerchant()
    local ok, err = pcall(CaptureMerchantInner)
    if not ok then
        TrainerSpells:MSG("|cffff5555TrainerSpells Fehler:|r " .. tostring(err))
    end
end

function TrainerSpells:IsPetSpellKnown(spellID, pet)
    if spellID == nil then return nil end
    spellID = tonumber(spellID)
    if pet and TrainerSpells_Character and TrainerSpells_Character.learnedSpellsPet and TrainerSpells_Character.learnedSpellsPet[pet] and TrainerSpells_Character.learnedSpellsPet[pet][spellID] ~= nil then return TrainerSpells_Character.learnedSpellsPet[pet][spellID] end
    if TrainerSpells_Character and TrainerSpells_Character.learnedSpellsPet then
        for i, data in pairs(TrainerSpells_Character.learnedSpellsPet) do
            if data[spellID] ~= nil then return data[spellID] end
        end
    end

    return nil
end

local function FindPetSpellIDByNameAndRank(pet, spellName, rankNum)
    if not spellName then return nil end
    local levels = TrainerSpells_PetData and TrainerSpells_PetData[pet]
    if not levels then return nil end
    for _, spells in pairs(levels) do
        for spellID, data in pairs(spells) do
            local name = GetSpellInfo(spellID)
            local rank = GetSpellSubtext(spellID)
            local dbRankNum = rank and tonumber(rank:match("%d+"))
            if name == spellName then
                if dbRankNum and rankNum then
                    if dbRankNum == rankNum then return spellID end
                else
                    return spellID
                end
            end
        end
    end
end

GameTooltip:HookScript(
    "OnTooltipSetItem",
    function(self)
        local pet = DetectPetFromTooltip(self)
        local family = UnitCreatureFamily("pet")
        if not pet then return end
        local itemName, itemLink = self:GetItem()
        local rankNum = itemName and tonumber(itemName:match("%(.-(%d+)%)"))
        local spellName = itemLink and C_Item and C_Item.GetItemSpell(itemLink)
        local spellID = FindPetSpellIDByNameAndRank(pet, spellName, rankNum)
        if not spellID then return end
        local isPetSpellKnown = TrainerSpells:IsPetSpellKnown(spellID, family)
        if isPetSpellKnown == true then
            if pet ~= family then
                self:AddLine(TrainerSpells:Trans("LID_ALREADYKNOWN"), 0.9, 0.2, 0.2)
            end
        elseif isPetSpellKnown == false then
            self:AddLine(TrainerSpells:Trans("LID_NOTLEARNEDYET"), 0.2, 0.9, 0.2)
        else
            self:AddLine(TrainerSpells:Trans("LID_NOTSCANNEDYET"), 0.9, 0.9, 0.2)
        end

        self:Show()
    end
)

local function MarkKnownPetSpells(pet, dataTable)
    if not UnitExists("pet") or UnitHealth("pet") <= 0 then return end
    local petSpells = {}
    local i = 1
    while true do
        local name, rank = GetSpellBookItemName(i, BOOKTYPE_PET)
        if not name then break end
        local rankNum = rank and tonumber(rank:match("%d+"))
        petSpells[name] = math.max(petSpells[name] or 0, rankNum or 1)
        i = i + 1
    end

    TrainerSpells_Character.learnedSpellsPet[pet] = TrainerSpells_Character.learnedSpellsPet[pet] or {}
    local changed = false
    for _, spells in pairs(dataTable) do
        for spellID, data in pairs(spells) do
            spellID = tonumber(spellID)
            local info = C_Spell.GetSpellInfo(spellID)
            local name = info and info.name
            local rankNum = type(data) == "table" and tonumber(data.rank)
            local maxKnown = name and petSpells[name]
            if not maxKnown then
                TrainerSpells_Character.learnedSpellsPet[pet][spellID] = false
                changed = true
            elseif rankNum then
                TrainerSpells_Character.learnedSpellsPet[pet][spellID] = rankNum <= maxKnown
                changed = true
            end
        end
    end

    return changed
end

local function SyncKnownPetSpellsForActivePet()
    if not GetSpellInfo or not UnitCreatureFamily then return end
    local family = UnitCreatureFamily("pet")
    local petData = family and TrainerSpells_PetData[family]
    if not petData then return end
    local changed = MarkKnownPetSpells(family, petData)
    if changed and TrainerSpells_Refresh then
        TrainerSpells_Refresh()
    end
end

local captureScheduled = false
local merchantCaptureScheduled = false
local petSyncScheduled = false
f:SetScript(
    "OnEvent",
    function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "TrainerSpells" then
            TrainerSpells_Data = TrainerSpells_Data or {}
            TrainerSpells_Ignored = TrainerSpells_Ignored or {}
            TrainerSpells_IgnoredNames = TrainerSpells_IgnoredNames or {}
            TrainerSpells_Character = TrainerSpells_Character or {}
            TrainerSpells_Character.collapsedGroups = TrainerSpells_Character.collapsedGroups or {}
            TrainerSpells_Character.learnedSpellsPet = TrainerSpells_Character.learnedSpellsPet or {}
            if TrainerSpells_Character.showIgnoredInTrainer == nil then
                TrainerSpells_Character.showIgnoredInTrainer = false
            end

            TrainerSpells_Character.rowHeight = TrainerSpells_Character.rowHeight or 16
            TrainerSpells_PetData = TrainerSpells_PetData or {}
            TrainerSpells_PetTrainerData = TrainerSpells_PetTrainerData or {}
            TrainerSpells_ProfessionData = TrainerSpells_ProfessionData or {}
            TrainerSpells:SetVersion(133741, "0.2.0")
            MergeBuiltinData()
        elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
            do
                local isTradeskill = IsTradeskillTrainer and IsTradeskillTrainer()
                local professionKey, professionSkillLine
                if isTradeskill then
                    professionKey, professionSkillLine = DetectTrainerProfession()
                end

                DebugTrainer("Event %s: npcName=%s npcGUID=%s isTradeskill=%s professionKey=%s professionSkillLine=%s", event, tostring(UnitName("npc")), tostring(UnitGUID and UnitGUID("npc")), tostring(isTradeskill), tostring(professionKey), tostring(professionSkillLine))
            end

            EnsureTrainerUpdateOverrideInstalled()
            EnsureTrainerFilterHookInstalled()
            if debug_trainer and ClassTrainerFrame and TrainerSpellsScanButton == nil then
                local scanButton = CreateFrame("Button", "TrainerSpellsScanButton", ClassTrainerFrame, "UIPanelButtonTemplate")
                scanButton:SetSize(80, 22)
                scanButton:SetText("Scannen")
                scanButton:SetPoint("BOTTOMLEFT", ClassTrainerFrame, "TOPRIGHT", 0, 0)
                scanButton:SetScript(
                    "OnClick",
                    function()
                        local ok, err = pcall(ScanAllTrainerRequirements)
                        if not ok then
                            TrainerSpells:MSG("|cffff5555TrainerSpells Fehler:|r " .. tostring(err))
                        end
                    end
                )
            end

            if C_Timer then
                if not captureScheduled then
                    captureScheduled = true
                    C_Timer.After(
                        0.1,
                        function()
                            captureScheduled = false
                            CaptureTrainer()
                            CaptureTrainerRequirements()
                        end
                    )
                end
            else
                CaptureTrainer()
                CaptureTrainerRequirements()
            end
        elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
            if C_Timer then
                if not merchantCaptureScheduled then
                    merchantCaptureScheduled = true
                    C_Timer.After(
                        0.1,
                        function()
                            merchantCaptureScheduled = false
                            CaptureMerchant()
                        end
                    )
                end
            else
                CaptureMerchant()
            end
        elseif event == "SPELLS_CHANGED" or (event == "UNIT_PET" and arg1 == "player") then
            if C_Timer then
                if not petSyncScheduled then
                    petSyncScheduled = true
                    C_Timer.After(
                        1,
                        function()
                            petSyncScheduled = false
                            SyncKnownPetSpellsForActivePet()
                        end
                    )
                end
            else
                SyncKnownPetSpellsForActivePet()
            end
        end
    end
)

TrainerSpells_Capture = CaptureTrainer
TrainerSpells_CaptureMerchant = CaptureMerchant
TrainerSpells_SyncPetSpells = SyncKnownPetSpellsForActivePet
function TrainerSpells_ToggleIgnoreSpell(spellID)
    spellID = tonumber(spellID)
    local _, classToken = UnitClass("player")
    if not classToken or not spellID then return end
    TrainerSpells_Ignored[classToken] = TrainerSpells_Ignored[classToken] or {}
    local ignored = TrainerSpells_Ignored[classToken]
    if ignored[spellID] then
        ignored[spellID] = nil
    else
        ignored[spellID] = true
    end
end

function TrainerSpells_ToggleIgnoreName(name)
    local _, classToken = UnitClass("player")
    if not classToken or not name then return end
    TrainerSpells_IgnoredNames[classToken] = TrainerSpells_IgnoredNames[classToken] or {}
    local ignored = TrainerSpells_IgnoredNames[classToken]
    if ignored[name] then
        ignored[name] = nil
        local ignoredSpells = TrainerSpells_Ignored[classToken]
        if ignoredSpells then
            for spellID in pairs(ignoredSpells) do
                if GetSpellInfo(spellID) == name then
                    ignoredSpells[spellID] = nil
                end
            end
        end
    else
        ignored[name] = true
    end
end

function TrainerSpells_IsSpellIgnored(spellID)
    spellID = tonumber(spellID)
    local _, classToken = UnitClass("player")
    if not classToken or not spellID then return false end

    return TrainerSpells_Ignored[classToken] and TrainerSpells_Ignored[classToken][spellID] or false
end

function TrainerSpells_IsNameIgnored(name)
    local _, classToken = UnitClass("player")
    if not classToken or not name then return false end

    return TrainerSpells_IgnoredNames[classToken] and TrainerSpells_IgnoredNames[classToken][name] or false
end

function TrainerSpells_IsIgnored(spellID, name)
    return TrainerSpells_IsSpellIgnored(spellID) or TrainerSpells_IsNameIgnored(name)
end

local _, TrainerSpells = ...
local debug_trainer = true
TrainerSpells_Data = TrainerSpells_Data or {}
TrainerSpells_Ignored = TrainerSpells_Ignored or {}
TrainerSpells_IgnoredNames = TrainerSpells_IgnoredNames or {}
TrainerSpells_Character = TrainerSpells_Character or {}
TrainerSpells_Character.collapsedGroups = TrainerSpells_Character.collapsedGroups or {}
TrainerSpells_Character.learnedPetSpells = TrainerSpells_Character.learnedPetSpells or {}
TrainerSpells_PetData = TrainerSpells_PetData or {}
TrainerSpells_PetTrainerData = TrainerSpells_PetTrainerData or {}
local BEAST_TRAINING_SPELL_ID = 5149
local PET_TRAINER_SKILL_LINE = ""
local trainingSpellInfo = C_Spell.GetSpellInfo(BEAST_TRAINING_SPELL_ID)
if trainingSpellInfo and trainingSpellInfo.name then
    PET_TRAINER_SKILL_LINE = trainingSpellInfo.name
end

local PROFESSION_SKILL_LINES = {}
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
    end
end

--688, -- Imp
--697, -- Voidwalker
--712, -- Succubus
--101822, -- Incubus
--691, -- Felhunter
--30146 -- Felguard
local PET_SUMMON_SPELL_IDS = {688, 697, 712, 101822, 691, 30146}
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

    return spellID
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

local function CaptureTrainerInner()
    local _, classToken = UnitClass("player")
    if not classToken then
        print("|cffff5555TrainerSpells:|r UnitClass(\"player\") lieferte keinen Klassen-Token.")

        return
    end

    if not GetNumTrainerServices then
        print("|cffff5555TrainerSpells:|r GetNumTrainerServices existiert nicht (API in dieser Client-Version anders).")

        return
    end

    local numServices = GetNumTrainerServices()
    local neu = 0
    local neuPet = 0
    for i = 1, numServices do
        local _, rankText, sType = GetTrainerServiceInfo(i)
        local rank = rankText and tonumber(rankText:match("%d+"))
        if sType == "available" or sType == "unavailable" or sType == "used" then
            local levelReq = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
            local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
            local spellID = GetSpellIDForService(i)
            local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(i)
            if spellID and not PROFESSION_SKILL_LINES[skillLine] then
                local isPetTraining = skillLine == PET_TRAINER_SKILL_LINE
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
                    requires = existing and existing.requires
                }
            end
        end
    end

    if neu > 0 then
        print(("|cff33ff99TrainerSpells:|r %d neue Spell(s) für %s erfasst."):format(neu, classToken))
    end

    if neuPet > 0 then
        print(("|cff33ff99TrainerSpells:|r %d neue Pet-Trainer-Fähigkeit(en) für %s erfasst."):format(neuPet, classToken))
    end
end

local function CaptureTrainer()
    local ok, err = pcall(CaptureTrainerInner)
    if not ok then
        print("|cffff5555TrainerSpells Fehler:|r " .. tostring(err))
    end
end

local function OnTrainerServiceSelectedInner(id)
    local _, classToken = UnitClass("player")
    if not classToken or not id then return end
    local fs = _G["ClassTrainerSkillRequirements"]
    local text = fs and fs:GetText()
    local requires = text and ParseRequirementText(text)
    if not requires then return end
    local spellID = GetSpellIDForService(id)
    if not spellID then return end
    local levelReq = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(id) or 0
    local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(id)
    local isPetTraining = skillLine == PET_TRAINER_SKILL_LINE
    local levels = isPetTraining and TrainerSpells_PetTrainerData[classToken] or TrainerSpells_Data[classToken]
    local bucket = levels and levels[levelReq]
    if bucket and bucket[spellID] then
        bucket[spellID].requires = requires
        if TrainerSpells_Refresh then
            TrainerSpells_Refresh()
        end
    end
end

local function OnTrainerServiceButtonClicked(self)
    local id = self:GetID()
    local ok, err = pcall(OnTrainerServiceSelectedInner, id)
    if not ok then
        print("|cffff5555TrainerSpells Fehler:|r " .. tostring(err))
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

local function ExpandAllTrainerHeaders()
    local i = 1
    while i <= GetNumTrainerServices() do
        local _, _, category, expanded = GetTrainerServiceInfo(i)
        if category == "header" and not expanded then
            ExpandTrainerSkillLine(i)
        end

        i = i + 1
    end
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
        print(("|cff33ff99TrainerSpells:|r Scan abgeschlossen (%d/%d erfasst)."):format(visitedCount, targetCount))

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
        print("|cffff5555TrainerSpells:|r Scan nicht möglich, benötigte API fehlt.")

        return
    end

    local button = _G["ClassTrainerSkill1"]
    if not button then
        print("|cffff5555TrainerSpells:|r Scan nicht möglich, Trainer-Button nicht gefunden.")

        return
    end

    ExpandAllTrainerHeaders()
    local targetCount = CountRealTrainerServices()
    local maxOffset = GetNumTrainerServices() + 200
    print(("|cff33ff99TrainerSpells:|r Scan gestartet (%d Einträge, das dauert einen Moment)..."):format(targetCount))
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
                            rank = data.rank
                        }
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
                            rank = data.rank
                        }
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
                        rank = data.rank
                    }
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
    if not GetMerchantNumItems or not GetItemSpell then return end
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
                    local _, spellID = GetItemSpell(itemLink)
                    if spellID then
                        local _, _, price = GetMerchantItemInfo(i)
                        local rankNum = itemName and tonumber(itemName:match("%((%d+)%)"))
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
        print(("|cff33ff99TrainerSpells:|r %d neue Pet-Fähigkeit(en) erfasst."):format(neu))
    end
end

local function CaptureMerchant()
    local ok, err = pcall(CaptureMerchantInner)
    if not ok then
        print("|cffff5555TrainerSpells Fehler:|r " .. tostring(err))
    end
end

local function GetKnownPetSpellRanks()
    local known = {}
    if not GetSpellBookItemName then return known end
    local i = 1
    while true do
        local name = GetSpellBookItemName(i, "pet")
        if not name then break end
        local subtext = GetSpellSubtext and GetSpellSubtext(i, "pet")
        local rankNum = (subtext and tonumber(subtext:match("(%d+)"))) or 1
        known[name] = math.max(known[name] or 0, rankNum)
        i = i + 1
    end

    return known
end

local function MarkKnownPetSpells(dataTable, knownRanks)
    local changed = false
    for _, spells in pairs(dataTable) do
        for spellID, data in pairs(spells) do
            if not TrainerSpells_Character.learnedPetSpells[spellID] then
                local name = GetSpellInfo(spellID)
                local rank = type(data) == "table" and data.rank
                local rankNum = (type(rank) == "number" and rank) or (type(rank) == "string" and tonumber(rank:match("%d+"))) or 1
                local maxKnown = name and knownRanks[name]
                if maxKnown and rankNum <= maxKnown then
                    TrainerSpells_Character.learnedPetSpells[spellID] = true
                    changed = true
                end
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
    local knownRanks = GetKnownPetSpellRanks()
    local changed = MarkKnownPetSpells(petData, knownRanks)
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
            TrainerSpells_Character.learnedPetSpells = TrainerSpells_Character.learnedPetSpells or {}
            TrainerSpells_PetData = TrainerSpells_PetData or {}
            TrainerSpells_PetTrainerData = TrainerSpells_PetTrainerData or {}
            MergeBuiltinData()
        elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
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
                            print("|cffff5555TrainerSpells Fehler:|r " .. tostring(err))
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
                        0.1,
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
    else
        ignored[name] = true
    end
end

function TrainerSpells_IsSpellIgnored(spellID)
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

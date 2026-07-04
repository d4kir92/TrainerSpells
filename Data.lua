TrainerSpells_Data = TrainerSpells_Data or {}
TrainerSpells_Ignored = TrainerSpells_Ignored or {}
TrainerSpells_IgnoredNames = TrainerSpells_IgnoredNames or {}
TrainerSpells_Character = TrainerSpells_Character or {}
TrainerSpells_Character.collapsedGroups = TrainerSpells_Character.collapsedGroups or {}
TrainerSpells_Character.learnedPetSpells = TrainerSpells_Character.learnedPetSpells or {}
TrainerSpells_PetData = TrainerSpells_PetData or {}
TrainerSpells_PetTrainerData = TrainerSpells_PetTrainerData or {}
local PET_NAMES = {"Imp", "Voidwalker", "Succubus", "Incubus", "Felhunter"}
local PET_TRAINER_SKILL_LINE = "Beast Training"
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
        local _, rank, sType = GetTrainerServiceInfo(i)
        if sType == "available" or sType == "unavailable" or sType == "used" then
            local levelReq = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
            local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
            local spellID = GetSpellIDForService(i)
            if spellID then
                local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(i)
                local isPetTraining = skillLine == PET_TRAINER_SKILL_LINE
                if isPetTraining then
                    local oldBucket = TrainerSpells_Data[classToken] and TrainerSpells_Data[classToken][levelReq or 0]
                    if oldBucket then
                        oldBucket[spellID] = nil
                    end
                end

                local bucket = isPetTraining and EnsurePetTrainerPath(classToken, levelReq or 0) or EnsurePath(classToken, levelReq or 0)
                if bucket[spellID] == nil then
                    if isPetTraining then
                        neuPet = neuPet + 1
                    else
                        neu = neu + 1
                    end
                end

                bucket[spellID] = {
                    cost = cost,
                    rank = rank,
                    status = sType
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

local function EnsurePetPath(pet, level)
    TrainerSpells_PetData[pet] = TrainerSpells_PetData[pet] or {}
    TrainerSpells_PetData[pet][level] = TrainerSpells_PetData[pet][level] or {}

    return TrainerSpells_PetData[pet][level]
end

local function DetectPetFromTooltip(tooltip)
    for i = 1, tooltip:NumLines() do
        local fs = _G[tooltip:GetName() .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        local petWord = text and text:match("Teaches%s+(%a+)")
        if petWord then
            for _, pet in ipairs(PET_NAMES) do
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
                        local rankNum = itemName and itemName:match("Rank (%d+)")
                        local bucket = EnsurePetPath(pet, itemMinLevel)
                        if bucket[spellID] == nil then
                            neu = neu + 1
                        end

                        bucket[spellID] = {
                            cost = price or 0,
                            rank = rankNum and ("Rank " .. rankNum) or nil,
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
                local rankNum = (rank and tonumber(rank:match("%d+"))) or 1
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
        elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
            if C_Timer then
                if not captureScheduled then
                    captureScheduled = true
                    C_Timer.After(
                        0.1,
                        function()
                            captureScheduled = false
                            CaptureTrainer()
                        end
                    )
                end
            else
                CaptureTrainer()
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

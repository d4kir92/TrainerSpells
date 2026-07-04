TrainerSpells_Data = TrainerSpells_Data or {}
TrainerSpells_Ignored = TrainerSpells_Ignored or {}
TrainerSpells_IgnoredNames = TrainerSpells_IgnoredNames or {}
TrainerSpells_Character = TrainerSpells_Character or {}
TrainerSpells_Character.collapsedGroups = TrainerSpells_Character.collapsedGroups or {}
TrainerSpells_PetData = TrainerSpells_PetData or {}
local PET_NAMES = {"Imp", "Voidwalker", "Succubus", "Incubus", "Felhunter"}
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("TRAINER_SHOW")
f:RegisterEvent("TRAINER_UPDATE")
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_UPDATE")
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
    for i = 1, numServices do
        local _, rank, sType = GetTrainerServiceInfo(i)
        if sType == "available" or sType == "unavailable" or sType == "used" then
            local levelReq = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
            local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
            local spellID = GetSpellIDForService(i)
            if spellID then
                local bucket = EnsurePath(classToken, levelReq or 0)
                if bucket[spellID] == nil then
                    neu = neu + 1
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
                if petWord:lower() == pet:lower() then
                    return pet
                end
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
            local _, _, _, _, itemMinLevel = GetItemInfo(itemLink)
            if itemMinLevel then
                scanTooltip:ClearLines()
                scanTooltip:SetMerchantItem(i)
                local pet = DetectPetFromTooltip(scanTooltip)
                if pet then
                    local spellName, spellID = GetItemSpell(itemLink)
                    if spellID then
                        local _, _, price = GetMerchantItemInfo(i)
                        local rankNum = spellName and spellName:match("Rank (%d+)")
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

local captureScheduled = false
local merchantCaptureScheduled = false
f:SetScript(
    "OnEvent",
    function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName == "TrainerSpells" then
            TrainerSpells_Data = TrainerSpells_Data or {}
            TrainerSpells_Ignored = TrainerSpells_Ignored or {}
            TrainerSpells_IgnoredNames = TrainerSpells_IgnoredNames or {}
            TrainerSpells_Character = TrainerSpells_Character or {}
            TrainerSpells_Character.collapsedGroups = TrainerSpells_Character.collapsedGroups or {}
            TrainerSpells_PetData = TrainerSpells_PetData or {}
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
        end
    end
)

TrainerSpells_Capture = CaptureTrainer
TrainerSpells_CaptureMerchant = CaptureMerchant
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

TrainerSkills_Data = TrainerSkills_Data or {}
TrainerSkills_Ignored = TrainerSkills_Ignored or {}
TrainerSkills_IgnoredNames = TrainerSkills_IgnoredNames or {}
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("TRAINER_SHOW")
f:RegisterEvent("TRAINER_UPDATE")
local scanTooltip = CreateFrame("GameTooltip", "TrainerSkillsScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
local function GetSpellIDForService(i)
    scanTooltip:ClearLines()
    scanTooltip:SetTrainerService(i)
    local _, spellID = scanTooltip:GetSpell()

    return spellID
end

local function EnsurePath(class, level)
    TrainerSkills_Data[class] = TrainerSkills_Data[class] or {}
    TrainerSkills_Data[class][level] = TrainerSkills_Data[class][level] or {}

    return TrainerSkills_Data[class][level]
end

local function CaptureTrainerInner()
    local _, classToken = UnitClass("player")
    if not classToken then
        print("|cffff5555TrainerSkills:|r UnitClass(\"player\") lieferte keinen Klassen-Token.")

        return
    end

    if not GetNumTrainerServices then
        print("|cffff5555TrainerSkills:|r GetNumTrainerServices existiert nicht (API in dieser Client-Version anders).")

        return
    end

    local numServices = GetNumTrainerServices()
    local neu = 0
    for i = 1, numServices do
        local name, rank, sType = GetTrainerServiceInfo(i)
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
        print(("|cff33ff99TrainerSkills:|r %d neue Spell(s) für %s erfasst."):format(neu, classToken))
    end
end

local function CaptureTrainer()
    local ok, err = pcall(CaptureTrainerInner)
    if not ok then
        print("|cffff5555TrainerSkills Fehler:|r " .. tostring(err))
    end
end

local captureScheduled = false
f:SetScript(
    "OnEvent",
    function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName == "TrainerSkills" then
            TrainerSkills_Data = TrainerSkills_Data or {}
            TrainerSkills_Ignored = TrainerSkills_Ignored or {}
            TrainerSkills_IgnoredNames = TrainerSkills_IgnoredNames or {}
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
        end
    end
)

TrainerSkills_Capture = CaptureTrainer
function TrainerSkills_ToggleIgnoreSpell(spellID)
    local _, classToken = UnitClass("player")
    if not classToken or not spellID then return end
    TrainerSkills_Ignored[classToken] = TrainerSkills_Ignored[classToken] or {}
    local ignored = TrainerSkills_Ignored[classToken]
    if ignored[spellID] then
        ignored[spellID] = nil
    else
        ignored[spellID] = true
    end
end

function TrainerSkills_ToggleIgnoreName(name)
    local _, classToken = UnitClass("player")
    if not classToken or not name then return end
    TrainerSkills_IgnoredNames[classToken] = TrainerSkills_IgnoredNames[classToken] or {}
    local ignored = TrainerSkills_IgnoredNames[classToken]
    if ignored[name] then
        ignored[name] = nil
    else
        ignored[name] = true
    end
end

function TrainerSkills_IsSpellIgnored(spellID)
    local _, classToken = UnitClass("player")
    if not classToken or not spellID then return false end

    return TrainerSkills_Ignored[classToken] and TrainerSkills_Ignored[classToken][spellID] or false
end

function TrainerSkills_IsNameIgnored(name)
    local _, classToken = UnitClass("player")
    if not classToken or not name then return false end

    return TrainerSkills_IgnoredNames[classToken] and TrainerSkills_IgnoredNames[classToken][name] or false
end

function TrainerSkills_IsIgnored(spellID, name)
    return TrainerSkills_IsSpellIgnored(spellID) or TrainerSkills_IsNameIgnored(name)
end

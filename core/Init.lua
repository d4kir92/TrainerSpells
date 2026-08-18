local _, TrainerSpells = ...
TrainerSpells.DebugTrainerEnabled = false
function TrainerSpells:DebugTrainer(fmt, ...)
    if not TrainerSpells.DebugTrainerEnabled then return end
    TrainerSpells:MSG(("|cff3399ffTrainerSpells Debug:|r " .. fmt):format(...))
end

local _, _, _, tocVersion = GetBuildInfo()
local INTERFACE_VERSION = tonumber(tocVersion) or 0
local FIRST_VERSION_WITHOUT_CLASS_TRAINERS = 50000
function TrainerSpells:HasClassTrainers()
    return INTERFACE_VERSION < FIRST_VERSION_WITHOUT_CLASS_TRAINERS
end

TrainerSpells_Data = TrainerSpells_Data or {}
TrainerSpells_Ignored = TrainerSpells_Ignored or {}
TrainerSpells_IgnoredNames = TrainerSpells_IgnoredNames or {}
TrainerSpells_IgnoredProfessions = TrainerSpells_IgnoredProfessions or {}
TrainerSpells_Character = TrainerSpells_Character or {}
TrainerSpells_Character.collapsedGroups = TrainerSpells_Character.collapsedGroups or {}
TrainerSpells_Character.learnedSpellsPet = TrainerSpells_Character.learnedSpellsPet or {}
if TrainerSpells_Character.showIgnoredInTrainer == nil then TrainerSpells_Character.showIgnoredInTrainer = false end
TrainerSpells_Character.rowHeight = TrainerSpells_Character.rowHeight or 16
TrainerSpells_PetData = TrainerSpells_PetData or {}
TrainerSpells_PetTrainerData = TrainerSpells_PetTrainerData or {}
TrainerSpells_ProfessionData = TrainerSpells_ProfessionData or {}
TrainerSpells_RecipeData = TrainerSpells_RecipeData or {}
TrainerSpells:SetAddonOutput("TrainerSpells", 133741)
local BEAST_TRAINING_SPELL_ID = 5149
local PET_TRAINER_SKILL_LINE = ""
local trainingSpellInfo = C_Spell.GetSpellInfo(BEAST_TRAINING_SPELL_ID)
if trainingSpellInfo and trainingSpellInfo.name then PET_TRAINER_SKILL_LINE = trainingSpellInfo.name end
local PROFESSION_SKILL_LINES = {}
local PROFESSION_NAME_TO_KEY = {}
local PROFESSION_KEY_TO_NAME = {}
local PROFESSION_SPELLS = {
    ["Alchemy"] = 3101,
    ["Archaeology"] = 78670,
    ["Blacksmithing"] = 9785,
    ["Cooking"] = 18260,
    ["Enchanting"] = 7413,
    ["Engineering"] = 4036,
    ["First Aid"] = 7924,
    ["Fishing"] = 7620,
    ["Herbalism"] = 13614,
    ["Inscription"] = 45357,
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

function TrainerSpells:DetectTrainerProfession()
    if not GetNumTrainerServices or not GetTrainerServiceSkillLine then return nil end
    for i = 1, GetNumTrainerServices() do
        local skillLine = GetTrainerServiceSkillLine(i)
        if skillLine and PROFESSION_SKILL_LINES[skillLine] then return PROFESSION_NAME_TO_KEY[skillLine] or skillLine, skillLine end
    end
    return nil
end

function TrainerSpells:IsPetTrainerSkillLine(skillLine)
    return skillLine == PET_TRAINER_SKILL_LINE
end

TrainerSpells.ScanTooltip = CreateFrame("GameTooltip", "TrainerSpellsScanTooltip", nil, "GameTooltipTemplate")
TrainerSpells.ScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
function TrainerSpells:IsSaneSpellID(spellID)
    return type(spellID) == "number" and spellID > 0 and spellID < 2000000
end

function TrainerSpells:GetSpellIDForService(i)
    local scanTooltip = TrainerSpells.ScanTooltip
    scanTooltip:ClearLines()
    scanTooltip:SetTrainerService(i)
    local _, spellID = scanTooltip:GetSpell()
    if not spellID then
        local name = GetTrainerServiceInfo(i)
        if name then
            local _, _, _, _, _, _, foundSpellID = GetSpellInfo(name)
            if type(foundSpellID) == "number" and foundSpellID > 0 then spellID = foundSpellID end
        end
    end
    return spellID
end

function TrainerSpells:GetSkillReqForService(i)
    if not GetTrainerServiceSkillReq then return 0 end
    local _, skillReq = GetTrainerServiceSkillReq(i)
    return skillReq or 0
end

function TrainerSpells:ExpandAllTrainerHeaders()
    if not GetNumTrainerServices or not GetTrainerServiceInfo or not ExpandTrainerSkillLine then return end
    local i = 1
    while i <= GetNumTrainerServices() do
        local _, _, category, expanded = GetTrainerServiceInfo(i)
        if category == "header" and not expanded then ExpandTrainerSkillLine(i) end
        i = i + 1
    end
end

function TrainerSpells:EnsurePath(class, level)
    TrainerSpells_Data[class] = TrainerSpells_Data[class] or {}
    TrainerSpells_Data[class][level] = TrainerSpells_Data[class][level] or {}
    return TrainerSpells_Data[class][level]
end

function TrainerSpells:EnsurePetTrainerPath(class, level)
    TrainerSpells_PetTrainerData[class] = TrainerSpells_PetTrainerData[class] or {}
    TrainerSpells_PetTrainerData[class][level] = TrainerSpells_PetTrainerData[class][level] or {}
    return TrainerSpells_PetTrainerData[class][level]
end

function TrainerSpells:EnsureProfessionPath(profession, skillReq)
    TrainerSpells_ProfessionData[profession] = TrainerSpells_ProfessionData[profession] or {}
    TrainerSpells_ProfessionData[profession][skillReq] = TrainerSpells_ProfessionData[profession][skillReq] or {}
    return TrainerSpells_ProfessionData[profession][skillReq]
end

function TrainerSpells:EnsureRecipePath(profession, skillReq)
    TrainerSpells_RecipeData[profession] = TrainerSpells_RecipeData[profession] or {}
    TrainerSpells_RecipeData[profession][skillReq] = TrainerSpells_RecipeData[profession][skillReq] or {}
    return TrainerSpells_RecipeData[profession][skillReq]
end

function TrainerSpells:EnsurePetPath(pet, level)
    TrainerSpells_PetData[pet] = TrainerSpells_PetData[pet] or {}
    TrainerSpells_PetData[pet][level] = TrainerSpells_PetData[pet][level] or {}
    return TrainerSpells_PetData[pet][level]
end

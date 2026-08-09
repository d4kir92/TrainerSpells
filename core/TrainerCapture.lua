local _, TrainerSpells = ...
local function ResolveTalentSpellIDByName(name)
    if not GetNumTalentTabs or not GetNumTalents or not GetTalentInfo or not GetTalentLink then return nil end
    for tab = 1, GetNumTalentTabs() do
        for i = 1, GetNumTalents(tab) do
            local talentName = GetTalentInfo(tab, i)
            if talentName == name then
                local link = GetTalentLink(tab, i)
                if link then
                    local scanTooltip = TrainerSpells.ScanTooltip
                    scanTooltip:ClearLines()
                    scanTooltip:SetHyperlink(link)
                    local _, spellID = scanTooltip:GetSpell()
                    if TrainerSpells:IsSaneSpellID(spellID) then return spellID end
                end
                return nil
            end
        end
    end
end

local function ResolveRequirementSpellID(name)
    local _, _, _, _, _, _, spellID = GetSpellInfo(name)
    if TrainerSpells:IsSaneSpellID(spellID) then return spellID end
    spellID = ResolveTalentSpellIDByName(name)
    if TrainerSpells:IsSaneSpellID(spellID) then return spellID end
    local baseName = name:match("^(.-)%s*%b()$")
    if baseName then
        _, _, _, _, _, _, spellID = GetSpellInfo(baseName)
        if TrainerSpells:IsSaneSpellID(spellID) then return spellID end
        spellID = ResolveTalentSpellIDByName(baseName)
        if TrainerSpells:IsSaneSpellID(spellID) then return spellID end
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
            if spellID then table.insert(spellIDs, spellID) end
        end
    end

    if #spellIDs == 0 then return nil end
    return spellIDs
end

local function CaptureTrainerInner()
    local _, classToken = UnitClass("player")
    local isTradeskill = IsTradeskillTrainer and IsTradeskillTrainer()
    local professionKey, professionSkillLine
    if isTradeskill then professionKey, professionSkillLine = TrainerSpells:DetectTrainerProfession() end
    TrainerSpells:DebugTrainer("CaptureTrainerInner: npcName=%s npcGUID=%s classToken=%s isTradeskill=%s professionKey=%s professionSkillLine=%s", tostring(UnitName("npc")), tostring(UnitGUID and UnitGUID("npc")), tostring(classToken), tostring(isTradeskill), tostring(professionKey), tostring(professionSkillLine))
    if not classToken then
        TrainerSpells:MSG("UnitClass(\"player\") lieferte keinen Klassen-Token.")
        return
    end

    if not GetNumTrainerServices then
        TrainerSpells:ERR("GetNumTrainerServices existiert nicht (API in dieser Client-Version anders).")
        return
    end

    TrainerSpells:ExpandAllTrainerHeaders()
    local numServices = GetNumTrainerServices()
    TrainerSpells:DebugTrainer("CaptureTrainerInner: numServices=%d", numServices)
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

    TrainerSpells:DebugTrainer("CaptureTrainerInner: rankFound=%s", tostring(rankFound))
    if not rankFound then return end
    for i = 1, numServices do
        local name, rankText, sType = GetTrainerServiceInfo(i)
        local rank = rankText and tonumber(rankText:match("%d+"))
        local levelReq = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
        if (rank ~= nil or levelReq ~= nil) and (sType == "available" or sType == "unavailable" or sType == "used") then
            local cost = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
            local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(i)
            if name and professionKey then
                local spellID = TrainerSpells:GetSpellIDForService(i)
                local icon = GetTrainerServiceIcon and GetTrainerServiceIcon(i)
                local skillReq = TrainerSpells:GetSkillReqForService(i)
                local bucket = TrainerSpells:EnsureProfessionPath(professionKey, skillReq)
                local existing = bucket[name]
                if existing == nil then neuProf = neuProf + 1 end
                bucket[name] = {
                    spellID = spellID,
                    icon = icon,
                    cost = cost,
                    rank = rank,
                    status = sType,
                    levelReq = (levelReq and levelReq > 0) and levelReq or nil,
                    requires = existing and existing.requires,
                    faction = existing and existing.faction,
                    race = existing and existing.race
                }
            else
                local spellID = TrainerSpells:GetSpellIDForService(i)
                if spellID then
                    local isPetTraining = TrainerSpells:IsPetTrainerSkillLine(skillLine)
                    if skillLine ~= lastDebugSkillLine then
                        lastDebugSkillLine = skillLine
                        TrainerSpells:DebugTrainer("CaptureTrainerInner: skillLine=%s isPetTraining=%s classToken=%s", tostring(skillLine), tostring(isPetTraining), tostring(classToken))
                    end

                    if isPetTraining then
                        local oldBucket = TrainerSpells_Data[classToken] and TrainerSpells_Data[classToken][levelReq or 0]
                        if oldBucket then oldBucket[spellID] = nil end
                    end

                    local bucket = isPetTraining and TrainerSpells:EnsurePetTrainerPath(classToken, levelReq or 0) or TrainerSpells:EnsurePath(classToken, levelReq or 0)
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
                        faction = existing and existing.faction,
                        race = existing and existing.race
                    }
                end
            end
        end
    end

    if TrainerSpells.DebugTrainerEnabled then
        if neu > 0 then TrainerSpells:MSG(("|cff33ff99TrainerSpells:|r %d neue Spell(s) für %s erfasst."):format(neu, classToken)) end
        if neuPet > 0 then TrainerSpells:MSG(("|cff33ff99TrainerSpells:|r %d neue Pet-Trainer-Fähigkeit(en) für %s erfasst."):format(neuPet, classToken)) end
        if neuProf > 0 then TrainerSpells:MSG(("|cff33ff99TrainerSpells:|r %d neue Rezept(e) für %s erfasst."):format(neuProf, professionSkillLine or "Beruf")) end
    end
end

function TrainerSpells:CaptureTrainer()
    local ok, err = pcall(CaptureTrainerInner)
    if not ok then TrainerSpells:ERR("|cffff5555TrainerSpells Fehler:|r " .. tostring(err)) end
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
    if isTradeskill then professionKey = TrainerSpells:DetectTrainerProfession() end
    local bucket, key
    if professionKey then
        local name = GetTrainerServiceInfo(id)
        local skillReq = TrainerSpells:GetSkillReqForService(id)
        local profession = TrainerSpells_ProfessionData[professionKey]
        bucket = profession and profession[skillReq]
        key = name
    else
        local spellID = TrainerSpells:GetSpellIDForService(id)
        if not spellID then return end
        local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(id)
        local levelReq = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(id) or 0
        local isPetTraining = TrainerSpells:IsPetTrainerSkillLine(skillLine)
        local levels = isPetTraining and TrainerSpells_PetTrainerData[classToken] or TrainerSpells_Data[classToken]
        bucket = levels and levels[levelReq]
        key = spellID
    end

    if bucket and key and bucket[key] then
        bucket[key].requires = requires
        if TrainerSpells_Refresh then TrainerSpells_Refresh() end
        if TrainerSpells_ProfessionRefresh then TrainerSpells_ProfessionRefresh() end
    end
end

local function OnTrainerServiceButtonClicked(self)
    local id = self:GetID()
    local ok, err = pcall(OnTrainerServiceSelectedInner, id)
    if not ok then TrainerSpells:MSG("|cffff5555TrainerSpells Fehler:|r " .. tostring(err)) end
end

local hookedTrainerButtons = {}
function TrainerSpells:CaptureTrainerRequirements()
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

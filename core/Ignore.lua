local _, TrainerSpells = ...
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
                if GetSpellInfo(spellID) == name then ignoredSpells[spellID] = nil end
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

function TrainerSpells_IsProfessionSpellIgnored(spellID)
    spellID = tonumber(spellID)
    local _, classToken = UnitClass("player")
    if not classToken or not spellID then return false end
    local professionKey, _ = TrainerSpells:DetectTrainerProfession()
    if not professionKey then return false end
    TrainerSpells_IgnoredProfessions[professionKey] = TrainerSpells_IgnoredProfessions[professionKey] or {}
    local ignored = TrainerSpells_IgnoredProfessions[professionKey]
    return ignored[spellID] or false
end

function TrainerSpells_ToggleIgnoreProfessionSpell(spellID)
    spellID = tonumber(spellID)
    local _, classToken = UnitClass("player")
    if not classToken or not spellID then return end
    local professionKey, _ = TrainerSpells:DetectTrainerProfession()
    if not professionKey then return end
    TrainerSpells_IgnoredProfessions[professionKey] = TrainerSpells_IgnoredProfessions[professionKey] or {}
    local ignored = TrainerSpells_IgnoredProfessions[professionKey]
    if ignored[spellID] then
        ignored[spellID] = nil
    else
        ignored[spellID] = true
    end

    if TrainerSpells_ProfessionRefresh then TrainerSpells_ProfessionRefresh() end
end

local _, TrainerSpells = ...
function TrainerSpells:AddHeaderItem(items, text, colorCode, totalCost, groupKey, prefixText)
    table.insert(items, {
        isHeader = true,
        text = text,
        color = colorCode,
        totalCost = totalCost,
        groupKey = groupKey,
        collapsed = TrainerSpells:IsGroupCollapsed(groupKey),
        prefixText = prefixText
    })
end

function TrainerSpells:AddEntryItems(items, list, colorCode, showLevel, showCostTooltip, dimName, levelLabel)
    for _, entry in ipairs(list) do
        table.insert(items, {
            isHeader = false,
            entry = entry,
            color = colorCode,
            showLevel = showLevel,
            showCostTooltip = showCostTooltip,
            dimName = dimName,
            levelLabel = levelLabel,
        })
    end
end

function TrainerSpells:SumCost(list)
    local total = 0
    for _, entry in ipairs(list) do
        total = total + (entry.cost or 0)
    end
    return total
end

function TrainerSpells:BuildEntriesFromData(dataTable)
    local allEntries = {}
    local knownMaxRank = {}
    local playerFaction = TrainerSpells:GetPlayerFaction()
    local playerRace = TrainerSpells:GetPlayerRace()
    for lvl, spells in pairs(dataTable) do
        for key, data in pairs(spells) do
            local cost, rank, status, requires, faction, race, spellID, icon, levelReq
            local source
            if type(data) == "table" then
                cost, rank, status, requires, faction, race = data.cost, data.rank, data.status, data.requires, data.faction, data.race
                spellID, icon, levelReq = data.spellID, data.icon, data.levelReq
                source = data.source
            else
                cost = data
            end

            local raceMatches = true
            if race and playerRace then
                if type(race) == "table" then
                    raceMatches = false
                    for _, r in ipairs(race) do
                        if r == playerRace then raceMatches = true break end
                    end
                else
                    raceMatches = race == playerRace
                end
            end

            if (not faction or not playerFaction or faction == playerFaction) and raceMatches then
                local name
                if type(key) == "number" then
                    spellID = spellID or key
                    name, _, icon = GetSpellInfo(key)
                else
                    name = key
                end

                name = name or ("SpellID " .. tostring(key))
                if not icon and spellID then
                    local _, _, resolvedIcon = GetSpellInfo(spellID)
                    icon = resolvedIcon
                end

                icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
                local hasRealRank = (type(rank) == "number") or (type(rank) == "string" and rank:match("%d+") ~= nil)
                local rankNum = (type(rank) == "number" and rank) or (type(rank) == "string" and tonumber(rank:match("%d+"))) or 1
                local isLearnedPetSpell = spellID and TrainerSpells:IsPetSpellKnown(spellID)
                local directlyKnown = (spellID and IsPlayerSpell and IsPlayerSpell(spellID)) or isLearnedPetSpell or status == "used"
                local entry = {
                    level = lvl,
                    key = key,
                    spellID = spellID,
                    cost = cost,
                    name = name,
                    icon = icon,
                    rankNum = rankNum,
                    hasRealRank = hasRealRank,
                    directlyKnown = directlyKnown,
                    requires = requires,
                    levelReq = levelReq,
                    source = source,
                }

                table.insert(allEntries, entry)
                if directlyKnown and hasRealRank then knownMaxRank[name] = math.max(knownMaxRank[name] or 0, rankNum) end
            end
        end
    end
    return allEntries, knownMaxRank
end

function TrainerSpells:ClassifyEntries(dataTable, searchText, selectedLevel, skipTalentCheck, professionKey)
    local allEntries, knownMaxRank = TrainerSpells:BuildEntriesFromData(dataTable)
    local talentNames, learnedTalents
    if not skipTalentCheck then talentNames, learnedTalents = TrainerSpells:GetTalentNameSet() end
    local ignored, known, remaining = {}, {}, {}
    for _, entry in ipairs(allEntries) do
        if TrainerSpells:EntryMatchesSearch(entry, searchText) then
            local isProfessionIgnored = TrainerSpells_IsProfessionSpellIgnored and TrainerSpells_IsProfessionSpellIgnored(entry.spellID, professionKey)
            if (TrainerSpells_IsIgnored and TrainerSpells_IsIgnored(entry.spellID, entry.name)) or isProfessionIgnored then
                table.insert(ignored, entry)
            else
                local maxKnown = knownMaxRank[entry.name] or 0
                local isKnown = entry.directlyKnown or (entry.hasRealRank and entry.rankNum <= maxKnown)
                if isKnown then
                    table.insert(known, entry)
                else
                    table.insert(remaining, entry)
                end
            end
        end
    end

    local available, missingTalents, future = {}, {}, {}
    for _, entry in ipairs(remaining) do
        local looksTalentGated = talentNames and ((talentNames[entry.name] and not learnedTalents[entry.name]) or TrainerSpells:RequiresUnknownTalent(entry, talentNames, learnedTalents))
        if looksTalentGated then
            table.insert(missingTalents, entry)
        elseif entry.level > selectedLevel then
            table.insert(future, entry)
        else
            table.insert(available, entry)
        end
    end

    local nextLevel
    for _, entry in ipairs(future) do
        if not nextLevel or entry.level < nextLevel then nextLevel = entry.level end
    end

    local soon, higher = {}, {}
    for _, entry in ipairs(future) do
        if entry.level == nextLevel then
            table.insert(soon, entry)
        else
            table.insert(higher, entry)
        end
    end

    TrainerSpells:SortEntries(available)
    TrainerSpells:SortEntries(missingTalents)
    TrainerSpells:SortEntries(ignored)
    TrainerSpells:SortEntries(soon)
    TrainerSpells:SortEntries(higher)
    TrainerSpells:SortEntries(known)
    return {
        available = available,
        soon = soon,
        higher = higher,
        missingTalents = missingTalents,
        ignored = ignored,
        known = known,
        nextLevel = nextLevel,
    }
end

function TrainerSpells:AppendGroupItems(items, groups, keyPrefix, labelPrefix, unitLabel, showCost)
    local Colors = TrainerSpells.UIColors
    if showCost == nil then showCost = true end
    local entryLevelLabel = unitLabel and unitLabel ~= TrainerSpells:Trans("LID_LVL") and unitLabel or nil
    unitLabel = unitLabel or TrainerSpells:Trans("LID_LVL")
    if #groups.available > 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_AVAILABLENOW"), Colors.AVAILABLE, showCost and TrainerSpells:SumCost(groups.available) or nil, keyPrefix .. "available", labelPrefix)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "available") then TrainerSpells:AddEntryItems(items, groups.available, Colors.AVAILABLE, true, showCost, false, entryLevelLabel) end
    end

    if #groups.soon > 0 then
        TrainerSpells:AddHeaderItem(items, ("%s (%s %d)"):format(TrainerSpells:Trans("LID_COMINGSOON"), unitLabel, groups.nextLevel), Colors.SOON, showCost and TrainerSpells:SumCost(groups.soon) or nil, keyPrefix .. "soon", labelPrefix)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "soon") then TrainerSpells:AddEntryItems(items, groups.soon, Colors.SOON, true, showCost, false, entryLevelLabel) end
    end

    if #groups.higher > 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_NOTYETAVAILABLE"), Colors.NOTYET, showCost and TrainerSpells:SumCost(groups.higher) or nil, keyPrefix .. "higher", labelPrefix)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "higher") then TrainerSpells:AddEntryItems(items, groups.higher, Colors.NOTYET, true, showCost, false, entryLevelLabel) end
    end

    if #groups.missingTalents > 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_MISSINGREQUIREDTALENTS"), Colors.TALENT, showCost and TrainerSpells:SumCost(groups.missingTalents) or nil, keyPrefix .. "missingTalents", labelPrefix)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "missingTalents") then TrainerSpells:AddEntryItems(items, groups.missingTalents, Colors.TALENT, true, showCost, false, entryLevelLabel) end
    end

    if #groups.ignored > 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_IGNORED"), Colors.IGNORED, nil, keyPrefix .. "ignored", labelPrefix)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "ignored") then TrainerSpells:AddEntryItems(items, groups.ignored, Colors.IGNORED, true, showCost, true, entryLevelLabel) end
    end

    if #groups.known > 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_ALREADYKNOWN"), Colors.KNOWN, showCost and TrainerSpells:SumCost(groups.known) or nil, keyPrefix .. "known", labelPrefix)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "known") then TrainerSpells:AddEntryItems(items, groups.known, Colors.KNOWN, true, showCost, true, entryLevelLabel) end
    end
end

local function MergePetData(keys)
    local merged = {}
    for _, key in ipairs(keys) do
        local data = TrainerSpells_PetData and TrainerSpells_PetData[key]
        if data then
            for lvl, spells in pairs(data) do
                merged[lvl] = merged[lvl] or {}
                for spellID, entryData in pairs(spells) do
                    merged[lvl][spellID] = entryData
                end
            end
        end
    end
    return merged
end

function TrainerSpells:AppendPetAbilities(items, searchText, selectedLevel)
    local Colors = TrainerSpells.UIColors
    local petItems = {}
    for _, petGroup in ipairs(TrainerSpells.PetGroups) do
        local merged = MergePetData(petGroup.keys)
        if next(merged) then
            local groupKey = "pet_" .. table.concat(petGroup.keys, "_")
            local groups = TrainerSpells:ClassifyEntries(merged, searchText, selectedLevel, true)
            local subItems = {}
            TrainerSpells:AppendGroupItems(subItems, groups, groupKey .. "_", petGroup.label)
            if #subItems > 0 then
                TrainerSpells:AddHeaderItem(petItems, petGroup.label, Colors.PET_HEADER, nil, groupKey)
                if not TrainerSpells:IsGroupCollapsed(groupKey) then
                    for _, item in ipairs(subItems) do
                        table.insert(petItems, item)
                    end
                end
            end
        end
    end

    if #petItems > 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_PETTRAINING"), Colors.PET_HEADER, nil, "petAbilities")
        if not TrainerSpells:IsGroupCollapsed("petAbilities") then
            for _, item in ipairs(petItems) do
                table.insert(items, item)
            end
        end
    end
end

function TrainerSpells:AppendPetTrainerAbilities(items, searchText, selectedLevel, classToken)
    local petTrainerData = TrainerSpells_PetTrainerData and TrainerSpells_PetTrainerData[classToken]
    if not petTrainerData or not next(petTrainerData) then return end
    local groups = TrainerSpells:ClassifyEntries(petTrainerData, searchText, selectedLevel, true)
    local subItems = {}
    TrainerSpells:AppendGroupItems(subItems, groups, "pettrainer_")
    if #subItems == 0 then return end
    TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_PETTRAINING"), TrainerSpells.UIColors.PET_HEADER, nil, "petTraining")
    if not TrainerSpells:IsGroupCollapsed("petTraining") then
        for _, item in ipairs(subItems) do
            table.insert(items, item)
        end
    end
end

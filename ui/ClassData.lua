local _, TrainerSpells = ...
function TrainerSpells:AddHeaderItem(items, text, colorCode, totalCost, groupKey, prefixText, spellCount, headerDepth, countKind)
    table.insert(items, {
        isHeader = true,
        text = text,
        color = colorCode,
        totalCost = totalCost,
        groupKey = groupKey,
        collapsed = TrainerSpells:IsGroupCollapsed(groupKey),
        prefixText = prefixText,
        spellCount = spellCount,
        headerDepth = headerDepth,
        countKind = countKind
    })
end

function TrainerSpells:AddEntryItems(items, list, colorCode, showLevel, showCostTooltip, dimName, levelLabel, rowDepth)
    for _, entry in ipairs(list) do
        table.insert(items, {
            isHeader = false,
            entry = entry,
            color = colorCode,
            showLevel = showLevel,
            showCostTooltip = showCostTooltip,
            dimName = dimName,
            levelLabel = levelLabel,
            rowDepth = rowDepth,
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

local function CountGroupEntries(groups)
    return #groups.available + #groups.soon + #groups.higher + #groups.missingTalents + #groups.ignored + #groups.known
end

local function RaceMatches(race, playerRace)
    if not race or not playerRace then return true end
    if type(race) ~= "table" then return race == playerRace end
    for _, raceToken in ipairs(race) do
        if raceToken == playerRace then return true end
    end

    return false
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

            local raceMatches = RaceMatches(race, playerRace)

            if (not faction or not playerFaction or faction == playerFaction) and raceMatches then
                local name
                if type(key) == "number" then
                    spellID = spellID or key
                    name, _, icon = TrainerSpells:GetSpellInfo(key)
                else
                    name = key
                end

                name = name or ("SpellID " .. tostring(key))
                if not icon and spellID then
                    local _, _, resolvedIcon = TrainerSpells:GetSpellInfo(spellID)
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
            local isIgnored
            if professionKey then
                isIgnored = TrainerSpells_IsProfessionSpellIgnored and TrainerSpells_IsProfessionSpellIgnored(entry.spellID, professionKey)
            else
                isIgnored = TrainerSpells_IsIgnored and TrainerSpells_IsIgnored(entry.spellID, entry.name)
            end

            if isIgnored then
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

function TrainerSpells:AppendGroupItems(items, groups, keyPrefix, labelPrefix, unitLabel, showCost, headerDepth, countKind)
    local Colors = TrainerSpells.UIColors
    if showCost == nil then showCost = true end
    local entryLevelLabel = unitLabel and unitLabel ~= TrainerSpells:Trans("LID_LVL") and unitLabel or nil
    unitLabel = unitLabel or TrainerSpells:Trans("LID_LVL")
    if #groups.available > 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_AVAILABLENOW"), Colors.AVAILABLE, showCost and TrainerSpells:SumCost(groups.available) or nil, keyPrefix .. "available", labelPrefix, #groups.available, headerDepth, countKind)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "available") then TrainerSpells:AddEntryItems(items, groups.available, Colors.AVAILABLE, true, showCost, false, entryLevelLabel, headerDepth) end
    end

    if #groups.soon > 0 then
        TrainerSpells:AddHeaderItem(items, ("%s (%s %d)"):format(TrainerSpells:Trans("LID_COMINGSOON"), unitLabel, groups.nextLevel), Colors.SOON, showCost and TrainerSpells:SumCost(groups.soon) or nil, keyPrefix .. "soon", labelPrefix, #groups.soon, headerDepth, countKind)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "soon") then TrainerSpells:AddEntryItems(items, groups.soon, Colors.SOON, true, showCost, false, entryLevelLabel, headerDepth) end
    end

    if #groups.higher > 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_NOTYETAVAILABLE"), Colors.NOTYET, showCost and TrainerSpells:SumCost(groups.higher) or nil, keyPrefix .. "higher", labelPrefix, #groups.higher, headerDepth, countKind)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "higher") then TrainerSpells:AddEntryItems(items, groups.higher, Colors.NOTYET, true, showCost, false, entryLevelLabel, headerDepth) end
    end

    if #groups.missingTalents > 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_MISSINGREQUIREDTALENTS"), Colors.TALENT, showCost and TrainerSpells:SumCost(groups.missingTalents) or nil, keyPrefix .. "missingTalents", labelPrefix, #groups.missingTalents, headerDepth, countKind)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "missingTalents") then TrainerSpells:AddEntryItems(items, groups.missingTalents, Colors.TALENT, true, showCost, false, entryLevelLabel, headerDepth) end
    end

    if #groups.ignored > 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_IGNORED"), Colors.IGNORED, nil, keyPrefix .. "ignored", labelPrefix, #groups.ignored, headerDepth, countKind)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "ignored") then TrainerSpells:AddEntryItems(items, groups.ignored, Colors.IGNORED, true, showCost, true, entryLevelLabel, headerDepth) end
    end

    if #groups.known > 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_ALREADYKNOWN"), Colors.KNOWN, showCost and TrainerSpells:SumCost(groups.known) or nil, keyPrefix .. "known", labelPrefix, #groups.known, headerDepth, countKind)
        if not TrainerSpells:IsGroupCollapsed(keyPrefix .. "known") then TrainerSpells:AddEntryItems(items, groups.known, Colors.KNOWN, true, showCost, true, entryLevelLabel, headerDepth) end
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
    for _, petGroup in ipairs(TrainerSpells.PetGroups) do
        local merged = MergePetData(petGroup.keys)
        if next(merged) then
            local groupKey = "pet_" .. table.concat(petGroup.keys, "_")
            local groups = TrainerSpells:ClassifyEntries(merged, searchText, selectedLevel, true)
            local subItems = {}
            TrainerSpells:AppendGroupItems(subItems, groups, groupKey .. "_", nil, nil, nil, 1)
            if #subItems > 0 then
                local groupCount = CountGroupEntries(groups)
                TrainerSpells:AddHeaderItem(items, petGroup.label, Colors.PET_HEADER, nil, groupKey, nil, groupCount)
                if not TrainerSpells:IsGroupCollapsed(groupKey) then
                    for _, item in ipairs(subItems) do
                        table.insert(items, item)
                    end
                end
            end
        end
    end
end

function TrainerSpells:AppendPetTrainerAbilities(items, searchText, selectedLevel, classToken)
    local petTrainerData = TrainerSpells_PetTrainerData and TrainerSpells_PetTrainerData[classToken]
    if not petTrainerData or not next(petTrainerData) then return end
    local groups = TrainerSpells:ClassifyEntries(petTrainerData, searchText, selectedLevel, true)
    TrainerSpells:AppendGroupItems(items, groups, "pettrainer_")
end

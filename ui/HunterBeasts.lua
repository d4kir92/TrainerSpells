local _, TrainerSpells = ...
local data = TrainerSpellsHunterBeasts
if type(data) ~= "table" or type(data.beasts) ~= "table" or #data.beasts == 0 or select(2, UnitClass("player")) ~= "HUNTER" then return end
local Beasts = {
    mapNames = {},
    trainerCosts = nil,
    spellBeasts = {},
    foodKeys = {{1, "LID_FOOD_MEAT"}, {2, "LID_FOOD_FISH"}, {4, "LID_FOOD_CHEESE"}, {8, "LID_FOOD_BREAD"}, {16, "LID_FOOD_FUNGUS"}, {32, "LID_FOOD_FRUIT"}, {64, "LID_FOOD_RAWMEAT"}, {128, "LID_FOOD_RAWFISH"}},
    classColors = {[1] = "|cffffd100", [2] = "|cffff8c00", [3] = "|cffff4040", [4] = "|cffb0c8ff"},
    classKeys = {[1] = "LID_ELITE", [2] = "LID_RAREELITE", [3] = "LID_BOSS", [4] = "LID_RARE"},
    maxTooltipTeachers = 10,
    knownIcon = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t",
    favoriteIcon = "|TInterface\\Common\\ReputationStar:0:0:0:0:32:32:0:16:0:16|t",
}
TrainerSpells.HunterBeasts = Beasts
local TrainerLocations = TrainerSpells.TrainerLocations
Beasts.rankBySpell = {}
for key, ability in pairs(data.abilities) do
    for _, rank in ipairs(ability.ranks) do Beasts.rankBySpell[rank.spell] = {key = key, rank = rank} end
end

function Beasts.TaughtRanks(beast, listed)
    local spells, byAbility = {}, {}
    local knownLevel = beast.maxLevel > 0 and beast.maxLevel < 9999
    for _, spell in ipairs(listed or {}) do
        local found = Beasts.rankBySpell[spell]
        if knownLevel and found then
            byAbility[found.key] = byAbility[found.key] or {}
            byAbility[found.key][spell] = true
        else
            table.insert(spells, spell)
        end
    end
    local minLevel = beast.minLevel > 0 and beast.minLevel or beast.maxLevel
    for key, listedSpells in pairs(byAbility) do
        local ranks, kept, best = data.abilities[key].ranks, 0, nil
        for index, rank in ipairs(ranks) do
            local nextRank = ranks[index + 1]
            if rank.level <= beast.maxLevel and (not nextRank or nextRank.level > minLevel) then
                best = rank.spell
                if listedSpells[rank.spell] then
                    table.insert(spells, rank.spell)
                    kept = kept + 1
                end
            end
        end
        if kept == 0 and best then table.insert(spells, best) end
    end
    table.sort(spells)
    return spells
end

for _, beast in ipairs(data.beasts) do
    if data.teacherSource ~= "petopia" then beast.spells = Beasts.TaughtRanks(beast, beast.spells) end
    beast.spells = beast.spells or {}
    for _, spell in ipairs(beast.spells) do
        Beasts.spellBeasts[spell] = Beasts.spellBeasts[spell] or {}
        table.insert(Beasts.spellBeasts[spell], beast)
    end
end

function Beasts.Settings()
    local settings = TrainerSpells_Character
    if settings.beastMode ~= "rares" and settings.beastMode ~= "abilities" and settings.beastMode ~= "zones" then settings.beastMode = "pets" end
    local family = settings.beastFamily
    if type(family) ~= "number" or (family ~= -1 and family ~= 0 and not data.families[family]) then settings.beastFamily = 0 end
    return settings
end

function Beasts.FamilyName(familyID)
    local family = data.families[familyID]
    if not family then return tostring(familyID) end
    local locale = GetLocale() == "enGB" and "enUS" or GetLocale()
    return family.names[locale] or family.names.enUS or tostring(familyID)
end

function Beasts.BeastName(beast, cachedOnly)
    if GetLocale() ~= "enUS" and GetLocale() ~= "enGB" then
        local info = cachedOnly and TrainerLocations.GetCachedCreatureInfo(beast.id) or not cachedOnly and TrainerLocations.GetCreatureInfo(beast.id)
        if info and info.name then return info.name end
    end
    return beast.name
end

Beasts.searchTexts = {}
function Beasts.SearchText(beast)
    local text = Beasts.searchTexts[beast.id]
    if text then return text end
    local parts = {beast.name, Beasts.FamilyName(beast.family)}
    for _, zone in ipairs(Beasts.ZoneNames(beast)) do table.insert(parts, zone) end
    for _, spell in ipairs(beast.spells or {}) do
        if not Beasts.IsTrainerSpell(spell) then table.insert(parts, Beasts.AbilityLine(spell)) end
    end
    text = table.concat(parts, " ")
    Beasts.searchTexts[beast.id] = text
    return text
end

function Beasts.SpellName(spellID, fallback)
    local name = TrainerSpells:GetSpellInfo(spellID)
    return name or fallback or tostring(spellID)
end

function Beasts.SpellIcon(spellID)
    local _, _, icon = TrainerSpells:GetSpellInfo(spellID)
    return icon or 134400
end

function Beasts.AbilityName(key)
    local ability = data.abilities[key]
    local first = ability and ability.ranks[1]
    return first and Beasts.SpellName(first.spell, key) or key
end

function Beasts.MapName(uiMapID)
    local name = Beasts.mapNames[uiMapID]
    if name then return name end
    local info = C_Map.GetMapInfo(uiMapID)
    name = info and info.name or tostring(uiMapID)
    Beasts.mapNames[uiMapID] = name
    return name
end

function Beasts.ZoneNames(beast)
    local names, seen = {}, {}
    for _, spawn in ipairs(beast.spawns or {}) do
        local name = Beasts.MapName(spawn[1])
        if not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    return names
end

function Beasts.LevelText(beast)
    if beast.maxLevel <= 0 or beast.maxLevel >= 9999 then return "??" end
    if beast.minLevel == beast.maxLevel or beast.minLevel <= 0 then return tostring(beast.maxLevel) end
    return beast.minLevel .. "-" .. beast.maxLevel
end

function Beasts.CanTame(beast)
    local minLevel = beast.minLevel > 0 and beast.minLevel or beast.maxLevel
    return minLevel > 0 and minLevel < 9999 and minLevel <= (UnitLevel("player") or 1)
end

function Beasts.ClassTag(beast)
    local key = Beasts.classKeys[beast.classification]
    if not key then return "" end
    return Beasts.classColors[beast.classification] .. "[" .. TrainerSpells:Trans(key) .. "]|r "
end


function Beasts.FindRank(spellID)
    local found = Beasts.rankBySpell[spellID]
    if found then return found.key, found.rank end
end

function Beasts.RankText(rank)
    return TrainerSpells:Trans("LID_RANK"):format(rank.rank)
end

function Beasts.FoodText(mask)
    local names = {}
    for _, food in ipairs(Beasts.foodKeys) do
        if bit.band(mask or 0, food[1]) ~= 0 then table.insert(names, TrainerSpells:Trans(food[2])) end
    end
    return table.concat(names, ", ")
end

function Beasts.ModifierText(modifiers)
    local parts = {}
    for _, entry in ipairs({{"health", _G.HEALTH or "Health"}, {"armor", _G.ARMOR or "Armor"}, {"damage", _G.DAMAGE or "Damage"}}) do
        local value = modifiers[entry[1]] or 1
        local color = value > 1.001 and "|cff30d030" or value < 0.999 and "|cffff4444" or "|cffffffff"
        table.insert(parts, entry[2] .. " " .. color .. ("x%.2f"):format(value) .. "|r")
    end
    return table.concat(parts, "  ")
end

function Beasts.TrainerCost(abilityKey, rank)
    if not Beasts.trainerCosts then
        Beasts.trainerCosts = {}
        for _, spells in pairs(TrainerSpellsBuiltin_HunterPet or {}) do
            for spellID, entry in pairs(spells) do
                local name = TrainerSpells:GetSpellInfo(spellID)
                if name and type(entry) == "table" and entry.rank then
                    Beasts.trainerCosts[name] = Beasts.trainerCosts[name] or {}
                    local known = Beasts.trainerCosts[name][entry.rank]
                    if not known or (entry.cost or 0) < known then Beasts.trainerCosts[name][entry.rank] = entry.cost or 0 end
                end
            end
        end
    end
    local costs = Beasts.trainerCosts[Beasts.AbilityName(abilityKey)]
    return costs and costs[rank.rank]
end

function Beasts.SpawnEntries(beast)
    local entries = {}
    local name = Beasts.BeastName(beast, true)
    for _, spawn in ipairs(beast.spawns or {}) do
        table.insert(entries, {name = name, zoneName = Beasts.MapName(spawn[1]), beast = beast, location = {uiMapID = spawn[1], x = spawn[2], y = spawn[3]}})
    end
    return entries
end

function Beasts.SetNearestWaypoint(beasts)
    local entries = {}
    for _, beast in ipairs(beasts) do
        for _, entry in ipairs(Beasts.SpawnEntries(beast)) do table.insert(entries, entry) end
    end
    local nearest = TrainerLocations.FindNearest(entries) or entries[1]
    TrainerLocations.SetNearestWaypoint(nearest, "LID_NOBEAST")
    return nearest
end

function Beasts.Teachers(spellID, tameableFirst)
    local family = Beasts.Settings().beastFamily
    local teachers = {}
    for _, beast in ipairs(Beasts.spellBeasts[spellID] or {}) do
        if family <= 0 or beast.family == family then table.insert(teachers, beast) end
    end
    if tameableFirst then
        local tameable = {}
        for _, beast in ipairs(teachers) do
            if Beasts.CanTame(beast) then table.insert(tameable, beast) end
        end
        if #tameable > 0 then return tameable end
    end
    return teachers
end

function Beasts.MatchesSearch(searchText, ...)
    if searchText == "" then return true end
    for index = 1, select("#", ...) do
        local text = select(index, ...)
        if type(text) == "string" and text:lower():find(searchText, 1, true) then return true end
    end
    return false
end

function Beasts.AbilityLine(spellID)
    local key, rank = Beasts.FindRank(spellID)
    if not key then return Beasts.SpellName(spellID) end
    return Beasts.AbilityName(key) .. " " .. rank.rank
end

function Beasts.AbilityLineColored(spellID)
    if Beasts.IsKnown and Beasts.IsKnown(spellID) then return "|cff9d9d9d" .. Beasts.AbilityLine(spellID) .. "|r " .. Beasts.knownIcon end
    return "|cff30d030" .. Beasts.AbilityLine(spellID) .. "|r"
end

function Beasts.FavoritePrefix(isFavorite)
    return isFavorite and Beasts.favoriteIcon and (Beasts.favoriteIcon .. " ") or ""
end

function Beasts.AddClickHints(tooltip, leftKey, rightKey)
    tooltip:AddLine(" ")
    tooltip:AddLine(TrainerSpells:Trans(leftKey), 0.2, 1, 0.2)
    tooltip:AddLine(TrainerSpells:Trans(rightKey), 0.2, 1, 0.2)
    tooltip:AddLine(TrainerSpells:Trans("LID_SHIFTCLICK_MAP"), 0.2, 1, 0.2)
    tooltip:AddLine(TrainerSpells:Trans("LID_CTRLCLICK_FAVORITE"), 0.2, 1, 0.2)
end

Beasts.trainerAbilities = {}
function Beasts.IsTrainerAbility(key)
    local cached = Beasts.trainerAbilities[key]
    if cached ~= nil then return cached end
    local sold = false
    for _, rank in ipairs(data.abilities[key] and data.abilities[key].ranks or {}) do
        if Beasts.TrainerCost(key, rank) then sold = true end
    end
    Beasts.trainerAbilities[key] = sold
    return sold
end

function Beasts.IsTrainerSpell(spellID)
    local found = Beasts.rankBySpell[spellID]
    return found ~= nil and Beasts.IsTrainerAbility(found.key)
end

function Beasts.SortedSpells(beast)
    local spells = {}
    for _, spell in ipairs(beast.spells or {}) do
        if not Beasts.IsTrainerSpell(spell) then table.insert(spells, spell) end
    end
    table.sort(spells, function(a, b) return Beasts.AbilityLine(a) < Beasts.AbilityLine(b) end)
    return spells
end

function Beasts.IsRare(beast)
    return beast.classification == 2 or beast.classification == 4
end

function Beasts.FilteredBeasts(searchText)
    local settings = Beasts.Settings()
    local result = {}
    for _, beast in ipairs(data.beasts) do
        local family = settings.beastFamily
        local matchesFamily = family == 0 or beast.family == family or family == -1 and Beasts.IsFavoriteBeast and Beasts.IsFavoriteBeast(beast.id)
        local visible = matchesFamily and (not settings.beastTameableOnly or Beasts.CanTame(beast)) and (settings.beastMode ~= "rares" or Beasts.IsRare(beast))
        if visible and (searchText == "" or Beasts.MatchesSearch(searchText, Beasts.BeastName(beast, true), Beasts.SearchText(beast))) then table.insert(result, beast) end
    end
    return result
end

function Beasts.InitBeastRow(rowFrame, elementData, icon, nameFS, levelFS)
    local beast = elementData.beast
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", rowFrame, "LEFT", 4 + ((elementData.rowDepth or 0) * 16), 0)
    if beast.model and beast.model > 0 and SetPortraitTextureFromCreatureDisplayID then
        SetPortraitTextureFromCreatureDisplayID(icon, beast.model)
    else
        icon:SetTexture(data.families[beast.family] and data.families[beast.family].icon or 132161)
    end
    local name = Beasts.BeastName(beast)
    local abilities = {}
    for _, spell in ipairs(Beasts.SortedSpells(beast)) do table.insert(abilities, Beasts.AbilityLineColored(spell)) end
    local abilityText = #abilities > 0 and ("  " .. table.concat(abilities, " · ")) or ""
    local favorite = Beasts.FavoritePrefix(Beasts.IsFavoriteBeast and Beasts.IsFavoriteBeast(beast.id))
    nameFS:SetText(favorite .. Beasts.ClassTag(beast) .. TrainerSpells.UIColors.SPELL_NAME .. name .. "|r" .. abilityText)
    local zones = Beasts.ZoneNames(beast)
    local levelColor = Beasts.CanTame(beast) and "|cffffffff" or "|cffff4444"
    local speed = Beasts.SpeedText and Beasts.SpeedText(beast)
    local speedText = speed and ("|cffffd100" .. speed .. "s|r  ") or ""
    levelFS:SetText("|cff9d9d9d" .. (zones[1] or "") .. (#zones > 1 and " +" .. (#zones - 1) or "") .. "|r  " .. speedText .. levelColor .. TrainerSpells:Trans("LID_LVL") .. " " .. Beasts.LevelText(beast) .. "|r")
    rowFrame:EnableMouse(true)
    rowFrame:SetScript("OnEnter", function(sel)
        GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
        Beasts.AddBeastTooltip(GameTooltip, beast)
        Beasts.AddClickHints(GameTooltip, "LID_BEAST_LEFTCLICK", "LID_BEAST_RIGHTCLICK")
        GameTooltip:Show()
    end)
    rowFrame:SetScript("OnLeave", GameTooltip_Hide)
    rowFrame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and IsControlKeyDown() then
            Beasts.ToggleFavoriteBeast(beast.id)
        elseif button == "LeftButton" and IsShiftKeyDown() then
            Beasts.ShowOnMap({beast}, Beasts.BeastName(beast))
        elseif button == "RightButton" then
            Beasts.SetNearestWaypoint({beast})
        elseif button == "LeftButton" then
            Beasts.ShowDetails(beast)
        end
    end)
end

function Beasts.AddBeastTooltip(tooltip, beast)
    tooltip:SetText(Beasts.FavoritePrefix(Beasts.IsFavoriteBeast and Beasts.IsFavoriteBeast(beast.id)) .. Beasts.BeastName(beast))
    local tag = Beasts.classKeys[beast.classification]
    if tag then tooltip:AddLine(TrainerSpells:Trans(tag), 1, 0.82, 0) end
    tooltip:AddDoubleLine(TrainerSpells:Trans("LID_FAMILY"), Beasts.FamilyName(beast.family), 1, 0.82, 0, 1, 1, 1)
    local levelColor = Beasts.CanTame(beast) and {1, 1, 1} or {1, 0.27, 0.27}
    tooltip:AddDoubleLine(TrainerSpells:Trans("LID_LVL"), Beasts.LevelText(beast), 1, 0.82, 0, levelColor[1], levelColor[2], levelColor[3])
    local speed = Beasts.SpeedText and Beasts.SpeedText(beast)
    tooltip:AddDoubleLine(TrainerSpells:Trans("LID_ATTACKSPEED"), speed and (speed .. "s") or TrainerSpells:Trans("LID_ATTACKSPEED_UNKNOWN"), 1, 0.82, 0, 1, 1, 1)
    local zones = Beasts.ZoneNames(beast)
    if #zones > 0 then tooltip:AddDoubleLine(TrainerSpells:Trans("LID_ZONES"), table.concat(zones, ", "), 1, 0.82, 0, 1, 1, 1) end
    local spells = Beasts.SortedSpells(beast)
    if #spells > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine(TrainerSpells:Trans("LID_BEASTMODE_ABILITIES"), 1, 0.82, 0)
        for _, spell in ipairs(spells) do
            local _, rank = Beasts.FindRank(spell)
            local detail = rank and (TrainerSpells:Trans("LID_PETLEVEL") .. " " .. rank.level .. " · " .. rank.tp .. " " .. TrainerSpells:Trans("LID_TP")) or ""
            tooltip:AddDoubleLine("|T" .. Beasts.SpellIcon(spell) .. ":0|t " .. Beasts.AbilityLineColored(spell), detail, 1, 1, 1, 0.7, 0.7, 0.7)
        end
    end
end

function Beasts.InitRankRow(rowFrame, elementData, icon, nameFS, levelFS)
    local key, rank = elementData.abilityKey, elementData.rank
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", rowFrame, "LEFT", 4 + ((elementData.rowDepth or 0) * 16), 0)
    icon:SetTexture(Beasts.SpellIcon(rank.spell))
    local teachers = Beasts.Teachers(rank.spell)
    local trainerCost = Beasts.TrainerCost(key, rank)
    local petLevel = UnitLevel("pet") or 0
    local levelColor = (UnitExists("pet") and petLevel >= rank.level) and "|cff30d030" or "|cffffffff"
    local known = Beasts.IsKnown and Beasts.IsKnown(rank.spell)
    local favorite = Beasts.FavoritePrefix(Beasts.IsFavoriteSpell and Beasts.IsFavoriteSpell(rank.spell))
    local nameColor = known and TrainerSpells.UIColors.KNOWN or TrainerSpells.UIColors.SPELL_NAME
    nameFS:SetText(favorite .. nameColor .. Beasts.AbilityName(key) .. "|r  " .. TrainerSpells.UIColors.RANK .. Beasts.RankText(rank) .. "|r" .. (known and (" " .. Beasts.knownIcon) or ""))
    local source
    if trainerCost then
        source = "|cff4db8ff" .. TrainerSpells:Trans("LID_PETTRAINER") .. (trainerCost > 0 and (" " .. GetMoneyString(trainerCost, true)) or "") .. "|r"
    elseif #teachers > 0 then
        source = "|cff9d9d9d" .. TrainerSpells:Trans("LID_TEACHERS"):format(#teachers) .. "|r"
    else
        source = "|cffff4444" .. TrainerSpells:Trans("LID_UNKNOWNSOURCE") .. "|r"
    end
    levelFS:SetText(source .. "  " .. levelColor .. TrainerSpells:Trans("LID_PETLEVEL") .. " " .. rank.level .. "|r  |cffffd100" .. rank.tp .. " " .. TrainerSpells:Trans("LID_TP") .. "|r")
    rowFrame:EnableMouse(true)
    rowFrame:SetScript("OnEnter", function(sel)
        GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(rank.spell)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(TrainerSpells:Trans("LID_PETLEVEL"), rank.level, 1, 0.82, 0, 1, 1, 1)
        GameTooltip:AddDoubleLine(TrainerSpells:Trans("LID_TRAININGPOINTS"), rank.tp, 1, 0.82, 0, 1, 1, 1)
        if known then GameTooltip:AddLine(Beasts.knownIcon .. " " .. TrainerSpells:Trans("LID_RANKLEARNED"), 0.6, 0.6, 0.6) end
        local families = {}
        for _, familyID in ipairs(data.abilities[key].families) do table.insert(families, Beasts.FamilyName(familyID)) end
        table.sort(families)
        GameTooltip:AddLine(TrainerSpells:Trans("LID_FAMILY") .. ": " .. table.concat(families, ", "), 1, 1, 1, true)
        if trainerCost then GameTooltip:AddLine(TrainerSpells:Trans("LID_PETTRAINER") .. (trainerCost > 0 and (": " .. GetMoneyString(trainerCost, true)) or ""), 0.3, 0.72, 1) end
        if #teachers > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(TrainerSpells:Trans("LID_TAUGHTBY"), 1, 0.82, 0)
            local sorted = {}
            for _, beast in ipairs(teachers) do table.insert(sorted, beast) end
            table.sort(sorted, function(a, b)
                if Beasts.CanTame(a) ~= Beasts.CanTame(b) then return Beasts.CanTame(a) end
                return a.maxLevel < b.maxLevel
            end)
            for index, beast in ipairs(sorted) do
                if index > Beasts.maxTooltipTeachers then
                    GameTooltip:AddLine(TrainerSpells:Trans("LID_AND_MORE"):format(#sorted - Beasts.maxTooltipTeachers), 0.6, 0.6, 0.6)
                    break
                end
                local color = Beasts.CanTame(beast) and {1, 1, 1} or {1, 0.27, 0.27}
                GameTooltip:AddDoubleLine(Beasts.ClassTag(beast) .. Beasts.BeastName(beast) .. " (" .. Beasts.LevelText(beast) .. ")", Beasts.ZoneNames(beast)[1] or "", color[1], color[2], color[3], 0.7, 0.7, 0.7)
            end
            Beasts.AddClickHints(GameTooltip, "LID_ABILITY_LEFTCLICK", "LID_ABILITY_RIGHTCLICK")
        else
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(TrainerSpells:Trans("LID_ABILITY_LEFTCLICK"), 0.2, 1, 0.2)
            GameTooltip:AddLine(TrainerSpells:Trans("LID_CTRLCLICK_FAVORITE"), 0.2, 1, 0.2)
        end
        GameTooltip:Show()
    end)
    rowFrame:SetScript("OnLeave", GameTooltip_Hide)
    rowFrame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and IsControlKeyDown() then
            Beasts.ToggleFavoriteSpell(rank.spell)
            return
        end
        if button == "LeftButton" and IsShiftKeyDown() then
            Beasts.ShowOnMap(Beasts.Teachers(rank.spell), Beasts.AbilityName(key) .. " " .. rank.rank)
            return
        end
        if button == "LeftButton" then
            Beasts.ShowAbility(key, rank)
        elseif button == "RightButton" then
            local candidates = Beasts.Teachers(rank.spell, true)
            if #candidates == 0 then
                TrainerSpells:MSG(TrainerSpells:Trans("LID_NOBEAST"))
                return
            end
            Beasts.SetNearestWaypoint(candidates)
        end
    end)
end

function Beasts.SortedFamilies()
    local families = {}
    for familyID in pairs(data.families) do table.insert(families, familyID) end
    table.sort(families, function(a, b) return Beasts.FamilyName(a) < Beasts.FamilyName(b) end)
    return families
end

function Beasts.SortBeasts(beasts)
    local names = {}
    for _, beast in ipairs(beasts) do names[beast] = Beasts.BeastName(beast, true) end
    table.sort(beasts, function(a, b)
        if a.maxLevel ~= b.maxLevel then return a.maxLevel < b.maxLevel end
        if names[a] ~= names[b] then return names[a] < names[b] end
        return a.id < b.id
    end)
end

Beasts.zoneOf = {}
function Beasts.ZoneOf(uiMapID)
    if not uiMapID then return nil end
    local cached = Beasts.zoneOf[uiMapID]
    if cached then return cached end
    local zone, info, depth = uiMapID, C_Map.GetMapInfo(uiMapID), 0
    while info and info.mapType and info.mapType > 3 and info.parentMapID and info.parentMapID > 0 and depth < 5 do
        zone, info, depth = info.parentMapID, C_Map.GetMapInfo(info.parentMapID), depth + 1
    end
    Beasts.zoneOf[uiMapID] = zone
    return zone
end

function Beasts.CurrentZone()
    return Beasts.ZoneOf(C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
end

function Beasts.BuildZoneItems(items, searchText)
    local byZone, zoneIDs = {}, {}
    for _, beast in ipairs(Beasts.FilteredBeasts(searchText)) do
        local seen = {}
        for _, spawn in ipairs(beast.spawns or {}) do
            local zone = Beasts.ZoneOf(spawn[1])
            if zone and not seen[zone] then
                seen[zone] = true
                if not byZone[zone] then
                    byZone[zone] = {}
                    table.insert(zoneIDs, zone)
                end
                table.insert(byZone[zone], beast)
            end
        end
    end
    local current = Beasts.CurrentZone()
    table.sort(zoneIDs, function(a, b)
        if (a == current) ~= (b == current) then return a == current end
        return Beasts.MapName(a) < Beasts.MapName(b)
    end)
    if current and not byZone[current] then TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_CURRENTZONE_NONE"):format(Beasts.MapName(current)), "|cff9d9d9d") end
    for _, zone in ipairs(zoneIDs) do
        local beasts = byZone[zone]
        Beasts.SortBeasts(beasts)
        local groupKey = "beast_zone_" .. zone
        local name = zone == current and TrainerSpells:Trans("LID_CURRENTZONE"):format(Beasts.MapName(zone)) or Beasts.MapName(zone)
        TrainerSpells:AddHeaderItem(items, name .. "  |cff9d9d9d(" .. #beasts .. ")|r", zone == current and "|cff30d030" or "|cffffd100", nil, groupKey)
        if not TrainerSpells:IsGroupCollapsed(groupKey) then
            for _, beast in ipairs(beasts) do table.insert(items, {initRow = Beasts.InitBeastRow, beast = beast, rowDepth = 1}) end
        end
    end
end

local zoneWatcher = CreateFrame("Frame")
zoneWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneWatcher:SetScript("OnEvent", function()
    if TrainerSpells.BeastControls and TrainerSpells.BeastControls:IsVisible() then TrainerSpells_Refresh() end
end)

function Beasts.BuildPetItems(items, searchText)
    local byFamily, here, current = {}, {}, Beasts.CurrentZone()
    for _, beast in ipairs(Beasts.FilteredBeasts(searchText)) do
        for _, spawn in ipairs(beast.spawns or {}) do
            if current and Beasts.ZoneOf(spawn[1]) == current then
                table.insert(here, beast)
                break
            end
        end
        byFamily[beast.family] = byFamily[beast.family] or {}
        table.insert(byFamily[beast.family], beast)
    end
    if current and #here == 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_CURRENTZONE_NONE"):format(Beasts.MapName(current)), "|cff9d9d9d")
    elseif current then
        Beasts.SortBeasts(here)
        local groupKey = "beast_family_currentzone"
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_CURRENTZONE"):format(Beasts.MapName(current)) .. "  |cff9d9d9d(" .. #here .. ")|r", "|cff30d030", nil, groupKey)
        if not TrainerSpells:IsGroupCollapsed(groupKey) then
            for _, beast in ipairs(here) do table.insert(items, {initRow = Beasts.InitBeastRow, beast = beast, rowDepth = 1}) end
        end
    end
    for _, familyID in ipairs(Beasts.SortedFamilies()) do
        local beasts = byFamily[familyID]
        if beasts then
            Beasts.SortBeasts(beasts)
            local groupKey = "beast_family_" .. familyID
            local family = data.families[familyID]
            local header = "|T" .. family.icon .. ":0|t " .. Beasts.FamilyName(familyID) .. "  |cff9d9d9d(" .. #beasts .. ")|r"
            TrainerSpells:AddHeaderItem(items, header, "|cffffd100", nil, groupKey)
            if not TrainerSpells:IsGroupCollapsed(groupKey) then
                for _, beast in ipairs(beasts) do table.insert(items, {initRow = Beasts.InitBeastRow, beast = beast, rowDepth = 1}) end
            end
        end
    end
end

function Beasts.TeachesInZone(spellID, zone)
    for _, beast in ipairs(Beasts.Teachers(spellID)) do
        for _, spawn in ipairs(beast.spawns or {}) do
            if Beasts.ZoneOf(spawn[1]) == zone then return true end
        end
    end
    return false
end

function Beasts.AddCurrentZoneAbilities(items, keys, visibleRanks)
    local current = Beasts.CurrentZone()
    if not current then return end
    local rows = {}
    for _, key in ipairs(keys) do
        for _, rank in ipairs(visibleRanks[key]) do
            if Beasts.TeachesInZone(rank.spell, current) then table.insert(rows, {initRow = Beasts.InitRankRow, abilityKey = key, rank = rank, rowDepth = 1}) end
        end
    end
    if #rows == 0 then
        TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_CURRENTZONE_NONE"):format(Beasts.MapName(current)), "|cff9d9d9d")
        return
    end
    local groupKey = "beast_ability_currentzone"
    TrainerSpells:AddHeaderItem(items, TrainerSpells:Trans("LID_CURRENTZONE"):format(Beasts.MapName(current)), "|cff30d030", nil, groupKey, nil, #rows, nil, "skill")
    if not TrainerSpells:IsGroupCollapsed(groupKey) then
        for _, row in ipairs(rows) do table.insert(items, row) end
    end
end

function Beasts.BuildAbilityItems(items, searchText)
    local settings = Beasts.Settings()
    local keys = {}
    for key, ability in pairs(data.abilities) do
        local matchesFamily = settings.beastFamily == 0
        for _, familyID in ipairs(ability.families) do
            if familyID == settings.beastFamily then matchesFamily = true end
        end
        if settings.beastFamily == -1 then
            for _, rank in ipairs(ability.ranks) do
                if Beasts.IsFavoriteSpell(rank.spell) then matchesFamily = true end
            end
        end
        local familyNames = {}
        for _, familyID in ipairs(ability.families) do table.insert(familyNames, Beasts.FamilyName(familyID)) end
        if matchesFamily and not Beasts.IsTrainerAbility(key) and Beasts.MatchesSearch(searchText, Beasts.AbilityName(key), key, table.concat(familyNames, " ")) then table.insert(keys, key) end
    end
    table.sort(keys, function(a, b) return Beasts.AbilityName(a) < Beasts.AbilityName(b) end)
    local visibleRanks = {}
    for _, key in ipairs(keys) do
        local ability = data.abilities[key]
        local ranks = {}
        for _, rank in ipairs(ability.ranks) do
            local visible = Beasts.TrainerCost(key, rank) == nil
            if visible and settings.beastFamily == -1 then
                visible = Beasts.IsFavoriteSpell(rank.spell)
            elseif visible then
                visible = settings.beastFamily == 0 or #Beasts.Teachers(rank.spell) > 0
            end
            if visible and settings.beastTameableOnly then
                local _, tameable = next(Beasts.Teachers(rank.spell, true))
                visible = tameable ~= nil and Beasts.CanTame(tameable)
            end
            if visible then table.insert(ranks, rank) end
        end
        visibleRanks[key] = ranks
    end
    Beasts.AddCurrentZoneAbilities(items, keys, visibleRanks)
    for _, key in ipairs(keys) do
        local ability, ranks = data.abilities[key], visibleRanks[key]
        if #ranks > 0 then
            local groupKey = "beast_ability_" .. key
            local first = ability.ranks[1]
            local header = (first and ("|T" .. Beasts.SpellIcon(first.spell) .. ":0|t ") or "") .. Beasts.AbilityName(key)
            TrainerSpells:AddHeaderItem(items, header, ability.generic and "|cffffffff" or "|cffffd100", nil, groupKey, nil, #ranks, nil, "skill")
            if not TrainerSpells:IsGroupCollapsed(groupKey) then
                for _, rank in ipairs(ranks) do table.insert(items, {initRow = Beasts.InitRankRow, abilityKey = key, rank = rank, rowDepth = 1}) end
            end
        end
    end
end

function TrainerSpells:BuildBeastItems(items, searchText)
    local mode = Beasts.Settings().beastMode
    if mode == "abilities" then
        Beasts.BuildAbilityItems(items, searchText or "")
    elseif mode == "zones" then
        Beasts.BuildZoneItems(items, searchText or "")
    else
        Beasts.BuildPetItems(items, searchText or "")
    end
end

function Beasts.CreateDetailFrame()
    local frame = TrainerSpells:CreateUIWindowFrame("TrainerSpellsBeastDetailFrame", UIParent)
    frame:SetSize(640, 460)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "TrainerSpellsBeastDetailFrame") end
    frame.title = frame.TitleText or frame.TitleContainer and frame.TitleContainer.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not frame.title:GetPoint() then frame.title:SetPoint("TOP", frame, "TOP", 0, -6) end
    local model = CreateFrame("PlayerModel", nil, frame)
    model:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
    model:SetSize(240, 340)
    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    model.facing = 0
    model.zoom = 1
    model:SetScript("OnMouseDown", function(sel, button)
        if button == "LeftButton" then sel.dragX = GetCursorPosition() end
    end)
    model:SetScript("OnMouseUp", function(sel) sel.dragX = nil end)
    model:SetScript("OnUpdate", function(sel)
        if not sel.dragX then return end
        local x = GetCursorPosition()
        sel.facing = sel.facing + (x - sel.dragX) * 0.02
        sel.dragX = x
        sel:SetFacing(sel.facing)
    end)
    model:SetScript("OnMouseWheel", function(sel, delta)
        sel.zoom = math.max(0.5, math.min(3, sel.zoom - delta * 0.15))
        if sel.SetCamDistanceScale then sel:SetCamDistanceScale(sel.zoom) end
    end)
    frame.model = model
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOP", model, "BOTTOM", 0, -4)
    hint:SetText(TrainerSpells:Trans("LID_MODEL_HINT"))
    local scroll = CreateFrame("Frame", nil, frame, "WowScrollBox")
    scroll:SetPoint("TOPLEFT", model, "TOPRIGHT", 14, 0)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 46)
    local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content.scrollable = true
    content:SetSize(1, 1)
    local view = CreateScrollBoxLinearView()
    view:SetPanExtent(40)
    ScrollUtil.InitScrollBoxWithScrollBar(scroll, scrollBar, view)
    frame.scroll, frame.content = scroll, content
    local info = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    info:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    info:SetJustifyH("LEFT")
    info:SetJustifyV("TOP")
    info:SetSpacing(3)
    frame.info = info
    local nearest = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    nearest:SetSize(180, 24)
    nearest:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    nearest:SetText(TrainerSpells:Trans("LID_NEARESTSPAWN"))
    nearest:SetScript("OnClick", function()
        if frame.beast then Beasts.SetNearestWaypoint({frame.beast}) end
    end)
    frame.nearest = nearest
    local map = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    map:SetSize(150, 24)
    map:SetPoint("RIGHT", nearest, "LEFT", -6, 0)
    map:SetScript("OnClick", function()
        if not frame.beast then return end
        if Beasts.IsPinned(frame.beast) then Beasts.ClearMap() else Beasts.ShowOnMap({frame.beast}, Beasts.BeastName(frame.beast)) end
        Beasts.ShowDetails(frame.beast)
    end)
    frame.map = map
    local favorite = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    favorite:SetSize(130, 24)
    favorite:SetPoint("RIGHT", map, "LEFT", -6, 0)
    favorite:SetScript("OnClick", function()
        if frame.beast then Beasts.ToggleFavoriteBeast(frame.beast.id) end
    end)
    frame.favorite = favorite
    Beasts.detailFrame = frame
    return frame
end

function Beasts.ShowDetails(beast)
    local frame = Beasts.detailFrame or Beasts.CreateDetailFrame()
    frame.beast = beast
    frame.title:SetText(Beasts.BeastName(beast))
    local model = frame.model
    model:ClearModel()
    if beast.model and beast.model > 0 then model:SetDisplayInfo(beast.model) else model:SetCreature(beast.id) end
    model.facing, model.zoom = 0.5, 1
    model:SetFacing(model.facing)
    if model.SetCamDistanceScale then model:SetCamDistanceScale(1) end
    local family = data.families[beast.family]
    local lines = {}
    local tag = Beasts.classKeys[beast.classification]
    if tag then table.insert(lines, Beasts.classColors[beast.classification] .. TrainerSpells:Trans(tag) .. "|r") end
    table.insert(lines, "|cffffd100" .. TrainerSpells:Trans("LID_FAMILY") .. ":|r " .. (family and ("|T" .. family.icon .. ":0|t ") or "") .. Beasts.FamilyName(beast.family))
    table.insert(lines, "|cffffd100" .. TrainerSpells:Trans("LID_LVL") .. ":|r " .. (Beasts.CanTame(beast) and "" or "|cffff4444") .. Beasts.LevelText(beast) .. "|r")
    local speed = Beasts.SpeedText(beast)
    table.insert(lines, "|cffffd100" .. TrainerSpells:Trans("LID_ATTACKSPEED") .. ":|r " .. (speed and (speed .. "s") or ("|cff9d9d9d" .. TrainerSpells:Trans("LID_ATTACKSPEED_UNKNOWN") .. "|r")))
    if family and family.food and family.food > 0 then table.insert(lines, "|cffffd100" .. TrainerSpells:Trans("LID_DIET") .. ":|r " .. Beasts.FoodText(family.food)) end
    if family and family.role then table.insert(lines, "|cffffd100" .. TrainerSpells:Trans("LID_ROLE") .. ":|r " .. TrainerSpells:Trans("LID_ROLE_" .. family.role:upper())) end
    if family and family.modifiers then table.insert(lines, "|cffffd100" .. TrainerSpells:Trans("LID_MODIFIERS") .. ":|r " .. Beasts.ModifierText(family.modifiers)) end
    local zones = Beasts.ZoneNames(beast)
    if #zones > 0 then table.insert(lines, "|cffffd100" .. TrainerSpells:Trans("LID_ZONES") .. ":|r " .. table.concat(zones, ", ")) end
    local spells = Beasts.SortedSpells(beast)
    if #spells > 0 then
        table.insert(lines, " ")
        table.insert(lines, "|cffffd100" .. TrainerSpells:Trans("LID_BEASTMODE_ABILITIES") .. "|r")
        for _, spell in ipairs(spells) do
            local _, rank = Beasts.FindRank(spell)
            local detail = rank and ("  |cff9d9d9d" .. TrainerSpells:Trans("LID_PETLEVEL") .. " " .. rank.level .. " · " .. rank.tp .. " " .. TrainerSpells:Trans("LID_TP") .. "|r") or ""
            table.insert(lines, "|T" .. Beasts.SpellIcon(spell) .. ":0|t " .. Beasts.AbilityLineColored(spell) .. detail)
        end
    end
    if family and family.abilities and #family.abilities > 0 then
        local names = {}
        for _, key in ipairs(family.abilities) do
            if not Beasts.IsTrainerAbility(key) then table.insert(names, Beasts.AbilityName(key)) end
        end
        table.sort(names)
        table.insert(lines, " ")
        table.insert(lines, "|cffffd100" .. TrainerSpells:Trans("LID_FAMILYABILITIES") .. ":|r " .. table.concat(names, ", "))
    end
    local width = frame.scroll:GetWidth() or 0
    frame.content:SetWidth(width >= 50 and width or 342)
    frame.info:SetText(table.concat(lines, "\n"))
    frame.content:SetHeight(math.ceil(frame.info:GetStringHeight()) + 8)
    frame.scroll:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    frame.scroll:ScrollToBegin()
    local hasSpawns = beast.spawns and #beast.spawns > 0 or false
    frame.nearest:SetEnabled(hasSpawns)
    frame.map:SetEnabled(hasSpawns)
    frame.map:SetText(TrainerSpells:Trans(Beasts.IsPinned(beast) and "LID_PINS_CLEAR" or "LID_SHOWONMAP"))
    frame.favorite:SetText(TrainerSpells:Trans(Beasts.IsFavoriteBeast(beast.id) and "LID_FAVORITE_REMOVE" or "LID_FAVORITE_ADD"))
    frame.title:SetText(Beasts.FavoritePrefix(Beasts.IsFavoriteBeast(beast.id)) .. Beasts.BeastName(beast))
    frame:Show()
    frame:Raise()
end

function Beasts.CreateAbilityFrame()
    local frame = TrainerSpells:CreateUIWindowFrame("TrainerSpellsBeastAbilityFrame", UIParent)
    frame:SetSize(520, 440)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "TrainerSpellsBeastAbilityFrame") end
    frame.title = frame.TitleText or frame.TitleContainer and frame.TitleContainer.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not frame.title:GetPoint() then frame.title:SetPoint("TOP", frame, "TOP", 0, -6) end
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -34)
    frame.icon = icon
    local info = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    info:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    info:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    info:SetJustifyH("LEFT")
    info:SetJustifyV("TOP")
    info:SetSpacing(3)
    frame.info = info
    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -122)
    frame.header = header
    local scroll = CreateFrame("Frame", nil, frame, "WowScrollBox")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -142)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 46)
    local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content.scrollable = true
    content:SetSize(1, 1)
    local view = CreateScrollBoxLinearView()
    view:SetPanExtent(40)
    ScrollUtil.InitScrollBoxWithScrollBar(scroll, scrollBar, view)
    frame.scroll, frame.content, frame.rows = scroll, content, {}
    local nearest = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    nearest:SetSize(160, 24)
    nearest:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    nearest:SetText(TrainerSpells:Trans("LID_NEARESTBEAST"))
    nearest:SetScript("OnClick", function()
        local candidates = frame.rank and Beasts.Teachers(frame.rank.spell, true) or {}
        if #candidates == 0 then
            TrainerSpells:MSG(TrainerSpells:Trans("LID_NOBEAST"))
            return
        end
        Beasts.SetNearestWaypoint(candidates)
    end)
    frame.nearest = nearest
    local map = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    map:SetSize(140, 24)
    map:SetPoint("RIGHT", nearest, "LEFT", -6, 0)
    map:SetText(TrainerSpells:Trans("LID_SHOWONMAP"))
    map:SetScript("OnClick", function()
        if frame.rank then Beasts.ShowOnMap(Beasts.Teachers(frame.rank.spell), Beasts.AbilityName(frame.abilityKey) .. " " .. frame.rank.rank) end
    end)
    frame.map = map
    local favorite = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    favorite:SetSize(150, 24)
    favorite:SetPoint("RIGHT", map, "LEFT", -6, 0)
    favorite:SetScript("OnClick", function()
        if frame.rank then Beasts.ToggleFavoriteSpell(frame.rank.spell) end
    end)
    frame.favorite = favorite
    Beasts.abilityFrame = frame
    return frame
end

function Beasts.AbilityRow(frame, index)
    local row = frame.rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, frame.content)
    row:SetHeight(22)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.portrait = row:CreateTexture(nil, "ARTWORK")
    row.portrait:SetSize(18, 18)
    row.portrait:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.zone = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.zone:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.zone:SetJustifyH("RIGHT")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", row.portrait, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row.zone, "LEFT", -8, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetScript("OnEnter", function(sel)
        GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
        Beasts.AddBeastTooltip(GameTooltip, sel.beast)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(TrainerSpells:Trans("LID_BEAST_LEFTCLICK"), 0.2, 1, 0.2)
        GameTooltip:AddLine(TrainerSpells:Trans("LID_BEAST_RIGHTCLICK"), 0.2, 1, 0.2)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(sel, button)
        if button == "RightButton" then Beasts.SetNearestWaypoint({sel.beast}) else Beasts.ShowDetails(sel.beast) end
    end)
    frame.rows[index] = row
    return row
end

function Beasts.ShowAbility(key, rank, keepScroll)
    local frame = Beasts.abilityFrame or Beasts.CreateAbilityFrame()
    frame.abilityKey, frame.rank = key, rank
    local name = Beasts.AbilityName(key) .. " " .. Beasts.RankText(rank)
    local isFavorite = Beasts.IsFavoriteSpell(rank.spell)
    frame.title:SetText(Beasts.FavoritePrefix(isFavorite) .. name)
    frame.icon:SetTexture(Beasts.SpellIcon(rank.spell))
    local lines = {}
    table.insert(lines, "|cffffd100" .. TrainerSpells:Trans("LID_PETLEVEL") .. ":|r " .. rank.level .. "   |cffffd100" .. TrainerSpells:Trans("LID_TRAININGPOINTS") .. ":|r " .. rank.tp)
    local trainerCost = Beasts.TrainerCost(key, rank)
    if trainerCost then table.insert(lines, "|cff4db8ff" .. TrainerSpells:Trans("LID_PETTRAINER") .. (trainerCost > 0 and (": " .. GetMoneyString(trainerCost, true)) or "") .. "|r") end
    if Beasts.IsKnown and Beasts.IsKnown(rank.spell) then table.insert(lines, Beasts.knownIcon .. " |cff9d9d9d" .. TrainerSpells:Trans("LID_RANKLEARNED") .. "|r") end
    local families = {}
    for _, familyID in ipairs(data.abilities[key].families) do table.insert(families, Beasts.FamilyName(familyID)) end
    table.sort(families)
    table.insert(lines, "|cffffd100" .. TrainerSpells:Trans("LID_FAMILY") .. ":|r " .. table.concat(families, ", "))
    frame.info:SetText(table.concat(lines, "\n"))
    local teachers = {}
    for _, beast in ipairs(Beasts.Teachers(rank.spell)) do table.insert(teachers, beast) end
    table.sort(teachers, function(a, b)
        if Beasts.CanTame(a) ~= Beasts.CanTame(b) then return Beasts.CanTame(a) end
        if a.maxLevel ~= b.maxLevel then return a.maxLevel < b.maxLevel end
        return a.id < b.id
    end)
    frame.header:SetText(TrainerSpells:Trans("LID_TAUGHTBY") .. " |cff9d9d9d(" .. #teachers .. ")|r")
    local width = frame.scroll:GetWidth() or 0
    if width < 50 then width = 476 end
    frame.content:SetWidth(width)
    local entries, rowCount, offset = Beasts.TeacherZoneEntries(teachers), 0, 0
    for _, label in ipairs(frame.zoneLabels or {}) do label:Hide() end
    frame.zoneLabels = frame.zoneLabels or {}
    for _, entry in ipairs(entries) do
        if entry.header then
            local label = Beasts.AbilityZoneLabel(frame, entry.index)
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -offset)
            label:SetPoint("TOPRIGHT", frame.content, "TOPRIGHT", 0, -offset)
            label.groupKey = entry.groupKey
            label.text:SetText(entry.header)
            Beasts.SetCollapseIcon(label.icon, entry.collapsed)
            label:Show()
            offset = offset + 22
        else
            rowCount = rowCount + 1
            Beasts.FillAbilityRow(frame, rowCount, entry.beast, offset)
            offset = offset + 22
        end
    end
    for index = rowCount + 1, #frame.rows do frame.rows[index]:Hide() end
    frame.content:SetHeight(math.max(1, offset))
    frame.scroll:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    if not keepScroll then frame.scroll:ScrollToBegin() end
    local hasTeachers = #teachers > 0
    frame.nearest:SetEnabled(hasTeachers)
    frame.map:SetEnabled(hasTeachers)
    frame.favorite:SetText(TrainerSpells:Trans(isFavorite and "LID_FAVORITE_REMOVE" or "LID_FAVORITE_ADD"))
    frame:Show()
    frame:Raise()
end

function Beasts.TeacherZoneEntries(teachers)
    local byZone, zoneIDs, unknown = {}, {}, {}
    for _, beast in ipairs(teachers) do
        local seen = {}
        for _, spawn in ipairs(beast.spawns or {}) do
            local zone = Beasts.ZoneOf(spawn[1])
            if zone and not seen[zone] then
                seen[zone] = true
                if not byZone[zone] then
                    byZone[zone] = {}
                    table.insert(zoneIDs, zone)
                end
                table.insert(byZone[zone], beast)
            end
        end
        if not next(seen) then table.insert(unknown, beast) end
    end
    local current = Beasts.CurrentZone()
    table.sort(zoneIDs, function(a, b)
        if (a == current) ~= (b == current) then return a == current end
        return Beasts.MapName(a) < Beasts.MapName(b)
    end)
    local entries, headers = {}, 0
    local function addGroup(text, beasts, groupKey)
        headers = headers + 1
        local collapsed = TrainerSpells:IsGroupCollapsed(groupKey)
        table.insert(entries, {header = text .. "  |cff9d9d9d(" .. #beasts .. ")|r", index = headers, groupKey = groupKey, collapsed = collapsed})
        if not collapsed then
            for _, beast in ipairs(beasts) do table.insert(entries, {beast = beast}) end
        end
    end
    for _, zone in ipairs(zoneIDs) do
        local text = zone == current and ("|cff30d030" .. TrainerSpells:Trans("LID_CURRENTZONE"):format(Beasts.MapName(zone)) .. "|r") or ("|cffffd100" .. Beasts.MapName(zone) .. "|r")
        addGroup(text, byZone[zone], "beast_teacher_zone_" .. zone)
    end
    if #unknown > 0 then addGroup("|cff9d9d9d" .. TrainerSpells:Trans("LID_ZONE_UNKNOWN") .. "|r", unknown, "beast_teacher_zone_unknown") end
    return entries
end

function Beasts.SetCollapseIcon(texture, collapsed)
    local atlas = collapsed and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse"
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas)
    else
        texture:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    end
end

function Beasts.AbilityZoneLabel(frame, index)
    local label = frame.zoneLabels[index]
    if label then return label end
    label = CreateFrame("Button", nil, frame.content)
    label:SetHeight(22)
    label:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    label.icon = label:CreateTexture(nil, "ARTWORK")
    label.icon:SetSize(16, 16)
    label.icon:SetPoint("LEFT", label, "LEFT", 2, 0)
    label.text = label:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label.text:SetPoint("LEFT", label.icon, "RIGHT", 6, 0)
    label.text:SetJustifyH("LEFT")
    label:SetScript("OnClick", function(sel)
        if not sel.groupKey or not TrainerSpells_Character then return end
        TrainerSpells_Character.collapsedGroups[sel.groupKey] = not TrainerSpells_Character.collapsedGroups[sel.groupKey] or nil
        if frame.rank then Beasts.ShowAbility(frame.abilityKey, frame.rank, true) end
    end)
    frame.zoneLabels[index] = label
    return label
end

function Beasts.FillAbilityRow(frame, index, beast, offset)
    local row = Beasts.AbilityRow(frame, index)
    row.beast = beast
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 12, -offset)
    row:SetPoint("TOPRIGHT", frame.content, "TOPRIGHT", 0, -offset)
    if beast.model and beast.model > 0 and SetPortraitTextureFromCreatureDisplayID then
        SetPortraitTextureFromCreatureDisplayID(row.portrait, beast.model)
    else
        row.portrait:SetTexture(data.families[beast.family] and data.families[beast.family].icon or 132161)
    end
    local levelColor = Beasts.CanTame(beast) and "|cffffffff" or "|cffff4444"
    row.text:SetText(Beasts.FavoritePrefix(Beasts.IsFavoriteBeast(beast.id)) .. Beasts.ClassTag(beast) .. TrainerSpells.UIColors.SPELL_NAME .. Beasts.BeastName(beast) .. "|r  " .. levelColor .. TrainerSpells:Trans("LID_LVL") .. " " .. Beasts.LevelText(beast) .. "|r")
    local zones = Beasts.ZoneNames(beast)
    row.zone:SetText("|cff9d9d9d" .. (zones[1] or "") .. (#zones > 1 and (" +" .. (#zones - 1)) or "") .. "|r")
    row:Show()
end

function Beasts.CreateDropdown(parent, width, getText, fillMenu)
    local modern = MenuUtil and MenuUtil.CreateRootMenuDescription
    local dropdown
    if modern then
        dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        dropdown:SetSize(width, 26)
        dropdown:SetupMenu(function(_, root)
            fillMenu(function(text, isSelected, onSelect) root:CreateRadio(text, isSelected, onSelect) end)
        end)
    else
        dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
        UIDropDownMenu_SetWidth(dropdown, width - 30)
        UIDropDownMenu_Initialize(dropdown, function()
            fillMenu(function(text, isSelected, onSelect)
                local info = UIDropDownMenu_CreateInfo()
                info.text = text
                info.checked = isSelected
                info.func = function()
                    onSelect()
                    CloseDropDownMenus()
                    dropdown:UpdateLabel()
                end
                UIDropDownMenu_AddButton(info)
            end)
        end)
    end
    function dropdown:UpdateLabel()
        if modern then self:SetText(getText()) else UIDropDownMenu_SetText(self, getText()) end
    end
    return dropdown
end

function TrainerSpells.CreateBeastControls(addon, parent)
    local controls = CreateFrame("Frame", nil, parent)
    controls:SetHeight(36)
    controls:Hide()
    local dropdowns = {}
    local function Changed()
        for _, dropdown in ipairs(dropdowns) do dropdown:UpdateLabel() end
        TrainerSpells_Refresh()
    end
    local modeText = {pets = "LID_BEASTMODE_PETS", rares = "LID_BEASTMODE_RARES", abilities = "LID_BEASTMODE_ABILITIES", zones = "LID_BEASTMODE_ZONES"}
    local mode = Beasts.CreateDropdown(controls, 150, function() return TrainerSpells:Trans(modeText[Beasts.Settings().beastMode]) end, function(add)
        for _, value in ipairs({"pets", "rares", "abilities", "zones"}) do
            add(TrainerSpells:Trans(modeText[value]), function() return Beasts.Settings().beastMode == value end, function()
                Beasts.Settings().beastMode = value
                Changed()
            end)
        end
    end)
    mode:SetPoint("LEFT", controls, "LEFT", 0, 0)
    local family = Beasts.CreateDropdown(controls, 170, function()
        local selected = Beasts.Settings().beastFamily
        if selected == -1 then return TrainerSpells:Trans("LID_FAVORITES") end
        return selected == 0 and TrainerSpells:Trans("LID_ALLFAMILIES") or Beasts.FamilyName(selected)
    end, function(add)
        add(TrainerSpells:Trans("LID_ALLFAMILIES"), function() return Beasts.Settings().beastFamily == 0 end, function()
            Beasts.Settings().beastFamily = 0
            Changed()
        end)
        add(Beasts.favoriteIcon .. " " .. TrainerSpells:Trans("LID_FAVORITES"), function() return Beasts.Settings().beastFamily == -1 end, function()
            Beasts.Settings().beastFamily = -1
            Changed()
        end)
        for _, familyID in ipairs(Beasts.SortedFamilies()) do
            add("|T" .. data.families[familyID].icon .. ":0|t " .. Beasts.FamilyName(familyID), function() return Beasts.Settings().beastFamily == familyID end, function()
                Beasts.Settings().beastFamily = familyID
                Changed()
            end)
        end
    end)
    family:SetPoint("LEFT", mode, "RIGHT", 8, 0)
    dropdowns = {mode, family}
    local tameable = CreateFrame("CheckButton", nil, controls, "UICheckButtonTemplate")
    tameable:SetSize(24, 24)
    tameable:SetPoint("LEFT", family, "RIGHT", 8, 0)
    function controls:SetTwoRows(twoRows)
        tameable:ClearAllPoints()
        mode:ClearAllPoints()
        if twoRows then
            mode:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, -4)
            tameable:SetPoint("TOPLEFT", controls, "TOPLEFT", 12, -36)
            controls:SetHeight(62)
        else
            mode:SetPoint("LEFT", controls, "LEFT", 0, 0)
            tameable:SetPoint("LEFT", family, "RIGHT", 8, 0)
            controls:SetHeight(36)
        end
    end
    local tameableText = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    tameableText:SetPoint("LEFT", tameable, "RIGHT", 2, 0)
    tameableText:SetText(TrainerSpells:Trans("LID_BEASTS_TAMEABLEONLY"))
    tameable:SetScript("OnClick", function(self)
        TrainerSpells_Character.beastTameableOnly = self:GetChecked() and true or false
        TrainerSpells_Refresh()
    end)
    local nearest = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    nearest:SetHeight(24)
    nearest:SetPoint("LEFT", tameableText, "RIGHT", 12, 0)
    nearest:SetText(TrainerSpells:Trans("LID_NEARESTBEAST"))
    nearest:SetWidth(math.max(120, nearest:GetTextWidth() + 30))
    nearest:SetScript("OnClick", function()
        Beasts.SetNearestWaypoint(Beasts.FilteredBeasts((TrainerSpells_SearchText or ""):lower()))
    end)
    nearest:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TrainerSpells:Trans("LID_NEARESTBEAST"))
        GameTooltip:AddLine(TrainerSpells:Trans("LID_NEARESTBEAST_DESC"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    nearest:SetScript("OnLeave", GameTooltip_Hide)
    TrainerLocations.AddResolveListener(function()
        if controls:IsVisible() then TrainerSpells_Refresh() end
    end)
    controls:SetScript("OnShow", function()
        tameable:SetChecked(TrainerSpells_Character.beastTameableOnly and true or false)
        for _, dropdown in ipairs(dropdowns) do dropdown:UpdateLabel() end
    end)
    return controls
end
TrainerSpells.BeastControls = TrainerSpells:CreateBeastControls(TrainerSpells.ClassFrame)

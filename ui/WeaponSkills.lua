local _, TrainerSpells = ...
local weaponData = TrainerSpellsWeaponSkills
if not weaponData then return end

local classFrame = TrainerSpells.ClassFrame
local orderBySpellID = {}
for index, spellID in ipairs(weaponData.order) do
    orderBySpellID[spellID] = index
end

local function IsWeaponSkillKnown(spellID)
    local spellBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if C_SpellBook and spellBank then
        if C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(spellID, spellBank, false) then return true end
        if C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then return true end
    end

    return IsPlayerSpell and IsPlayerSpell(spellID) or false
end

local function BuildLocations(skill, faction)
    local locations = {}
    local zoneIDs = skill.locations and skill.locations[faction]
    for _, zoneID in ipairs(zoneIDs or {}) do
        local zone = weaponData.zones[zoneID]
        if zone then
            table.insert(locations, {
                id = zoneID,
                icon = zone.icon,
                name = C_Map.GetAreaInfo(zoneID) or tostring(zoneID),
                uiMapID = zone.uiMapID,
            })
        end
    end

    table.sort(locations, function(a, b) return a.name < b.name end)
    return locations
end

local function EntryMatchesSearch(entry, searchText)
    if searchText == "" then return true end
    local text = entry.name
    for _, location in ipairs(entry.locations) do
        text = text .. " " .. location.name
    end

    return text:lower():find(searchText, 1, true) ~= nil
end

local function SortWeaponEntries(entries)
    local grouping = TrainerSpells_Character.weaponGrouping
    table.sort(entries, function(a, b)
        if grouping == "location" then
            local locationA = a.locations[1] and a.locations[1].name or ""
            local locationB = b.locations[1] and b.locations[1].name or ""
            if locationA ~= locationB then return locationA < locationB end
        end

        local orderA = orderBySpellID[a.spellID] or 0
        local orderB = orderBySpellID[b.spellID] or 0
        if orderA == orderB then return a.name < b.name end
        return orderA < orderB
    end)
end

local function AppendWeaponCategory(items, entries, text, color, groupKey, showCost, headerDepth)
    if #entries == 0 then return end
    TrainerSpells:AddHeaderItem(items, text, color, showCost and TrainerSpells:SumCost(entries) or nil, groupKey, nil, #entries, headerDepth, "skill")
    if TrainerSpells:IsGroupCollapsed(groupKey) then return end
    for _, entry in ipairs(entries) do
        table.insert(items, {
            isWeaponSkill = true,
            entry = entry,
            color = color,
            showCost = showCost,
            rowDepth = headerDepth,
        })
    end
end

local function AppendStatusCategories(items, available, future, known, keyPrefix, headerDepth)
    SortWeaponEntries(available)
    SortWeaponEntries(future)
    SortWeaponEntries(known)
    AppendWeaponCategory(items, available, TrainerSpells:Trans("LID_AVAILABLENOW"), TrainerSpells.UIColors.AVAILABLE, keyPrefix .. "available", true, headerDepth)
    AppendWeaponCategory(items, future, TrainerSpells:Trans("LID_NOTYETAVAILABLE"), TrainerSpells.UIColors.NOTYET, keyPrefix .. "notyet", true, headerDepth)
    AppendWeaponCategory(items, known, TrainerSpells:Trans("LID_ALREADYLEARNED"), TrainerSpells.UIColors.KNOWN, keyPrefix .. "known", false, headerDepth)
end

local function AddToStatus(entry, selectedLevel, available, future, known)
    if entry.known then
        if not TrainerSpells_Character.hideLearnedWeaponSkills then table.insert(known, entry) end
    else
        table.insert(entry.level <= selectedLevel and available or future, entry)
    end
end

local function BuildLocationItems(items, entries, searchText, selectedLevel)
    local groups = {}
    for _, entry in ipairs(entries) do
        for _, location in ipairs(entry.locations) do
            local locationEntry = {
                spellID = entry.spellID,
                name = entry.name,
                icon = entry.icon,
                level = entry.level,
                cost = entry.cost,
                known = entry.known,
                locations = {location},
            }

            if not (locationEntry.known and TrainerSpells_Character.hideLearnedWeaponSkills) and EntryMatchesSearch(locationEntry, searchText) then
                local group = groups[location.id]
                if not group then
                    group = {id = location.id, name = location.name, available = {}, future = {}, known = {}}
                    groups[location.id] = group
                end

                AddToStatus(locationEntry, selectedLevel, group.available, group.future, group.known)
            end
        end
    end

    local orderedGroups = {}
    for _, group in pairs(groups) do
        table.insert(orderedGroups, group)
    end

    table.sort(orderedGroups, function(a, b) return a.name < b.name end)
    for _, group in ipairs(orderedGroups) do
        if #group.available + #group.future + #group.known > 0 then
            local groupKey = "weapon_location_" .. group.id
            TrainerSpells:AddHeaderItem(items, group.name, "|cffffffff", nil, groupKey)
            if not TrainerSpells:IsGroupCollapsed(groupKey) then
                AppendStatusCategories(items, group.available, group.future, group.known, groupKey .. "_", 1)
            end
        end
    end
end

function TrainerSpells:BuildWeaponSkillItems(items, searchText, selectedLevel)
    local classToken = select(2, UnitClass("player"))
    local faction = UnitFactionGroup("player")
    local entries = {}
    for _, spellID in ipairs(weaponData.order) do
        local skill = weaponData.skills[spellID]
        if skill and skill.classes[classToken] then
            local name, _, icon = TrainerSpells:GetSpellInfo(spellID)
            local locations = BuildLocations(skill, faction)
            if name and icon and #locations > 0 then
                table.insert(entries, {
                    spellID = spellID,
                    name = name,
                    icon = icon,
                    level = skill.level or 1,
                    cost = skill.cost,
                    known = IsWeaponSkillKnown(spellID),
                    locations = locations,
                })
            end
        end
    end

    if TrainerSpells_Character.weaponGrouping == "location" then
        BuildLocationItems(items, entries, searchText, selectedLevel)
        return
    end

    local available, future, known = {}, {}, {}
    for _, entry in ipairs(entries) do
        if EntryMatchesSearch(entry, searchText) then AddToStatus(entry, selectedLevel, available, future, known) end
    end

    AppendStatusCategories(items, available, future, known, "weapon_", 0)
end

local controls = CreateFrame("Frame", "TrainerSpellsWeaponControls", classFrame)
TrainerSpells.WeaponControls = controls
controls:SetHeight(28)
controls:Hide()
local dropdown = CreateFrame("DropdownButton", "TrainerSpellsWeaponGroupingDropdown", controls, "WowStyle1DropdownTemplate")
dropdown:SetPoint("LEFT")
dropdown:SetSize(170, 26)
local hideLearned = CreateFrame("CheckButton", "TrainerSpellsHideLearnedWeaponSkills", controls, "UICheckButtonTemplate")
hideLearned:SetPoint("LEFT", dropdown, "RIGHT", 10, 0)
hideLearned:SetSize(24, 24)
hideLearned:SetChecked(TrainerSpells_Character.hideLearnedWeaponSkills)
local hideLearnedText = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
hideLearnedText:SetPoint("LEFT", hideLearned, "RIGHT", 2, 0)
hideLearnedText:SetText(TrainerSpells:Trans("LID_HIDELEARNED"))
hideLearned:SetScript("OnClick", function(self)
    TrainerSpells_Character.hideLearnedWeaponSkills = self:GetChecked() and true or false
    TrainerSpells_Refresh()
end)

local function GroupingLabel(mode)
    return TrainerSpells:Trans(mode == "location" and "LID_LOCATION" or "LID_WEAPON")
end

local function UpdateDropdownText()
    dropdown:SetText(GroupingLabel(TrainerSpells_Character.weaponGrouping))
end

dropdown:SetupMenu(function(_, rootDescription)
    for _, mode in ipairs({"weapon", "location"}) do
        rootDescription:CreateRadio(GroupingLabel(mode), function()
            return TrainerSpells_Character.weaponGrouping == mode
        end, function()
            TrainerSpells_Character.weaponGrouping = mode
            UpdateDropdownText()
            TrainerSpells_Refresh()
        end)
    end
end)

UpdateDropdownText()

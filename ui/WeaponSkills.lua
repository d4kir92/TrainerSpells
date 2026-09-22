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

local function AppendWeaponCategory(items, entries, text, color, groupKey)
    if #entries == 0 then return end
    TrainerSpells:AddHeaderItem(items, text, color, nil, groupKey, nil, #entries)
    if TrainerSpells:IsGroupCollapsed(groupKey) then return end
    for _, entry in ipairs(entries) do
        table.insert(items, {
            isWeaponSkill = true,
            entry = entry,
            color = color,
        })
    end
end

function TrainerSpells:BuildWeaponSkillItems(items, searchText, selectedLevel)
    local classToken = select(2, UnitClass("player"))
    local faction = UnitFactionGroup("player")
    local available, future = {}, {}
    for _, spellID in ipairs(weaponData.order) do
        local skill = weaponData.skills[spellID]
        if skill and skill.classes[classToken] and not IsWeaponSkillKnown(spellID) then
            local name, _, icon = TrainerSpells:GetSpellInfo(spellID)
            local locations = BuildLocations(skill, faction)
            if name and icon and #locations > 0 then
                local entry = {
                    spellID = spellID,
                    name = name,
                    icon = icon,
                    level = skill.level or 1,
                    locations = locations,
                }

                if EntryMatchesSearch(entry, searchText) then
                    table.insert(entry.level <= selectedLevel and available or future, entry)
                end
            end
        end
    end

    SortWeaponEntries(available)
    SortWeaponEntries(future)
    AppendWeaponCategory(items, available, TrainerSpells:Trans("LID_AVAILABLENOW"), TrainerSpells.UIColors.AVAILABLE, "weapon_available")
    AppendWeaponCategory(items, future, TrainerSpells:Trans("LID_NOTYETAVAILABLE"), TrainerSpells.UIColors.NOTYET, "weapon_notyet")
end

local controls = CreateFrame("Frame", "TrainerSpellsWeaponControls", classFrame)
TrainerSpells.WeaponControls = controls
controls:SetHeight(28)
controls:Hide()
local label = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
label:SetPoint("LEFT")
label:SetText(TrainerSpells:Trans("LID_GROUPBY") .. ":")
local dropdown = CreateFrame("DropdownButton", "TrainerSpellsWeaponGroupingDropdown", controls, "WowStyle1DropdownTemplate")
dropdown:SetPoint("LEFT", label, "RIGHT", 10, 0)
dropdown:SetSize(170, 26)

local function GroupingLabel(mode)
    return TrainerSpells:Trans(mode == "location" and "LID_LOCATION" or "LID_WEAPON")
end

local function UpdateDropdownText()
    dropdown:SetText(GroupingLabel(TrainerSpells_Character.weaponGrouping))
end

dropdown:SetupMenu(function(_, rootDescription)
    for _, mode in ipairs({"location", "weapon"}) do
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

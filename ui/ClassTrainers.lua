local _, TrainerSpells = ...
local trainerData = TrainerSpellsClassTrainers
if not trainerData then return end
local petTrainerData = TrainerSpellsPetTrainers or {}

local classFrame = TrainerSpells.ClassFrame
local localeAliases = {enGB = "enUS"}
local factionTokens = {Alliance = "A", Horde = "H"}
local petTrainerTexts = {
    HUNTER = {label = "LID_PETTRAINER", nearest = "LID_NEARESTPETTRAINER", desc = "LID_NEARESTPETTRAINER_DESC", none = "LID_NOPETTRAINER"},
    WARLOCK = {label = "LID_DEMONTRAINER", nearest = "LID_NEARESTDEMONTRAINER", desc = "LID_NEARESTDEMONTRAINER_DESC", none = "LID_NODEMONTRAINER"},
}

local function GetTrainerName(trainer)
    local locale = localeAliases[GetLocale()] or GetLocale()
    return trainer.names[locale] or trainer.names.enUS
end

local function BuildEntry(trainer, location, petLabel)
    return {
        displayID = trainer.displayID,
        location = location,
        name = GetTrainerName(trainer),
        npcID = trainer.npcID,
        starter = trainer.starter,
        petLabel = petLabel,
        zoneName = C_Map.GetAreaInfo(location.areaID) or tostring(location.areaID),
    }
end

local function AddEntries(entries, trainers, searchText, usableOnly, petLabel)
    local faction = factionTokens[UnitFactionGroup("player")]
    local level = UnitLevel("player") or 1
    local hideStarter = TrainerSpells_Character.hideStarterClassTrainers
    for _, trainer in ipairs(trainers or {}) do
        local matchesFaction = faction and trainer.faction:find(faction, 1, true)
        local isUsable = not trainer.starter or level <= 6
        local isVisible = usableOnly or not hideStarter or not trainer.starter
        if matchesFaction and isVisible and (not usableOnly or isUsable) then
            for _, location in ipairs(trainer.locations) do
                local entry = BuildEntry(trainer, location, petLabel)
                local searchable = (entry.name .. " " .. entry.zoneName .. " " .. (petLabel or "")):lower()
                if searchText == "" or searchable:find(searchText, 1, true) then table.insert(entries, entry) end
            end
        end
    end
end

local function SortEntries(entries)
    table.sort(entries, function(a, b)
        if a.zoneName ~= b.zoneName then return a.zoneName < b.zoneName end
        if (a.petLabel ~= nil) ~= (b.petLabel ~= nil) then return a.petLabel == nil end
        return a.name < b.name
    end)
    return entries
end

local function GetPlayerClassToken()
    return select(2, UnitClass("player"))
end

local function GetPetTrainerLabel(classToken)
    local texts = petTrainerTexts[classToken]
    return texts and TrainerSpells:Trans(texts.label)
end

local function GetEntries(searchText, usableOnly)
    local entries = {}
    AddEntries(entries, trainerData[GetPlayerClassToken()], searchText, usableOnly)
    return SortEntries(entries)
end

local function GetPetEntries(searchText, usableOnly)
    local entries = {}
    local classToken = GetPlayerClassToken()
    AddEntries(entries, petTrainerData[classToken], searchText, usableOnly, GetPetTrainerLabel(classToken))
    return SortEntries(entries)
end

function TrainerSpells:BuildClassTrainerItems(items, searchText)
    local entries = GetEntries(searchText, false)
    for _, entry in ipairs(GetPetEntries(searchText, false)) do table.insert(entries, entry) end
    SortEntries(entries)
    local lastAreaID
    for _, entry in ipairs(entries) do
        if entry.location.areaID ~= lastAreaID then
            lastAreaID = entry.location.areaID
            TrainerSpells:AddHeaderItem(items, entry.zoneName, "|cffffffff", nil, "class_trainer_" .. lastAreaID)
        end
        if not TrainerSpells:IsGroupCollapsed("class_trainer_" .. lastAreaID) then
            table.insert(items, {isClassTrainer = true, entry = entry})
        end
    end
end

local function GetWorldPosition(uiMapID, x, y)
    if not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return nil end
    local continentID, position = C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(x / 100, y / 100))
    if not continentID or not position then return nil end
    return continentID, position
end

local function FindNearest(entries)
    if not C_Map.GetWorldPosFromMapPos then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    local mapPosition = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not mapID or not mapPosition then return nil end
    local playerContinent, playerWorld = C_Map.GetWorldPosFromMapPos(mapID, mapPosition)
    local nearest
    local nearestDistance
    for _, entry in ipairs(entries) do
        local location = entry.location
        local continentID, worldPosition = GetWorldPosition(location.uiMapID, location.x, location.y)
        if playerWorld and continentID == playerContinent and worldPosition then
            local dx = worldPosition.x - playerWorld.x
            local dy = worldPosition.y - playerWorld.y
            local distance = dx * dx + dy * dy
            if not nearestDistance or distance < nearestDistance then
                nearest = entry
                nearestDistance = distance
            end
        end
    end
    return nearest
end

function TrainerSpells:GetNearestClassTrainer()
    return FindNearest(GetEntries("", true))
end

function TrainerSpells:GetNearestPetTrainer()
    return FindNearest(GetPetEntries("", true))
end

function TrainerSpells:SetClassTrainerWaypoint(entry)
    if not entry or not entry.location then return false end
    local location = entry.location
    local waypoint = {
        uiMapID = location.uiMapID,
        x = location.x,
        y = location.y,
        npcName = entry.name,
    }
    return TrainerSpells:SetWeaponTrainerWaypoint(waypoint)
end

local function SetNearestWaypoint(entry, noneKey)
    if entry and TrainerSpells:SetClassTrainerWaypoint(entry) then
        TrainerSpells:MSG((TrainerSpells:Trans("LID_WAYPOINTFOR")):format(entry.name, entry.zoneName, entry.location.x, entry.location.y))
    else
        TrainerSpells:MSG(TrainerSpells:Trans(noneKey))
    end
end

local controls = CreateFrame("Frame", "TrainerSpellsClassTrainerControls", classFrame)
TrainerSpells.ClassTrainerControls = controls
controls:SetHeight(36)
controls:Hide()
local nearestButton = CreateFrame("Button", nil, controls, "MainMenuFrameButtonTemplate")
nearestButton:SetPoint("LEFT")
nearestButton:SetSize(200, 36)
nearestButton:SetText(TrainerSpells:Trans("LID_NEARESTCLASSTRAINER"))
nearestButton:SetScript("OnClick", function()
    SetNearestWaypoint(TrainerSpells:GetNearestClassTrainer(), "LID_NOCLASSTRAINER")
end)
nearestButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TrainerSpells:Trans("LID_NEARESTCLASSTRAINER"))
    GameTooltip:AddLine(TrainerSpells:Trans("LID_NEARESTCLASSTRAINER_DESC"), 1, 1, 1, true)
    GameTooltip:Show()
end)
nearestButton:SetScript("OnLeave", GameTooltip_Hide)
local nearestPetButton = CreateFrame("Button", nil, controls, "MainMenuFrameButtonTemplate")
nearestPetButton:SetPoint("LEFT", nearestButton, "RIGHT", 8, 0)
nearestPetButton:SetSize(200, 36)
nearestPetButton:Hide()
nearestPetButton:SetScript("OnClick", function()
    local texts = petTrainerTexts[GetPlayerClassToken()]
    if texts then SetNearestWaypoint(TrainerSpells:GetNearestPetTrainer(), texts.none) end
end)
nearestPetButton:SetScript("OnEnter", function(self)
    local texts = petTrainerTexts[GetPlayerClassToken()]
    if not texts then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(TrainerSpells:Trans(texts.nearest))
    GameTooltip:AddLine(TrainerSpells:Trans(texts.desc), 1, 1, 1, true)
    GameTooltip:Show()
end)
nearestPetButton:SetScript("OnLeave", GameTooltip_Hide)
local hideStarter = CreateFrame("CheckButton", "TrainerSpellsHideStarterClassTrainers", controls, "UICheckButtonTemplate")
hideStarter:SetSize(24, 24)
hideStarter:SetChecked(TrainerSpells_Character.hideStarterClassTrainers)
local hideStarterText = controls:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
hideStarterText:SetPoint("LEFT", hideStarter, "RIGHT", 2, 0)
hideStarterText:SetText(TrainerSpells:Trans("LID_HIDESTARTERTRAINERS"))
hideStarter:SetScript("OnClick", function(self)
    TrainerSpells_Character.hideStarterClassTrainers = self:GetChecked() and true or false
    TrainerSpells_Refresh()
end)
controls:SetScript("OnShow", function()
    hideStarter:SetChecked(TrainerSpells_Character.hideStarterClassTrainers)
    local texts = petTrainerTexts[GetPlayerClassToken()]
    local showPetButton = texts and petTrainerData[GetPlayerClassToken()] and true or false
    nearestPetButton:SetShown(showPetButton)
    if showPetButton then nearestPetButton:SetText(TrainerSpells:Trans(texts.nearest)) end
    hideStarter:ClearAllPoints()
    hideStarter:SetPoint("LEFT", showPetButton and nearestPetButton or nearestButton, "RIGHT", 12, 0)
end)

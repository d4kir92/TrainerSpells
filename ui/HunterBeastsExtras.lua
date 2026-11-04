local _, TrainerSpells = ...
local Beasts = TrainerSpells.HunterBeasts
if not Beasts then return end
local data = TrainerSpellsHunterBeasts
Beasts.beastById = {}
for _, beast in ipairs(data.beasts) do Beasts.beastById[beast.id] = beast end
Beasts.maxMapPins = 400

function Beasts.Store()
    local settings = TrainerSpells_Character
    settings.beastKnown = settings.beastKnown or {}
    settings.beastTamed = settings.beastTamed or {}
    settings.beastFavorites = settings.beastFavorites or {}
    settings.beastFavorites.beasts = settings.beastFavorites.beasts or {}
    settings.beastFavorites.spells = settings.beastFavorites.spells or {}
    return settings
end

function Beasts.IsKnown(spellID)
    local store = Beasts.Store()
    for _, found in pairs(store.beastKnown) do
        if found[spellID] then return true end
    end
    return false
end

function Beasts.IsFavoriteBeast(npcID)
    return Beasts.Store().beastFavorites.beasts[npcID] == true
end

function Beasts.IsFavoriteSpell(spellID)
    return Beasts.Store().beastFavorites.spells[spellID] == true
end

function Beasts.ToggleFavoriteBeast(npcID)
    local favorites = Beasts.Store().beastFavorites.beasts
    favorites[npcID] = not favorites[npcID] or nil
    TrainerSpells_Refresh()
    if Beasts.detailFrame and Beasts.detailFrame:IsShown() and Beasts.detailFrame.beast then Beasts.ShowDetails(Beasts.detailFrame.beast) end
end

function Beasts.ToggleFavoriteSpell(spellID)
    local favorites = Beasts.Store().beastFavorites.spells
    favorites[spellID] = not favorites[spellID] or nil
    TrainerSpells_Refresh()
    local frame = Beasts.abilityFrame
    if frame and frame:IsShown() and frame.rank then Beasts.ShowAbility(frame.abilityKey, frame.rank, true) end
end

function Beasts.SpeedStore()
    TrainerSpells_Global = TrainerSpells_Global or {}
    TrainerSpells_Global.beastSpeeds = TrainerSpells_Global.beastSpeeds or {}
    return TrainerSpells_Global.beastSpeeds
end

function Beasts.GetSpeed(beast)
    return Beasts.SpeedStore()[beast.id] or beast.speed
end

function Beasts.SpeedText(beast)
    local speed = Beasts.GetSpeed(beast)
    return speed and ("%.1f"):format(speed) or nil
end

function Beasts.IsUsable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

function Beasts.UnitBeast(unit)
    if not unit then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or not Beasts.IsUsable(guid) or type(guid) ~= "string" then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType ~= "Creature" then return nil end
    return Beasts.beastById[tonumber(npcID)]
end

function Beasts.RecordSpeed(unit, beast)
    if not beast then return end
    local okCombat, inCombat = pcall(UnitAffectingCombat, unit)
    if not okCombat or not Beasts.IsUsable(inCombat) or inCombat then return end
    local ok, speed = pcall(UnitAttackSpeed, unit)
    if not ok or not Beasts.IsUsable(speed) or type(speed) ~= "number" or speed <= 0 then return end
    local rounded = math.floor(speed * 10 + 0.5) / 10
    local store = Beasts.SpeedStore()
    if store[beast.id] ~= rounded then
        store[beast.id] = rounded
        Beasts.ScheduleRefresh()
    end
end

function Beasts.RankByName(name, rankText)
    if not Beasts.IsUsable(name) or type(name) ~= "string" then return nil end
    if not Beasts.nameIndex then
        Beasts.nameIndex = {}
        for key in pairs(data.abilities) do
            Beasts.nameIndex[key] = key
            Beasts.nameIndex[Beasts.AbilityName(key)] = key
        end
    end
    local key = Beasts.nameIndex[name]
    if not key then return nil end
    local number = Beasts.IsUsable(rankText) and type(rankText) == "string" and tonumber(rankText:match("%d+")) or 1
    for _, rank in ipairs(data.abilities[key].ranks) do
        if rank.rank == number then return rank.spell end
    end
end

function Beasts.SetKnownSource(source, found)
    if not next(found) then return end
    local store = Beasts.Store().beastKnown
    local old = store[source]
    local changed = not old
    if old then
        for spell in pairs(found) do if not old[spell] then changed = true end end
        for spell in pairs(old) do if not found[spell] then changed = true end end
    end
    store[source] = found
    if changed then Beasts.ScheduleRefresh() end
end

function Beasts.ScanCraft()
    if not GetNumCrafts or not GetCraftInfo or not GetCraftDisplaySkillLine then return end
    local beastTraining = TrainerSpells:GetSpellInfo(5149)
    if not beastTraining or GetCraftDisplaySkillLine() ~= beastTraining then return end
    local found = {}
    for index = 1, GetNumCrafts() or 0 do
        local name, rankText, craftType = GetCraftInfo(index)
        if craftType ~= "header" then
            local spell = Beasts.RankByName(name, rankText)
            if spell then found[spell] = true end
        end
    end
    Beasts.SetKnownSource("craft", found)
end

function Beasts.ScanPetBook()
    local found = {}
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    if book and book.HasPetSpells and book.GetSpellBookItemInfo and bank then
        for index = 1, book.HasPetSpells() or 0 do
            local ok, info = pcall(book.GetSpellBookItemInfo, index, bank)
            if ok and type(info) == "table" then
                local spell = info.spellID or info.actionID
                if Beasts.IsUsable(spell) and Beasts.rankBySpell[spell] then
                    found[spell] = true
                else
                    spell = Beasts.RankByName(info.name, info.subName)
                    if spell then found[spell] = true end
                end
            end
        end
    else
        local count = HasPetSpells and HasPetSpells() or 0
        local getName = GetSpellBookItemName or GetSpellName
        for index = 1, getName and count or 0 do
            local ok, name, rankText = pcall(getName, index, BOOKTYPE_PET or "pet")
            local spell = ok and Beasts.RankByName(name, rankText)
            if spell then found[spell] = true end
        end
    end
    local petName = UnitName("pet")
    if Beasts.IsUsable(petName) and petName then Beasts.SetKnownSource("pet:" .. petName, found) end
end

function Beasts.ScanStable()
    local stable = C_StableInfo
    if not stable then return end
    local tamed = Beasts.Store().beastTamed
    for _, method in ipairs({"GetActivePetList", "GetStabledPetList"}) do
        local ok, list = pcall(stable[method] or error)
        for _, pet in ipairs(ok and type(list) == "table" and list or {}) do
            local creatureID = pet.creatureID
            if Beasts.IsUsable(creatureID) and Beasts.beastById[creatureID] then tamed[creatureID] = true end
        end
    end
    local found = {}
    for creatureID in pairs(tamed) do
        for _, spell in ipairs(Beasts.beastById[creatureID] and Beasts.beastById[creatureID].spells or {}) do found[spell] = true end
    end
    Beasts.SetKnownSource("tamed", found)
end

function Beasts.ScanKnown()
    for _, scan in ipairs({Beasts.ScanCraft, Beasts.ScanPetBook, Beasts.ScanStable}) do
        local ok, err = pcall(scan)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end

function Beasts.ScheduleRefresh()
    if Beasts.refreshScheduled or not C_Timer then return end
    Beasts.refreshScheduled = true
    C_Timer.After(0.5, function()
        Beasts.refreshScheduled = false
        if TrainerSpells_Refresh then TrainerSpells_Refresh() end
        if Beasts.UpdatePins then Beasts.UpdatePins() end
    end)
end

function Beasts.ScheduleScan()
    if Beasts.scanScheduled or not C_Timer then return end
    Beasts.scanScheduled = true
    C_Timer.After(1, function()
        Beasts.scanScheduled = false
        Beasts.ScanKnown()
    end)
end

Beasts.eventFrame = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "CRAFT_SHOW", "CRAFT_UPDATE", "PET_BAR_UPDATE", "UNIT_PET", "SPELLS_CHANGED", "PET_STABLE_SHOW", "PET_STABLE_UPDATE", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT"}) do
    pcall(Beasts.eventFrame.RegisterEvent, Beasts.eventFrame, event)
end
Beasts.eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        Beasts.RecordSpeed("target", Beasts.UnitBeast("target"))
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Beasts.RecordSpeed("mouseover", Beasts.UnitBeast("mouseover"))
    elseif event ~= "UNIT_PET" or unit == "player" then
        Beasts.ScheduleScan()
    end
end)

function Beasts.AddUnitTooltip(tooltip)
    if not tooltip or not tooltip.GetUnit then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or not Beasts.IsUsable(unit) then return end
    local beast = Beasts.UnitBeast(unit)
    if not beast then return end
    Beasts.RecordSpeed(unit, beast)
    local favorite = Beasts.IsFavoriteBeast(beast.id) and (Beasts.favoriteIcon .. " ") or ""
    tooltip:AddLine(favorite .. "|cffffd100" .. TrainerSpells:Trans("LID_TAMEABLE") .. ":|r " .. Beasts.FamilyName(beast.family), 1, 1, 1)
    local speed = Beasts.SpeedText(beast)
    if speed then tooltip:AddLine("|cffffd100" .. TrainerSpells:Trans("LID_ATTACKSPEED") .. ":|r " .. speed, 1, 1, 1) end
    for _, spell in ipairs(Beasts.SortedSpells(beast)) do
        tooltip:AddLine("|T" .. Beasts.SpellIcon(spell) .. ":0|t " .. Beasts.AbilityLineColored(spell), 1, 1, 1)
    end
    tooltip:Show()
    return true
end

function Beasts.AddUnitTooltipOnce(tooltip)
    if tooltip ~= GameTooltip or tooltip.trainerSpellsBeastShown then return end
    if Beasts.AddUnitTooltip(tooltip) then tooltip.trainerSpellsBeastShown = true end
end

GameTooltip:HookScript("OnTooltipCleared", function(tooltip) tooltip.trainerSpellsBeastShown = nil end)
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, Beasts.AddUnitTooltipOnce)
end
if GameTooltip:HasScript("OnTooltipSetUnit") then GameTooltip:HookScript("OnTooltipSetUnit", Beasts.AddUnitTooltipOnce) end

function Beasts.IsMapAncestor(ancestorID, uiMapID)
    local info = C_Map.GetMapInfo(uiMapID)
    local depth = 0
    while info and info.parentMapID and info.parentMapID ~= 0 and depth < 10 do
        if info.parentMapID == ancestorID then return true end
        info = C_Map.GetMapInfo(info.parentMapID)
        depth = depth + 1
    end
    return false
end

function Beasts.ProjectSpawn(spawn, mapID)
    if spawn[1] == mapID then return spawn[2] / 100, spawn[3] / 100 end
    if not C_Map.GetWorldPosFromMapPos or not C_Map.GetMapPosFromWorldPos or not CreateVector2D then return nil end
    if not Beasts.IsMapAncestor(mapID, spawn[1]) then return nil end
    local continentID, world = C_Map.GetWorldPosFromMapPos(spawn[1], CreateVector2D(spawn[2] / 100, spawn[3] / 100))
    if not continentID or not world then return nil end
    local _, position = C_Map.GetMapPosFromWorldPos(continentID, world, mapID)
    if not position or position.x < 0 or position.x > 1 or position.y < 0 or position.y > 1 then return nil end
    return position.x, position.y
end

function Beasts.EnsureMapOverlay()
    if Beasts.mapOverlay then return Beasts.mapOverlay end
    local canvas = WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
    if not canvas then return nil end
    local overlay = CreateFrame("Frame", nil, canvas)
    overlay:SetAllPoints(canvas)
    overlay:SetFrameLevel(canvas:GetFrameLevel() + 50)
    overlay.pins = {}
    Beasts.mapOverlay = overlay
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() Beasts.UpdatePins() end) end
    if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function() Beasts.UpdatePinSizes() end) end
    WorldMapFrame:HookScript("OnShow", function() Beasts.UpdatePins() end)
    return overlay
end

function Beasts.AcquirePin(index)
    local overlay = Beasts.mapOverlay
    local pin = overlay.pins[index]
    if pin then return pin end
    pin = CreateFrame("Button", nil, overlay)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    pin.highlight = pin:CreateTexture(nil, "HIGHLIGHT")
    pin.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    pin.highlight:SetBlendMode("ADD")
    pin.highlight:SetAllPoints()
    pin:SetScript("OnEnter", function(sel)
        GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
        Beasts.AddBeastTooltip(GameTooltip, sel.beast)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(TrainerSpells:Trans("LID_LEFTCLICK_SETWAYPOINT"), 0.2, 1, 0.2)
        GameTooltip:AddLine(TrainerSpells:Trans("LID_PIN_RIGHTCLICK"), 0.2, 1, 0.2)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", GameTooltip_Hide)
    pin:SetScript("OnClick", function(sel, button)
        if button == "RightButton" then
            Beasts.ClearMap()
        else
            TrainerSpells:SetMapWaypoint({uiMapID = sel.spawn[1], x = sel.spawn[2], y = sel.spawn[3], npcName = Beasts.BeastName(sel.beast)})
        end
    end)
    overlay.pins[index] = pin
    return pin
end

function Beasts.UpdatePinSizes()
    local overlay = Beasts.mapOverlay
    if not overlay then return end
    local scale = WorldMapFrame.ScrollContainer.Child:GetScale() or 1
    local size = 18 / math.max(0.1, scale)
    for _, pin in ipairs(overlay.pins) do pin:SetSize(size, size) end
end

function Beasts.UpdatePins()
    local overlay = Beasts.mapOverlay
    if not overlay then return end
    for _, pin in ipairs(overlay.pins) do pin:Hide() end
    local pinned = Beasts.pinned
    local mapID = WorldMapFrame:GetMapID()
    if not pinned or not mapID or not WorldMapFrame:IsShown() then return end
    local width, height = overlay:GetWidth(), overlay:GetHeight()
    local count = 0
    for _, beast in ipairs(pinned.beasts) do
        local family = data.families[beast.family]
        for _, spawn in ipairs(beast.spawns or {}) do
            local x, y = Beasts.ProjectSpawn(spawn, mapID)
            if x and count < Beasts.maxMapPins then
                count = count + 1
                local pin = Beasts.AcquirePin(count)
                pin.beast, pin.spawn = beast, spawn
                if beast.model and beast.model > 0 and SetPortraitTextureFromCreatureDisplayID then
                    SetPortraitTextureFromCreatureDisplayID(pin.icon, beast.model)
                else
                    pin.icon:SetTexture(family and family.icon or 132161)
                end
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", overlay, "TOPLEFT", x * width, -y * height)
                pin:Show()
            end
        end
    end
    Beasts.UpdatePinSizes()
end

function Beasts.ShowOnMap(beasts, label)
    local list = {}
    for _, beast in ipairs(beasts or {}) do
        if beast.spawns and #beast.spawns > 0 then table.insert(list, beast) end
    end
    if #list == 0 then
        TrainerSpells:MSG(TrainerSpells:Trans("LID_NOBEAST"))
        return
    end
    if not Beasts.EnsureMapOverlay() then return end
    Beasts.pinned = {beasts = list, label = label}
    local entries = {}
    for _, beast in ipairs(list) do
        for _, entry in ipairs(Beasts.SpawnEntries(beast)) do table.insert(entries, entry) end
    end
    local target = TrainerSpells.TrainerLocations.FindNearest(entries) or entries[1]
    if not (InCombatLockdown and InCombatLockdown()) then TrainerSpells:OpenWorldMapAt(target.location.uiMapID) end
    Beasts.UpdatePins()
    TrainerSpells:MSG(TrainerSpells:Trans("LID_PINS_SHOWN"):format(label or "", #list))
end

function Beasts.ClearMap()
    Beasts.pinned = nil
    Beasts.UpdatePins()
end

function Beasts.IsPinned(beast)
    if not Beasts.pinned then return false end
    for _, pinned in ipairs(Beasts.pinned.beasts) do
        if pinned == beast then return true end
    end
    return false
end

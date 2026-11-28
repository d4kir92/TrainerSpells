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
    if not Beasts.storeCleaned then
        Beasts.storeCleaned = true
        settings.beastTamed = nil
        for source in pairs(settings.beastKnown) do
            if source == "tamed" or source:find("^pet:") then settings.beastKnown[source] = nil end
        end
    end
    if not settings.beastKnownExactRanks then
        for _, found in pairs(settings.beastKnown) do
            for spell in pairs(found) do
                local entry = Beasts.rankBySpell[spell]
                if entry and entry.rank.rank == 1 and #data.abilities[entry.key].ranks > 1 then found[spell] = nil end
            end
        end
        settings.beastKnownExactRanks = true
    end
    settings.beastKnown.learned = settings.beastKnown.learned or {}
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
    local ranks = data.abilities[key].ranks
    local number = Beasts.IsUsable(rankText) and type(rankText) == "string" and tonumber(rankText:match("%d+"))
    if not number then return #ranks == 1 and ranks[1].spell or nil end
    for _, rank in ipairs(ranks) do
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
    if not GetNumCrafts or not GetCraftInfo then return end
    local beastTraining = TrainerSpells:GetSpellInfo(5149)
    if not beastTraining then return end
    local craftName = GetCraftDisplaySkillLine and GetCraftDisplaySkillLine() or GetCraftName and GetCraftName()
    if not craftName and GetCraftSkillLine and (GetNumCrafts() or 0) > 0 then
        local ok, line = pcall(GetCraftSkillLine, 1)
        if ok then craftName = line end
    end
    if craftName ~= beastTraining then return end
    local found = {}
    for spell in pairs(Beasts.Store().beastKnown.craft or {}) do found[spell] = true end
    for index = 1, GetNumCrafts() or 0 do
        local name, rankText, craftType = GetCraftInfo(index)
        if craftType ~= "header" then
            local spell = Beasts.RankByName(name, rankText)
            if spell then found[spell] = true end
        end
    end
    Beasts.SetKnownSource("craft", found)
end

function Beasts.MarkLearned(spell)
    if not spell or not Beasts.rankBySpell[spell] then return end
    local learned = Beasts.Store().beastKnown.learned
    if learned[spell] then return end
    learned[spell] = true
    Beasts.ScheduleRefresh()
end

function Beasts.LearnPatterns()
    if Beasts.learnPatterns then return Beasts.learnPatterns end
    Beasts.learnPatterns = {}
    for _, format in ipairs({ERR_LEARN_SPELL_S, ERR_LEARN_ABILITY_S}) do
        if type(format) == "string" then
            local pattern = "^" .. format:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
            table.insert(Beasts.learnPatterns, pattern)
        end
    end
    return Beasts.learnPatterns
end

function Beasts.SpellFromLearnText(text)
    local id = tonumber(text:match("|Hspell:(%d+)"))
    if id and Beasts.rankBySpell[id] then return id end
    local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""):gsub("[%[%]]", "")
    local name, rankText = plain:match("^(.-)%s*%((.-)%)%s*$")
    name = name or plain
    if not rankText and id then
        local getSubtext = C_Spell and C_Spell.GetSpellSubtext or GetSpellSubtext
        local ok, subtext = pcall(getSubtext or error, id)
        if ok and Beasts.IsUsable(subtext) then rankText = subtext end
    end
    return Beasts.RankByName(name, rankText) or Beasts.RankFromPetBook(name)
end

function Beasts.RankFromPetBook(name)
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    if not book or not book.HasPetSpells or not book.GetSpellBookItemInfo or not bank then return nil end
    local ok, count = pcall(book.HasPetSpells)
    if not ok or not Beasts.IsUsable(count) then return nil end
    for index = 1, count or 0 do
        local okInfo, info = pcall(book.GetSpellBookItemInfo, index, bank)
        if okInfo and type(info) == "table" and Beasts.IsUsable(info.name) and info.name == name then
            local id = Beasts.IsUsable(info.spellID) and info.spellID
            if id and Beasts.rankBySpell[id] then return id end
            local spell = Beasts.RankByName(name, info.subName)
            if spell then return spell end
        end
    end
end

function Beasts.OnSystemMessage(message)
    if not Beasts.IsUsable(message) or type(message) ~= "string" then return end
    for _, pattern in ipairs(Beasts.LearnPatterns()) do
        local text = message:match(pattern)
        if text then
            Beasts.MarkLearned(Beasts.SpellFromLearnText(text))
            return
        end
    end
end

function Beasts.ScanTrainer()
    if select(2, UnitClass("player")) ~= "HUNTER" or not GetNumTrainerServices or not GetTrainerServiceInfo then return end
    local petType = Enum and Enum.TrainerType and Enum.TrainerType.Pet
    local isBeastTraining = petType ~= nil and C_Trainer and C_Trainer.GetTrainerType and C_Trainer.GetTrainerType() == petType
    local source = isBeastTraining and "craft" or "trainer"
    local found = {}
    for spell in pairs(Beasts.Store().beastKnown[source] or {}) do found[spell] = true end
    -- SetTrainerServiceTypeFilter fires TRAINER_UPDATE synchronously, which refreshes ClassTrainerFrame.footer
    -- while tainted and taints InputBindingManager in the Gamepad UI.
    local restoreUsed = not TrainerSpells.IsGamepadUIEnabled() and GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter and not GetTrainerServiceTypeFilter("used")
    if restoreUsed then
        Beasts.ignoreTrainerUpdateUntil = GetTime() + 2
        SetTrainerServiceTypeFilter("used", true)
    end
    local ok, err = pcall(function()
        for index = 1, GetNumTrainerServices() or 0 do
            local name, rankText, serviceType = TrainerSpells:GetTrainerServiceInfo(index)
            if serviceType == "used" or (isBeastTraining and (serviceType == "available" or serviceType == "unavailable")) then
                local spell = Beasts.RankByName(name, rankText) or TrainerSpells:GetSpellIDForService(index, true)
                if not Beasts.rankBySpell[spell] then spell = nil end
                if spell then found[spell] = true end
            end
        end
    end)
    if restoreUsed then SetTrainerServiceTypeFilter("used", false) end
    if not ok then error(err) end
    Beasts.SetKnownSource(source, found)
end

function Beasts.ScanKnown()
    for _, scan in ipairs({Beasts.ScanCraft, Beasts.ScanTrainer}) do
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
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "CRAFT_SHOW", "CRAFT_UPDATE", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "CHAT_MSG_SYSTEM", "TRAINER_SHOW", "TRAINER_UPDATE", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT"}) do
    pcall(Beasts.eventFrame.RegisterEvent, Beasts.eventFrame, event)
end
Beasts.eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "CHAT_MSG_SYSTEM" then
        if select(2, UnitClass("player")) == "HUNTER" then Beasts.OnSystemMessage(unit) end
    elseif event == "LEARNED_SPELL_IN_TAB" then
        if Beasts.IsUsable(unit) then Beasts.MarkLearned(unit) end
        Beasts.ScheduleScan()
    elseif event == "PLAYER_TARGET_CHANGED" then
        Beasts.RecordSpeed("target", Beasts.UnitBeast("target"))
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        Beasts.RecordSpeed("mouseover", Beasts.UnitBeast("mouseover"))
    elseif event == "TRAINER_UPDATE" and Beasts.ignoreTrainerUpdateUntil and GetTime() < Beasts.ignoreTrainerUpdateUntil then
        return
    elseif event ~= "UNIT_PET" or unit == "player" then
        Beasts.ScheduleScan()
    end
end)

function Beasts.AddUnitTooltip(tooltip)
    if select(2, UnitClass("player")) ~= "HUNTER" or TrainerSpells_Character.showBeastTooltips == false then return end
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

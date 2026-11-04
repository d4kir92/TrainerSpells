local _, TrainerSpells = ...
local AutoRanks = {
    maxSlot = 180,
    pending = false,
    broken = false,
    timer = nil,
}
TrainerSpells.AutoRanks = AutoRanks

local function Secret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function OtherAddonLoaded()
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return isLoaded and isLoaded("AutoSpellRanks") and true or false
end

function AutoRanks.Settings()
    local settings = TrainerSpells_Character or {}
    if settings.autoSpellRanks == nil then settings.autoSpellRanks = true end
    if settings.autoSpellRanksReport == nil then settings.autoSpellRanksReport = true end
    return settings
end

function AutoRanks.IsActive()
    return AutoRanks.Settings().autoSpellRanks and not AutoRanks.broken and not OtherAddonLoaded()
end

function AutoRanks.SpellName(spellID)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if not name then name = TrainerSpells:GetSpellInfo(spellID) end
    if name == nil or Secret(name) then return nil end
    return name
end

function AutoRanks.Rank(spellID)
    local subtext = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID) or GetSpellSubtext and GetSpellSubtext(spellID)
    if type(subtext) ~= "string" or Secret(subtext) then return 0 end
    return tonumber(subtext:match("%d+")) or 0
end

function AutoRanks.Remember(best, name, spellID)
    if not name or not spellID or Secret(name) then return end
    local rank = AutoRanks.Rank(spellID)
    local known = best[name]
    if rank > 0 and (not known or rank > known.rank) then best[name] = {spellID = spellID, rank = rank} end
end

function AutoRanks.LegacyHighestRanks()
    local best = {}
    if not GetNumSpellTabs or not GetSpellTabInfo or not GetSpellBookItemInfo then return best end
    local bookType = BOOKTYPE_SPELL or "spell"
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for index = (offset or 0) + 1, (offset or 0) + (count or 0) do
            local itemType, spellID = GetSpellBookItemInfo(index, bookType)
            if itemType == "SPELL" and spellID and not (IsPassiveSpell and IsPassiveSpell(index, bookType)) then AutoRanks.Remember(best, AutoRanks.SpellName(spellID), spellID) end
        end
    end
    return best
end

function AutoRanks.HighestRanks()
    local best = {}
    if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines or not C_SpellBook.GetSpellBookSkillLineInfo then return AutoRanks.LegacyHighestRanks() end
    local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if lineInfo and not lineInfo.offSpecID and lineInfo.itemIndexOffset and lineInfo.numSpellBookItems then
            for index = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
                if item and item.itemType == spellType and item.spellID and not item.isOffSpec and not item.isPassive then AutoRanks.Remember(best, item.name, item.spellID) end
            end
        end
    end
    return best
end

function AutoRanks.Place(slot, spellID)
    ClearCursor()
    if C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(spellID) else PickupSpell(spellID) end
    if GetCursorInfo() ~= "spell" then
        ClearCursor()
        return false
    end
    local ok = pcall(PlaceAction, slot)
    ClearCursor()
    if not ok then
        AutoRanks.broken = true
        TrainerSpells:MSG(TrainerSpells:Trans("LID_AUTORANKS_FAILED"))
    end
    return ok
end

function AutoRanks.Scan()
    if not AutoRanks.IsActive() then return end
    if InCombatLockdown() then
        AutoRanks.pending = true
        return
    end
    if GetCursorInfo() then
        AutoRanks.Schedule(2)
        return
    end
    local best = AutoRanks.HighestRanks()
    local swapped, order, barRanks = {}, {}, {}
    for slot = 1, AutoRanks.maxSlot do
        local actionType, spellID = GetActionInfo(slot)
        if actionType == "spell" and spellID and not Secret(spellID) then
            local name = AutoRanks.SpellName(spellID)
            if name then barRanks[name] = math.max(barRanks[name] or 0, AutoRanks.Rank(spellID)) end
        end
    end
    for slot = 1, AutoRanks.maxSlot do
        local actionType, spellID = GetActionInfo(slot)
        if actionType == "spell" and spellID and not Secret(spellID) then
            local name = AutoRanks.SpellName(spellID)
            local target = name and best[name]
            local oldRank = AutoRanks.Rank(spellID)
            if target and target.spellID ~= spellID and target.rank > oldRank and oldRank == barRanks[name] then
                if not AutoRanks.Place(slot, target.spellID) then
                    if AutoRanks.broken then break end
                else
                    if not swapped[name] then
                        swapped[name] = {rank = target.rank, oldRank = oldRank, count = 0}
                        table.insert(order, name)
                    end
                    swapped[name].oldRank = math.min(swapped[name].oldRank, oldRank)
                    swapped[name].count = swapped[name].count + 1
                end
            end
        end
    end
    if not AutoRanks.Settings().autoSpellRanksReport then return end
    for _, name in ipairs(order) do
        local entry = swapped[name]
        TrainerSpells:MSG(TrainerSpells:Trans("LID_AUTORANKS_SWAPPED"):format(name, entry.oldRank, entry.rank, entry.count))
    end
end

function AutoRanks.Schedule(delay)
    if AutoRanks.timer then AutoRanks.timer:Cancel() end
    AutoRanks.timer = C_Timer.NewTimer(delay, function()
        AutoRanks.timer = nil
        AutoRanks.Scan()
    end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB", "PLAYER_REGEN_ENABLED"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if AutoRanks.Settings().autoSpellRanks and OtherAddonLoaded() then TrainerSpells:MSG(TrainerSpells:Trans("LID_AUTORANKS_OTHERADDON")) end
        AutoRanks.Schedule(3)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if AutoRanks.pending then
            AutoRanks.pending = false
            AutoRanks.Schedule(0.5)
        end
    elseif AutoRanks.IsActive() then
        AutoRanks.Schedule(1)
    end
end)

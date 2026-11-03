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
    local name = C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if not name then
        local info = C_Spell.GetSpellInfo(spellID)
        name = info and info.name
    end
    if name == nil or Secret(name) then return nil end
    return name
end

function AutoRanks.Rank(spellID)
    local subtext = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
    if type(subtext) ~= "string" or Secret(subtext) then return 0 end
    return tonumber(subtext:match("%d+")) or 0
end

function AutoRanks.HighestRanks()
    local best = {}
    if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines then return best end
    local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if lineInfo and not lineInfo.offSpecID then
            for index = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
                if item and item.itemType == spellType and item.spellID and not item.isOffSpec and not item.isPassive and item.name and not Secret(item.name) then
                    local rank = AutoRanks.Rank(item.spellID)
                    local known = best[item.name]
                    if rank > 0 and (not known or rank > known.rank) then best[item.name] = {spellID = item.spellID, rank = rank} end
                end
            end
        end
    end
    return best
end

function AutoRanks.Place(slot, spellID)
    ClearCursor()
    if C_Spell.PickupSpell then C_Spell.PickupSpell(spellID) else PickupSpell(spellID) end
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
    local swapped, order = {}, {}
    for slot = 1, AutoRanks.maxSlot do
        local actionType, spellID = GetActionInfo(slot)
        if actionType == "spell" and spellID and not Secret(spellID) then
            local name = AutoRanks.SpellName(spellID)
            local target = name and best[name]
            local oldRank = AutoRanks.Rank(spellID)
            if target and target.spellID ~= spellID and target.rank > oldRank then
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

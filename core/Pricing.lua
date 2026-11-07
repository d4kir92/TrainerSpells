local _, TrainerSpells = ...
TrainerSpells.Pricing = {
    capitals = {
        Alliance = {72, 47, 54, 69, 930, 1134},
        Horde = {76, 68, 81, 530, 911, 1133},
    },
    sideFactions = {
        Alliance = {72, 47, 54, 69, 930, 1134, 1094, 2779},
        Horde = {76, 68, 81, 530, 911, 1133, 1124, 2778},
    },
    foreverFactions = {
        Alliance = {72, 47, 54, 69, 2779},
        Horde = {76, 68, 81, 530, 2778},
    },
    factionAreas = {
        [47] = {1537},
        [54] = {1537, 1},
        [68] = {1497},
        [69] = {1657},
        [72] = {1519},
        [76] = {1637},
        [81] = {1638},
        [530] = {1637, 14},
        [2778] = {16593},
        [2779] = {16593},
    },
    trainerFactions = {
        tbc = {
            DRUID = {69, 72, 81, 609, 911, 930},
            HUNTER = {47, 69, 72, 76, 81, 530, 911, 930},
            MAGE = {47, 54, 68, 72, 76, 530, 911, 930},
            PALADIN = {47, 72, 911, 930},
            PRIEST = {47, 68, 69, 72, 76, 530, 911, 930},
            ROGUE = {21, 47, 54, 68, 69, 72, 76, 530, 911},
            SHAMAN = {76, 81, 930},
            WARLOCK = {47, 54, 68, 72, 76, 911},
            WARRIOR = {47, 54, 68, 69, 72, 76, 81, 930},
        },
        wrath = {
            DRUID = {69, 72, 81, 609, 911, 930},
            HUNTER = {47, 69, 72, 76, 81, 530, 911, 930},
            MAGE = {47, 54, 68, 72, 76, 530, 911, 930, 1090},
            PALADIN = {47, 72, 911, 930},
            PRIEST = {47, 68, 69, 72, 76, 530, 911, 930},
            ROGUE = {21, 47, 54, 68, 69, 72, 76, 530, 911},
            SHAMAN = {76, 81, 930},
            WARLOCK = {47, 54, 68, 72, 76, 911},
            WARRIOR = {47, 54, 68, 69, 72, 76, 81, 930},
        },
        cata = {
            DRUID = {69, 72, 76, 81, 530, 609, 911, 930, 942, 1134},
            HUNTER = {47, 68, 69, 72, 76, 81, 530, 911, 930, 932, 934, 1094, 1124, 1133, 1134},
            MAGE = {47, 54, 68, 69, 72, 76, 530, 911, 930, 932, 934, 1090, 1133, 1134},
            PALADIN = {47, 72, 81, 911, 930, 932, 934, 1094, 1124},
            PRIEST = {47, 54, 68, 69, 72, 76, 81, 530, 911, 930, 932, 934, 1094, 1124, 1133, 1134},
            ROGUE = {21, 47, 54, 68, 69, 72, 76, 530, 911, 933, 934, 1094, 1124, 1133, 1134},
            SHAMAN = {47, 72, 76, 81, 530, 911, 930, 932, 1133},
            WARLOCK = {47, 54, 68, 72, 76, 530, 911, 934, 1094, 1124, 1133, 1134},
            WARRIOR = {47, 54, 68, 69, 72, 76, 81, 530, 911, 930, 932, 934, 1094, 1124, 1133, 1134},
        },
    },
}

function TrainerSpells.Pricing.IsForever()
    local interface = select(4, GetBuildInfo()) or 0
    return interface >= 16000 and interface < 20000
end

function TrainerSpells.Pricing.UsesClassicDiscounts()
    return TrainerSpells.Pricing.IsForever() or (WOW_PROJECT_CLASSIC ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
end

function TrainerSpells.Pricing.GetTrainerFactions(classToken)
    local interface = select(4, GetBuildInfo()) or 0
    if TrainerSpells.Pricing.IsForever() then return TrainerSpells.Pricing.foreverFactions[UnitFactionGroup("player")] end
    local list = TrainerSpells.Pricing.trainerFactions[interface < 30000 and "tbc" or interface < 40000 and "wrath" or "cata"]
    return list[classToken]
end

function TrainerSpells.Pricing.GetFaction(factionID)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local data = C_Reputation.GetFactionDataByID(factionID)
        if data then return data.name, data.reaction end
    elseif GetFactionInfoByID then
        local name, _, standing = GetFactionInfoByID(factionID)
        return name, standing
    end
end

function TrainerSpells.Pricing.GetDiscount(standing)
    if type(standing) ~= "number" then return 0 end
    if TrainerSpells.Pricing.UsesClassicDiscounts() then return standing >= 6 and 10 or 0 end
    return math.max(0, math.min(20, (standing - 4) * 5))
end

function TrainerSpells.Pricing.GetFactions()
    local Pricing = TrainerSpells.Pricing
    local side = UnitFactionGroup("player")
    local enemy = {}
    for group, ids in pairs(Pricing.sideFactions) do
        if group ~= side then
            for _, id in ipairs(ids) do enemy[id] = true end
        end
    end

    local classToken = select(2, UnitClass("player"))
    local factions = {}
    for _, factionID in ipairs(Pricing.GetTrainerFactions(classToken) or Pricing.capitals[side] or {}) do
        local name, standing = Pricing.GetFaction(factionID)
        if name and not enemy[factionID] and type(standing) == "number" then
            table.insert(factions, {
                id = factionID,
                name = name,
                standing = standing,
                discount = Pricing.GetDiscount(standing)
            })
        end
    end

    table.sort(factions, function(left, right)
        if left.discount ~= right.discount then return left.discount > right.discount end
        return left.name < right.name
    end)
    return factions
end

function TrainerSpells.Pricing.IsInFactionArea(factionID)
    local areas = TrainerSpells.Pricing.factionAreas[factionID]
    if not areas or not C_Map or not C_Map.GetAreaInfo or not GetRealZoneText then return false end
    local zone = GetRealZoneText()
    if not zone or zone == "" then return false end
    for _, areaID in ipairs(areas) do
        if C_Map.GetAreaInfo(areaID) == zone then return true end
    end
    return false
end

function TrainerSpells.Pricing.GetBestDiscount()
    local Pricing = TrainerSpells.Pricing
    local names, bestStanding = {}, 0
    for _, faction in ipairs(Pricing.GetFactions()) do
        if faction.standing > bestStanding then
            names, bestStanding = {faction.name}, faction.standing
        elseif faction.standing == bestStanding then
            table.insert(names, faction.name)
        end
    end

    local best = Pricing.GetDiscount(bestStanding)
    if best <= 0 or #names == 0 then return best, nil end
    table.sort(names)
    local label = _G["FACTION_STANDING_LABEL" .. bestStanding]
    return best, table.concat(names, ", ") .. (label and (" (" .. label .. ")") or "")
end

function TrainerSpells.Pricing.CaptureBaseCost(cost, existing)
    if not TrainerSpells.DebugTrainerEnabled then return existing and existing.baseCost, existing and existing.baseCostEstimated end
    if type(cost) ~= "number" or cost <= 0 then return cost, false end
    if existing and existing.baseCost and not existing.baseCostEstimated then return existing.baseCost, false end
    local standing = UnitReaction and UnitReaction("npc", "player")
    if type(standing) ~= "number" or TrainerSpells.Pricing.GetDiscount(standing) > 0 then return nil, nil end
    if TrainerSpells.Pricing.UsesClassicDiscounts() and GetPVPRankInfo and UnitPVPRank then
        local rank = select(2, GetPVPRankInfo(UnitPVPRank("player"), "player"))
        if rank and rank >= 3 then return nil, nil end
    end
    return cost, false
end

function TrainerSpells.Pricing.Apply(entry, data, discount, factionName)
    entry.priceEligible = true
    if type(data) ~= "table" or data.baseCost == nil then return end
    entry.baseCost = data.baseCost
    entry.baseCostEstimated = data.baseCostEstimated
    entry.cost = math.floor(data.baseCost * (100 - discount) / 100 + 0.000001)
    entry.priceFaction = factionName
    entry.priceDiscount = discount
end

function TrainerSpells.Pricing.GetDisplayMode()
    local mode = TrainerSpells_Character and TrainerSpells_Character.priceDisplay
    if mode == "discounted" or mode == "base" then return mode end
    return "both"
end

function TrainerSpells.Pricing.Text(baseCost, cost, estimated, color)
    if baseCost == nil then return GetMoneyString(cost or 0, true) end
    local mode = TrainerSpells.Pricing.GetDisplayMode()
    local prefix = estimated and "~" or ""
    local function Colored(value)
        local valueColor = color
        if valueColor == nil or valueColor == "|cffffffff" or valueColor == "|cffff3333" then valueColor = (GetMoney() or 0) >= value and "|cffffffff" or "|cffff3333" end
        return valueColor .. prefix .. GetMoneyString(value, true) .. "|r"
    end

    if mode == "base" then return Colored(baseCost) end
    if mode == "discounted" or baseCost == (cost or 0) then return Colored(cost or 0) end
    return Colored(baseCost) .. " / " .. Colored(cost or 0)
end

function TrainerSpells.Pricing.AddTooltip(tooltip, entry)
    if not entry.priceEligible then return end
    if entry.baseCost == nil then
        tooltip:AddLine(TrainerSpells:Trans("LID_PRICE_UNVERIFIED"), 1, 0.82, 0, true)
        return
    end
    local mode = TrainerSpells.Pricing.GetDisplayMode()
    local prefix = entry.baseCostEstimated and "~" or ""
    local money = GetMoney() or 0
    local function PriceLine(label, value)
        tooltip:AddLine(TrainerSpells:Trans(label) .. ": " .. (money >= value and "|cffffffff" or "|cffff3333") .. prefix .. GetMoneyString(value, true) .. "|r", 1, 1, 1)
    end

    local single = mode ~= "both" or entry.baseCost == (entry.cost or 0)
    if single then
        PriceLine("LID_COSTS", mode == "base" and entry.baseCost or (entry.cost or 0))
    else
        PriceLine("LID_PRICE_BASE", entry.baseCost)
        PriceLine("LID_PRICE_BEST", entry.cost or 0)
    end

    if mode ~= "base" and entry.priceFaction and (entry.priceDiscount or 0) > 0 then
        for _, faction in ipairs(TrainerSpells.Pricing.GetFactions()) do
            if faction.discount > 0 then
                local label = _G["FACTION_STANDING_LABEL" .. faction.standing]
                local text = string.format(TrainerSpells:Trans("LID_PRICE_FACTIONS"), faction.discount) .. ": " .. faction.name .. (label and (" (" .. label .. ")") or "")
                if TrainerSpells.Pricing.IsInFactionArea(faction.id) then
                    tooltip:AddLine(text, 0.2, 1, 0.2, true)
                else
                    tooltip:AddLine(text, 0.8, 0.8, 0.8, true)
                end
            end
        end
        tooltip:AddLine(TrainerSpells:Trans("LID_PRICE_COMPARE"), 0.6, 0.6, 0.6, true)
    end

    if entry.baseCostEstimated then tooltip:AddLine(TrainerSpells:Trans("LID_PRICE_ESTIMATED"), 0.6, 0.6, 0.6, true) end
end

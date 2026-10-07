local _, TrainerSpells = ...
TrainerSpells.Pricing = {
    capitals = {
        Alliance = {72, 47, 54, 69, 930, 1134},
        Horde = {76, 68, 81, 530, 911, 1133},
    },
}

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
    if WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then return standing >= 6 and 10 or 0 end
    return math.max(0, math.min(20, (standing - 4) * 5))
end

function TrainerSpells.Pricing.GetBestDiscount()
    local best, factionName, bestStanding = 0, nil, 0
    for _, factionID in ipairs(TrainerSpells.Pricing.capitals[UnitFactionGroup("player")] or {}) do
        local name, standing = TrainerSpells.Pricing.GetFaction(factionID)
        local discount = TrainerSpells.Pricing.GetDiscount(standing)
        if type(standing) == "number" and standing > bestStanding then best, factionName, bestStanding = discount, name, standing end
    end
    return best, factionName
end

function TrainerSpells.Pricing.CaptureBaseCost(cost, existing)
    if type(cost) ~= "number" or cost <= 0 then return cost, false end
    local standing = UnitReaction and UnitReaction("npc", "player")
    if type(standing) ~= "number" then return existing and existing.baseCost, existing and existing.baseCostEstimated end
    local discount = TrainerSpells.Pricing.GetDiscount(standing)
    if WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC and GetPVPRankInfo and UnitPVPRank then
        local rank = select(2, GetPVPRankInfo(UnitPVPRank("player"), "player"))
        if rank and rank >= 3 then return existing and existing.baseCost, existing and existing.baseCostEstimated end
    end
    local percent = 100 - discount
    local low = math.ceil(cost * 100 / percent)
    local high = math.ceil((cost + 1) * 100 / percent) - 1
    if existing and existing.baseCost and existing.baseCost >= low and existing.baseCost <= high then return existing.baseCost, (low ~= high and existing.baseCostEstimated) or standing == 5 end
    return low, low ~= high or standing == 5
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

function TrainerSpells.Pricing.Text(baseCost, cost, estimated, color)
    if baseCost == nil then return GetMoneyString(cost or 0, true) end
    if baseCost == (cost or 0) then return (estimated and "~" or "") .. GetMoneyString(baseCost, true) end
    return "|cffaaaaaa" .. (estimated and "~" or "") .. GetMoneyString(baseCost, true) .. "|r / " .. (color or "|cffffffff") .. (estimated and "~" or "") .. GetMoneyString(cost or 0, true) .. "|r"
end

function TrainerSpells.Pricing.AddTooltip(tooltip, entry)
    if not entry.priceEligible then return end
    if entry.baseCost == nil then
        tooltip:AddLine(TrainerSpells:Trans("LID_PRICE_UNVERIFIED"), 1, 0.82, 0, true)
        return
    end
    local color = (GetMoney() or 0) >= (entry.cost or 0) and "|cffffffff" or "|cffff3333"
    if entry.baseCost == (entry.cost or 0) then
        tooltip:AddLine(TrainerSpells:Trans("LID_COSTS") .. ": " .. color .. (entry.baseCostEstimated and "~" or "") .. GetMoneyString(entry.baseCost, true) .. "|r", 1, 1, 1)
        return
    end
    tooltip:AddLine(TrainerSpells:Trans("LID_PRICE_BASE") .. ": " .. (entry.baseCostEstimated and "~" or "") .. GetMoneyString(entry.baseCost, true), 0.8, 0.8, 0.8)
    tooltip:AddLine(TrainerSpells:Trans("LID_PRICE_BEST") .. ": " .. color .. (entry.baseCostEstimated and "~" or "") .. GetMoneyString(entry.cost or 0, true) .. "|r", 1, 1, 1)
    if entry.priceFaction then tooltip:AddLine(entry.priceFaction .. " (" .. entry.priceDiscount .. "%)", 0.8, 0.8, 0.8) end
    tooltip:AddLine(TrainerSpells:Trans("LID_PRICE_COMPARE"), 0.8, 0.8, 0.8, true)
end

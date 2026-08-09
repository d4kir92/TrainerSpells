local _, TrainerSpells = ...
local classFrame = CreateFrame("Frame", "TrainerSpellsFrame", UIParent)
classFrame:SetSize(420, 480)
classFrame:SetPoint("CENTER")
classFrame:SetFrameStrata("HIGH")
classFrame:SetFrameLevel(500)
classFrame:Hide()
TrainerSpells.ClassFrame = classFrame
TrainerSpells.RowSpacing = 0.5
TrainerSpells.HeaderExtraGap = 12
TrainerSpells.MinRowHeight, TrainerSpells.MaxRowHeight = 10, 32
local MAX_ICON_SIZE = 32
TrainerSpells.HeaderHeight = 16
TrainerSpells.RowHeight = (TrainerSpells_Character and TrainerSpells_Character.rowHeight) or 16
TrainerSpells.RowHeight = math.max(TrainerSpells.MinRowHeight, math.min(TrainerSpells.MaxRowHeight, TrainerSpells.RowHeight))
TrainerSpells.UIColors = {
    AVAILABLE = "|cff30d030",
    SOON = "|cff4db8ff",
    NOTYET = "|cffff4444",
    TALENT = "|cffff9933",
    KNOWN = "|cff888888",
    IGNORED = "|cff666666",
    PET_HEADER = "|cffcc66ff",
    SPELL_NAME = "|cffffffff",
    DIM_NAME = "|cff999999",
    RANK = "|cffaaaaaa",
    COLLAPSE_EXPANDED = "|cffffffff-|r ",
    COLLAPSE_COLLAPSED = "|cffffffff+|r ",
}

TrainerSpells.PetGroups = {
    {
        label = TrainerSpells:GetPetNameById(688),
        keys = {"Imp"}
    },
    {
        label = TrainerSpells:GetPetNameById(697),
        keys = {"Voidwalker"}
    },
    {
        label = TrainerSpells:GetPetNameById(712),
        keys = {"Succubus", "Incubus"}
    },
    {
        label = TrainerSpells:GetPetNameById(691),
        keys = {"Felhunter"}
    },
    {
        label = TrainerSpells:GetPetNameById(30146),
        keys = {"Felguard"}
    },
}

function TrainerSpells:IsDragonflightUIEnabled()
    return TrainerSpells:IsAddonLoaded("DragonflightUI")
end

function TrainerSpells:IsLeatrixWideProfessionEnabled()
    return TrainerSpells:IsAddonLoaded("Leatrix_Plus") and LeaPlusDB and LeaPlusDB["EnhanceProfessions"] == "On"
end

function TrainerSpells:IsGroupCollapsed(groupKey)
    return groupKey and TrainerSpells_Character and TrainerSpells_Character.collapsedGroups[groupKey] or false
end

local function ToggleGroup(groupKey)
    if not groupKey or not TrainerSpells_Character then return end
    TrainerSpells_Character.collapsedGroups[groupKey] = not TrainerSpells_Character.collapsedGroups[groupKey] or nil
end

local function GetLevelDiffColorCode(level)
    if GetQuestDifficultyColor then
        local r, g, b = GetQuestDifficultyColor(level)
        if type(r) == "table" then r, g, b = r.r, r.g, r.b end
        if r then return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255) end
    end
    return TrainerSpells.UIColors.RANK
end

function TrainerSpells:GetTalentNameSet()
    local names, learned = {}, {}
    if GetNumTalentTabs and GetNumTalents and GetTalentInfo then
        for tab = 1, GetNumTalentTabs() do
            for i = 1, GetNumTalents(tab) do
                local talentName, _, _, _, rank = GetTalentInfo(tab, i)
                if talentName then
                    names[talentName] = true
                    if (rank or 0) > 0 then learned[talentName] = true end
                end
            end
        end
    end
    return names, learned
end

function TrainerSpells:GetPlayerFaction()
    return UnitFactionGroup and UnitFactionGroup("player")
end

local function IsReqSpellKnown(spellID)
    if not IsPlayerSpell or type(spellID) ~= "number" then return false end
    local ok, known = pcall(IsPlayerSpell, spellID)
    return ok and known or false
end

function TrainerSpells:RequiresUnknownTalent(entry, talentNames, learnedTalents)
    if not entry.requires then return false end
    for _, reqSpellID in ipairs(entry.requires) do
        local reqName = GetSpellInfo(reqSpellID)
        if reqName and talentNames[reqName] and not learnedTalents[reqName] and not IsReqSpellKnown(reqSpellID) then return true end
    end
    return false
end

local function FormatCost(copper)
    if not copper or copper == 0 then return "kostenlos" end
    return GetMoneyString(copper, true)
end

local function GetLocalizedRankText(spellID)
    local subtext = GetSpellSubtext and spellID and GetSpellSubtext(spellID)
    return (subtext and subtext ~= "") and subtext or nil
end

function TrainerSpells:EntryMatchesSearch(entry, search)
    if not search or search == "" then return true end
    if entry.name and entry.name:lower():find(search, 1, true) then return true end
    if entry.level and tostring(entry.level):find(search, 1, true) then return true end
    if entry.levelReq and tostring(entry.levelReq):find(search, 1, true) then return true end
    return false
end

function TrainerSpells:SortEntries(list)
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.key < b.key
    end)
end

local ignoreMenuFrame = CreateFrame("Frame", "TrainerSpellsIgnoreMenu", UIParent, "UIDropDownMenuTemplate")
local ignoreMenuEntry
local function IgnoreMenu_Initialize(self, level)
    local entry = ignoreMenuEntry
    if not entry then return end
    local isProfessionSpell = false
    local professionKey
    if entry.spellID and GetTradeSkillLine then
        local skillLine = GetTradeSkillLine()
        if skillLine then
            professionKey = TrainerSpells:GetProfessionKey(skillLine)
            if professionKey then isProfessionSpell = true end
        end
    end

    local rankSubtext = GetLocalizedRankText(entry.spellID)
    local rankText = rankSubtext and (" " .. rankSubtext) or ""
    local info = UIDropDownMenu_CreateInfo()
    info.text = entry.name .. rankText
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
    if isProfessionSpell then
        local spellIgnored = TrainerSpells_IsProfessionSpellIgnored and TrainerSpells_IsProfessionSpellIgnored(entry.spellID, professionKey)
        info = UIDropDownMenu_CreateInfo()
        info.text = spellIgnored and TrainerSpells:Trans("LID_STOPIGNORINGTHISRANK") or TrainerSpells:Trans("LID_IGNORINGTHISRANK")
        info.notCheckable = true
        info.func = function()
            TrainerSpells_ToggleIgnoreProfessionSpell(entry.spellID, professionKey)
            TrainerSpells_ProfessionRefresh()
        end

        UIDropDownMenu_AddButton(info, level)
    else
        local spellIgnored = TrainerSpells_IsSpellIgnored and TrainerSpells_IsSpellIgnored(entry.spellID)
        local nameIgnored = TrainerSpells_IsNameIgnored and TrainerSpells_IsNameIgnored(entry.name)
        info = UIDropDownMenu_CreateInfo()
        info.text = spellIgnored and TrainerSpells:Trans("LID_STOPIGNORINGTHISRANK") or TrainerSpells:Trans("LID_IGNORINGTHISRANK")
        info.notCheckable = true
        info.func = function()
            TrainerSpells_ToggleIgnoreSpell(entry.spellID)
            TrainerSpells_Refresh()
        end

        UIDropDownMenu_AddButton(info, level)
        info = UIDropDownMenu_CreateInfo()
        info.text = nameIgnored and TrainerSpells:Trans("LID_STOPIGNOREINGALLRANKS") or TrainerSpells:Trans("LID_IGNOREALLRANKS")
        info.notCheckable = true
        info.func = function()
            TrainerSpells_ToggleIgnoreName(entry.name)
            TrainerSpells_Refresh()
        end

        UIDropDownMenu_AddButton(info, level)
    end

    info = UIDropDownMenu_CreateInfo()
    info.text = TrainerSpells:Trans("LID_CANCEL")
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
end

UIDropDownMenu_Initialize(ignoreMenuFrame, IgnoreMenu_Initialize, "MENU")
function TrainerSpells:ShowIgnoreMenu(anchor, entry)
    ignoreMenuEntry = entry
    ToggleDropDownMenu(1, nil, ignoreMenuFrame, "cursor", 0, 0)
    if DropDownList1 then
        DropDownList1:SetFrameStrata("TOOLTIP")
        DropDownList1:SetFrameLevel(600)
    end
end

local pendingSpellTooltipExtra
GameTooltip:HookScript("OnTooltipSetSpell", function(tooltip)
    local extra = pendingSpellTooltipExtra
    if not extra then return end
    local _, spellID = tooltip:GetSpell()
    if spellID ~= extra.spellID then return end
    if extra.showCost then
        local canAfford = not extra.cost or extra.cost == 0 or (GetMoney() or 0) >= extra.cost
        local costColor = canAfford and "|cffffffff" or "|cffff3333"
        tooltip:AddLine(TrainerSpells:Trans("LID_COSTS") .. ": " .. costColor .. FormatCost(extra.cost) .. "|r", 1, 1, 1)
        tooltip:AddLine(TrainerSpells:Trans("LID_OWNGOLD") .. ": " .. GetMoneyString(GetMoney() or 0, true), 1, 1, 1)
    end

    if extra.source then tooltip:AddLine(TrainerSpells:Trans("LID_SOURCE") .. ": " .. extra.source, 0.9, 0.9, 0.9, true) end
    tooltip:Show()
end)

function TrainerSpells:InitScrollRow(rowFrame, elementData)
    local Colors = TrainerSpells.UIColors
    if not rowFrame.icon then
        local icon = rowFrame:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", rowFrame, "LEFT", 4, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        rowFrame.icon = icon
        local nameFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFS:SetJustifyH("LEFT")
        nameFS:SetWordWrap(false)
        rowFrame.nameFS = nameFS
        local levelFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        levelFS:SetPoint("RIGHT", rowFrame, "RIGHT", -4, 0)
        levelFS:SetJustifyH("RIGHT")
        rowFrame.levelFS = levelFS
    end

    local icon, nameFS, levelFS = rowFrame.icon, rowFrame.nameFS, rowFrame.levelFS
    local iconSize = math.max(8, math.min(MAX_ICON_SIZE, (rowFrame:GetHeight() or TrainerSpells.RowHeight) - 4))
    icon:SetSize(iconSize, iconSize)
    rowFrame:EnableMouse(false)
    rowFrame:SetScript("OnEnter", nil)
    rowFrame:SetScript("OnLeave", nil)
    rowFrame:SetScript("OnMouseUp", nil)
    icon:Show()
    icon:SetTexture(nil)
    nameFS:ClearAllPoints()
    nameFS:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    nameFS:SetPoint("RIGHT", levelFS, "LEFT", -4, 0)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetText("")
    levelFS:SetText("")
    if elementData.isHeader then
        icon:Hide()
        nameFS:ClearAllPoints()
        nameFS:SetPoint("BOTTOMLEFT", rowFrame, "BOTTOMLEFT", 4, 5)
        nameFS:SetPoint("BOTTOMRIGHT", rowFrame, "BOTTOMRIGHT", -4, 5)
        nameFS:SetJustifyH("CENTER")
        local collapseIcon = elementData.groupKey and (elementData.collapsed and Colors.COLLAPSE_COLLAPSED or Colors.COLLAPSE_EXPANDED) or ""
        local prefix = elementData.prefixText and (Colors.PET_HEADER .. "[" .. elementData.prefixText .. "] |r") or ""
        nameFS:SetText(collapseIcon .. prefix .. elementData.color .. elementData.text .. "|r")
        if elementData.totalCost or elementData.groupKey then
            rowFrame:EnableMouse(true)
            rowFrame:SetScript("OnEnter", function(sel)
                if not elementData.totalCost then return end
                GameTooltip:SetOwner(sel, "ANCHOR_RIGHT")
                GameTooltip:AddLine(elementData.text)
                local canAfford = elementData.totalCost == 0 or (GetMoney() or 0) >= elementData.totalCost
                local costColor = canAfford and "|cffffffff" or "|cffff3333"
                GameTooltip:AddLine(TrainerSpells:Trans("LID_TOTALCOST") .. ": " .. costColor .. FormatCost(elementData.totalCost) .. "|r", 1, 1, 1)
                GameTooltip:AddLine(TrainerSpells:Trans("LID_OWNGOLD") .. ": " .. GetMoneyString(GetMoney() or 0, true), 1, 1, 1)
                GameTooltip:Show()
            end)

            rowFrame:SetScript("OnLeave", GameTooltip_Hide)
            rowFrame:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" and elementData.groupKey then
                    ToggleGroup(elementData.groupKey)
                    if TrainerSpells_Refresh then TrainerSpells_Refresh() end
                    if TrainerSpells_ProfessionRefresh then TrainerSpells_ProfessionRefresh() end
                end
            end)
        end
    else
        local entry = elementData.entry
        icon:SetTexture(entry.icon)
        local rankSubtext = GetLocalizedRankText(entry.spellID)
        local rankText = rankSubtext and (" " .. Colors.RANK .. "(" .. rankSubtext .. ")|r") or ""
        local nameColor = elementData.dimName and Colors.DIM_NAME or Colors.SPELL_NAME
        nameFS:SetText(nameColor .. entry.name .. "|r" .. rankText)
        if elementData.showLevel then
            if elementData.levelLabel then
                local levelPrefix = entry.levelReq and (TrainerSpells:Trans("LID_LVL") .. " " .. entry.levelReq .. " ") or ""
                levelFS:SetText(Colors.RANK .. levelPrefix .. elementData.levelLabel .. " " .. entry.level .. "|r")
            else
                levelFS:SetText(GetLevelDiffColorCode(entry.level) .. "Level " .. entry.level .. "|r")
            end
        end

        rowFrame:EnableMouse(true)
        rowFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local showCost = elementData.showCostTooltip and entry.cost ~= nil
            if entry.spellID then
                pendingSpellTooltipExtra = {
                    spellID = entry.spellID,
                    showCost = showCost,
                    cost = entry.cost,
                    source = entry.source,
                }

                GameTooltip:SetSpellByID(entry.spellID)
            else
                pendingSpellTooltipExtra = nil
                GameTooltip:SetText(entry.name)
                if showCost then
                    local canAfford = not entry.cost or entry.cost == 0 or (GetMoney() or 0) >= entry.cost
                    local costColor = canAfford and "|cffffffff" or "|cffff3333"
                    GameTooltip:AddLine(TrainerSpells:Trans("LID_COSTS") .. ": " .. costColor .. FormatCost(entry.cost) .. "|r", 1, 1, 1)
                    GameTooltip:AddLine(TrainerSpells:Trans("LID_OWNGOLD") .. ": " .. GetMoneyString(GetMoney() or 0, true), 1, 1, 1)
                end

                if entry.source then GameTooltip:AddLine(TrainerSpells:Trans("LID_SOURCE") .. ": " .. entry.source, 0.9, 0.9, 0.9, true) end
            end

            GameTooltip:Show()
        end)

        rowFrame:SetScript("OnLeave", function(self)
            pendingSpellTooltipExtra = nil
            GameTooltip_Hide(self)
        end)

        rowFrame:SetScript("OnMouseUp", function(self, button) if button == "RightButton" then TrainerSpells:ShowIgnoreMenu(self, entry) end end)
    end
end

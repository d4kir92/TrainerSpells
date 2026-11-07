local _, TrainerSpells = ...
local PriceScan = {
    scans = {},
    fieldOrder = {"cost", "rank", "requires", "faction", "race"},
    serviceTypes = {
        available = true,
        unavailable = true,
        used = true
    },
    frameName = "TrainerSpellsPriceScanFrame",
    titleKey = "LID_PRICESCAN_TITLE",
    waitingKey = "LID_PRICESCAN_WAITING",
    wrongTrainerKey = "LID_PRICESCAN_NOTCLASS",
    offsetX = 0,
    offsetY = 0
}

local PetPriceScan = setmetatable({
    scans = {},
    pet = true,
    frameName = "TrainerSpellsPetPriceScanFrame",
    titleKey = "LID_PRICESCAN_PETTITLE",
    waitingKey = "LID_PRICESCAN_PETWAITING",
    wrongTrainerKey = "LID_PRICESCAN_NOTPET",
    offsetX = 40,
    offsetY = -40
}, {
    __index = PriceScan
})

TrainerSpells.PriceScan = PriceScan
TrainerSpells.PetPriceScan = PetPriceScan
local function SortedNumberKeys(data)
    local keys = {}
    for key in pairs(data or {}) do
        if type(key) == "number" then table.insert(keys, key) end
    end

    table.sort(keys)
    return keys
end

local function ClassFileName(classToken)
    return classToken:sub(1, 1) .. classToken:sub(2):lower()
end

local function DataFolder()
    local _, _, _, tocVersion = GetBuildInfo()
    local interface = tonumber(tocVersion) or 0
    if interface >= 40000 then return "cata" end
    if interface >= 30000 then return "wrath" end
    if interface >= 20000 then return "tbc" end
    if interface >= 16000 then return "forever" end
    return "classicera"
end

local function FormatValue(value)
    if type(value) == "number" then
        if value == math.floor(value) then return ("%d"):format(value) end
        return tostring(value)
    end

    if type(value) == "string" then
        local escaped = value:gsub("\\", "\\\\"):gsub("\"", "\\\"")
        return "\"" .. escaped .. "\""
    end

    if type(value) == "table" then
        local parts = {}
        for _, item in ipairs(value) do
            table.insert(parts, FormatValue(item))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(value)
end

local function FormatEntry(entry)
    local parts = {}
    local used = {}
    for _, key in ipairs(PriceScan.fieldOrder) do
        if entry[key] ~= nil then
            table.insert(parts, key .. " = " .. FormatValue(entry[key]))
            used[key] = true
        end
    end

    local extra = {}
    for key in pairs(entry) do
        if type(key) == "string" and not used[key] then table.insert(extra, key) end
    end

    table.sort(extra)
    for _, key in ipairs(extra) do
        table.insert(parts, key .. " = " .. FormatValue(entry[key]))
    end

    if #parts == 0 then return "{}" end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

local function Money(cost)
    return ("%d (%s)"):format(cost or 0, GetMoneyString and GetMoneyString(cost or 0, true) or "")
end

local function HasPvPDiscount()
    if not (TrainerSpells.Pricing.UsesClassicDiscounts() and GetPVPRankInfo and UnitPVPRank) then return false end
    local rank = select(2, GetPVPRankInfo(UnitPVPRank("player"), "player"))
    return rank ~= nil and rank >= 3
end

local function IsPetTrainer()
    if C_Trainer and C_Trainer.GetTrainerType and Enum.TrainerType and Enum.TrainerType.Pet ~= nil and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet then return true end
    if not GetNumTrainerServices or not GetTrainerServiceSkillLine then return false end
    for i = 1, GetNumTrainerServices() do
        if TrainerSpells:IsPetTrainerSkillLine(GetTrainerServiceSkillLine(i)) then return true end
    end
    return false
end

function PriceScan:GetBuiltin(classToken)
    return TrainerSpellsBuiltin and TrainerSpellsBuiltin[classToken] or {}
end

function PriceScan:GetTarget(classToken)
    return "TrainerSpellsBuiltin." .. classToken, "TrainerSpellsBuiltin = TrainerSpellsBuiltin or {}"
end

function PriceScan:GetFileName(classToken)
    return ClassFileName(classToken)
end

function PetPriceScan:GetBuiltin()
    return TrainerSpellsBuiltin_HunterPet or {}
end

function PetPriceScan:GetTarget()
    return "TrainerSpellsBuiltin_HunterPet"
end

function PetPriceScan:GetFileName()
    return "HunterPet"
end

function PriceScan:BuildMerged(classToken)
    local builtin = self:GetBuiltin(classToken)
    local merged, levelOf = {}, {}
    for level, spells in pairs(builtin) do
        merged[level] = {}
        for spellID, data in pairs(spells) do
            local copy = {}
            for key, value in pairs(data) do
                copy[key] = value
            end

            merged[level][spellID] = copy
            levelOf[spellID] = level
        end
    end

    local changes = {}
    for spellID, scan in pairs(self.scans[classToken] or {}) do
        local oldLevel = levelOf[spellID]
        if oldLevel == nil then
            merged[scan.level] = merged[scan.level] or {}
            merged[scan.level][spellID] = {
                cost = scan.cost,
                rank = scan.rank
            }

            table.insert(changes, {
                kind = "add",
                spellID = spellID,
                scan = scan,
                diffs = {"level " .. scan.level, "cost " .. Money(scan.cost), scan.rank and ("rank " .. scan.rank) or nil}
            })
        else
            local entry = merged[oldLevel][spellID]
            local diffs = {}
            if scan.level ~= oldLevel then
                table.insert(diffs, ("level %d -> %d"):format(oldLevel, scan.level))
                merged[oldLevel][spellID] = nil
                if next(merged[oldLevel]) == nil then merged[oldLevel] = nil end
                merged[scan.level] = merged[scan.level] or {}
                merged[scan.level][spellID] = entry
            end

            if (entry.cost or 0) ~= scan.cost then
                table.insert(diffs, ("cost %s -> %s"):format(Money(entry.cost), Money(scan.cost)))
                entry.cost = scan.cost
            end

            if scan.rank and entry.rank ~= scan.rank then
                table.insert(diffs, ("rank %s -> %d"):format(tostring(entry.rank or "-"), scan.rank))
                entry.rank = scan.rank
            end

            if #diffs > 0 then
                table.insert(changes, {
                    kind = "edit",
                    spellID = spellID,
                    scan = scan,
                    diffs = diffs
                })
            end
        end
    end

    table.sort(changes, function(left, right)
        if left.scan.level ~= right.scan.level then return left.scan.level < right.scan.level end
        return left.spellID < right.spellID
    end)
    return merged, changes
end

function PriceScan:BuildFileText(classToken, merged)
    local target, header = self:GetTarget(classToken)
    local lines = {header}
    local levels = SortedNumberKeys(merged)
    if #levels == 0 then
        table.insert(lines, target .. " = " .. target .. " or {}")
    else
        table.insert(lines, target .. " = " .. target .. " or {")
        for _, level in ipairs(levels) do
            table.insert(lines, ("    [%d] = {"):format(level))
            for _, spellID in ipairs(SortedNumberKeys(merged[level])) do
                table.insert(lines, ("        [%d] = %s,"):format(spellID, FormatEntry(merged[level][spellID])))
            end

            table.insert(lines, "    },")
        end

        table.insert(lines, "}")
    end
    return table.concat(lines, "\n") .. "\n"
end

function PriceScan:BuildChangesText(changes)
    if #changes == 0 then return TrainerSpells:Trans("LID_PRICESCAN_NOCHANGES") end
    local lines = {}
    for _, change in ipairs(changes) do
        local label = change.kind == "add" and ("|cff33ff99" .. TrainerSpells:Trans("LID_PRICESCAN_ADD") .. "|r") or ("|cffffd100" .. TrainerSpells:Trans("LID_PRICESCAN_EDIT") .. "|r")
        local name = change.scan.name or "?"
        if change.scan.rankText and change.scan.rankText ~= "" then name = name .. " (" .. change.scan.rankText .. ")" end
        table.insert(lines, ("%s  [%d] %s  #%d"):format(label, change.scan.level, name, change.spellID))
        for _, diff in ipairs(change.diffs) do
            table.insert(lines, "      " .. diff)
        end
    end
    return table.concat(lines, "\n")
end

local function SetBoxText(box, text)
    local lineCount = select(2, text:gsub("\n", "\n")) + 1
    box.shownText = text
    box:SetText(text)
    box:SetHeight(math.max(box.minHeight, lineCount * 14 + 12))
end

function PriceScan:Refresh()
    local frame = self.frame
    if not frame or not frame:IsShown() then return end
    local _, classToken = UnitClass("player")
    if not classToken then return end
    local merged, changes = self:BuildMerged(classToken)
    frame.FileLabel:SetText(TrainerSpells:Trans("LID_PRICESCAN_FILE"):format(("data/%s/%s.lua"):format(DataFolder(), self:GetFileName(classToken))))
    frame.ChangesLabel:SetText(TrainerSpells:Trans("LID_PRICESCAN_CHANGES"):format(#changes))
    frame.Status:SetText(self.status or TrainerSpells:Trans(self.waitingKey))
    SetBoxText(frame.ChangesBox, self:BuildChangesText(changes))
    SetBoxText(frame.FileBox, self:BuildFileText(classToken, merged))
end

function PriceScan:SetStatus(text)
    self.status = text
    self:Refresh()
end

function PriceScan:Scan()
    if not self.frame or not self.frame:IsShown() then return end
    if not GetNumTrainerServices or not GetTrainerServiceCost then return end
    local _, classToken = UnitClass("player")
    if not classToken then return end
    local petTrainer = IsPetTrainer()
    if (IsTradeskillTrainer and IsTradeskillTrainer()) or (self.pet and (not petTrainer or classToken ~= "HUNTER")) then
        self:SetStatus("|cffff5555" .. TrainerSpells:Trans(self.wrongTrainerKey) .. "|r")
        return
    end

    local discount = TrainerSpells.Pricing.GetDiscount(UnitReaction and UnitReaction("npc", "player"))
    if discount > 0 or HasPvPDiscount() then
        self:SetStatus("|cffff5555" .. TrainerSpells:Trans("LID_PRICESCAN_DISCOUNT") .. "|r")
        return
    end

    if TrainerSpells.EnableTrainerDebugFilters then TrainerSpells:EnableTrainerDebugFilters() end
    TrainerSpells:ExpandAllTrainerHeaders()
    local builtinLevels = self:GetBuiltin(classToken)
    local inBuiltin = {}
    for _, spells in pairs(builtinLevels) do
        for spellID in pairs(spells) do
            inBuiltin[spellID] = true
        end
    end

    local rows, count, known = {}, 0, 0
    for i = 1, GetNumTrainerServices() do
        local name, rankText, sType, levelReq = TrainerSpells:GetTrainerServiceInfo(i)
        if self.serviceTypes[sType] then
            local spellID = TrainerSpells:GetSpellIDForService(i)
            local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(i)
            local isPet = petTrainer or TrainerSpells:IsPetTrainerSkillLine(skillLine)
            if spellID and isPet == (self.pet == true) and not TrainerSpells:IsRidingSpell(spellID) and not TrainerSpells:IsWeaponSkillSpell(spellID) then
                if not levelReq or levelReq == 0 then levelReq = TrainerSpells:GetSpellLevelLearned(spellID) end
                if levelReq and levelReq > 0 then
                    rows[spellID] = {
                        level = levelReq,
                        cost = GetTrainerServiceCost(i) or 0,
                        rank = rankText and tonumber(rankText:match("%d+")),
                        rankText = rankText,
                        name = name
                    }

                    count = count + 1
                    if inBuiltin[spellID] then known = known + 1 end
                end
            end
        end
    end

    if count > 0 and known == 0 then
        self:SetStatus("|cffff5555" .. TrainerSpells:Trans(self.wrongTrainerKey) .. "|r")
        return
    end

    if count == 0 then return end
    self.scans[classToken] = self.scans[classToken] or {}
    for spellID, row in pairs(rows) do
        self.scans[classToken][spellID] = row
    end

    self:SetStatus(TrainerSpells:Trans("LID_PRICESCAN_SCANNED"):format(count, UnitName("npc") or "?"))
end

function PriceScan:ScheduleScan()
    if self.scanScheduled then return end
    self.scanScheduled = true
    C_Timer.After(0.2, function()
        self.scanScheduled = false
        local ok, err = pcall(self.Scan, self)
        if not ok then TrainerSpells:ERR("|cffff5555TrainerSpells:|r " .. tostring(err)) end
    end)
end

local function CreateTextBox(frame, left, right, minHeight)
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -96)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", right, 52)
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(right - left - 8)
    editBox:SetMaxLetters(0)
    editBox.minHeight = minHeight
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnTextChanged", function(self, userInput) if userInput then self:SetText(self.shownText or "") end end)
    scrollFrame:SetScrollChild(editBox)
    return editBox
end

function PriceScan:CreateFrame()
    local scan = self
    local frame = CreateFrame("Frame", self.frameName, UIParent, "BackdropTemplate")
    frame:SetSize(1000, 600)
    frame:SetPoint("CENTER", self.offsetX, self.offsetY)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {
            left = 11,
            right = 12,
            top = 12,
            bottom = 11
        }
    })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText(TrainerSpells:Trans(self.titleKey))
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", 24, -48)
    status:SetPoint("TOPRIGHT", -24, -48)
    status:SetJustifyH("LEFT")
    frame.Status = status
    local changesLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    changesLabel:SetPoint("TOPLEFT", 24, -76)
    frame.ChangesLabel = changesLabel
    local fileLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fileLabel:SetPoint("TOPLEFT", 504, -76)
    frame.FileLabel = fileLabel
    frame.ChangesBox = CreateTextBox(frame, 24, 470, 440)
    frame.FileBox = CreateTextBox(frame, 504, 950, 440)
    local selectButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectButton:SetSize(160, 24)
    selectButton:SetPoint("BOTTOMRIGHT", -24, 20)
    selectButton:SetText(TrainerSpells:Trans("LID_PRICESCAN_SELECTFILE"))
    selectButton:SetScript("OnClick", function()
        frame.FileBox:SetFocus()
        frame.FileBox:HighlightText()
    end)

    local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearButton:SetSize(160, 24)
    clearButton:SetPoint("BOTTOMLEFT", 24, 20)
    clearButton:SetText(TrainerSpells:Trans("LID_PRICESCAN_CLEAR"))
    clearButton:SetScript("OnClick", function()
        scan.scans = {}
        scan:SetStatus(nil)
    end)

    frame:SetScript("OnShow", function()
        scan:Refresh()
        if ClassTrainerFrame and ClassTrainerFrame:IsShown() then scan:ScheduleScan() end
    end)

    frame:Hide()
    table.insert(UISpecialFrames, self.frameName)
    self.frame = frame
end

function PriceScan:Toggle()
    if not self.frame then self:CreateFrame() end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("TRAINER_SHOW")
eventFrame:RegisterEvent("TRAINER_UPDATE")
eventFrame:SetScript("OnEvent", function()
    local classOpen = PriceScan.frame and PriceScan.frame:IsShown()
    local petOpen = PetPriceScan.frame and PetPriceScan.frame:IsShown()
    if not classOpen and not petOpen then return end
    if select(2, UnitClass("player")) == "HUNTER" and IsPetTrainer() then
        if petOpen then
            PetPriceScan:ScheduleScan()
        else
            PetPriceScan:Toggle()
        end
    elseif classOpen then
        PriceScan:ScheduleScan()
    end
end)

SLASH_TRAINERSPELLSPRICES1 = "/tsprices"
SLASH_TRAINERSPELLSPRICES2 = "/trainerspellsprices"
SlashCmdList.TRAINERSPELLSPRICES = function(input)
    if tostring(input or ""):lower():match("pet") then
        PetPriceScan:Toggle()
    else
        PriceScan:Toggle()
    end
end

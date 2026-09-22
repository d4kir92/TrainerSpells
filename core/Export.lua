local _, TrainerSpells = ...
local exportFrame
local exportBox
local function SortNumberKeys(data)
    local keys = {}
    for key in pairs(data or {}) do
        if type(key) == "number" then table.insert(keys, key) end
    end
    table.sort(keys)
    return keys
end

local function BuildLevelExport(levelData)
    local lines = {}
    for _, level in ipairs(SortNumberKeys(levelData)) do
        local spells = levelData[level]
        for _, spellID in ipairs(SortNumberKeys(spells)) do
            local entry = spells[spellID]
            local cost = type(entry) == "table" and entry.cost or entry
            local rank = type(entry) == "table" and entry.rank or nil
            local requires = type(entry) == "table" and entry.requires or nil
            local requirementText = ""
            if type(requires) == "table" then
                local requirementIDs = {}
                for _, requiredSpellID in ipairs(requires) do
                    table.insert(requirementIDs, tostring(requiredSpellID))
                end
                requirementText = table.concat(requirementIDs, "|")
            end
            table.insert(lines, table.concat({level, spellID, cost or 0, rank or "", requirementText}, ";"))
        end
    end
    return table.concat(lines, "\n"), #lines
end

local function BuildClassExport(classToken)
    local classData = TrainerSpells_Data and TrainerSpells_Data[classToken]
    return BuildLevelExport(classData)
end

local WARLOCK_PETS = {
    {token = "Imp", spellID = 688},
    {token = "Voidwalker", spellID = 697},
    {token = "Succubus", spellID = 712},
    {token = "Incubus", spellID = 101822},
    {token = "Felhunter", spellID = 691},
    {token = "Felguard", spellID = 30146}
}

local function MergePetData(token, localizedName)
    local merged = {}
    local keys = {token}
    if localizedName and localizedName ~= token then table.insert(keys, localizedName) end
    for _, key in ipairs(keys) do
        local levels = TrainerSpells_PetData and TrainerSpells_PetData[key]
        for level, spells in pairs(levels or {}) do
            merged[level] = merged[level] or {}
            for spellID, entry in pairs(spells) do
                merged[level][spellID] = entry
            end
        end
    end
    return merged
end

local function BuildWarlockPetExport()
    local sections = {}
    local count = 0
    for _, pet in ipairs(WARLOCK_PETS) do
        local localizedName = TrainerSpells:GetPetNameById(pet.spellID)
        local text, petCount = BuildLevelExport(MergePetData(pet.token, localizedName))
        if petCount > 0 then
            table.insert(sections, ("[%s]\n%s"):format(pet.token, text))
            count = count + petCount
        end
    end
    return table.concat(sections, "\n\n"), count
end

local function CreateExportFrame()
    local frame = CreateFrame("Frame", "TrainerSpellsExportFrame", UIParent, "BackdropTemplate")
    frame:SetSize(720, 520)
    frame:SetPoint("CENTER")
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
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    frame.Title = title

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 24, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", -46, 24)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(640)
    editBox:SetMaxLetters(0)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    scrollFrame:SetScrollChild(editBox)

    exportFrame = frame
    exportBox = editBox
end

local function ShowExport(title, text, count)
    if not exportFrame then CreateExportFrame() end
    local lineCount = text == "" and 1 or select(2, text:gsub("\n", "\n")) + 1
    exportFrame.Title:SetText(title)
    exportBox:SetText(text)
    exportBox:SetHeight(math.max(440, lineCount * 14 + 12))
    exportFrame:Show()
    exportBox:SetFocus()
    exportBox:HighlightText()
end

function TrainerSpells:ShowClassExport()
    local localizedClass, classToken = UnitClass("player")
    if not classToken then
        TrainerSpells:MSG("Die aktuelle Klasse konnte nicht ermittelt werden.")
        return
    end

    local text, count = BuildClassExport(classToken)
    ShowExport(("TrainerSpells: %s (%d Einträge)"):format(localizedClass or classToken, count), text, count)
    if count == 0 then TrainerSpells:MSG("Für die aktuelle Klasse wurden noch keine Daten erfasst.") end
end

function TrainerSpells:ShowPetExport()
    local localizedClass, classToken = UnitClass("player")
    local text, count
    if classToken == "HUNTER" then
        text, count = BuildLevelExport(TrainerSpells_PetTrainerData and TrainerSpells_PetTrainerData.HUNTER)
    elseif classToken == "WARLOCK" then
        text, count = BuildWarlockPetExport()
    else
        TrainerSpells:MSG("Der Pet-Export ist nur für Jäger und Hexenmeister verfügbar.")
        return
    end

    ShowExport(("TrainerSpells Pets: %s (%d Einträge)"):format(localizedClass or classToken, count), text, count)
    if count == 0 then TrainerSpells:MSG("Für die Pets der aktuellen Klasse wurden noch keine Daten erfasst.") end
end

SLASH_TRAINERSPELLSDUMP1 = "/tsdump"
SLASH_TRAINERSPELLSDUMP2 = "/trainerspellsdump"
SlashCmdList.TRAINERSPELLSDUMP = function()
    TrainerSpells:ShowClassExport()
end

SLASH_TRAINERSPELLSPETDUMP1 = "/tspetdump"
SLASH_TRAINERSPELLSPETDUMP2 = "/trainerspellspetdump"
SlashCmdList.TRAINERSPELLSPETDUMP = function()
    TrainerSpells:ShowPetExport()
end

local _, TrainerSpells = ...
TrainerSpells.TabSettings = {}
TrainerSpells.TabSettingKeys = {"spellbook", "class", "pet", "trainers", "weapons", "professions", "profession_skill", "profession_recipes", "profession_trainers", "compendium_class", "compendium_professions"}
TrainerSpells.SharedTabSettings = {
    TRAINERSPELLS_COMPENDIUM_CLASS = "compendium_class",
    TRAINERSPELLS_COMPENDIUM_PROFESSIONS = "compendium_professions"
}

function TrainerSpells:LoadTabSettings()
    for _, key in ipairs(self.TabSettingKeys) do
        self.TabSettings[key] = TrainerSpells_Character[key] ~= false
    end
end

TrainerSpells:LoadTabSettings()
TrainerSpells.TabSettingListeners = {}
TrainerSpells.SettingCheckboxes = {}
function TrainerSpells:OnTabSettingsChanged(listener)
    table.insert(self.TabSettingListeners, listener)
end

function TrainerSpells:ApplyTabSettings()
    if not self.SettingsReady then return end
    self:LoadTabSettings()
    for _, listener in ipairs(self.TabSettingListeners) do
        local ok, err = pcall(listener)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
    self:RegisterCompendiumTabs()
    if self.SettingsWindow and self.SettingsWindow.UpdateDependencies then self.SettingsWindow:UpdateDependencies() end
end

TrainerSpells:RegisterSharedSettings({
    keys = {"TRAINERSPELLS_COMPENDIUM_CLASS", "TRAINERSPELLS_COMPENDIUM_PROFESSIONS"},
    getDB = function() return TrainerSpells_Character end,
    get = function(key) return TrainerSpells_Character[TrainerSpells.SharedTabSettings[key]] ~= false end,
    set = function(key, value) TrainerSpells_Character[TrainerSpells.SharedTabSettings[key]] = value end,
    onChange = function(key, value)
        local checkbox = TrainerSpells.SettingCheckboxes[TrainerSpells.SharedTabSettings[key]]
        if checkbox and checkbox.SetChecked then checkbox:SetChecked(value ~= false) end
        TrainerSpells:ApplyTabSettings()
    end
})

function TrainerSpells:IsTabEnabled(key)
    return self.TabSettings[key] ~= false
end

function TrainerSpells:FilterTabViews(views, prefix)
    local visible = {}
    for _, entry in ipairs(views) do
        if self:IsTabEnabled((prefix or "") .. (entry.view or entry.mode)) then table.insert(visible, entry) end
    end
    return visible
end

function TrainerSpells:HasSpellbookTabs()
    local _, classToken = UnitClass("player")
    return self:IsTabEnabled("class") or self:IsTabEnabled("trainers") and self.BuildClassTrainerItems ~= nil or self:IsTabEnabled("weapons") and self.BuildWeaponSkillItems ~= nil or self:IsTabEnabled("pet") and self:HasPetClassData(classToken)
end

function TrainerSpells:GetTabLayout(key)
    return TrainerSpells_Character and TrainerSpells_Character[key] == "tabs" and "tabs" or "combined"
end

function TrainerSpells:HasProfessionTabs()
    return self:IsTabEnabled("profession_skill") or self:IsTabEnabled("profession_recipes") or self:IsTabEnabled("profession_trainers")
end

function TrainerSpells:ToggleSettings()
    if not self.SettingsWindow then
        local win = self:CreateUIWindow({name = "TrainerSpellsSettings", title = "|T133741:20:20|t TrainerSpells v0.8.8", width = 520, height = 600})
        self.SettingsWindow = win
        win:AddSearch()
        win:AddCategory({label = "LID_GENERAL", key = "general"})
        win:AddCheckbox({
            label = "LID_SHOWMINIMAPBUTTON",
            added = "2026-10-07",
            value = TrainerSpells_Character.showMinimapButton ~= false,
            func = function(value)
                TrainerSpells_Character.showMinimapButton = value
                if value then self:ShowMMBtn("TrainerSpells") else self:HideMMBtn("TrainerSpells") end
            end
        })
        for _, category in ipairs({
            {label = "LID_SETTINGS_SPELLBOOK", key = "spellbook", layout = "spellbookLayout", compendium = "compendium_class", compendiumLabel = "LID_SETTINGS_COMPENDIUM_CLASS", options = {
                {"class", "LID_CLASSTRAINER"},
                {"pet", "LID_PETTRAINING"},
                {"trainers", "LID_CLASSTRAINERS"},
                {"weapons", "LID_SETTINGS_WEAPONS"}
            }},
            {label = "LID_PROFESSIONS", key = "professions", layout = "professionLayout", compendium = "compendium_professions", compendiumLabel = "LID_SETTINGS_COMPENDIUM_PROFESSIONS", options = {
                {"profession_skill", "LID_PROFESSION_FROMTRAINER"},
                {"profession_recipes", "LID_PROFESSION_OTHERRECIPES"},
                {"profession_trainers", "LID_PROFESSION_FINDTRAINER"}
            }}
        }) do
            win:AddCategory({label = category.label, key = category.key})
            local function AddParent(key, label)
                local checkbox = win:AddCheckbox({
                    label = label,
                    added = "2026-10-07",
                    value = TrainerSpells_Character[key] ~= false,
                    func = function(value)
                        TrainerSpells_Character[key] = value
                        for sharedKey, setting in pairs(self.SharedTabSettings) do
                            if setting == key then self:SetSharedSetting(sharedKey, value) end
                        end
                        self:ApplyTabSettings()
                    end
                })
                self.SettingCheckboxes[key] = checkbox
                return checkbox
            end
            local layout = win:AddDropdown({
                label = "LID_SETTINGS_LAYOUT",
                value = self:GetTabLayout(category.layout),
                choices = {
                    {value = "combined", label = "LID_SETTINGS_LAYOUT_COMBINED"},
                    {value = "tabs", label = "LID_SETTINGS_LAYOUT_TABS"}
                },
                func = function(value)
                    TrainerSpells_Character[category.layout] = value
                    self:ApplyTabSettings()
                end
            })
            win:AddDependency(layout, function() return TrainerSpells_Character[category.key] ~= false end, 0)
            local addonTab = AddParent(category.key, "LID_SETTINGS_ADDONTAB")
            local children = {}
            for _, option in ipairs(category.options) do
                local key = option[1]
                local checkbox = win:AddCheckbox({
                    label = option[2],
                    added = "2026-10-07",
                    value = TrainerSpells_Character[key] ~= false,
                    func = function(value)
                        TrainerSpells_Character[key] = value
                        self:ApplyTabSettings()
                    end
                })
                self.SettingCheckboxes[key] = checkbox
                win:AddDependency(checkbox, function()
                    return TrainerSpells_Character[category.key] ~= false or TrainerSpells_Character[category.compendium] ~= false
                end)
                table.insert(children, checkbox)
            end
            local compendiumTab = AddParent(category.compendium, category.compendiumLabel)
            for _, checkbox in ipairs(children) do
                win:AddRequirement(checkbox, addonTab)
                win:AddRequirement(checkbox, compendiumTab)
            end
        end
        win:UpdateDependencies()
        win:Layout()
    end
    self.SettingsWindow:SetShown(not self.SettingsWindow:IsShown())
end

function TrainerSpells:InitializeSettings()
    self:LoadTabSettings()
    self.SettingsReady = true
    if TrainerSpells_Character.showMinimapButton == nil then TrainerSpells_Character.showMinimapButton = true end
    self:CreateMinimapButton({
        name = "TrainerSpells",
        icon = 133741,
        dbtab = TrainerSpells_Character,
        dbkey = "showMinimapButton",
        vTT = {{"TrainerSpells"}, {self:Trans("LID_SETTINGS_OPEN")}},
        funcL = function() self:ToggleSettings() end,
        funcR = function() self:ToggleSettings() end
    })
    self:AddSlash("ts", function() self:ToggleSettings() end)
    self:AddSlash("trainerspells", function() self:ToggleSettings() end)
    self:ApplyTabSettings()
end
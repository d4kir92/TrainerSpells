local _, TrainerSkills = ...
function TrainerSkills:Content(name, parent)
    local content = CreateFrame("Frame", name, parent)
    content:SetFrameStrata("HIGH")
    content:SetSize(100, 100)
    content.bg = content:CreateTexture()
    content.bg:SetTexture("Interface\\AddOns\\TrainerSkills\\media\\inset")
    content.bg:SetSize(512, 512)
    content.bg:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    local ScrollBox = CreateFrame("Frame", nil, content, "WowScrollBoxList")
    ScrollBox:SetAllPoints(content)
    local ScrollBar = CreateFrame("EventFrame", nil, content, "MinimalScrollBar")
    ScrollBar:SetPoint("TOPLEFT", ScrollBox, "TOPRIGHT")
    ScrollBar:SetPoint("BOTTOMLEFT", ScrollBox, "BOTTOMRIGHT")
    local DataProvider = CreateDataProvider()
    local ScrollView = CreateScrollBoxListLinearView()
    local function Initializer(button, data, ...)
        if button.leftText == nil and button.rightText == nil then
            button.leftText = button:CreateFontString(nil, nil, "GameFontNormal")
            button.leftText:SetPoint("CENTER", button, "CENTER", 0, 0)
            button.leftText:SetWidth(button:GetWidth() - 20)
            button.leftText:SetJustifyH("LEFT")
            button.rightText = button:CreateFontString(nil, nil, "GameFontNormal")
            button.rightText:SetPoint("CENTER", button, "CENTER", 0, 0)
            button.rightText:SetWidth(button:GetWidth() - 20)
            button.rightText:SetJustifyH("RIGHT")
            button:SetText("")
        end

        local spellName, _, spellIcon = GetSpellInfo(data.spell.id)
        if IsSpellKnown(data.spell.id) or IsSpellKnown(data.spell.id, true) then
            button:SetScript(
                "OnClick",
                function()
                    print(data.spell.id)
                end
            )

            button.leftText:SetText("KNOWN: " .. spellName)
            button.rightText:SetText("Level " .. data.lvl)
        else
            local level = UnitLevel("player")
            if level >= data.lvl then
                button:SetScript(
                    "OnClick",
                    function()
                        print(data.spell.id)
                    end
                )

                button.leftText:SetText("AVAILABLE NOW: " .. spellName)
                button.rightText:SetText("Level " .. data.lvl)
            else
                button:SetScript(
                    "OnClick",
                    function()
                        print(data.spell.id)
                    end
                )

                button.leftText:SetText(spellName)
                button.rightText:SetText("Level " .. data.lvl)
            end
        end
    end

    local function CustomFactory(factory, node)
        factory(node, Initializer)
    end

    ScrollView:SetElementExtent(22)
    ScrollView:SetElementFactory(CustomFactory)
    ScrollView:SetDataProvider(DataProvider)
    ScrollUtil.InitScrollBoxListWithScrollBar(ScrollBox, ScrollBar, ScrollView)
    ScrollView:SetElementInitializer("Button", Initializer)
    local tab = {}
    local _, class = UnitClass("player")
    if class == "HUNTER" then
        tab = TrainerSkills:GetHunterSpells()
    end

    DataProvider:Flush()
    local data = {}
    for lvl, spells in pairs(tab) do
        for _, spell in pairs(spells) do
            table.insert(
                data,
                {
                    spell = spell,
                    lvl = lvl,
                }
            )
        end
    end

    table.sort(
        data,
        function(a, b)
            local knownA = IsSpellKnown(a.spell.id) or IsSpellKnown(a.spell.id, true)
            local knownB = IsSpellKnown(b.spell.id) or IsSpellKnown(b.spell.id, true)
            if knownA ~= knownB then return not knownA end
            if a.lvl ~= b.lvl then return a.lvl < b.lvl end

            return a.spell.id < b.spell.id
        end
    )

    -- 3. Wenn Level auch gleich ist: Sortiere nach ID
    DataProvider:Flush()
    DataProvider:InsertTable(data)

    return content
end

function TrainerSkills:Init()
    if SpellBookFrame then
        local content = TrainerSkills:Content("test", SpellBookFrame)
        content:SetPoint("TOPLEFT", 20, -74)
        content:SetPoint("BOTTOMRIGHT", -60, 80)
        local skillLineTab = _G["SpellBookSkillLineTab" .. 6]
        skillLineTab:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        if skillLineTab then
            hooksecurefunc(
                SpellBookFrame,
                "UpdateSkillLineTabs",
                function()
                    skillLineTab.tooltip = "TrainerSkills"
                    skillLineTab:Show()
                    if SpellBookFrame.selectedSkillLine == 6 then
                        skillLineTab:SetChecked(true)
                        content:Show()
                        ShowAllSpellRanksCheckbox:Hide()
                    else
                        skillLineTab:SetChecked(false)
                        content:Hide()
                    end
                end
            )

            hooksecurefunc(
                SpellBookFrame,
                "Update",
                function()
                    if SpellBookFrame.bookType ~= BOOKTYPE_SPELL then
                        content:Hide()
                    elseif SpellBookFrame.selectedSkillLine == SKILL_LINE_TAB then
                        content:Show()
                    end
                end
            )
        end
    end
end

TrainerSkills:Init()

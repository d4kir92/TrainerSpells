local _, TrainerSkills = ...
local TRSKSetup = CreateFrame("FRAME", "TRSKSetup")
TrainerSkills:RegisterEvent(TRSKSetup, "PLAYER_LOGIN")
TRSKSetup:SetScript(
    "OnEvent",
    function(self, event, ...)
        if event == "PLAYER_LOGIN" then
            TRSK = TRSK or {}
            TrainerSkills:SetVersion(136142, "0.1.24")
            TrainerSkills:SetAddonOutput("TrainerSkills", 136142)
            TrainerSkills:AddSlash("mina", TrainerSkills.ToggleSettings)
            TrainerSkills:AddSlash("TRSK", TrainerSkills.ToggleSettings)
            TrainerSkills:AddSlash("TrainerSkills", TrainerSkills.ToggleSettings)
            local mmbtn = nil
            TrainerSkills:CreateMinimapButton(
                {
                    ["name"] = "TrainerSkills",
                    ["icon"] = 136142,
                    ["var"] = mmbtn,
                    ["dbtab"] = TRSK,
                    ["vTT"] = {{"TrainerSkills", "v" .. TrainerSkills:GetVersion()}, {TrainerSkills:Trans("LID_LEFTCLICK"), TrainerSkills:Trans("LID_OPENSETTINGS")}, {TrainerSkills:Trans("LID_RIGHTCLICK"), TrainerSkills:Trans("LID_HIDEMINIMAPBUTTON")}},
                    ["funcL"] = function()
                        TrainerSkills:ToggleSettings()
                    end,
                    ["funcR"] = function()
                        TrainerSkills:SV(TRSK, "SHOWMINIMAPBUTTON", false)
                        TrainerSkills:HideMMBtn("TrainerSkills")
                        TrainerSkills:MSG("Minimap Button is now hidden.")
                    end,
                    ["dbkey"] = "SHOWMINIMAPBUTTON"
                }
            )

            TrainerSkills:InitSettings()
        end
    end
)

local mn_settings = nil
function TrainerSkills:ToggleSettings()
    if mn_settings then
        if mn_settings:IsShown() then
            mn_settings:Hide()
        else
            mn_settings:Show()
        end
    end
end

function TrainerSkills:InitSettings()
    TRSK = TRSK or {}
    if TRSK["BARWIDTH"] == nil then
        TRSK["BARWIDTH"] = 140
    end

    mn_settings = TrainerSkills:CreateWindow(
        {
            ["name"] = "TrainerSkills",
            ["pTab"] = {"CENTER"},
            ["sw"] = 520,
            ["sh"] = 520,
            ["title"] = format("TrainerSkills v%s", TrainerSkills:GetVersion())
        }
    )

    local x = 15
    local y = 10
    TrainerSkills:SetAppendX(x)
    TrainerSkills:SetAppendY(y)
    TrainerSkills:SetAppendParent(mn_settings)
    TrainerSkills:SetAppendTab(TRSK)
    TrainerSkills:AppendCategory("GENERAL")
    TrainerSkills:AppendCheckbox(
        "SHOWMINIMAPBUTTON",
        TrainerSkills:GetWoWBuild() ~= "RETAIL",
        function()
            if TrainerSkills:GV(TRSK, "SHOWMINIMAPBUTTON", TrainerSkills:GetWoWBuild() ~= "RETAIL") then
                TrainerSkills:ShowMMBtn("TrainerSkills")
            else
                TrainerSkills:HideMMBtn("TrainerSkills")
            end
        end
    )
end

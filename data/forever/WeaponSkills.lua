TrainerSpellsWeaponSkills = {
    order = {196, 197, 198, 199, 201, 202, 1180, 15590, 227, 200, 264, 266, 5011, 2567},
    zones = {
        [1497] = {
            uiMapID = 1458,
            icon = 135766
        },
        [1519] = {
            uiMapID = 1453,
            icon = 135763
        },
        [1537] = {
            uiMapID = 1455,
            icon = 135757
        },
        [1637] = {
            uiMapID = 1454,
            icon = 135759
        },
        [1638] = {
            uiMapID = 1456,
            icon = 135765
        },
        [1657] = {
            uiMapID = 1457,
            icon = 135755
        },
    },
    skills = {
        [196] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                HUNTER = true,
                SHAMAN = true,
                ROGUE = true
            },
            locations = {
                Alliance = {1537},
                Horde = {1637}
            },
        },
        [197] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                HUNTER = true,
                SHAMAN = true
            },
            locations = {
                Alliance = {1537},
                Horde = {1637}
            },
        },
        [198] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                ROGUE = true,
                PRIEST = true,
                SHAMAN = true,
                DRUID = true
            },
            locations = {
                Alliance = {1537},
                Horde = {1638}
            },
        },
        [199] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                SHAMAN = true,
                DRUID = true
            },
            locations = {
                Alliance = {1537},
                Horde = {1638}
            },
        },
        [200] = {
            cost = 10000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                HUNTER = true,
                DRUID = true
            },
            level = 20,
            locations = {
                Alliance = {1519},
                Horde = {1497}
            },
        },
        [201] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                HUNTER = true,
                ROGUE = true,
                MAGE = true,
                WARLOCK = true
            },
            locations = {
                Alliance = {1519},
                Horde = {1497}
            },
        },
        [202] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                PALADIN = true,
                HUNTER = true
            },
            locations = {
                Alliance = {1519},
                Horde = {1497}
            },
        },
        [227] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                PRIEST = true,
                SHAMAN = true,
                DRUID = true,
                WARLOCK = true,
                MAGE = true
            },
            locations = {
                Alliance = {1519, 1657},
                Horde = {1637, 1638}
            },
        },
        [264] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true
            },
            locations = {
                Alliance = {1657},
                Horde = {1637}
            },
        },
        [266] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true
            },
            locations = {
                Alliance = {1537},
                Horde = {1638}
            },
        },
        [1180] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true,
                PRIEST = true,
                SHAMAN = true,
                DRUID = true,
                WARLOCK = true,
                MAGE = true
            },
            locations = {
                Alliance = {1537, 1519, 1657},
                Horde = {1637, 1497}
            },
        },
        [2567] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true
            },
            locations = {
                Alliance = {1537, 1657},
                Horde = {1637}
            },
        },
        [5011] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true
            },
            locations = {
                Alliance = {1537, 1519},
                Horde = {1497}
            },
        },
        [15590] = {
            cost = 1000,
            classes = {
                WARRIOR = true,
                HUNTER = true,
                ROGUE = true,
                SHAMAN = true,
                DRUID = true
            },
            locations = {
                Alliance = {1537, 1657},
                Horde = {1637}
            },
        },
    },
}

local _, _, _, weaponSkillsInterface = GetBuildInfo()
weaponSkillsInterface = tonumber(weaponSkillsInterface) or 0
if weaponSkillsInterface ~= 16001 then
    if weaponSkillsInterface < 30000 then TrainerSpellsWeaponSkills.skills[196].classes.ROGUE = nil end
    if weaponSkillsInterface < 20000 then
        TrainerSpellsWeaponSkills.skills[197].classes.SHAMAN = nil
        TrainerSpellsWeaponSkills.skills[199].classes.SHAMAN = nil
    end
end

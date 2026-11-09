local _, TrainerSpells = ...
TrainerSpells.QuestSpells = {
    DRUID = {
        [1066] = 16,
        [5487] = 10,
        [8946] = 14,
    },
    HUNTER = {
        [1515] = 10,
        [5149] = 10,
    },
    MAGE = {
        [10140] = 60,
    },
    PALADIN = {
        [5502] = 20,
        [7328] = 12,
        [13819] = 40,
    },
    PRIEST = {
        [2651] = { [4] = 20 },
        [2652] = { [5] = 10 },
        [2944] = { [5] = 20 },
        [6346] = { [3] = 20 },
        [9035] = { [8] = 10 },
        [10797] = { [4] = 10 },
        [13896] = { [1] = 20 },
        [13908] = { [1] = 10, [3] = 10 },
        [18137] = { [8] = 20 },
    },
    ROGUE = {
        [2842] = 20,
    },
    SHAMAN = {
        [3599] = 10,
    },
    WARLOCK = {
        [688] = 1,
        [691] = 30,
        [697] = 10,
        [712] = 20,
        [5784] = 40,
        [23161] = 60,
    },
    WARRIOR = {
        [71] = 10,
        [355] = 10,
        [2458] = 30,
        [7386] = 10,
        [20252] = 30,
    },
}

local defensiveStance = {
    [1] = {questID = 1638, questName = "A Warrior's Training", uiMapID = 1429, x = 41.09, y = 65.77},
    [2] = {questID = 1498, questName = "Path of Defense", uiMapID = 1413, x = 61, y = 21},
    [3] = {questID = 1678, questName = "Vejrek"},
    [4] = {questID = 1683, questName = "Vorlus Vilehoof"},
    [5] = {questID = 1819, questName = "Ulag the Cleaver"},
    [6] = {questID = 1498, questName = "Path of Defense", uiMapID = 1413, x = 61, y = 21},
    [7] = {questID = 1678, questName = "Vejrek"},
    [8] = {questID = 1498, questName = "Path of Defense", uiMapID = 1413, x = 61, y = 21},
}
local taming = {
    [2] = {questID = 6062, questName = "Taming the Beast", uiMapID = 1411, x = 51.85, y = 43.49},
    [3] = {questID = 6064, questName = "Taming the Beast", uiMapID = 1426, x = 45.81, y = 53.04},
    [4] = {questID = 6063, questName = "Taming the Beast", uiMapID = 1438, x = 56.68, y = 59.49},
    [6] = {questID = 6061, questName = "Taming the Beast", uiMapID = 1412, x = 46.93, y = 59.65},
    [8] = {questID = 6062, questName = "Taming the Beast", uiMapID = 1411, x = 51.85, y = 43.49},
}
local berserkerStance = {
    Alliance = {questID = 1718, questName = "The Islander", uiMapID = 1453, x = 80.41, y = 59.8},
    Horde = {questID = 1718, questName = "The Islander", uiMapID = 1458, x = 47.4, y = 17.29},
}

TrainerSpells.QuestSpellStarts = {
    [71] = defensiveStance,
    [355] = defensiveStance,
    [688] = {
        [2] = {questID = 1485, questName = "Vile Familiars"},
        [5] = {questID = 1470, questName = "Piercing the Veil"},
        [7] = {questID = 1599, questName = "Beginnings"},
    },
    [691] = {questID = 1798, questName = "Seeking Strahad"},
    [697] = {
        [2] = {questID = 1506, questName = "Gan'rul's Summons"},
        [8] = {questID = 1506, questName = "Gan'rul's Summons"},
    },
    [712] = {
        [1] = {questID = 1738, questName = "Heartswood"},
        [7] = {questID = 1738, questName = "Heartswood"},
    },
    [1066] = {
        Alliance = {questID = 26, questName = "A Lesson to Learn", uiMapID = 1457, x = 35.37, y = 8.4},
        Horde = {questID = 27, questName = "A Lesson to Learn", uiMapID = 1456, x = 76.48, y = 27.22},
    },
    [1515] = taming,
    [2458] = berserkerStance,
    [2651] = {questID = 5674, questName = "Elune's Grace", uiMapID = 1457, x = 38.33, y = 80.95},
    [2652] = {questID = 5658, questName = "Touch of Weakness"},
    [2842] = {
        Alliance = {questID = 2360, questName = "Mathias and the Defias", uiMapID = 1453, x = 75, y = 59},
        Horde = {questID = 2460, questName = "The Shattered Salute", uiMapID = 1454, x = 43.05, y = 53.74},
    },
    [2944] = {questID = 5646, questName = "Devouring Plague"},
    [3599] = {
        [6] = {questID = 2984, questName = "Call of Fire", uiMapID = 1412, x = 47.4, y = 62.54},
    },
    [5149] = taming,
    [5487] = {
        Alliance = {questID = 5921, questName = "Moonglade", uiMapID = 1457, x = 35.37, y = 8.4},
        Horde = {questID = 5922, questName = "Moonglade", uiMapID = 1456, x = 76.48, y = 27.22},
    },
    [5502] = {questID = 1654, questName = "The Test of Righteousness"},
    [5784] = {
        [1] = {questID = 4488, questName = "Summon Felsteed", uiMapID = 1453, x = 39.24, y = 84.96},
        [5] = {questID = 4489, questName = "Summon Felsteed", uiMapID = 1458, x = 86.21, y = 15.93},
        [7] = {questID = 4487, questName = "Summon Felsteed", uiMapID = 1455, x = 50.35, y = 5.66},
    },
    [7328] = {
        [1] = {questID = 1642, questName = "The Tome of Divinity", uiMapID = 1429, x = 41.1, y = 66.04},
        [3] = {questID = 1646, questName = "The Tome of Divinity"},
    },
    [6346] = {questID = 5645, questName = "A Lack of Fear", uiMapID = 1455, x = 25.21, y = 10.76},
    [7386] = defensiveStance,
    [8946] = {
        Alliance = {questID = 6121, questName = "Lessons Anew", uiMapID = 1457, x = 35.37, y = 8.4},
        Horde = {questID = 6126, questName = "Lessons Anew", uiMapID = 1456, x = 76.48, y = 27.22},
    },
    [9035] = {questID = 5652, questName = "Hex of Weakness", uiMapID = 1454, x = 35.59, y = 87.82},
    [10140] = {questID = 7463, questName = "Arcane Refreshment"},
    [13819] = {
        [3] = {questID = 4486, questName = "The Tome of Nobility", uiMapID = 1455, x = 23.13, y = 6.14},
    },
    [10797] = {questID = 5629, questName = "Returning Home", uiMapID = 1438, x = 55.56, y = 56.75},
    [13896] = {questID = 5676, questName = "Arcane Feedback"},
    [13908] = {
        [1] = {questID = 5637, questName = "Desperate Prayer"},
        [3] = {questID = 5635, questName = "Desperate Prayer", uiMapID = 1426, x = 47.34, y = 52.19},
    },
    [18137] = {questID = 5680, questName = "Shadowguard", uiMapID = 1454, x = 35.59, y = 87.82},
    [20252] = berserkerStance,
    [23161] = {questID = 7563, questName = "Rage of Blood", uiMapID = 1428, x = 12, y = 31},
}

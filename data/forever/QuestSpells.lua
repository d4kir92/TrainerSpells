local _, TrainerSpells = ...
TrainerSpells.QuestSpells = {
    DRUID = {
        [768] = 20,
        [1066] = 16,
        [5487] = 10,
        [8946] = 14,
    },
    HUNTER = {
        [1515] = 10,
        [5149] = 10,
    },
    PALADIN = {
        [7328] = 12,
    },
    PRIEST = {
        [2651] = { [4] = 20 },
        [2652] = { [5] = 10 },
        [9035] = { [8] = 10 },
        [13896] = { [1] = 20 },
        [13908] = { [3] = 10 },
        [18137] = { [8] = 20 },
        [1277331] = { [3] = 20 },
        [1277370] = { [1] = 10 },
        [1277455] = { [7] = 10 },
        [1277462] = { [7] = 20 },
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
    [1] = {questID = 94863, questName = "Taming the Beast", uiMapID = 1429, x = 41.2, y = 66.2},
    [2] = {questID = 6062, questName = "Taming the Beast", uiMapID = 1411, x = 51.85, y = 43.49},
    [3] = {questID = 6064, questName = "Taming the Beast", uiMapID = 1426, x = 45.81, y = 53.04},
    [4] = {questID = 6063, questName = "Taming the Beast", uiMapID = 1438, x = 56.68, y = 59.49},
    [6] = {questID = 6061, questName = "Taming the Beast", uiMapID = 1412, x = 46.93, y = 59.65},
    [8] = {questID = 6062, questName = "Taming the Beast", uiMapID = 1411, x = 51.85, y = 43.49},
    [95] = {questID = 94007, questName = "Taming the Beast", uiMapID = 2521, x = 45.2, y = 44.2},
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
    [768] = {
        Alliance = {questID = 98393, questName = "The Great Cat Spirit", uiMapID = 1457, x = 35.37, y = 8.4},
        Horde = {questID = 98340, questName = "The Great Cat Spirit", uiMapID = 1456, x = 76.48, y = 27.22},
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
    [3599] = {
        [6] = {questID = 2984, questName = "Call of Fire", uiMapID = 1412, x = 47.4, y = 62.54},
    },
    [5149] = taming,
    [5487] = {
        Alliance = {questID = 5921, questName = "Moonglade", uiMapID = 1457, x = 35.37, y = 8.4},
        Horde = {questID = 5922, questName = "Moonglade", uiMapID = 1456, x = 76.48, y = 27.22},
    },
    [5784] = {
        [1] = {questID = 4488, questName = "Summon Felsteed", uiMapID = 1453, x = 39.24, y = 84.96},
        [5] = {questID = 4489, questName = "Summon Felsteed", uiMapID = 1458, x = 86.21, y = 15.93},
        [7] = {questID = 4487, questName = "Summon Felsteed", uiMapID = 1455, x = 50.35, y = 5.66},
    },
    [7328] = {
        [1] = {questID = 1642, questName = "The Tome of Divinity", uiMapID = 1429, x = 41.1, y = 66.04},
        [3] = {questID = 1646, questName = "The Tome of Divinity"},
    },
    [7386] = defensiveStance,
    [8946] = {
        Alliance = {questID = 6121, questName = "Lessons Anew", uiMapID = 1457, x = 35.37, y = 8.4},
        Horde = {questID = 6126, questName = "Lessons Anew", uiMapID = 1456, x = 76.48, y = 27.22},
    },
    [9035] = {questID = 5652, questName = "Hex of Weakness", uiMapID = 1454, x = 35.59, y = 87.82},
    [13896] = {questID = 5676, questName = "Arcane Feedback"},
    [13908] = {questID = 5635, questName = "Desperate Prayer", uiMapID = 1426, x = 47.34, y = 52.19},
    [18137] = {questID = 5680, questName = "Shadowguard", uiMapID = 1454, x = 35.59, y = 87.82},
    [20252] = berserkerStance,
    [1277331] = {questID = 5645, questName = "Chastise", uiMapID = 1455, x = 25.21, y = 10.76},
    [1277370] = {questID = 94774, questName = "Divine Grace", uiMapID = 1429, x = 43.28, y = 65.72},
    [1277455] = {questID = 94824, questName = "Confounding Flash"},
    [1277462] = {questID = 94820, questName = "Contingency Plan"},
}

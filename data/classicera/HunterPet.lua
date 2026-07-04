-- Pet-Trainer-Daten (Beast Training) fuer Hunter, Classic Era
-- Gleiche Struktur wie TrainerSpells_PetTrainerData im WTF-SavedVariables-Ordner: [level][spellID] = {cost, rank}
-- Einfach den Inhalt von TrainerSpells_PetTrainerData["HUNTER"] aus der WTF-Datei hier reinkopieren (status-Feld wird ignoriert).
TrainerSpellsBuiltin_HunterPet = TrainerSpellsBuiltin_HunterPet or {
    [10] = {
        [4195] = {cost = 10, rank = "Rank 1"},
        [24547] = {cost = 10, rank = "Rank 1"},
    },
    [12] = {
        [4196] = {cost = 120, rank = "Rank 2"},
        [24556] = {cost = 120, rank = "Rank 2"},
    },
    [18] = {
        [4197] = {cost = 400, rank = "Rank 3"},
        [24557] = {cost = 400, rank = "Rank 3"},
    },
    [20] = {
        [14923] = {cost = 440, rank = "Rank 3"},
        [24440] = {cost = 440, rank = "Rank 1"},
        [24475] = {cost = 440, rank = "Rank 1"},
        [24490] = {cost = 440, rank = "Rank 1"},
        [24494] = {cost = 440, rank = "Rank 1"},
        [24495] = {cost = 440, rank = "Rank 1"},
    },
    [24] = {
        [4198] = {cost = 1400, rank = "Rank 4"},
        [24558] = {cost = 1400, rank = "Rank 4"},
    },
    [30] = {
        [4199] = {cost = 1600, rank = "Rank 5"},
        [14924] = {cost = 1600, rank = "Rank 4"},
        [24441] = {cost = 1600, rank = "Rank 2"},
        [24476] = {cost = 1600, rank = "Rank 2"},
        [24508] = {cost = 1600, rank = "Rank 2"},
        [24511] = {cost = 1600, rank = "Rank 2"},
        [24514] = {cost = 1600, rank = "Rank 2"},
        [24559] = {cost = 1600, rank = "Rank 5"},
    },
    [36] = {
        [4200] = {cost = 2800, rank = "Rank 6"},
        [24560] = {cost = 2800, rank = "Rank 6"},
    },
    [40] = {
        [14925] = {cost = 3600, rank = "Rank 5"},
        [24463] = {cost = 3600, rank = "Rank 3"},
        [24477] = {cost = 3600, rank = "Rank 3"},
        [24509] = {cost = 3600, rank = "Rank 3"},
        [24512] = {cost = 3600, rank = "Rank 3"},
        [24515] = {cost = 3600, rank = "Rank 3"},
    },
    [42] = {
        [4201] = {cost = 4800, rank = "Rank 7"},
        [24561] = {cost = 4800, rank = "Rank 7"},
    },
    [48] = {
        [4202] = {cost = 6400, rank = "Rank 8"},
        [24562] = {cost = 6400, rank = "Rank 8"},
    },
    [50] = {
        [14926] = {cost = 7200, rank = "Rank 6"},
        [24464] = {cost = 7200, rank = "Rank 4"},
        [24478] = {cost = 7200, rank = "Rank 4"},
        [24510] = {cost = 7200, rank = "Rank 4"},
        [24513] = {cost = 7200, rank = "Rank 4"},
        [24516] = {cost = 7200, rank = "Rank 4"},
    },
    [54] = {
        [5048] = {cost = 8400, rank = "Rank 9"},
        [24631] = {cost = 8400, rank = "Rank 9"},
    },
    [60] = {
        [5049] = {cost = 10000, rank = "Rank 10"},
        [14927] = {cost = 10000, rank = "Rank 7"},
        [24632] = {cost = 10000, rank = "Rank 10"},
    },
}

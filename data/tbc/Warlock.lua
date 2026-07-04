-- Trainer-Daten: TBC, Warlock
-- Gleiche Struktur wie TrainerSpells_Data im WTF-SavedVariables-Ordner: [level][spellID] = {cost, rank}
-- Einfach den Inhalt von TrainerSpells_Data["WARLOCK"] aus der WTF-Datei hier reinkopieren (status-Feld wird ignoriert).
-- Hinweis: Grimoires/Pet-Faehigkeiten gehoeren NICHT hier rein, sondern in WarlockPet.lua
TrainerSpellsBuiltin = TrainerSpellsBuiltin or {}
TrainerSpellsBuiltin.WARLOCK = TrainerSpellsBuiltin.WARLOCK or {
    -- [1] = {
    --     [686] = {cost = 0, rank = nil}, -- Shadow Bolt
    -- },
}

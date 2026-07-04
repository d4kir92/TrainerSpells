-- Trainer-Daten: TBC, Hunter
-- Gleiche Struktur wie TrainerSpells_Data im WTF-SavedVariables-Ordner: [level][spellID] = {cost, rank}
-- Einfach den Inhalt von TrainerSpells_Data["HUNTER"] aus der WTF-Datei hier reinkopieren (status-Feld wird ignoriert).
-- Hinweis: Beast-Training-Faehigkeiten (Pet-Trainer) gehoeren NICHT hier rein, sondern in HunterPet.lua
TrainerSpellsBuiltin = TrainerSpellsBuiltin or {}
TrainerSpellsBuiltin.HUNTER = TrainerSpellsBuiltin.HUNTER or {
    -- [1] = {
    --     [75] = {cost = 0, rank = nil}, -- Auto Shot
    -- },
}

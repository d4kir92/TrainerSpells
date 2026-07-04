-- Trainer-Daten: TBC, Druid
-- Gleiche Struktur wie TrainerSpells_Data im WTF-SavedVariables-Ordner: [level][spellID] = {cost, rank}
-- Einfach den Inhalt von TrainerSpells_Data["DRUID"] aus der WTF-Datei hier reinkopieren (status-Feld wird ignoriert).
TrainerSpellsBuiltin = TrainerSpellsBuiltin or {}
TrainerSpellsBuiltin.DRUID = TrainerSpellsBuiltin.DRUID or {
    -- [1] = {
    --     [5176] = {cost = 0, rank = nil}, -- Wrath
    -- },
}

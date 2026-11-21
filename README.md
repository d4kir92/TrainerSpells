# TrainerSpells

TrainerSpells shows what you can learn from class, pet, weapon, and profession trainers, without visiting every trainer first. Its lists sit right in your spellbook and profession window.

## Features

### Class spells

- Adds a TrainerSpells tab to the spellbook with every trainer spell for your class, sorted into Available Now, Not Yet Available, Already Learned, and Missing Required Talents.
- Category headers show the number of spells and the total training cost. The total turns red when you cannot afford it.
- Shows the normal price next to the price with your best capital-city reputation discount.
- Marks quest-taught class spells and names the quest. Left-clicking one sets a waypoint to the quest giver, if its location is known.
- Lets you ignore single spells, or a spell rank and every rank above it, so they no longer show up as missing.
- **Spoiler-free:** hides spells more than 2 levels above your level, and all quest spells.
- **Train All:** learns every spell the open trainer can teach after a confirmation with the number of spells and the total cost. On WoW Forever you have to turn it on in the settings first, and it is not available in the Gamepad UI, which keeps the game's own trainer list.
- Shift-click a spell to link it in chat.

### Pets

- Hunter and warlock pet abilities in their own list. Warlock spells are grouped by demon.
- **Beast Taming (hunter):** tameable pets, their abilities, and where to find them, including rare pets. A filter shows only pets you can tame at your level.

### Trainer locations (WoW Forever)

- Lists every class trainer and pet trainer for your class and faction, grouped by zone and searchable, with NPC portraits.
- A button selects the nearest trainer on your continent; every row can set a waypoint.
- Starter-area trainers are marked and can be hidden.

### Weapon skills (WoW Forever)

- Shows every weapon skill, its weapon master, city, required level, and cost, grouped by weapon or by location.
- Clicking a city icon sets a waypoint to the weapon master and opens the city map.
- Already learned weapon skills can be hidden.

### Professions

- Adds a TrainerSpells tab to the profession window with three views: **From Trainer**, **Other Recipes** (with drop, vendor, and quest sources), and **Find Trainer**.
- A dropdown switches between your own and all other professions.
- Vendor recipes name the vendor and zone; map icons set a waypoint (TomTom as fallback).
- Recipe item tooltips list your characters with that profession who have not learned the recipe yet.
- Profession ignores are saved account-wide; a separate Spoiler-free option hides recipes more than 5 skill points above your skill.

### More

- Adjustable row height for every list.
- Works together with **AzerothCompendium**: class and profession lists can also be shown as tabs inside the Compendium.
- Supports the **Classic UI** spellbook layout on WoW Forever.

## Supported clients

- WoW Forever
- Classic Era
- The Burning Crusade Classic
- Wrath of the Lich King Classic / Titan
- Cataclysm Classic
- Mists of Pandaria Classic

## Installation

1. Copy the `TrainerSpells` folder into your World of Warcraft `Interface/AddOns` directory.
2. Enable **TrainerSpells** in the character-selection add-on list.
3. Log in or reload the user interface.

## Usage

Open your spellbook or a profession window and select the TrainerSpells tab.

Data that is not bundled with the addon is recorded automatically whenever you open a trainer.

## Configuration

Enter `/ts` or `/trainerspells` in chat, or left-click the minimap button, to open the settings window.

The settings are grouped into **General**, **Spellbook**, and **Professions**. You can turn the minimap button and every addon tab on or off per character. Changes are applied with **Save & Reload**.

## Localization

TrainerSpells includes translations for all World of Warcraft client locales:

`deDE`, `enUS`, `esES`, `esMX`, `frFR`, `itIT`, `koKR`, `ptBR`, `ruRU`, `zhCN`, and `zhTW`.

## Credits

- Spell, recipe, trainer, and vendor data: [Wowhead](https://www.wowhead.com/) and [wago.tools](https://wago.tools/).
- Part of the WoW Forever class trainer locations: [QuestieDB](https://github.com/Questie/QuestieDB).

## License

All Rights Reserved, see `LICENSE`.

## Author

D4KiR

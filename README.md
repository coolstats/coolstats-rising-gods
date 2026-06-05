# coolstats

coolstats is a World of Warcraft addon that brings character stats, item context, cached inspections, talent snapshots, and raid-log lookups into one polished in-game toolkit.

## Highlights

- Character stats panel with GearScore, equipped item level, ratings, durability, repair cost, and configurable layout.
- Item-level badges and rarity borders on character and inspect equipment slots.
- Raid-log tooltip context with score, best spec, boss parses, and alternate tooltip details.
- Logs browser with search, class/spec filters, sorting, favourites, cached gear status, and cached talent status.
- Cached gear armory view for players you have inspected or interacted with.
- Cached talents viewer with spec switching and Blizzard-style talent tooltips when available.
- Minimap launcher, player right-click integrations, and modern loot alert toasts.

The addon does not make web requests in-game. Raid-log data is bundled with the addon and refreshed through new addon builds.

## Installation

1. Download this repository.
2. Place the `coolstats` folder in `Interface/AddOns/`.
3. Make sure `coolstats.toc` is directly inside the `coolstats` folder.
4. Restart the game or run `/reload`.

## Commands

- `/coolstats` or `/cs` shows help.
- `/coolstats panel` toggles the character stats panel.
- `/coolstats ilvl` toggles item-level badges.
- `/coolstats borders` toggles slot rarity borders.
- `/coolstats tooltip` toggles tooltip cleanup.
- `/coolstats uwu [name]` opens raid-log details for a player.
- `/uwu [name]` is a shortcut for raid-log lookup.
- `/coolstats reset` resets options and reloads the UI.

## Notes

- GearScore and BonusScanner are optional dependencies. coolstats will use them when available.
- Cached gear and talent data are best-effort snapshots from players you have inspected or interacted with.
- Implied cached-gear ratings may not include every gem/enchant edge case.

<p align="center">
  <img src="assets/coolstats_readme_title.svg" alt="coolstats" width="420">
</p>

**A faster way to understand a player before the pull.**

coolstats brings UwU Logs lookups, a searchable player browser, cached gear and
talent inspection, and an optional character-panel overhaul together inside the
game.

It is built for raid formation and pugging: instead of repeatedly leaving the
game to look players up, you can quickly see their parses, rankings, available
specializations, and any equipment or talent snapshots you have previously
cached.

## Core Features

### UwU Logs In Game

| Tooltip logs | Direct player lookup |
| --- | --- |
| <img src="https://i.imgur.com/n2PYD7q.png" alt="UwU Logs inside a player tooltip" width="460"> | <img src="https://i.imgur.com/c057HzR.png" alt="Direct UwU Logs lookup from a player menu" width="354"> |

- Bundled UwU Logs database containing up to the top 400 players for every
  class specialization.
- Overall raid score, best rank, and specialization-specific parse data.
- Individual boss parses directly inside player tooltips by holding `ALT`.
- Parse colors and specialization icons make results easy to scan.
- Dedicated logs panels show every available specialization for a player.
- Side-by-side compare mode cross-references your logs with another player.
- UwU Logs action added to supported player and chat-name right-click menus.

The logs database is bundled with each addon release. coolstats does not make
web requests while the game is running.

### Player Browser

![coolstats player browser](https://i.imgur.com/NakLDmq.png)

The player browser brings all available player information into one searchable
table:

- Search players by name with responsive, delayed filtering.
- Filter by class, favourites, or main specialization.
- Sort columns in ascending, descending, or default order.
- View main spec, off spec, parses, best rank, and cache availability.
- See whether logs, gear, and talents are available before opening a player.
- Favourite players so they remain at the top of the default list.
- Right-click players to compare logs, whisper, invite, view cached talents,
  or favourite them.
- Open the normal logs and cached-armory panels by clicking a player.
- Escape closes open coolstats windows from front to back.
- Clear the locally stored inspection cache from inside the browser.

### Cached Gear And Talents

| Cached gear | Cached talents |
| --- | --- |
| ![Cached gear armory](https://i.imgur.com/C2z4SLy.png) | ![Cached talents](https://i.imgur.com/uTRNko9.png) |

When a player is available within inspection range, clicking, inspecting, or
looking them up can store a local snapshot of their equipment and talents.
Those snapshots can then be viewed later, even when the player is no longer
nearby.

- Paperdoll-style cached gear view with item icons, rarity borders, and item
  levels.
- Cached GearScore, equipped item level, and implied combat ratings.
- Cached talent builds with specialization backgrounds, rank indicators,
  specialization switching, and Blizzard-style talent tooltips when available.
- Up to 1,500 recent player snapshots are retained.
- Snapshots older than 14 days are automatically removed.

Cached gear statistics are estimates derived from item data. Some effects,
gems, enchants, talents, buffs, and other character-specific modifiers may not
be represented accurately.

### Optional Character Panel Improvements

![coolstats character panel](https://i.imgur.com/rJTGDsf.png)

| Character stats panel | Pop-out mode |
| --- | --- |
| <img src="https://i.imgur.com/hEzocO6.png" alt="Custom coolstats character stats panel" width="320"> | <img src="https://i.imgur.com/nxFxYDo.png" alt="Custom stat pop-out mode" width="440"> |

coolstats also includes an optional overhaul of the default character panel:

- Extended stats panel with GearScore, item level, ratings, durability, repair
  cost, movement speed, and additional class-relevant statistics.
- Reorderable stat rows and configurable sections with quick bulk toggles.
- Favourite important statistics.
- Detachable stat popouts.
- Configurable backgrounds, opacity, zoom, contrast, and text palettes.
- Item-level badges and rarity-colored equipment-slot borders.
- Cleaner item tooltips when GearScore is installed.
- Configurable loot-alert toasts for looted items, roll wins, and crafts.

Character-panel features can be disabled in settings while keeping the logs
browser, tooltip parses, and lookup functionality enabled. Changing this option
requires a UI reload.

## Quick Start

1. Download the latest install-ready ZIP from the GitHub Releases page.
2. Extract every included addon folder into `Interface/AddOns/`.
3. Ensure `Interface/AddOns/coolstats/coolstats.toc` and the included
   `Interface/AddOns/coolstats_Data_<Realm>/` folders exist.
4. Restart the game or run `/reload`.
5. Left-click the coolstats minimap button to open the player browser.

On login, coolstats confirms that it loaded successfully and shows the
freshness date of the bundled UwU Logs data. If the data is more than seven
days old, the addon displays a red update warning.

Minimap controls:

- **Left-click:** open the player browser.
- **Right-click:** open the coolstats menu.
- **Left-click and drag:** move the minimap button.

## Using Player Data

- **Hover a player:** view their overall UwU Logs result.
- **Hold `ALT` while hovering:** view individual boss parses.
- **Right-click a supported player name:** open their UwU Logs panel.
- **Click a player in the browser:** open their logs and cached gear.
- **Right-click a browser row:** compare logs, whisper, invite, view talents,
  or favourite.
- **Inspect or interact with a nearby player:** update their local gear and
  talent snapshots when inspection data is available.

## Commands

| Command | Action |
| --- | --- |
| `/coolstats` or `/cs` | Open settings |
| `/coolstats settings` | Open settings |
| `/coolstats browser` | Open the player browser |
| `/coolstats uwu [player name]` | Open UwU Logs for a player |

If no name is supplied to `/coolstats uwu`, the current target is used. If
there is no target, coolstats uses your character.

## Settings And Optional Dependencies

Most visual and quality-of-life features can be configured or disabled from
the coolstats settings panel.

- **GearScore:** optional. coolstats includes its own GearScore calculation;
  installing GearScore additionally enables compatibility and tooltip-cleanup
  behavior.
- **BonusScanner:** optional. Without it, the addon still works normally, but
  some detailed gear-contribution lines in stat tooltips are unavailable.

Neither dependency is required for logs, the player browser, cached gear and
talents, loot alerts, or the character-panel improvements.

## Data And Privacy

- coolstats does not make web requests or send telemetry from inside the game.
- Bundled logs are updated by installing a newer addon release.
- Cached gear, talents, favourites, and settings are stored locally in
  `coolstatsDB`.
- Cached inspection data can be cleared from the player browser.

## Support

Use the blue **HELP** button inside the player browser to begin an in-game
whisper to **Jumpscared** for questions, suggestions, or bug reports.

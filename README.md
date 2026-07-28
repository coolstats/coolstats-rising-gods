<p align="center">
  <img src="assets/coolstats_readme_title.svg" alt="coolstats" width="420">
</p>

# coolstats - Rising Gods

**A faster way to understand a player before the pull.**

This is the Rising Gods edition of coolstats for World of Warcraft 3.3.5a. It
is distributed separately from the Warmane edition and ships only the Rising
Gods load-on-demand data addon.

The core is based on upstream coolstats `v0.2.35`, while Rising Gods data,
release packaging, and public updater tooling are maintained independently in
this repository.

## Current Bundled Logs Coverage

As of `0.2.35-rg1`, the bundled data is:

- **Realm:** Rising-Gods
- **Phase:** ICC profile
- **Bundled players:** 10,075 active ranked players
- **Ranked pull size:** top 600 players per class/specialization
- **Generated player chunks:** 6 dynamic load chunks
- **Encounters:** Icecrown Citadel, Toravon, Halion, and Anub'arak
- **Generated:** 2026-07-27

The Rising Gods dataset intentionally stays ranked-player-only. Boss
leaderboards enrich players already present in the ranked coverage, but do not
add rankless boss-only records. Player data is ordered into dynamic chunks so
lower data-load settings keep higher-ranked coverage first while still showing
boss parses for covered players.

## Release Archive Layout

Official release ZIPs contain exactly the installable addon folders plus the
public data updater launchers:

```text
Update_Rising_Gods_Logs.bat
Update_Rising_Gods_Logs.sh
coolstats/
coolstats_Cache/
coolstats_Data_RisingGods/
coolstats_LogUpdater/
```

`Update_Rising_Gods_Logs.bat` is the Windows / PowerShell launcher.
`Update_Rising_Gods_Logs.sh` is the Linux / Bash launcher for Bazzite, Ubuntu,
SteamOS, and other distros with Bash and Python 3 available.

Do not combine this ZIP with the Warmane release. Both editions use the same
`coolstats` core addon folder name, but the realm data and release automation
are intentionally separate.

## Core Features

### UwU Logs In Game

| Tooltip logs | Direct player lookup |
| --- | --- |
| <img src="https://i.imgur.com/LrILZSH.png" alt="UwU Logs inside a player tooltip" width="460"> | <img src="https://i.imgur.com/3obzqzY.png" alt="Direct UwU Logs lookup from a player menu" width="354"> |

- Bundled realm-specific UwU Logs databases; no in-game web requests are made.
- Overall raid score, best rank, and specialization-specific parse data.
- Individual boss parses directly inside player tooltips by holding `ALT`.
- Parse colors and specialization icons make results easy to scan.
- Dedicated logs panels show every available specialization for a player.
- Selecting an individual boss in the browser shows boss parse, boss rank, and
  boss DPS directly in sortable columns.
- Side-by-side compare mode cross-references your logs with another player.
- UwU Logs action added to supported player and chat-name right-click menus.
- Compact `[coolstats: Player]` chat links let users with a compatible addon
  version open the linked player's logs directly.
- Individual player log panels include quick buttons for chat-linking logs and
  opening the player's Warmane Armory URL.
- Raid-progress fallback checks can show achievement/statistic progress when
  verified logs are missing on realms where the underlying client data is
  reliable.

The logs database is bundled with each addon release. coolstats does not make
web requests while the game is running.

### Player Browser

![coolstats player browser](https://i.imgur.com/XiqahAm.png)

The player browser brings all available player information into one searchable
table:

- Search players by name with responsive, delayed filtering.
- Filter by class, favourites, or main specialization.
- Sort columns in ascending, descending, or default order.
- Open a lightweight Statistics view for the current browser filters, showing
  class/spec representation with counts, percentages, a total sum, and an
  optional boss drilldown selector.
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
| ![Cached gear armory](https://i.imgur.com/ZTgwrKq.png) | ![Cached talents](https://i.imgur.com/uTRNko9.png) |

When a player is available within inspection range, clicking, inspecting, or
looking them up can store a local snapshot of their equipment and talents.
Those snapshots can then be viewed later, even when the player is no longer
nearby.

- Paperdoll-style cached gear view with item icons, rarity borders, and item
  levels.
- Cached GearScore, equipped item level, and implied combat ratings.
- Cached talent builds with specialization backgrounds, rank indicators,
  specialization switching, and Blizzard-style talent tooltips when available.
- Separate Tooltip & Cache options can disable cached gear updates and cached
  talent updates independently for players who prefer less inspect work.
- The player browser shows cached gear/talent counts and coolstats memory at a
  glance, with a Social-icon info button that opens the cache settings when
  troubleshooting lag.
- Up to 1,500 recent player snapshots are retained.
- Snapshots older than 14 days are automatically removed.

Cached gear statistics are estimates derived from item data. Cached gem presence
is shown when available and enchant bonuses are included when available, while
some effects, talents, buffs, socket bonuses, gem stat bonuses, and other
character-specific modifiers may not be represented accurately.

### Performance Analysis

coolstats Player Statistics and Distributions

| Player Statistics | Per-Boss Performance Distribution |
| --- | --- |
| <img src="https://i.imgur.com/gM7pajr.png" alt="Specialization Representation" width="320"> | <img src="https://i.imgur.com/aaIM5CQ.png" alt="Per Boss Performance Histrogramm" width="440"> |

- Statistics panel from the player browser, with class/spec representation bars, counts, percentages, a bottom sum, and a realm-aware boss drilldown selector.
- Individual Boss Performance analysis via the Parse Histogram - compare how you did against everyone else or your own class and specialization!


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

### Rising Gods Profiles

The Rising Gods edition uses Rising Gods database profile links, not Warmane
Armory links. For a character named `Vkskill`, the generated profile URL is:

```text
https://db.rising-gods.de/?profile=eu.rising-gods.Vkskill
```

Profile buttons appear in player log and player browser flows where a direct
character reference makes sense.

### Update Center And Peer Checks

The Update Center helps players notice stale data and find the correct release.

- `/cs update` opens copyable GitHub release links and local data status.
- Login freshness warnings appear when bundled UwU Logs data is old.
- `/cs versioncheck` asks the current raid or party which coolstats version and
  data timestamp they have.
- Group checks only use addon chat messages. Players who do not respond are
  treated as not having a compatible coolstats install loaded.
- Guild-wide checks are intentionally disabled for this edition.

### Optional Character Panel Improvements

coolstats also includes the optional shared character-panel feature set from
the main addon:

- Extended stats panel with GearScore, item level, ratings, durability, repair
  cost, movement speed, and class-relevant stats.
- Reorderable stat rows and configurable sections.
- Favourite important statistics.
- Detachable stat popouts.
- Configurable backgrounds, opacity, zoom, contrast, and text palettes.
- Item-level badges and rarity-colored equipment-slot borders.
- Cleaner item tooltips when GearScore is installed.
- Configurable loot-alert toasts for looted items, roll wins, and crafts.

Character-panel features can be disabled in settings while keeping logs,
tooltips, the browser, and lookup functionality enabled. Changing this option
requires a UI reload.

## Quick Start

1. Download `coolstats_rising_gods_<version>.zip` from this repository's latest
   GitHub Release.
2. Extract every top-level item into your World of Warcraft
   `Interface/AddOns/` folder.
3. Ensure these folders exist:

   ```text
   Interface/AddOns/coolstats/
   Interface/AddOns/coolstats_Cache/
   Interface/AddOns/coolstats_Data_RisingGods/
   Interface/AddOns/coolstats_LogUpdater/
   ```

4. Enable `coolstats`, `coolstats_Cache`, and
   `coolstats_Data_RisingGods` in the addon list.
5. Log into Rising Gods and run `/reload` after replacing an older build.
6. Left-click the coolstats minimap button to open the player browser.

Minimap controls:

- **Left-click:** open the player browser.
- **Right-click:** open the coolstats menu.
- **Left-click and drag:** move the minimap button.

## Public Data Updaters

Rising Gods log data can be refreshed without waiting for a full addon feature
release. The public updaters update only `coolstats_Data_RisingGods`.

| Platform | Launcher | How to run |
| --- | --- | --- |
| Windows | `Update_Rising_Gods_Logs.bat` | Double-click it, or run it from Command Prompt/PowerShell. |
| Linux, Bazzite, Ubuntu, SteamOS | `Update_Rising_Gods_Logs.sh` | Run `bash ./Update_Rising_Gods_Logs.sh` from the extracted release folder. |

Both launchers show a confirmation screen before replacing live addon files and
use numbered progress steps while they work. The Linux launcher is run through
`bash`, so it does not rely on the ZIP preserving executable permissions.
Refreshes also include duplicate-name safeguards for reused Rising Gods
character names: ambiguous ranked rows are confirmed through the UwU Logs
character endpoint, and affected boss rows are automatically repaired.
Generated data uses the same dynamic chunk metadata as official releases, so
the in-game player data-load slider can avoid loading lower-ranked chunks after
the next `/reload`.

### Python 3 Requirement

The public log updaters rebuild the Rising Gods data from UwU Logs on your
machine, so they require **Python 3**. The Windows `.bat` file launches the
PowerShell updater, and that updater calls Python during the data refresh. The
Linux `.sh` launcher calls `python3` when it is available, then falls back to
`python`.

Install Python only from the official Python website:

- Download Python: <https://www.python.org/downloads/>
- Windows setup guide: <https://docs.python.org/3/using/windows.html>
- Linux and Unix setup guide: <https://docs.python.org/3/using/unix.html>

On Windows, the easiest setup is the official installer from python.org. During
installation, enable the option that adds Python to `PATH`, then open a new
Command Prompt or PowerShell window and run:

```powershell
python --version
```

On Linux, most distros already ship Python 3. To check:

```bash
python3 --version
```

If Python is installed under a custom command or path, set it before running
the launcher:

```powershell
$env:COOLSTATS_PYTHON = "C:\Path\To\python.exe"
.\Update_Rising_Gods_Logs.bat
```

```bash
COOLSTATS_PYTHON=/custom/path/python3 bash ./Update_Rising_Gods_Logs.sh
```

Available modes:

- `1`: preview the UI and validate the currently bundled data.
- `2`: refresh this working folder only, with no live WoW install.
- `3`: refresh and install into a live `Interface/AddOns` folder.

When the official ZIP is extracted directly into `Interface/AddOns`, both
launchers auto-detect the current folder as the live AddOns folder and ask only
for confirmation.

The updater is intentionally readable source instead of a compiled executable.
It performs no GitHub publishing, uses no credentials, requests no administrator
rights, and ships no maintainer-local paths or saved install folders. It stages
new data, audits Rising Gods metadata, encounter coverage, chunk balance,
player-load metadata, duplicate keys, duplicate-name repairs, ranked-player
count, and rankless-row guards, then backs up the old live data addon before
replacement. The installed data addon is audited again after replacement.

If your WoW install is under a Windows protected folder such as `Program Files`,
Windows may deny write access to `Interface/AddOns`. In that case, run the
official updater from an elevated terminal or move the WoW/addon folder to a
normal writable location. The updater checks this before downloading data and
will leave the existing live addon untouched when writes are denied.

Examples:

```powershell
.\Update_Rising_Gods_Logs.bat
.\Update_Rising_Gods_Logs.bat -NoInstall
.\tools\update_rising_gods_live_logs.ps1 -ValidateOnly
```

```bash
bash ./Update_Rising_Gods_Logs.sh
bash ./Update_Rising_Gods_Logs.sh --no-install
python3 ./tools/update_rising_gods_live_logs.py --validate-only
```

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
| `/coolstats update` or `/cs update` | Open update links and data status |
| `/coolstats versioncheck` or `/cs versioncheck` | Check raid or party versions |
| `/coolstats cachedebug [player]` | Debug local cached gear/talent data |

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
- Bundled logs are updated by installing a newer release or by running one of
  the public data updater launchers.
- Rising Gods data is stored in the load-on-demand
  `coolstats_Data_RisingGods` addon.
- Cached gear, talents, favourites, and settings are stored locally in
  `coolstatsDB`.
- Cached inspection data can be cleared from the player browser.
- Release validation blocks Warmane realm data, maintainer-local paths,
  usernames, credentials, saved AddOns paths, and non-`coolstats` GitHub owners
  from the downloadable ZIP.

## Maintenance

Scripts are tracked in `tools/`:

```powershell
# Validate configured UwU encounters without writing data.
.\tools\update_rising_gods.ps1 -Mode Validate

# Refresh rankings and every configured boss leaderboard.
.\tools\update_rising_gods.ps1 -Mode Weekly

# Refresh weekly data and force a targeted character-profile boss repair.
.\tools\update_rising_gods.ps1 -Mode Weekly -BossName Pentendo

# Test, validate, package, and verify a release.
.\tools\prepare_rising_gods_release.ps1 -Version 0.2.35-rg1
```

See [DATA_MAINTENANCE.md](DATA_MAINTENANCE.md) for updater and release safety
rules.

## Support

Use the blue **HELP** button inside the player browser to begin an in-game
whisper to **Jumpscared** for questions, suggestions, or bug reports.

## Upstream

General core improvements may be synchronized from
[`coolstats/coolstats`](https://github.com/coolstats/coolstats), but Rising Gods
data and release automation remain isolated in this repository.

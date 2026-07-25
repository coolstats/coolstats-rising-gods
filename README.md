<p align="center">
  <img src="assets/coolstats_readme_title.svg" alt="coolstats" width="420">
</p>

# coolstats - Rising Gods

**A faster way to understand a player before the pull.**

This is the Rising Gods edition of coolstats for World of Warcraft 3.3.5a. It
is distributed separately from the Warmane edition and ships only the Rising
Gods load-on-demand data addon.

The core is based on upstream coolstats `v0.2.34`, while Rising Gods data,
release packaging, and public updater tooling are maintained independently in
this repository.

## Current Bundled Logs Coverage

As of `0.2.34-rg5`, the install-ready release ships:

- **Realm:** Rising-Gods
- **Phase:** ICC profile
- **Bundled players:** 10,075 active ranked players
- **Ranked pull size:** top 600 players per class/specialization
- **Encounters:** Icecrown Citadel, Toravon, Halion, and Anub'arak
- **Generated:** 2026-07-24

The Rising Gods dataset intentionally stays ranked-player-only. Boss
leaderboards enrich players already present in the ranked coverage, but do not
add rankless boss-only records. This keeps addon size and load behavior stable
while still showing boss parses for covered players.

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

coolstats brings UwU Logs data into the client without making web requests
while the game is running.

- Overall raid score, best rank, and specialization-specific parse data.
- Individual boss parses in tooltips by holding `ALT`.
- Dedicated player log panels for every available specialization.
- Parse colors and specialization icons for quick scanning.
- Boss parse, boss rank, and boss DPS columns when a browser boss filter is
  selected.
- Side-by-side Log Analysis for comparing two players across shared bosses.
- Direct player-log links through compact `[coolstats: Player]` chat tokens.
- UwU Logs actions on supported player and chat-name right-click menus.
- Quick player buttons for chat-linking logs and opening the Rising Gods
  profile page.

### Player Browser

The player browser is the main table for searching and comparing the bundled
data.

- Search players by name with delayed filtering to avoid stutter.
- Filter by class, main specialization, favourites, and individual boss.
- Sort by logs, gear, talents, boss parse, boss rank, and boss DPS.
- View main spec, off spec, log availability, cache availability, parse,
  ranking, and boss-specific DPS in one row.
- Favourite players so they stay near the top of the default list.
- Right-click browser rows to compare logs, whisper, invite, view cached
  talents, or favourite.
- Individual boss mode expands the browser to show a color-coded parse
  histogram with a smooth line overlay and a marker for the selected player
  when they have a log.
- The browser uses the coolstats tabard-style backdrop on the browser, logs,
  statistics, update, and analysis panels.

### Statistics Panel

The Statistics view summarizes the current browser slice without forcing users
to inspect rows one by one.

- Spec representation bars with class-colored labels and spec icons.
- Counts, percentages, and a bottom sum to verify the visible data total.
- Boss selector for drilling into representation on a single encounter.
- Cached calculations so switching filters stays responsive in the Wrath
  client.

### Cached Gear And Talents

When a player is available within inspection range, coolstats can store local
equipment and talent snapshots for later viewing.

- Paperdoll-style cached gear panel with item icons, rarity borders, and item
  levels.
- Cached GearScore, equipped item level, and derived combat ratings.
- Cached talent builds with specialization backgrounds, rank indicators,
  specialization switching, and Blizzard-style talent tooltips when available.
- Up to 1,500 recent player snapshots are retained.
- Snapshots older than 14 days are automatically pruned.
- The browser can clear the local inspection cache.

Cached gear statistics are estimates derived from available item data. Some
effects, gems, enchants, talents, buffs, and other character-specific modifiers
may not be represented accurately.

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
duplicate keys, ranked-player count, and rankless-row guards, then backs up the
old live data addon before replacement. The installed data addon is audited
again after replacement.

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
.\tools\prepare_rising_gods_release.ps1 -Version 0.2.34-rg5
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

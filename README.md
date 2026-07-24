# coolstats - Rising Gods

Rising Gods edition of coolstats for World of Warcraft 3.3.5a.

This repository is distributed separately from the Warmane edition. Its release
archive contains only:

```text
Update_Rising_Gods_Logs.bat
coolstats/
coolstats_Cache/
coolstats_Data_RisingGods/
coolstats_LogUpdater/
```

The core is based on upstream coolstats `v0.2.34`, while realm data, maintenance
scripts, releases, and GitHub history are maintained independently here.

## Features

- UwU Logs scores, rankings, and specialization-specific boss parses in game.
- Ranked-player-only bundled data; boss leaderboards enrich ranked players but do not add rankless boss-only records.
- ICC-era coverage for ICC 25 heroic, Toravon, Halion, and Anub'arak.
- Searchable player browser with class, spec, and individual-boss filters, plus boss parse distribution histograms.
- Boss DPS column when an individual boss filter is selected.
- Cached spec-representation statistics panel with boss-specific drilldown.
- Rising Gods profile links using `db.rising-gods.de`.
- Update Center with local version/data freshness and group version checks.
- Direct player-log links through compact `[coolstats: Player]` chat tokens.
- Cached gear and talent inspection.
- Optional character-panel enhancements and loot alerts.

The game addon performs no web requests. UwU Logs data is generated outside the
game and bundled into each release.

Current `0.2.34-rg3` data was refreshed on 2026-07-24 and includes 10,075
ranked players across the 13 configured Rising Gods encounters.

## Community Log Updater

Rising Gods log data can be refreshed without waiting for a full addon feature
release.

1. Download or clone this open-source repository into a normal writable folder
   such as Desktop or Documents.
2. Install Python 3 if `python` is not already available from Command Prompt.
3. Double-click `Update_Rising_Gods_Logs.bat`.
4. Choose `1` to preview, `2` to update this working folder only, or `3` to
   update and install into a live WoW folder.
5. If you choose live install, paste your `Interface\AddOns` folder path the
   first time it asks.
6. Review the confirmation screen and type `Y` to start.
7. Follow the numbered progress steps in the shell window.
8. Reload World of Warcraft after a live install finishes.

The updater is intentionally a readable batch file plus PowerShell/Python
scripts, not a compiled executable. It performs no GitHub publishing, uses no
credentials, and updates only the live `coolstats_Data_RisingGods` folder. The
existing live data addon is backed up before replacement. New data is generated
into a staging folder, audited for Rising Gods metadata, ICC boss coverage,
chunk distribution, duplicate player keys, ranked-player count, and rankless-row
guards, then Lua 5.1 checked when `luac` is available. The installed data addon
is audited again after replacement. For source or cloned repository workflows,
run it from the extracted repository folder and not directly from inside a ZIP.

Official release ZIPs also include `Update_Rising_Gods_Logs.bat` at the archive
root. If the ZIP is extracted directly into `Interface\AddOns`, double-clicking
that BAT auto-detects the current AddOns folder and only asks for confirmation
before refreshing and replacing `coolstats_Data_RisingGods`. The shipped BAT uses
only paths relative to its own folder; it does not contain or ship the maintainer's
local install path, username, saved AddOns path, credentials, or GitHub tooling.

## Installation

1. Download `coolstats_rising_gods_<version>.zip` from this repository's releases.
2. Extract the ZIP contents into `Interface/AddOns`.
3. Enable `coolstats`, `coolstats_Cache`, and `coolstats_Data_RisingGods`.
4. Log into Rising Gods and use `/reload` after replacing an older test build.

Do not combine this ZIP with the Warmane release. The release validator prevents
Warmane realm data from entering this archive, but both editions use the same
`coolstats` core addon folder and should be managed as separate distributions.

## Tester checklist

Because this project is tested by community volunteers on the live realm, please
report:

- the exact realm string printed by:

  ```text
  /run DEFAULT_CHAT_FRAME:AddMessage(GetRealmName())
  ```

- whether a known player opens in the UwU Logs panel;
- whether ICC, Toravon, Halion, and Anub'arak rows appear under the correct spec;
- whether the player browser can search and open players;
- any Lua error after enabling script errors:

  ```text
  /console scriptErrors 1
  /reload
  ```

## Maintenance

Scripts are tracked in `tools/`:

```powershell
# Validate configured UwU encounters without writing data.
.\tools\update_rising_gods.ps1 -Mode Validate

# Public/local workflow: refresh data and install only the data addon.
.\Update_Rising_Gods_Logs.bat

# Same BAT, explicit working-folder-only mode.
.\Update_Rising_Gods_Logs.bat -NoInstall

# Review the local generated data checks without network or live file writes.
.\tools\update_rising_gods_live_logs.ps1 -ValidateOnly

# Refresh rankings and every configured boss leaderboard.
# The generated package stays limited to ranked players.
.\tools\update_rising_gods.ps1 -Mode Weekly

# Refresh weekly data and force a targeted character-profile boss repair.
.\tools\update_rising_gods.ps1 -Mode Weekly -BossName Pentendo

# Test, validate, package, and verify a release.
.\tools\prepare_rising_gods_release.ps1 -Version 0.2.34-rg3
```

See [DATA_MAINTENANCE.md](DATA_MAINTENANCE.md) for safety rules.

## Upstream

General core improvements may be synchronized from
[`coolstats/coolstats`](https://github.com/coolstats/coolstats), but Rising Gods
data and release automation remain isolated in this repository.

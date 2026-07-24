# Changelog

## 0.2.34-rg3 - 2026-07-24

### Public log updater

- Added `Update_Rising_Gods_Logs.bat` to the release ZIP root so users can
  refresh Rising Gods UwU Logs data themselves after extracting the addon.
- Shipped the readable helper scripts in `coolstats_LogUpdater/tools/` instead
  of a compiled executable.
- Made release installs plug-and-play: when the ZIP is extracted directly into
  `Interface\AddOns`, the BAT auto-detects that folder and updates only
  `coolstats_Data_RisingGods`.

### Safety and privacy

- Added a fail-closed Rising Gods data integrity audit covering TOC wiring, ICC
  boss coverage, six generated chunks, chunk balance, duplicate Lua keys,
  ranked-player count, and rankless-row guards.
- Added a release privacy audit that blocks maintainer-local paths, usernames,
  saved AddOns paths, credentials, and non-`coolstats` GitHub owners from the
  downloadable ZIP.
- Validated staged data before replacement and validated the copied live data
  addon again after replacement.

### Distribution

- Bumped all Rising Gods TOC metadata to `0.2.34-rg3`.
- Kept the bundled data refreshed at 10,075 active ranked players across the 13
  configured ICC-era encounters.

## 0.2.34-rg2 - 2026-07-24

### Rising Gods data

- Refreshed the Rising-Gods ICC profile from UwU Logs on 2026-07-24.
- Expanded the weekly ranked pull from 400 to 600 players per class/spec.
- Bundled 10,075 active ranked players across the 13 configured ICC-era
  encounters.
- Completed 390 bulk boss requests with 129,436 bundled boss rows, no failed
  requests, and no boss-only players added.
- Added a targeted post-bulk character-profile repair path and used it to
  restore Pentendo's complete available boss parse set.

### Updater safety

- Hardened bulk boss refreshes so a transient partial bulk response cannot
  shrink an already cached player's boss rows.
- Added tests for the cached-boss merge behavior and the Rising Gods weekly
  refresh defaults.

### Distribution

- Bumped all Rising Gods TOC metadata to `0.2.34-rg2`.

## 0.2.34-rg1 - 2026-07-24

### Core sync

- Ported the shared addon runtime from upstream coolstats `v0.2.34`.
- Added the Update Center, group version/data freshness checks, and browser
  toolbar Update button.
- Added the cached Statistics panel with specialization representation bars,
  boss-specific drilldown, tabard backgrounds, and bottom sum validation.
- Added the Boss DPS browser column when an individual boss filter is selected.
- Kept the restored Log Analysis geometry so the comparison chart does not
  overflow the analysis window.

### Rising Gods

- Replaced Warmane Armory actions with Rising Gods profile links using
  `https://db.rising-gods.de/?profile=eu.rising-gods.<character>`.
- Kept Rising Gods realm loading isolated to `coolstats_Data_RisingGods`.
- Preserved the Rising Gods cache diagnostics and `/coolstats cachedebug`
  helper while syncing the shared runtime.

### Rising Gods data

- Refreshed the Rising-Gods ICC profile from UwU Logs on 2026-07-24.
- Bundled 7,429 active ranked players across the 13 configured ICC-era
  encounters.
- Completed 390 bulk boss requests with 101,805 bundled boss rows, no failed
  requests, and no boss-only players added.

### Distribution

- Bumped all Rising Gods TOC metadata to `0.2.34-rg1`.
- Kept release packaging limited to `coolstats`, `coolstats_Cache`, and
  `coolstats_Data_RisingGods`.

## 0.2.29-rg1 - 2026-07-16

### Core sync

- Ported the shared addon runtime from upstream coolstats `v0.2.29`.
- Added the updated player-browser boss filter, individual boss sort mode, taller color-coded parse histogram, and connected distribution curve.
- Kept Rising Gods realm handling isolated to `coolstats_Data_RisingGods`.

### Rising Gods data

- Refreshed the Rising-Gods ICC profile from UwU Logs.
- Bundled 7,422 active ranked players across the 13 configured ICC-era encounters.
- Completed 390 bulk boss requests with 101,671 bundled boss rows and no failed leaderboard or boss refresh requests.

### Distribution

- Bumped all Rising Gods TOC metadata to `0.2.29-rg1`.
- Kept release packaging limited to `coolstats`, `coolstats_Cache`, and `coolstats_Data_RisingGods`.

## 0.2.26-rg2 - 2026-07-11

### Rising Gods cache

- Hardened cached gear/talent snapshots by actively requesting inspect data on hover, forcing inspect refreshes when opening cached talents, and using `INSPECT_READY` as a safe talent-capture fallback.
- Added immediate browser-row updates when a gear snapshot is written.
- Added `/coolstats cachedebug [player]` and a missing-cache-addon warning to help testers confirm whether `coolstats_Cache` is loaded and whether snapshots are being stored.

### Distribution

- Bumped all Rising Gods TOC metadata to `0.2.26-rg2`.

## 0.2.26-rg1 - 2026-07-11

### Core sync

- Ported the upstream 0.2.26 achievement-comparison fallback hardening so first-hover raid progress checks can load Blizzard_AchievementUI safely before comparing another player.
- Added Lua 5.1 validation to the Rising Gods package flow so Wrath-client syntax/chunk issues block release packaging.

### Rising Gods data

- Refreshed the Rising-Gods ICC profile while keeping the package ranked-player-only.
- Kept boss leaderboards restricted to enriching current ranked players; rankless boss-only rows remain excluded.

### Distribution

- Bumped all Rising Gods TOC metadata to `0.2.26-rg1`.
- Kept release packaging isolated to `coolstats`, `coolstats_Cache`, and `coolstats_Data_RisingGods`.

## 0.2.23-rg2 - 2026-07-08

### Rising Gods

- Rebuilt the Rising Gods release as a ranked-player-only package.
- Stopped bulk boss leaderboards from creating rankless boss-only player records.
- Disabled previous-player preservation for the Rising Gods ICC profile so old bloated JSON cannot re-expand the generated addon data.
- Added tests that reject rankless generated player rows and enforce the Rising-Gods-only data policy.

### Distribution

- Prepared the release for a clean GitHub repository owned and authored only by `coolstats`.
- Bumped all Rising Gods TOC metadata to `0.2.23-rg2`.

## 0.2.23-rg1 - 2026-07-06

### Rising Gods

- Created a sterile Rising Gods edition based on upstream coolstats 0.2.23.
- Added load-on-demand UwU Logs data for the `Rising-Gods` ICC realm.
- Added the ICC-era boss roster: ICC 25 heroic, Toravon, Halion, and Anub'arak.
- Kept every player's boss parses separated by specialization.
- Added fail-closed updater checks for ranking failures, missing encounters, and unexpectedly small datasets.

### Distribution

- Added Rising-Gods-only update, package, validation, and release-preparation scripts.
- Release validation rejects Warmane realm-data folders.
- Disabled Warmane Armory links on Rising Gods.

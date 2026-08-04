# Rising Gods Data Maintenance

UwU Logs data is generated outside the game and bundled as the load-on-demand
addon family rooted at `coolstats_Data_RisingGods`.

## Canonical identifiers

- UwU Logs server: `Rising-Gods`
- normalized realm key: `risinggods`
- active phase: `icc`
- data addon family: `coolstats_Data_RisingGods` plus
  `coolstats_Data_RisingGods_UWU_*`
- JSON/cache slug: `rising_gods`

`Rising-Gods`, `Rising Gods`, and `RisingGods` normalize to the same client key.

## Safety rules

1. Run `tools/update_rising_gods.ps1 -Mode Validate` before a full refresh.
2. A weekly refresh must abort on any ranking request failure.
3. A weekly refresh must abort if the active player count is unexpectedly small.
4. A full boss refresh must abort if a configured encounter returns no rows.
5. Boss records remain separated by specialization.
6. Boss leaderboards may enrich ranked players, but must not create rankless boss-only records.
7. Bulk boss refreshes must merge with existing cached boss rows so a partial
   bulk response cannot shrink a player's available boss parses.
8. Duplicate display names must be resolved against the UwU character endpoint
   so reused names do not merge old and current character records.
9. Use `-BossName <character>` with weekly refreshes when a specific player's
   UwU character page needs targeted boss-log repair after the bulk pull.
10. Generated Lua is committed; raw JSON and cache files remain local and ignored.
11. The release archive must contain only the core, cache, log-updater, and
    Rising Gods data addon family.
12. Never point these scripts at the Warmane repository or its release directory.
13. Generated player data is split into load-on-demand shard addons using a
    roughly 3,000-player target, a six-chunk minimum for normal release-sized
    data, and a 16-chunk ceiling. The TOC must include
    `X-coolstats-PlayerCount` and `X-coolstats-PlayerChunks` so the in-game
    load slider and release audits agree on what can be skipped after
    `/reload`.
14. Boss payloads are split into raid-layer shard addons aligned to the same
    player chunks. For Rising Gods ICC data, keep ICC, VOA, Ruby Sanctum, and
    TOGC layers enabled by default and validate all layer TOCs before release.
15. Lua 5.1 validation must pass before packaging or publishing a release.
16. GitHub publishing must target only `https://github.com/coolstats/coolstats-rising-gods.git`.
17. Commits, tags, releases, and uploaded assets must be associated only with `coolstats <coolstats@users.noreply.github.com>`.
18. After publishing, verify the GitHub contributors/sidebar data still reports only `coolstats`.

## Public data updater

`Update_Rising_Gods_Logs.bat` and `Update_Rising_Gods_Logs.sh` are the
community-facing entry points for local log refreshes. Windows uses
`tools/update_rising_gods_live_logs.ps1`; Linux/Bazzite/Ubuntu/SteamOS and other
distros can run the shell launcher with `bash`, which calls
`tools/update_rising_gods_live_logs.py`. Both paths reuse the same UwU updater
as official releases.

The public updater must stay auditable and data-only:

- keep it as readable `.bat`, `.sh`, `.ps1`, and `.py` source; do not replace it
  with a compiled executable unless there is a specific, reviewed need;
- do not request administrator rights, credentials, GitHub tokens, or Git
  publishing access;
- update only `coolstats_Data_RisingGods` and generated
  `coolstats_Data_RisingGods_UWU_*` shard folders in the user's live
  `Interface\AddOns` folder;
- check live `Interface\AddOns` write access before downloading new data, so
  protected Windows folders fail early with a clear message;
- back up the old live data addon family before replacement;
- validate generated Rising Gods metadata, encounter coverage, shard TOCs,
  ranked-player count, duplicate player keys, dynamic chunk metadata, chunk
  distribution, raid layers, and rankless-row guards before install;
- resolve duplicate display names against the UwU character endpoint and run
  automatic boss-row repair for affected players;
- validate the copied live data addon family again after replacement, and
  restore the backup if replacement fails;
- keep the shipped launchers/helper files free of maintainer-local paths,
  usernames, saved AddOns paths, credentials, and non-`coolstats` GitHub owners;
- run the release privacy audit before publishing any ZIP;
- run Lua 5.1 validation when `luac` is available, and make it required only for
  official release packaging;
- ship both launchers at the release ZIP root and the helper scripts in
  `coolstats_LogUpdater/tools/` so an extracted release can auto-detect its
  `Interface\AddOns` folder;
- install staged data through a temporary folder, then atomically replace the
  final data family folders.

## Commands

```powershell
.\tools\update_rising_gods.ps1 -Mode Validate
.\tools\update_rising_gods.ps1 -Mode Weekly
.\tools\update_rising_gods.ps1 -Mode Weekly -BossName Pentendo
.\Update_Rising_Gods_Logs.bat
.\Update_Rising_Gods_Logs.bat -NoInstall
bash ./Update_Rising_Gods_Logs.sh
bash ./Update_Rising_Gods_Logs.sh --no-install
.\tools\update_rising_gods_live_logs.ps1 -ValidateOnly
.\tools\update_rising_gods_live_logs.ps1 -NoInstall
python3 ./tools/update_rising_gods_live_logs.py --validate-only
.\tools\validate_lua51.ps1
.\tools\prepare_rising_gods_release.ps1 -Version 0.2.38-rg1
```

Generated runtime data:

```text
realm_data/coolstats_Data_RisingGods/data/logs/icc/
realm_data/coolstats_Data_RisingGods_UWU_*/data/logs/icc/
```

Local ignored maintenance data:

```text
data/uwu_logs_rising_gods.json
data/uwu_character_boss_cache_rising_gods.json
```

## Release naming

- Tag releases as `v<version>`, for example `v0.2.38-rg1`.
- Title GitHub Releases as `coolstats Rising Gods <version>`.
- Upload `coolstats_rising_gods_<version>.zip` as the release asset.
- Do not use Warmane release assets, Warmane realm-data folders, or Warmane
  generated JSON/cache files in this repository.

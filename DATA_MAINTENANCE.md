# Rising Gods Data Maintenance

UwU Logs data is generated outside the game and bundled as the load-on-demand
addon `coolstats_Data_RisingGods`.

## Canonical identifiers

- UwU Logs server: `Rising-Gods`
- normalized realm key: `risinggods`
- active phase: `icc`
- data addon: `coolstats_Data_RisingGods`
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
8. Use `-BossName <character>` with weekly refreshes when a specific player's
   UwU character page needs targeted boss-log repair after the bulk pull.
9. Generated Lua is committed; raw JSON and cache files remain local and ignored.
10. The release archive must contain only the core, cache, and Rising Gods data addons.
11. Never point these scripts at the Warmane repository or its release directory.
12. Generated player data is split into six Lua chunks to keep individual files conservative for the 3.3.5 client.
13. Lua 5.1 validation must pass before packaging or publishing a release.
14. GitHub publishing must target only `https://github.com/coolstats/coolstats-rising-gods.git`.
15. Commits, tags, releases, and uploaded assets must be associated only with `coolstats <coolstats@users.noreply.github.com>`.
16. After publishing, verify the GitHub contributors/sidebar data still reports only `coolstats`.

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
- update only `coolstats_Data_RisingGods` in the user's live `Interface\AddOns`
  folder;
- back up the old live data addon before replacement;
- validate generated Rising Gods metadata, encounter coverage, ranked-player
  count, duplicate player keys, chunk distribution, and rankless-row guards
  before install;
- validate the copied live data addon again after replacement, and restore the
  backup if replacement fails;
- keep the shipped launchers/helper files free of maintainer-local paths,
  usernames, saved AddOns paths, credentials, and non-`coolstats` GitHub owners;
- run the release privacy audit before publishing any ZIP;
- run Lua 5.1 validation when `luac` is available, and make it required only for
  official release packaging.
- ship both launchers at the release ZIP root and the helper scripts in
  `coolstats_LogUpdater/tools/` so an extracted release can auto-detect its
  `Interface\AddOns` folder.

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
.\tools\prepare_rising_gods_release.ps1 -Version 0.2.34-rg4
```

Generated runtime data:

```text
realm_data/coolstats_Data_RisingGods/data/logs/icc/
```

Local ignored maintenance data:

```text
data/uwu_logs_rising_gods.json
data/uwu_character_boss_cache_rising_gods.json
```

## Release naming

- Tag releases as `v<version>`, for example `v0.2.34-rg2`.
- Title GitHub Releases as `coolstats Rising Gods <version>`.
- Upload `coolstats_rising_gods_<version>.zip` as the release asset.
- Do not use Warmane release assets, Warmane realm-data folders, or Warmane
  generated JSON/cache files in this repository.

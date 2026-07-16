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
7. Generated Lua is committed; raw JSON and cache files remain local and ignored.
8. The release archive must contain only the core, cache, and Rising Gods data addons.
9. Never point these scripts at the Warmane repository or its release directory.
10. Generated player data is split into six Lua chunks to keep individual files conservative for the 3.3.5 client.
11. Lua 5.1 validation must pass before packaging or publishing a release.
12. GitHub publishing must target only `https://github.com/coolstats/coolstats-rising-gods.git`.
13. Commits, tags, releases, and uploaded assets must be associated only with `coolstats <coolstats@users.noreply.github.com>`.
14. After publishing, verify the GitHub contributors/sidebar data still reports only `coolstats`.

## Commands

```powershell
.\tools\update_rising_gods.ps1 -Mode Validate
.\tools\update_rising_gods.ps1 -Mode Weekly
.\tools\validate_lua51.ps1
.\tools\prepare_rising_gods_release.ps1 -Version 0.2.29-rg1
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

- Tag releases as `v<version>`, for example `v0.2.29-rg1`.
- Title GitHub Releases as `coolstats Rising Gods <version>`.
- Upload `coolstats_rising_gods_<version>.zip` as the release asset.
- Do not use Warmane release assets, Warmane realm-data folders, or Warmane
  generated JSON/cache files in this repository.

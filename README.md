# coolstats — Rising Gods

Rising Gods edition of coolstats for World of Warcraft 3.3.5a.

This repository is distributed separately from the Warmane edition. Its release
archive contains only:

```text
coolstats/
coolstats_Cache/
coolstats_Data_RisingGods/
```

The core is based on upstream coolstats `v0.2.26`, while realm data, maintenance
scripts, releases, and GitHub history are maintained independently here.

## Features

- UwU Logs scores, rankings, and specialization-specific boss parses in game.
- Ranked-player-only bundled data; boss leaderboards enrich ranked players but do not add rankless boss-only records.
- ICC-era coverage for ICC 25 heroic, Toravon, Halion, and Anub'arak.
- Searchable player browser with class/spec filters and favourites.
- Direct player-log links through compact `[coolstats: Player]` chat tokens.
- Cached gear and talent inspection.
- Optional character-panel enhancements and loot alerts.

The game addon performs no web requests. UwU Logs data is generated outside the
game and bundled into each release.

## Installation

1. Download `coolstats_rising_gods_<version>.zip` from this repository's releases.
2. Extract all three addon folders into `Interface/AddOns`.
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

# Refresh rankings and every configured boss leaderboard.
# The generated package stays limited to ranked players.
.\tools\update_rising_gods.ps1 -Mode Weekly

# Test, validate, package, and verify a release.
.\tools\prepare_rising_gods_release.ps1 -Version 0.2.26-rg1
```

See [DATA_MAINTENANCE.md](DATA_MAINTENANCE.md) for safety rules.

## Upstream

General core improvements may be synchronized from
[`coolstats/coolstats`](https://github.com/coolstats/coolstats), but Rising Gods
data and release automation remain isolated in this repository.

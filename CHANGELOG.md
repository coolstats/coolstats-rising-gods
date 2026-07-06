# Changelog

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

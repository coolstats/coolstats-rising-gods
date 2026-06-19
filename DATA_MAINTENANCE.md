# Realm Data Maintenance

The in-game addon never makes web requests. Realm datasets are generated
outside the game and bundled into releases.

## Realm Profiles

- **Onyxia:** Ulduar and Emalon.
- **Icecrown:** Icecrown Citadel, Toravon, Halion, and Anub'arak.
- **Lordaeron:** Icecrown Citadel, Toravon, Halion, and Anub'arak.

Onyxia, Icecrown, and Lordaeron data is generated as separate load-on-demand addons.
Only the dataset matching the player's current realm is loaded in-game.

## Dataset Updates

Realm datasets are curated outside the public addon repository and shipped as
generated Lua data in tagged releases.

Weekly releases refresh the top 400 players per class/spec and all configured
boss leaderboards for Onyxia, Icecrown, and Lordaeron.

Generated load-on-demand addons are written to:

```text
coolstats/realm_data/coolstats_Data_Icecrown/
coolstats/realm_data/coolstats_Data_Lordaeron/
coolstats/realm_data/coolstats_Data_Onyxia/
```

The private data pipeline refuses to overwrite output when:

- A weekly class/spec rankings request fails.
- The fresh active-player count is below the minimum.
- An entire configured boss leaderboard produces no rows.

The release packaging script lifts realm data addons out of `realm_data` and
places them beside the core `coolstats` addon inside the install-ready ZIP.

# Changelog

## 0.2.22 - 2026-07-05

### Onyxia logs

- Refreshed Onyxia's Phase 3 rankings and all five TOGC 25H boss leaderboards plus Koralon.
- Retained Phase 2 overall rankings and Algalon as historical indicators.
- Preserve retained Algalon parses when a player's current TOGC best specialization differs from their historical Ulduar specialization.
- Disabled TOGC achievement/statistics fallback because Warmane cross-credits some 10H progress into the 25H client data.
- Show one honest TOGC logs row, including an empty `0/5` row when no verified TOGC logs exist.

### Log links

- Added compact `[coolstats: Player]` chat tokens from browser rows, browser actions, and UwU Logs panel titles.
- Convert received tokens into clickable UwU Logs links for players running version 0.2.22 or later.
- Keep shared tokens short and readable for players without a compatible coolstats version.

### Interface and stability

- Made Phase 3 and Phase 2 browser labels specific to Onyxia's TOGC phase.
- Fixed achievement comparison cleanup so closing Blizzard's comparison UI no longer leaves tooltips permanently stuck on "Achievement UI busy" or reuses stale player statistics.
- Colored player/specialization titles and specialization rows in UwU Logs panels with the player's class color.

## 0.2.21 - 2026-07-05

### Onyxia Phase 3

- Activated Trial of the Grand Crusader as Onyxia's current logs phase.
- Added the five 25-player heroic TOGC encounters and Koralon.
- Retained Algalon as the single historical boss indicator from Phase 2.
- Removed the deprecated Ulduar boss rows from the shipped Onyxia dataset.
- Left Onyxia's Lair out until it appears in the official player logs.

### Rankings and player browser

- Preserved Phase 2 overall parse scores and ranks separately from current data.
- Added a Phase 2 Overall row to player tooltips and logs panels.
- Made Phase 3 parse, rank, and specialization data the primary player-browser values.
- Added a sortable P2 Overall browser column containing the historical parse and rank.
- Added separate Phase 3 ranked-player and Phase 2 history counts.
- Prevented historical-only Ulduar results from appearing as current TOGC rankings.

### Stability

- Fixed the Wrath Lua 5.1 local-variable limit regression that prevented the tooltip module, player browser, and related features from loading.
- Added phase-transition validation for the retained history schema and boss roster.

## 0.2.20 - 2026-06-28

- Refreshed the bundled Onyxia, Icecrown, and Lordaeron logs datasets.
- Added preparation for Onyxia's TOGC phase transition.

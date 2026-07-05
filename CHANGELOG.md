# Changelog

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

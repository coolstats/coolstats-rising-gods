import importlib.util
import re
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).parents[1]
MODULE_PATH = Path(__file__).with_name("update_uwu_logs.py")
SPEC = importlib.util.spec_from_file_location("update_uwu_logs", MODULE_PATH)
uwu = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(uwu)


def player(name="Example", class_i=3, spec_i=2, score=9000, bosses=None):
    bosses = bosses or {}
    return {
        "name": name,
        "class_i": class_i,
        "best_spec_i": spec_i,
        "score_centi": score,
        "raw_points": 0,
        "spec_rank": 10,
        "specs": {spec_i: score},
        "spec_ranks": {spec_i: 10},
        "bosses": dict(bosses),
        "spec_bosses": {spec_i: dict(bosses)},
        "phase_history": {},
        "active": True,
    }


class RisingGodsTests(unittest.TestCase):
    def setUp(self):
        self.profile = uwu.configure_realm_profile("Rising-Gods", "icc")

    def test_repository_supports_only_rising_gods(self):
        self.assertEqual(set(uwu.REALM_PHASE_PROFILES), {"risinggods"})
        self.assertEqual(set(uwu.REALM_DEFAULT_PHASES), {"risinggods"})
        self.assertEqual(self.profile["addon_name"], "coolstats_Data_RisingGods")
        self.assertEqual(self.profile["data_slug"], "rising_gods")
        self.assertNotIn("retained_boss_lock", self.profile)

    def test_server_aliases_resolve_to_the_same_profile(self):
        for server in ("Rising-Gods", "Rising Gods", "RisingGods"):
            profile = uwu.configure_realm_profile(server)
            self.assertEqual(profile["phase_id"], "icc")

    def test_icc_era_roster(self):
        self.assertEqual(
            uwu.BOSS_ORDER,
            [
                "Lord Marrowgar",
                "Lady Deathwhisper",
                "Deathbringer Saurfang",
                "Festergut",
                "Rotface",
                "Professor Putricide",
                "Blood Prince Council",
                "Blood-Queen Lana'thel",
                "Sindragosa",
                "The Lich King",
                "Toravon the Ice Watcher",
                "Halion",
                "Anub'arak",
            ],
        )

    def test_default_paths_stay_inside_rising_gods_addon(self):
        lua_path = uwu.default_lua_path("Rising-Gods", self.profile)
        json_path = uwu.default_json_path("Rising-Gods", self.profile)
        cache_path = uwu.default_boss_cache_path("Rising-Gods", self.profile)
        self.assertIn("coolstats_Data_RisingGods", str(lua_path))
        self.assertEqual(json_path.name, "uwu_logs_rising_gods.json")
        self.assertEqual(json_path.parent.name, "data")
        self.assertEqual(cache_path.name, "uwu_character_boss_cache_rising_gods.json")
        self.assertEqual(cache_path.parent.name, "data")

    def test_default_boss_data_never_combines_specializations(self):
        current = player(
            bosses={
                "Lord Marrowgar": {"score_centi": 8000},
                "Festergut": {"score_centi": 8500},
            }
        )
        current["spec_bosses"][1] = {
            "Lord Marrowgar": {"score_centi": 9500},
            "The Lich King": {"score_centi": 7000},
        }
        aggregate = uwu.coherent_player_bosses(current)
        self.assertEqual(aggregate, current["spec_bosses"][2])
        self.assertNotIn("The Lich King", aggregate)

    def test_boss_leaderboards_do_not_create_rankless_players_by_default(self):
        rows = [[None, 100, "guid-1", "BossOnly", 1000, None]]
        updates, names, raid_rows, unique_rows = uwu.build_top_boss_updates(rows, {}, 10)
        self.assertEqual(updates, {})
        self.assertEqual(names, {})
        self.assertEqual(raid_rows, 1)
        self.assertEqual(unique_rows, 1)

    def test_boss_leaderboards_enrich_ranked_players_only(self):
        rows = [
            [None, 100, "guid-1", "RankedOne", 1000, None],
            [None, 100, "guid-2", "BossOnly", 900, None],
        ]
        updates, names, _, _ = uwu.build_top_boss_updates(
            rows,
            {"rankedone": "rankedone"},
            10,
        )
        self.assertEqual(set(updates), {"rankedone"})
        self.assertEqual(names, {"rankedone": "RankedOne"})

    def test_bulk_boss_merge_keeps_cached_rows_when_refresh_is_partial(self):
        current = player(name="Pentendo", class_i=3, spec_i=2, score=9619)
        refreshed = {
            2: {
                "Lord Marrowgar": {
                    "score_centi": 9951,
                    "rank_players": 50,
                    "rank_raids": 129,
                    "dps": 22459.53,
                }
            }
        }
        cache_entries = {
            "pentendo:2": {
                "name": "Pentendo",
                "spec_i": 2,
                "bosses": {
                    "Lord Marrowgar": {
                        "score_centi": 9000,
                        "rank_players": 100,
                        "rank_raids": 300,
                        "dps": 20000,
                    },
                    "The Lich King": {
                        "score_centi": 9745,
                        "rank_players": 67,
                        "rank_raids": 283,
                        "dps": 15565.86,
                    },
                },
            }
        }
        merged = uwu.merge_cached_spec_bosses(current, refreshed, cache_entries)
        self.assertEqual(merged[2]["Lord Marrowgar"]["score_centi"], 9951)
        self.assertEqual(merged[2]["The Lich King"]["score_centi"], 9745)

    def test_rising_gods_profile_is_ranked_player_only(self):
        profile = uwu.configure_realm_profile("Rising-Gods", "icc")
        self.assertIs(profile["preserve_previous_players"], False)
        self.assertIs(profile["include_boss_only_players"], False)

    def test_generated_release_data_contains_only_ranked_players(self):
        chunks = "".join(
            chunk.read_text(encoding="utf-8")
            for chunk in sorted((REPOSITORY_ROOT / "realm_data" / "coolstats_Data_RisingGods" / "data" / "logs" / "icc").glob("coolstats_uwu_data_*.lua"))
        )
        player_rows = re.findall(r'^\s+\["[^"]+"\]\s=', chunks, flags=re.MULTILINE)
        self.assertLess(len(player_rows), 12000)
        self.assertNotRegex(chunks, r'", 0, \d+, \d+, nil,')

    def test_loader_and_ui_are_rising_gods_specific(self):
        loader = (REPOSITORY_ROOT / "coolstats_data_loader.lua").read_text(encoding="utf-8")
        tooltip = (REPOSITORY_ROOT / "coolstats_tooltip.lua").read_text(encoding="utf-8")
        core = (REPOSITORY_ROOT / "coolstats.lua").read_text(encoding="utf-8")
        self.assertIn('risinggods = "coolstats_Data_RisingGods"', loader)
        self.assertNotIn('onyxia = "coolstats_Data_Onyxia"', loader)
        self.assertIn('risinggods = "Rising-Gods"', tooltip)
        self.assertIn('https://db.rising-gods.de/?profile=eu.rising-gods.', tooltip)
        self.assertNotIn("armory.warmane.com", tooltip)
        self.assertNotIn("Warmane Armory", tooltip)
        self.assertIn("GetCachedPlayerBrowserWarmaneArmoryUrl(name)", tooltip)
        self.assertIn("coolstats/coolstats-rising-gods/releases/latest", core)
        self.assertNotIn("warperia.com/addon-wotlk/coolstats", core)

    def test_release_script_has_a_strict_realm_allowlist(self):
        package_script = (
            REPOSITORY_ROOT / "tools" / "package_rising_gods_release.ps1"
        ).read_text(encoding="utf-8")
        self.assertIn('$expectedRealmAddonName = "coolstats_Data_RisingGods"', package_script)
        self.assertIn("Refusing to package non-Rising-Gods realm data", package_script)
        self.assertIn("coolstats_rising_gods_{0}.zip", package_script)

    def test_weekly_script_expands_coverage_and_supports_targeted_boss_repair(self):
        update_script = (
            REPOSITORY_ROOT / "tools" / "update_rising_gods.ps1"
        ).read_text(encoding="utf-8")
        updater = (REPOSITORY_ROOT / "tools" / "update_uwu_logs.py").read_text(encoding="utf-8")
        self.assertIn("[int]$MaxPerSpec = 600", update_script)
        self.assertIn("DEFAULT_MAX_PER_SPEC = 600", updater)
        self.assertIn("[string[]]$BossName", update_script)
        self.assertIn('"--boss-name"', update_script)
        self.assertIn("targeted character boss repair after bulk mode", updater)
        self.assertNotIn("boss-name is only used by --character-bosses", updater)

    def test_warmane_realm_directories_are_absent(self):
        realm_root = REPOSITORY_ROOT / "realm_data"
        self.assertFalse((realm_root / "coolstats_Data_Onyxia").exists())
        self.assertFalse((realm_root / "coolstats_Data_Icecrown").exists())
        self.assertFalse((realm_root / "coolstats_Data_Lordaeron").exists())


if __name__ == "__main__":
    unittest.main()

import importlib.util
import os
import re
import shutil
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).parents[1]
MODULE_PATH = Path(__file__).with_name("update_uwu_logs.py")
SPEC = importlib.util.spec_from_file_location("update_uwu_logs", MODULE_PATH)
uwu = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(uwu)

AUDIT_MODULE_PATH = Path(__file__).with_name("test_rising_gods_data_integrity.py")
AUDIT_SPEC = importlib.util.spec_from_file_location(
    "rising_gods_data_integrity_audit",
    AUDIT_MODULE_PATH,
)
audit = importlib.util.module_from_spec(AUDIT_SPEC)
AUDIT_SPEC.loader.exec_module(audit)


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

    def test_public_log_updater_is_auditable_and_data_only(self):
        launcher = (REPOSITORY_ROOT / "Update_Rising_Gods_Logs.bat").read_text(encoding="utf-8")
        shell_launcher = (REPOSITORY_ROOT / "Update_Rising_Gods_Logs.sh").read_text(encoding="utf-8")
        live_updater = (
            REPOSITORY_ROOT / "tools" / "update_rising_gods_live_logs.ps1"
        ).read_text(encoding="utf-8")
        linux_updater = (
            REPOSITORY_ROOT / "tools" / "update_rising_gods_live_logs.py"
        ).read_text(encoding="utf-8")
        self.assertIn("update_rising_gods_live_logs.ps1", launcher)
        self.assertIn("update_rising_gods_live_logs.py", shell_launcher)
        self.assertIn("coolstats_Data_RisingGods", launcher)
        self.assertIn("coolstats_Data_RisingGods", shell_launcher)
        self.assertIn("Windows / PowerShell launcher", launcher)
        self.assertIn("Linux / Bash launcher", shell_launcher)
        self.assertIn("confirmation screen", launcher)
        self.assertIn("confirmation screen", shell_launcher)
        self.assertIn("Preparing updater", launcher)
        self.assertIn("Preparing updater", shell_launcher)
        self.assertIn("Choose update mode", launcher)
        self.assertIn("Choose update mode", shell_launcher)
        self.assertIn("Update this working folder only", launcher)
        self.assertIn("Update this working folder only", shell_launcher)
        self.assertIn("-NoInstall", launcher)
        self.assertIn("--no-install", shell_launcher)
        self.assertIn("-ValidateOnly", launcher)
        self.assertIn("--validate-only", shell_launcher)
        self.assertIn("python3", shell_launcher)
        self.assertIn("COOLSTATS_PYTHON", shell_launcher)
        self.assertIn("Get-RunStepLabels", live_updater)
        self.assertIn("Write-Progress", live_updater)
        self.assertIn("Confirm-UpdatePlan", live_updater)
        self.assertIn("Checking live AddOns write access", live_updater)
        self.assertIn("Assert-AddOnsWriteAccess", live_updater)
        self.assertIn("Windows denied write access", live_updater)
        self.assertIn("Checking live AddOns write access", linux_updater)
        self.assertIn("assert_addons_write_access", linux_updater)
        self.assertIn("is not writable", linux_updater)
        self.assertIn("c o o l s t a t s", live_updater)
        self.assertIn("c o o l s t a t s", linux_updater)
        self.assertIn("Rising Gods logs", live_updater)
        self.assertIn("Rising Gods logs", linux_updater)
        self.assertIn("Get-UpdaterLayout", live_updater)
        self.assertIn("detect_layout", linux_updater)
        self.assertIn("Kind = \"Installed\"", live_updater)
        self.assertIn('kind="Installed"', linux_updater)
        self.assertIn("Using this release folder as AddOns path", live_updater)
        self.assertIn("Using this release folder as AddOns path", linux_updater)
        self.assertIn("coolstats_LogUpdater", launcher)
        self.assertIn("coolstats_LogUpdater", shell_launcher)
        self.assertIn("Release install detected", launcher)
        self.assertIn("Release install detected", shell_launcher)
        self.assertIn("Continue with this update? Type Y to start", live_updater)
        self.assertIn("Continue with this update? Type Y to start", linux_updater)
        self.assertIn('-Mode "Validate"', live_updater)
        self.assertIn('-Mode "Weekly"', live_updater)
        self.assertIn('mode="Validate"', linux_updater)
        self.assertIn('mode="Weekly"', linux_updater)
        self.assertIn("coolstats_Data_RisingGods", live_updater)
        self.assertIn("coolstats_Data_RisingGods", linux_updater)
        self.assertIn("Backed up old data addon", live_updater)
        self.assertIn("Backed up old data addon", linux_updater)
        self.assertIn("ValidateOnly", live_updater)
        self.assertIn("validate-only", linux_updater)
        self.assertIn("Resolve-OptionalLuac51Path", live_updater)
        self.assertIn("resolve_luac", linux_updater)
        self.assertIn("Lua 5.1 validation failed; refusing to install generated data", live_updater)
        self.assertIn("Lua 5.1 validation failed", linux_updater)
        self.assertIn("Assert-RisingGodsDataAddonShape", live_updater)
        self.assertIn("Invoke-RisingGodsDataIntegrityAudit", live_updater)
        self.assertIn("audit_data_addon", linux_updater)
        self.assertIn("test_rising_gods_data_integrity.ps1", live_updater)
        self.assertIn("test_rising_gods_data_integrity.py", linux_updater)
        self.assertIn("AllowTemporaryFolderName", live_updater)
        self.assertIn("allow_temporary_folder_name=True", linux_updater)
        self.assertIn("rankless player rows", live_updater)
        self.assertIn("Refusing to update from a workspace containing non-Rising-Gods realm data", live_updater)
        self.assertIn("Refusing to update from a workspace containing non-Rising-Gods realm data", linux_updater)
        self.assertNotIn("coolstats_Data_Onyxia", live_updater)
        self.assertNotIn("coolstats_Data_Onyxia", linux_updater)
        self.assertNotIn("C:\\", launcher)
        self.assertNotIn("C:\\", shell_launcher)
        self.assertNotIn("C:\\", live_updater)
        self.assertNotIn("C:\\", linux_updater)
        self.assertNotIn("D:\\", launcher)
        self.assertNotIn("D:\\", shell_launcher)
        self.assertNotIn("D:\\", live_updater)
        self.assertNotIn("D:\\", linux_updater)
        self.assertNotIn("/Users/", shell_launcher)
        self.assertNotIn("/Users/", linux_updater)
        self.assertNotIn("/home/", shell_launcher)
        self.assertNotIn("/home/", linux_updater)
        forbidden_fragments = (
            "Invoke-Expression",
            "iex ",
            "Start-Process",
            "Add-MpPreference",
            "Set-ExecutionPolicy",
            "git push",
        )
        for fragment in forbidden_fragments:
            self.assertNotIn(fragment, live_updater)
            self.assertNotIn(fragment, linux_updater)

    def test_release_package_ships_public_log_updater(self):
        package_script = (
            REPOSITORY_ROOT / "tools" / "package_rising_gods_release.ps1"
        ).read_text(encoding="utf-8")
        validator = (
            REPOSITORY_ROOT / "tools" / "validate_rising_gods_release.ps1"
        ).read_text(encoding="utf-8")
        wrapper = (REPOSITORY_ROOT / "tools" / "update_rising_gods.ps1").read_text(encoding="utf-8")
        updater = (REPOSITORY_ROOT / "tools" / "update_uwu_logs.py").read_text(encoding="utf-8")
        lua_validator = (
            REPOSITORY_ROOT / "tools" / "validate_lua51.ps1"
        ).read_text(encoding="utf-8")
        self.assertIn("Update_Rising_Gods_Logs.bat", package_script)
        self.assertIn("Update_Rising_Gods_Logs.sh", package_script)
        self.assertIn("coolstats_LogUpdater\\tools", package_script)
        self.assertIn("update_rising_gods_live_logs.ps1", package_script)
        self.assertIn("update_rising_gods_live_logs.py", package_script)
        self.assertIn("update_uwu_logs.py", package_script)
        self.assertIn("test_rising_gods_data_integrity.ps1", package_script)
        self.assertIn("test_rising_gods_data_integrity.py", package_script)
        self.assertIn("coolstats_LogUpdater", validator)
        self.assertIn("Missing public updater launcher", validator)
        self.assertIn("Update_Rising_Gods_Logs.sh", validator)
        self.assertIn("test_rising_gods_data_integrity.ps1", validator)
        self.assertIn("test_rising_gods_data_integrity.py", validator)
        self.assertIn("test_release_privacy.ps1", validator)
        self.assertIn("ExpectedMaxPerSpec 600", validator)
        self.assertIn("AllowInstalledLayout", wrapper)
        self.assertIn("--lua-output", wrapper)
        self.assertIn("--json-output", wrapper)
        self.assertIn("--boss-cache", wrapper)
        self.assertIn("--addon-version", wrapper)
        self.assertIn("ADDON_VERSION_OVERRIDE", updater)
        self.assertNotIn("C:\\", lua_validator)

    def test_release_privacy_audit_blocks_local_traces(self):
        privacy = (
            REPOSITORY_ROOT / "tools" / "test_release_privacy.ps1"
        ).read_text(encoding="utf-8")
        self.assertIn("absolute Windows drive path", privacy)
        self.assertIn("Windows user profile path", privacy)
        self.assertIn("local machine fragment", privacy)
        self.assertIn("github\\.com/(?!coolstats/)", privacy)
        self.assertIn('".sh" = $true', privacy)
        username = os.environ.get("USERNAME", "")
        if len(username) > 2:
            self.assertNotIn(username, privacy)

    def test_data_integrity_audit_guards_generated_tranches(self):
        audit = (
            REPOSITORY_ROOT / "tools" / "test_rising_gods_data_integrity.ps1"
        ).read_text(encoding="utf-8")
        python_audit = (
            REPOSITORY_ROOT / "tools" / "test_rising_gods_data_integrity.py"
        ).read_text(encoding="utf-8")
        self.assertIn("ExpectedChunkCount = 6", audit)
        self.assertIn("expected_chunk_count: int = 6", python_audit)
        self.assertIn("AllowTemporaryFolderName", audit)
        self.assertIn("allow_temporary_folder_name", python_audit)
        self.assertIn("Duplicate player key across chunks", audit)
        self.assertIn("Duplicate player key across chunks", python_audit)
        self.assertIn("Generated data chunks are not balanced", audit)
        self.assertIn("Generated data chunks are not balanced", python_audit)
        self.assertIn("rankless player rows", audit)
        self.assertIn("rankless player rows", python_audit)
        self.assertIn("coolstats_Data_RisingGods", audit)
        self.assertIn("coolstats_Data_RisingGods", python_audit)
        self.assertIn("maxPerSpec", audit)
        self.assertIn("maxPerSpec", python_audit)
        self.assertIn("Rising-Gods", audit)
        self.assertIn("Rising-Gods", python_audit)
        self.assertIn("Anub'arak", audit)
        self.assertIn("Anub'arak", python_audit)
        self.assertIn("Unexpected non-addon files", audit)
        self.assertIn("Unexpected non-addon files", python_audit)
        self.assertNotIn("coolstats_Data_Onyxia", audit)
        self.assertNotIn("coolstats_Data_Onyxia", python_audit)

    def test_python_data_integrity_audit_allows_installer_temp_folder_only_when_requested(self):
        source = REPOSITORY_ROOT / "realm_data" / "coolstats_Data_RisingGods"
        with tempfile.TemporaryDirectory() as temp_root:
            staged = Path(temp_root) / "coolstats_Data_RisingGods.__coolstats_update_tmp_123"
            shutil.copytree(source, staged)
            with self.assertRaisesRegex(RuntimeError, "must be named coolstats_Data_RisingGods"):
                audit.audit_data_addon(
                    staged,
                    expected_version="0.2.34-rg5",
                    expected_max_per_spec=600,
                    quiet=True,
                )
            result = audit.audit_data_addon(
                staged,
                expected_version="0.2.34-rg5",
                expected_max_per_spec=600,
                allow_temporary_folder_name=True,
                quiet=True,
            )
            self.assertEqual(result["players"], 10075)

    def test_warmane_realm_directories_are_absent(self):
        realm_root = REPOSITORY_ROOT / "realm_data"
        self.assertFalse((realm_root / "coolstats_Data_Onyxia").exists())
        self.assertFalse((realm_root / "coolstats_Data_Icecrown").exists())
        self.assertFalse((realm_root / "coolstats_Data_Lordaeron").exists())


if __name__ == "__main__":
    unittest.main()

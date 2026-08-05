#!/usr/bin/env python3
"""Cross-platform public updater for Rising Gods log data.

This is used by Update_Rising_Gods_Logs.sh for Linux/BSD-like environments and
does not require PowerShell. It updates only the Rising Gods data addon family.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

from test_rising_gods_data_integrity import audit_data_addon


DATA_ADDON_NAME = "coolstats_Data_RisingGods"
DATA_ADDON_SHARD_PREFIX = DATA_ADDON_NAME + "_UWU_"
JSON_NAME = "uwu_logs_rising_gods.json"
BOSS_CACHE_NAME = "uwu_character_boss_cache_rising_gods.json"


@dataclass(frozen=True)
class Layout:
    kind: str
    root: Path
    addons_root: Optional[Path]
    core_toc: Path
    live_data_addon: Path
    work_data_addon: Path
    json_output: Path
    boss_cache: Path


class UpdaterError(RuntimeError):
    pass


class Ui:
    def __init__(self, steps: List[str]) -> None:
        self.steps = steps
        self.index = 0

    @staticmethod
    def progress_bar(percent: int, width: int = 28) -> str:
        filled = max(0, min(width, int(percent / 100 * width)))
        return "[" + ("#" * filled) + ("-" * (width - filled)) + "]"

    def header(self) -> None:
        print()
        print("============================================================")
        print("                  c o o l s t a t s")
        print("                  Rising Gods logs")
        print("============================================================")
        print(f" Data-only updater for {DATA_ADDON_NAME} and its shards")
        print(" Duplicate-name safeguards and boss repairs are automatic.")
        print(" No admin rights, no credentials, no GitHub publishing.")
        print()

    def step(self, message: str) -> None:
        self.index += 1
        if self.index > len(self.steps):
            self.index = len(self.steps)
        percent = int(((self.index - 1) / max(len(self.steps), 1)) * 100)
        print()
        print(f"[{self.index}/{len(self.steps)}] {self.progress_bar(percent)} {percent}%")
        print(message)

    def complete(self, message: str) -> None:
        print()
        print(f"[{max(len(self.steps), 1)}/{max(len(self.steps), 1)}] {self.progress_bar(100)} 100%")
        print(message)


def run_step_labels(validate_only: bool, skip_api_validation: bool, no_install: bool) -> List[str]:
    steps = ["Check updater files"]
    if validate_only:
        return steps + ["Validate existing generated data", "Finish"]
    steps.append("Confirm update plan")
    if not skip_api_validation:
        steps.append("Validate UwU profile")
    if not no_install:
        steps.append("Check live AddOns write access")
    steps.extend(["Download UwU logs and rebuild data", "Validate generated data"])
    steps.append("Finish local refresh" if no_install else "Install live data addon shards")
    steps.append("Finish")
    return steps


def get_toc_version(toc_path: Path) -> str:
    if not toc_path.is_file():
        return ""
    for line in toc_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## Version:"):
            return line.split(":", 1)[1].strip()
    return ""


def detect_layout() -> Layout:
    script_dir = Path(__file__).resolve().parent
    root = script_dir.parent
    source_data_addon = root / "realm_data" / DATA_ADDON_NAME
    source_updater = root / "tools" / "update_uwu_logs.py"
    source_audit = root / "tools" / "test_rising_gods_data_integrity.py"

    if (root / "coolstats.toc").is_file() and source_data_addon.is_dir() and source_updater.is_file() and source_audit.is_file():
        return Layout(
            kind="Source",
            root=root,
            addons_root=None,
            core_toc=root / "coolstats.toc",
            live_data_addon=source_data_addon,
            work_data_addon=source_data_addon,
            json_output=root / "data" / JSON_NAME,
            boss_cache=root / "data" / BOSS_CACHE_NAME,
        )

    addons_root = root.parent
    installed_core_toc = addons_root / "coolstats" / "coolstats.toc"
    installed_data_addon = addons_root / DATA_ADDON_NAME
    installed_updater = root / "tools" / "update_uwu_logs.py"
    installed_audit = root / "tools" / "test_rising_gods_data_integrity.py"
    if installed_core_toc.is_file() and installed_data_addon.is_dir() and installed_updater.is_file() and installed_audit.is_file():
        return Layout(
            kind="Installed",
            root=root,
            addons_root=addons_root,
            core_toc=installed_core_toc,
            live_data_addon=installed_data_addon,
            work_data_addon=root / "work" / DATA_ADDON_NAME,
            json_output=root / "data" / JSON_NAME,
            boss_cache=root / "data" / BOSS_CACHE_NAME,
        )

    raise UpdaterError("Could not identify updater layout. Run from the source repository or from an extracted release inside Interface/AddOns.")


def assert_updater_layout(layout: Layout) -> None:
    required = [
        "tools/update_uwu_logs.py",
        "tools/test_rising_gods_data_integrity.py",
    ]
    for relative in required:
        path = layout.root / relative
        if not path.is_file():
            raise UpdaterError(f"Missing required Rising Gods file: {relative}")
    if not layout.core_toc.is_file():
        raise UpdaterError(f"Missing coolstats core TOC: {layout.core_toc}")
    if not layout.live_data_addon.is_dir():
        raise UpdaterError(f"Missing Rising Gods data addon: {layout.live_data_addon}")
    if layout.kind == "Source":
        realm_root = layout.root / "realm_data"
        unexpected = [
            path.name
            for path in realm_root.glob("coolstats_Data_*")
            if path.is_dir() and not is_data_family_name(path.name)
        ]
        if unexpected:
            raise UpdaterError("Refusing to update from a workspace containing non-Rising-Gods realm data: " + ", ".join(unexpected))


def resolve_addons_path(requested_path: str, repository_root: Path) -> Path:
    config_path = repository_root / "data" / "local_rising_gods_addons_path.txt"
    path_text = requested_path.strip()
    if not path_text and config_path.is_file():
        path_text = config_path.read_text(encoding="utf-8").splitlines()[0].strip()
        if path_text:
            print(f"Using saved AddOns path: {path_text}")
    if not path_text:
        print("Paste your World of Warcraft Interface/AddOns folder path.")
        print("Use the folder named Interface/AddOns from your WoW install.")
        path_text = input("AddOns path: ").strip()
    if not path_text:
        raise UpdaterError("No AddOns path was provided. Run with --no-install to refresh local data only.")
    path_text = path_text.strip().strip('"').strip("'")
    addons_path = Path(path_text).expanduser().resolve()
    if addons_path.name != "AddOns":
        raise UpdaterError(f"The path must be the Interface/AddOns folder, not the World of Warcraft root: {addons_path}")
    if not addons_path.is_dir():
        raise UpdaterError(f"AddOns folder does not exist: {addons_path}")
    return addons_path


def save_addons_path(addons_path: Path, repository_root: Path) -> None:
    data_dir = repository_root / "data"
    data_dir.mkdir(parents=True, exist_ok=True)
    (data_dir / "local_rising_gods_addons_path.txt").write_text(str(addons_path) + "\n", encoding="utf-8")


def confirm_update_plan(
    layout: Layout,
    addons_path: Optional[Path],
    max_per_spec: int,
    bulk_top_limit: int,
    boss_names: List[str],
    skip_api_validation: bool,
    no_install: bool,
    yes: bool,
) -> None:
    print()
    print("Update plan")
    print(f"  Source folder:      {layout.root}")
    print(f"  Live install:       {'disabled (--no-install)' if no_install else addons_path}")
    print(f"  Addon folders:      {DATA_ADDON_NAME} plus generated UWU shards")
    print(f"  UwU profile check:  {'skipped' if skip_api_validation else 'enabled'}")
    print(f"  Ranked pull:        {max_per_spec} players per class/spec")
    print(f"  Boss pull limit:    {bulk_top_limit} rows per boss/class/spec")
    print("  Duplicate names:    character-confirmed with automatic boss repair")
    print(f"  Targeted repairs:   {', '.join(boss_names) if boss_names else 'none'}")
    print()
    print("This will not modify the core coolstats addon or the cache addon.")
    print("The previous live data addon family is backed up before replacement.")
    if yes:
        print("Confirmation skipped because --yes was provided.")
        return
    response = input("Continue with this update? Type Y to start: ").strip()
    if response.upper() not in {"Y", "YES"}:
        raise UpdaterError("Update canceled by user before any refresh or live install.")


def run_generator(
    layout: Layout,
    python_cmd: str,
    mode: str,
    max_per_spec: int,
    bulk_top_limit: int,
    boss_names: List[str],
    lua_output: Optional[Path] = None,
    json_output: Optional[Path] = None,
    boss_cache: Optional[Path] = None,
    addon_version: str = "",
) -> None:
    script = layout.root / "tools" / "update_uwu_logs.py"
    if not script.is_file():
        raise UpdaterError(f"Missing UwU updater: {script}")
    command = [python_cmd, str(script), "--server", "Rising-Gods", "--phase", "icc"]
    if mode == "Validate":
        command.append("--validate-profile")
    elif mode == "Weekly":
        command.extend([
            "--weekly",
            "--max-per-spec",
            str(max_per_spec),
            "--bulk-top-limit",
            str(bulk_top_limit),
            "--duplicate-workers",
            "8",
            "--boss-workers",
            "4",
        ])
        if lua_output is not None:
            command.extend(["--lua-output", str(lua_output)])
        if json_output is not None:
            command.extend(["--json-output", str(json_output)])
        if boss_cache is not None:
            command.extend(["--boss-cache", str(boss_cache)])
        if addon_version:
            command.extend(["--addon-version", addon_version])
        for boss_name in boss_names:
            command.extend(["--boss-name", boss_name])
    else:
        raise UpdaterError(f"Unsupported update mode: {mode}")

    result = subprocess.run(command, cwd=layout.root)
    if result.returncode != 0:
        raise UpdaterError(f"Rising Gods {mode} update failed.")


def resolve_luac(requested_path: str) -> Optional[str]:
    candidates: List[str] = []
    if requested_path:
        candidates.append(requested_path)
    env_luac = os.environ.get("LUAC51", "").strip()
    if env_luac:
        candidates.append(env_luac)
    for name in ("luac5.1", "luac"):
        found = shutil.which(name)
        if found:
            candidates.append(found)
    for candidate in candidates:
        if candidate and Path(candidate).expanduser().is_file():
            return str(Path(candidate).expanduser().resolve())
    return None


def lua_files_for_validation(layout: Layout, validation_root: Path) -> List[Path]:
    if validation_root.name == DATA_ADDON_NAME:
        files: List[Path] = []
        for folder in collect_data_addon_family(validation_root):
            files.extend(folder.rglob("*.lua"))
        return sorted(path.resolve() for path in files)
    if (validation_root / "coolstats.toc").is_file():
        files = list(validation_root.glob("*.lua"))
        cache_path = validation_root / "cache_addon" / "coolstats_Cache"
        if cache_path.is_dir():
            files.extend(cache_path.glob("*.lua"))
        realm_root = validation_root / "realm_data"
        if realm_root.is_dir():
            files.extend(realm_root.rglob("*.lua"))
        return sorted(set(path.resolve() for path in files))
    return sorted(path.resolve() for path in validation_root.rglob("*.lua"))


def optional_lua51_validation(layout: Layout, validation_root: Path, luac_path: str, require_lua51: bool) -> None:
    luac = resolve_luac(luac_path)
    if not luac:
        if require_lua51:
            raise UpdaterError("Could not locate Lua 5.1 luac. Install luac 5.1, pass --luac-path, or set LUAC51.")
        print("Warning: Lua 5.1 compiler validation was skipped because luac 5.1 was not found.")
        print("Official releases still require Lua 5.1 validation; this local updater keeps a live backup before install.")
        return
    lua_files = lua_files_for_validation(layout, validation_root)
    if not lua_files:
        raise UpdaterError(f"No Lua files found under {validation_root}.")
    for lua_file in lua_files:
        result = subprocess.run([luac, "-p", str(lua_file)])
        if result.returncode != 0:
            raise UpdaterError(f"Lua 5.1 validation failed for {lua_file}; refusing to install generated data.")
    print(f"Lua 5.1 validation passed for {len(lua_files)} files.")


def assert_addons_write_access(addons_path: Path) -> None:
    addons_root = addons_path.resolve()
    probe = assert_child_path(addons_root, f"_coolstats_write_test_{os.getpid()}")
    try:
        probe.mkdir(parents=True, exist_ok=True)
        (probe / "probe.tmp").write_text("ok\n", encoding="ascii")
    except OSError as exc:
        raise UpdaterError(
            "The selected Interface/AddOns folder is not writable: "
            f"{addons_root}. If World of Warcraft is installed under Program Files "
            "or another protected location, move the game/addon to a writable folder "
            "or run the official coolstats updater from an elevated terminal. "
            f"Original error: {exc}"
        ) from exc
    finally:
        if probe.exists():
            try:
                remove_path(probe)
            except OSError:
                pass


def assert_child_path(root: Path, child_name: str) -> Path:
    if Path(child_name).is_absolute() or "/" in child_name or "\\" in child_name or ".." in child_name:
        raise UpdaterError(f"Unsafe child path: {child_name}")
    root_resolved = root.resolve()
    child = (root_resolved / child_name).resolve()
    try:
        child.relative_to(root_resolved)
    except ValueError as exc:
        raise UpdaterError(f"Unsafe path outside expected root: {child}") from exc
    return child


def is_data_family_name(name: str) -> bool:
    return name == DATA_ADDON_NAME or name.startswith(DATA_ADDON_SHARD_PREFIX)


def collect_data_addon_family(base_data_addon: Path) -> List[Path]:
    base = base_data_addon.resolve()
    parent = base.parent
    family = [
        path.resolve()
        for path in parent.iterdir()
        if path.is_dir() and is_data_family_name(path.name)
    ]
    names = {path.name for path in family}
    if DATA_ADDON_NAME not in names:
        raise UpdaterError(f"Missing Rising Gods base data addon: {base}")
    return sorted(family, key=lambda path: (path.name != DATA_ADDON_NAME, path.name))


def remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def install_data_addon(
    layout: Layout,
    addons_path: Path,
    source_data_addon: Path,
    expected_version: str,
    expected_max_per_spec: int,
) -> None:
    source = source_data_addon.resolve()
    addons_root = addons_path.resolve()
    source_family = collect_data_addon_family(source)
    temp_root = assert_child_path(addons_root, f"_coolstats_rising_gods_update_tmp_{os.getpid()}")
    backup_root = assert_child_path(addons_root, "_coolstats_backups")
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    backup = assert_child_path(backup_root, f"{DATA_ADDON_NAME}_{timestamp}_{os.getpid()}")
    old_moved = False
    moved_targets: List[tuple[Path, Path]] = []

    if not (addons_root / "coolstats" / "coolstats.toc").is_file():
        print("Warning: the core coolstats addon folder was not found in this AddOns path.")
        print("Install the official release ZIP first if this is a new setup.")

    try:
        if temp_root.exists():
            try:
                remove_path(temp_root)
            except OSError as exc:
                raise UpdaterError(
                    f"Could not clean the previous temporary update folder: {temp_root}. "
                    "Close World of Warcraft and any file browser windows using the folder, then try again. "
                    f"Original error: {exc}"
                ) from exc
        temp_root.mkdir(parents=True, exist_ok=True)
        try:
            for source_folder in source_family:
                shutil.copytree(source_folder, temp_root / source_folder.name)
        except OSError as exc:
            raise UpdaterError(
                f"Could not create the temporary update folders under: {temp_root}. "
                "The operating system may be denying writes to this AddOns folder. "
                "If it is under Program Files or another protected location, move the game/addon "
                "to a writable folder or run the official coolstats updater from an elevated terminal. "
                f"Original error: {exc}"
            ) from exc
        audit_data_addon(
            temp_root / DATA_ADDON_NAME,
            expected_version=expected_version,
            expected_max_per_spec=expected_max_per_spec,
            require_shards=True,
            quiet=True,
        )

        backup_root.mkdir(parents=True, exist_ok=True)
        backup.mkdir(parents=True, exist_ok=True)
        live_family = [
            path
            for path in addons_root.iterdir()
            if path.is_dir() and is_data_family_name(path.name)
        ]
        for target in sorted(live_family, key=lambda path: path.name):
            backup_target = backup / target.name
            shutil.move(str(target), str(backup_target))
            moved_targets.append((backup_target, target))
            old_moved = True
        if old_moved:
            print(f"Backed up old data addon family to: {backup}")

        for staged in sorted(temp_root.iterdir(), key=lambda path: path.name):
            if staged.is_dir() and is_data_family_name(staged.name):
                shutil.move(str(staged), str(assert_child_path(addons_root, staged.name)))
        remove_path(temp_root)
        audit_data_addon(
            addons_root / DATA_ADDON_NAME,
            expected_version=expected_version,
            expected_max_per_spec=expected_max_per_spec,
            require_shards=True,
            quiet=True,
        )
        print(f"Installed updated data addon family to: {addons_root}")
    except Exception:
        if temp_root.exists():
            remove_path(temp_root)
        for live in [
            path
            for path in addons_root.iterdir()
            if path.is_dir() and is_data_family_name(path.name)
        ]:
            remove_path(live)
        for backup_target, target in moved_targets:
            if backup_target.exists() and not target.exists():
                shutil.move(str(backup_target), str(target))
        if old_moved:
            print("Warning: restored previous data addon family from backup.")
        raise


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addons-path", "-AddOnsPath", default="")
    parser.add_argument("--max-per-spec", "-MaxPerSpec", type=int, default=600)
    parser.add_argument("--bulk-top-limit", "-BulkTopLimit", type=int, default=10000)
    parser.add_argument("--boss-name", "-BossName", action="append", default=[])
    parser.add_argument("--python", "-Python", default=sys.executable)
    parser.add_argument("--luac-path", "-LuacPath", default="")
    parser.add_argument("--skip-api-validation", "-SkipApiValidation", action="store_true")
    parser.add_argument("--no-install", "-NoInstall", action="store_true")
    parser.add_argument("--validate-only", "-ValidateOnly", action="store_true")
    parser.add_argument("--yes", "-Yes", action="store_true")
    parser.add_argument("--require-lua51", "-RequireLua51", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    ui = Ui(run_step_labels(args.validate_only, args.skip_api_validation, args.no_install))
    try:
        ui.header()
        layout = detect_layout()
        addon_version = get_toc_version(layout.core_toc)
        if not addon_version:
            raise UpdaterError(f"Could not read addon version from {layout.core_toc}.")

        ui.step("Checking updater files")
        assert_updater_layout(layout)

        if args.validate_only:
            ui.step("Validating existing generated data")
            result = audit_data_addon(
                layout.live_data_addon,
                expected_version=addon_version,
                expected_max_per_spec=args.max_per_spec,
                require_shards=True,
            )
            print(f"Generated data contains {result['players']} ranked players.")
            validation_root = layout.root if layout.kind == "Source" else layout.live_data_addon
            optional_lua51_validation(layout, validation_root, args.luac_path, args.require_lua51)
            ui.step("Finishing validation-only run")
            print("ValidateOnly was set, so no network refresh or live install was performed.")
            ui.complete("Validation-only run complete.")
            return 0

        if not shutil.which(args.python) and not Path(args.python).expanduser().is_file():
            raise UpdaterError(f"Python was not found. Install Python 3 and make sure it is available as '{args.python}'.")

        ui.step("Confirming update plan")
        live_addons_path: Optional[Path] = None
        if not args.no_install:
            if args.addons_path:
                live_addons_path = resolve_addons_path(args.addons_path, layout.root)
            elif layout.kind == "Installed":
                if layout.addons_root is None:
                    raise UpdaterError("Installed layout did not provide an AddOns root.")
                live_addons_path = layout.addons_root
                print(f"Using this release folder as AddOns path: {live_addons_path}")
            else:
                live_addons_path = resolve_addons_path(args.addons_path, layout.root)

        boss_names = [name for name in args.boss_name if name.strip()]
        confirm_update_plan(
            layout=layout,
            addons_path=live_addons_path,
            max_per_spec=args.max_per_spec,
            bulk_top_limit=args.bulk_top_limit,
            boss_names=boss_names,
            skip_api_validation=args.skip_api_validation,
            no_install=args.no_install,
            yes=args.yes,
        )

        if not args.no_install:
            if live_addons_path is None:
                raise UpdaterError("No live AddOns path was resolved.")
            ui.step("Checking live AddOns write access")
            assert_addons_write_access(live_addons_path)

        generated_data_addon = layout.work_data_addon
        lua_output = generated_data_addon / "data" / "logs" / "icc" / "coolstats_uwu_data.lua"
        if not args.skip_api_validation:
            ui.step("Validating Rising Gods UwU profile")
            run_generator(
                layout=layout,
                python_cmd=args.python,
                mode="Validate",
                max_per_spec=args.max_per_spec,
                bulk_top_limit=args.bulk_top_limit,
                boss_names=[],
            )

        ui.step("Refreshing Rising Gods logs")
        if layout.kind == "Installed":
            work_root = layout.root / "work"
            work_root.mkdir(parents=True, exist_ok=True)
            resolved_work = generated_data_addon.resolve()
            try:
                resolved_work.relative_to(work_root.resolve())
            except ValueError as exc:
                raise UpdaterError(f"Unsafe generated data workspace outside updater work folder: {resolved_work}") from exc
            for existing in [
                path
                for path in work_root.iterdir()
                if path.is_dir() and is_data_family_name(path.name)
            ]:
                remove_path(existing)

        run_generator(
            layout=layout,
            python_cmd=args.python,
            mode="Weekly",
            max_per_spec=args.max_per_spec,
            bulk_top_limit=args.bulk_top_limit,
            boss_names=boss_names,
            lua_output=lua_output,
            json_output=layout.json_output,
            boss_cache=layout.boss_cache,
            addon_version=addon_version,
        )

        ui.step("Validating generated data")
        result = audit_data_addon(
            generated_data_addon,
            expected_version=addon_version,
            expected_max_per_spec=args.max_per_spec,
            require_shards=True,
        )
        print(f"Generated data contains {result['players']} ranked players.")
        validation_root = layout.root if layout.kind == "Source" else generated_data_addon
        optional_lua51_validation(layout, validation_root, args.luac_path, args.require_lua51)

        if args.no_install:
            ui.step("Finishing local refresh")
            print("NoInstall was set, so the live AddOns folder was not changed.")
        else:
            if live_addons_path is None:
                raise UpdaterError("No live AddOns path was resolved.")
            ui.step("Installing live Rising Gods data addon family")
            install_data_addon(
                layout=layout,
                addons_path=live_addons_path,
                source_data_addon=generated_data_addon,
                expected_version=addon_version,
                expected_max_per_spec=args.max_per_spec,
            )
            if layout.kind == "Source":
                save_addons_path(live_addons_path, layout.root)

        ui.step("Finishing update")
        ui.complete("Rising Gods log update complete.")
        return 0
    except (OSError, UpdaterError, RuntimeError, subprocess.SubprocessError) as exc:
        print()
        print("Update failed:")
        print(str(exc))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

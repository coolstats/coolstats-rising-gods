#!/usr/bin/env python3
"""Validate the generated Rising Gods data addon family."""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Dict, Iterable, List, NamedTuple, Set


DATA_ADDON_NAME = "coolstats_Data_RisingGods"
DATA_ADDON_SHARD_PREFIX = DATA_ADDON_NAME + "_UWU_"

REQUIRED_BOSSES = [
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
]


class RaidLayer(NamedTuple):
    key: str
    name: str
    prefix: str


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require_file(path: Path, label: str) -> None:
    if not path.is_file():
        raise RuntimeError(f"Missing {label}: {path}")


def require_contains(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise RuntimeError(message)


def require_match(text: str, pattern: str, message: str) -> re.Match[str]:
    match = re.search(pattern, text)
    if not match:
        raise RuntimeError(message)
    return match


def toc_metadata(text: str) -> Dict[str, str]:
    metadata: Dict[str, str] = {}
    for line in text.splitlines():
        match = re.match(r"^##\s+([^:]+):\s*(.*)$", line)
        if match:
            metadata[match.group(1).strip()] = match.group(2).strip()
    return metadata


def toc_metadata_int(text: str, key: str) -> int:
    metadata = toc_metadata(text)
    if key not in metadata:
        raise RuntimeError(f"Rising Gods data TOC is missing {key}.")
    return int(metadata[key])


def expected_player_chunk_count(player_count: int) -> int:
    target_chunk_size = 3000
    min_chunk_count = 6
    max_chunk_count = 16
    minimum_players = 6000
    if player_count <= 0:
        return 1
    chunk_count = max(1, (player_count + target_chunk_size - 1) // target_chunk_size)
    if player_count >= minimum_players:
        chunk_count = max(min_chunk_count, chunk_count)
    return min(max_chunk_count, chunk_count)


def is_temporary_base_name(name: str) -> bool:
    return re.match(r"^coolstats_Data_RisingGods\.__coolstats_update_tmp(_\d+)?$", name) is not None


def is_data_family_name(name: str) -> bool:
    return name == DATA_ADDON_NAME or name.startswith(DATA_ADDON_SHARD_PREFIX)


def collect_family_dirs(base_addon_path: Path) -> List[Path]:
    parent = base_addon_path.parent
    family = [
        path
        for path in parent.iterdir()
        if path.is_dir() and (path == base_addon_path or is_data_family_name(path.name))
    ]
    return sorted(family, key=lambda path: (path.name != DATA_ADDON_NAME, path.name))


def reject_unexpected_files(folders: Iterable[Path]) -> None:
    unexpected_files = [
        path
        for folder in folders
        for path in folder.rglob("*")
        if path.is_file() and path.suffix.lower() not in {".toc", ".lua"}
    ]
    if unexpected_files:
        joined = ", ".join(str(path) for path in unexpected_files)
        raise RuntimeError(f"Unexpected non-addon files in data addon family: {joined}")


def parse_load_steps(header_text: str, expected_count: int, total_players: int) -> List[int]:
    match = require_match(header_text, r"playerLoadSteps\s*=\s*\{([^}]*)\}", "Generated header is missing playerLoadSteps.")
    load_steps = [int(value.strip()) for value in match.group(1).split(",") if value.strip()]
    if len(load_steps) != expected_count + 1:
        raise RuntimeError(
            f"Generated header playerLoadSteps has {len(load_steps)} entries; expected {expected_count + 1}."
        )
    if load_steps[0] != 0 or load_steps[-1] != total_players:
        raise RuntimeError(f"Generated header playerLoadSteps must start at 0 and end at {total_players}.")
    for index in range(1, len(load_steps)):
        if load_steps[index] < load_steps[index - 1]:
            raise RuntimeError("Generated header playerLoadSteps must be non-decreasing.")
    return load_steps


def parse_player_shard_name(header_text: str, index: int) -> str:
    addon_list = re.search(r"playerShardAddons\s*=\s*\{(?P<body>.*?)\}", header_text, flags=re.S)
    if addon_list:
        entry = re.search(rf"\[{index}\]\s*=\s*\"(?P<name>[^\"]+)\"", addon_list.group("body"))
        if entry:
            return entry.group("name")
    prefix = re.search(r"playerShardAddonPrefix\s*=\s*\"(?P<prefix>[^\"]+)\"", header_text)
    if prefix:
        return f"{prefix.group('prefix')}{index:02d}"
    return f"{DATA_ADDON_SHARD_PREFIX}{index:02d}"


def parse_raid_layers(header_text: str) -> List[RaidLayer]:
    layers: List[RaidLayer] = []
    pattern = re.compile(
        r"\[\d+\]\s*=\s*\{\s*key\s*=\s*\"(?P<key>[^\"]+)\"\s*,\s*"
        r"name\s*=\s*\"(?P<name>[^\"]+)\"\s*,\s*"
        r"shardAddonPrefix\s*=\s*\"(?P<prefix>[^\"]+)\"",
        flags=re.S,
    )
    for match in pattern.finditer(header_text):
        layers.append(RaidLayer(match.group("key"), match.group("name"), match.group("prefix")))
    return layers


def validate_shard_toc(
    shard_root: Path,
    shard_name: str,
    base_addon_name: str,
    expected_version: str,
    expected_index: int,
    expected_count: int,
    relative_lua_path: str,
    raid_layer: RaidLayer | None = None,
) -> None:
    toc_path = shard_root / f"{shard_name}.toc"
    require_file(toc_path, "Rising Gods shard TOC")
    toc_text = read_text(toc_path)
    require_contains(toc_text, "## RequiredDeps: coolstats, " + base_addon_name, f"{shard_name} must depend on {base_addon_name}.")
    require_contains(toc_text, "## LoadOnDemand: 1", f"{shard_name} must stay load-on-demand.")
    require_contains(toc_text, "## X-coolstats-Realm: Rising-Gods", f"{shard_name} realm metadata is missing.")
    require_contains(toc_text, "## X-coolstats-Phase: icc", f"{shard_name} phase metadata is missing.")
    require_contains(toc_text, f"## Version: {expected_version}", f"{shard_name} version does not match {expected_version}.")
    metadata = toc_metadata(toc_text)
    if metadata.get("X-coolstats-BaseAddon") != base_addon_name:
        raise RuntimeError(f"{shard_name} points at base addon {metadata.get('X-coolstats-BaseAddon')}, expected {base_addon_name}.")
    if int(metadata.get("X-coolstats-ShardIndex", "0")) != expected_index:
        raise RuntimeError(f"{shard_name} has the wrong shard index.")
    if int(metadata.get("X-coolstats-ShardCount", "0")) != expected_count:
        raise RuntimeError(f"{shard_name} has the wrong shard count.")
    if raid_layer:
        if metadata.get("X-coolstats-RaidLayer") != raid_layer.key:
            raise RuntimeError(f"{shard_name} has the wrong raid-layer metadata.")
        if metadata.get("X-coolstats-RaidName") != raid_layer.name:
            raise RuntimeError(f"{shard_name} has the wrong raid-name metadata.")
    require_contains(toc_text, relative_lua_path, f"{shard_name} TOC does not load {relative_lua_path}.")
    require_file(shard_root / relative_lua_path.replace("\\", "/"), f"{shard_name} generated Lua file")


def validate_player_chunk_text(text: str, chunk_name: str, expected_start: int) -> List[str]:
    require_match(text, rf"local\s+chunkStartIndex\s*=\s*{expected_start}", f"{chunk_name} has an incorrect chunkStartIndex guard.")
    require_contains(text, "ShouldSkipUwUDataChunk", f"{chunk_name} is missing the chunk-skip guard.")
    require_contains(text, "coolstatsUwUData.players", f"{chunk_name} does not merge into coolstatsUwUData.players.")
    if "local chunk = {" not in text and "local players = coolstatsUwUData" not in text:
        raise RuntimeError(f"{chunk_name} does not define a safe player merge target.")
    if "for key, player in pairs(chunk) do" not in text and 'players["' not in text:
        raise RuntimeError(f"{chunk_name} does not merge chunk rows safely.")
    if re.search(r'", 0, \d+, \d+, nil,', text):
        raise RuntimeError(f"Generated data contains rankless player rows in {chunk_name}.")
    player_keys = re.findall(r'(?m)^[\t ]+\["([^"]+)"\][\t ]*=', text)
    player_keys.extend(re.findall(r'(?m)^players\["([^"]+)"\]\s*=', text))
    if not player_keys:
        raise RuntimeError(f"Generated chunk {chunk_name} has no player rows.")
    return player_keys


def validate_raid_layer_chunk_text(text: str, chunk_name: str, raid_layer: RaidLayer, expected_start: int) -> None:
    require_contains(text, f'local layerKey = "{raid_layer.key}"', f"{chunk_name} has the wrong raid-layer key.")
    require_match(text, rf"local\s+chunkStartIndex\s*=\s*{expected_start}", f"{chunk_name} has an incorrect raid-layer chunkStartIndex.")
    require_contains(text, "ShouldSkipUwUDataRaidLayer", f"{chunk_name} is missing the raid-layer skip guard.")
    require_contains(text, "MarkUwUDataRaidLayerLoaded", f"{chunk_name} does not mark the raid layer as loaded.")


def audit_data_addon(
    data_addon_path: Path,
    expected_version: str = "",
    expected_max_per_spec: int = 600,
    min_players: int = 6000,
    max_players: int = 20000,
    expected_chunk_count: int = 0,
    allow_temporary_folder_name: bool = False,
    quiet: bool = False,
    require_shards: bool = False,
) -> Dict[str, int]:
    addon_path = data_addon_path.resolve()
    addon_name = addon_path.name
    if addon_name != DATA_ADDON_NAME and not (allow_temporary_folder_name and is_temporary_base_name(addon_name)):
        raise RuntimeError(f"Data addon folder must be named {DATA_ADDON_NAME}: {addon_path}")
    if not addon_path.is_dir():
        raise RuntimeError(f"Missing Rising Gods data addon folder: {addon_path}")

    toc_path = addon_path / f"{addon_name}.toc"
    if not toc_path.is_file() and addon_name != DATA_ADDON_NAME:
        toc_path = addon_path / f"{DATA_ADDON_NAME}.toc"
    log_dir = addon_path / "data" / "logs" / "icc"
    header_path = log_dir / "coolstats_uwu_data.lua"
    require_file(toc_path, "Rising Gods data TOC")
    require_file(header_path, "Rising Gods data header")
    if not log_dir.is_dir():
        raise RuntimeError(f"Missing Rising Gods ICC log data directory: {log_dir}")

    family_dirs = collect_family_dirs(addon_path)
    reject_unexpected_files(family_dirs)

    toc_text = read_text(toc_path)
    require_contains(toc_text, "## Title: |cff00c0ffcoolstats|r Data - Rising-Gods", "Rising Gods data TOC title is missing or incorrect.")
    require_contains(toc_text, "## RequiredDeps: coolstats", "Rising Gods data TOC must depend on coolstats.")
    require_contains(toc_text, "## LoadOnDemand: 1", "Rising Gods data TOC must stay load-on-demand.")
    require_contains(toc_text, "## X-coolstats-Realm: Rising-Gods", "Rising Gods realm metadata is missing or incorrect.")
    require_contains(toc_text, "## X-coolstats-Phase: icc", "Rising Gods phase metadata is missing or incorrect.")
    if expected_version:
        require_contains(toc_text, f"## Version: {expected_version}", f"Rising Gods data TOC version does not match {expected_version}.")

    toc_player_count = toc_metadata_int(toc_text, "X-coolstats-PlayerCount")
    toc_chunk_count = toc_metadata_int(toc_text, "X-coolstats-PlayerChunks")
    calculated_chunk_count = expected_player_chunk_count(toc_player_count)
    if toc_chunk_count != calculated_chunk_count:
        raise RuntimeError(
            f"Rising Gods data TOC has {toc_chunk_count} chunks for {toc_player_count} players; expected {calculated_chunk_count}."
        )
    if expected_chunk_count <= 0:
        expected_chunk_count = toc_chunk_count
    elif expected_chunk_count != toc_chunk_count:
        raise RuntimeError(
            f"Rising Gods data TOC chunk count {toc_chunk_count} does not match expected {expected_chunk_count}."
        )

    header_text = read_text(header_path)
    require_contains(header_text, 'realm = "Rising-Gods"', "Generated header is not for Rising-Gods.")
    require_contains(header_text, 'phaseId = "icc"', "Generated header is not for the ICC phase.")
    require_contains(header_text, 'defaultRaidName = "Icecrown Citadel"', "Generated header is missing the ICC default raid.")
    require_contains(header_text, 'source = "https://uwu-logs.xyz/top_points"', "Generated header is missing the UwU top-points source.")
    require_contains(header_text, 'topSource = "https://uwu-logs.xyz/top"', "Generated header is missing the UwU top source.")
    require_contains(header_text, 'characterSource = "https://uwu-logs.xyz/character"', "Generated header is missing the UwU character source.")
    require_match(header_text, rf"maxPerSpec\s*=\s*{expected_max_per_spec},", f"Generated header maxPerSpec does not match {expected_max_per_spec}.")
    require_match(header_text, r'generatedAt\s*=\s*"\d{4}-\d{2}-\d{2}T', "Generated header is missing an ISO generatedAt timestamp.")
    require_contains(header_text, "players = {},", "Generated header must initialize an empty players table before chunks load.")
    require_match(header_text, rf"totalPlayers\s*=\s*{toc_player_count},", "Generated header totalPlayers does not match TOC metadata.")
    require_match(header_text, rf"playerChunkCount\s*=\s*{toc_chunk_count},", "Generated header playerChunkCount does not match TOC metadata.")
    load_steps = parse_load_steps(header_text, toc_chunk_count, toc_player_count)

    for index, boss in enumerate(REQUIRED_BOSSES, start=1):
        require_contains(header_text, f'[{index}] = "{boss}"', f"Generated header is missing boss {index}: {boss}")

    is_sharded = "playerShardAddons" in header_text or "playerShardAddonPrefix" in header_text
    if require_shards and not is_sharded:
        raise RuntimeError("Rising Gods data must use load-on-demand shard addons.")

    player_keys: Set[str] = set()
    chunk_counts: List[int] = []
    expected_family_names: Set[str] = {DATA_ADDON_NAME}

    if is_sharded:
        base_chunk_files = sorted(log_dir.glob("coolstats_uwu_data_??.lua"))
        if base_chunk_files:
            raise RuntimeError("Sharded Rising Gods data must not leave player chunks in the base data addon.")
        toc_chunk_lines = [line for line in toc_text.splitlines() if re.search(r"coolstats_uwu_data_\d\d\.lua$", line)]
        if toc_chunk_lines:
            raise RuntimeError("Sharded Rising Gods base TOC must not list generated player chunk files.")

        base_version = expected_version or get_toc_version_from_text(toc_text)
        for index in range(1, expected_chunk_count + 1):
            shard_name = parse_player_shard_name(header_text, index)
            expected_family_names.add(shard_name)
            shard_root = addon_path.parent / shard_name
            if not shard_root.is_dir():
                raise RuntimeError(f"Missing Rising Gods player shard addon: {shard_root}")
            chunk_file_name = f"coolstats_uwu_data_{index:02d}.lua"
            relative_lua_path = f"data\\logs\\icc\\{chunk_file_name}"
            validate_shard_toc(shard_root, shard_name, DATA_ADDON_NAME, base_version, index, expected_chunk_count, relative_lua_path)
            chunk_path = shard_root / "data" / "logs" / "icc" / chunk_file_name
            matches = validate_player_chunk_text(read_text(chunk_path), chunk_file_name, load_steps[index - 1] + 1)
            for key in matches:
                if key in player_keys:
                    raise RuntimeError(f"Duplicate player key across chunks: {key}")
                player_keys.add(key)
            chunk_counts.append(len(matches))

        for raid_layer in parse_raid_layers(header_text):
            for index in range(1, expected_chunk_count + 1):
                layer_name = f"{raid_layer.prefix}{index:02d}"
                expected_family_names.add(layer_name)
                layer_root = addon_path.parent / layer_name
                if not layer_root.is_dir():
                    raise RuntimeError(f"Missing Rising Gods raid-layer shard addon: {layer_root}")
                layer_file_name = f"coolstats_uwu_data_{raid_layer.key}_{index:02d}.lua"
                relative_lua_path = f"data\\logs\\icc\\{layer_file_name}"
                validate_shard_toc(
                    layer_root,
                    layer_name,
                    DATA_ADDON_NAME,
                    base_version,
                    index,
                    expected_chunk_count,
                    relative_lua_path,
                    raid_layer=raid_layer,
                )
                layer_path = layer_root / "data" / "logs" / "icc" / layer_file_name
                validate_raid_layer_chunk_text(read_text(layer_path), layer_file_name, raid_layer, load_steps[index - 1] + 1)

        actual_family_names = {path.name for path in family_dirs if is_data_family_name(path.name)}
        stale = sorted(actual_family_names - expected_family_names)
        if stale:
            raise RuntimeError("Unexpected stale Rising Gods data shard addons: " + ", ".join(stale))
    else:
        expected_data_files = ["coolstats_uwu_data.lua"] + [
            f"coolstats_uwu_data_{index:02d}.lua" for index in range(1, expected_chunk_count + 1)
        ]
        for filename in expected_data_files:
            relative_path = f"data\\logs\\icc\\{filename}"
            require_file(addon_path / "data" / "logs" / "icc" / filename, "generated Rising Gods data file")
            require_contains(toc_text, relative_path, f"Rising Gods data TOC does not load {relative_path}.")

        chunk_files = sorted(log_dir.glob("coolstats_uwu_data_*.lua"))
        actual_chunk_names = [path.name for path in chunk_files]
        expected_chunk_names = expected_data_files[1:]
        if actual_chunk_names != expected_chunk_names:
            raise RuntimeError(
                "Unexpected Rising Gods chunk files. Expected "
                + ", ".join(expected_chunk_names)
                + "; found "
                + ", ".join(actual_chunk_names)
                + "."
            )
        for index, chunk in enumerate(chunk_files, start=1):
            matches = validate_player_chunk_text(read_text(chunk), chunk.name, load_steps[index - 1] + 1)
            for key in matches:
                if key in player_keys:
                    raise RuntimeError(f"Duplicate player key across chunks: {key}")
                player_keys.add(key)
            chunk_counts.append(len(matches))

    player_count = len(player_keys)
    if player_count != toc_player_count:
        raise RuntimeError(f"Generated data contains {player_count} player rows but TOC metadata says {toc_player_count}.")
    if player_count < min_players:
        raise RuntimeError(f"Generated data contains only {player_count} players; refusing to install.")
    if player_count > max_players:
        raise RuntimeError(f"Generated data contains {player_count} players, above the safety ceiling of {max_players}.")

    min_chunk = min(chunk_counts)
    max_chunk = max(chunk_counts)
    allowed_chunk_spread = max(30, expected_chunk_count * 5)
    if max_chunk - min_chunk > allowed_chunk_spread:
        raise RuntimeError(f"Generated data chunks are not balanced: min={min_chunk} max={max_chunk}.")

    result: Dict[str, int] = {
        "players": player_count,
        "chunks": len(chunk_counts),
        "min_chunk": min_chunk,
        "max_chunk": max_chunk,
        "max_per_spec": expected_max_per_spec,
        "shards": 1 if is_sharded else 0,
    }
    if not quiet:
        layout = "sharded" if is_sharded else "inline"
        print(
            "Rising Gods data integrity passed: "
            f"players={player_count} chunks={len(chunk_counts)} layout={layout} "
            f"minChunk={min_chunk} maxChunk={max_chunk} maxPerSpec={expected_max_per_spec}"
        )
    return result


def get_toc_version_from_text(toc_text: str) -> str:
    match = re.search(r"^##\s+Version:\s*(.+)$", toc_text, flags=re.M)
    if not match:
        raise RuntimeError("Rising Gods data TOC is missing ## Version.")
    return match.group(1).strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-addon-path", required=True, type=Path)
    parser.add_argument("--expected-version", default="")
    parser.add_argument("--expected-max-per-spec", type=int, default=600)
    parser.add_argument("--min-players", type=int, default=6000)
    parser.add_argument("--max-players", type=int, default=20000)
    parser.add_argument("--expected-chunk-count", type=int, default=0)
    parser.add_argument("--allow-temporary-folder-name", action="store_true")
    parser.add_argument("--require-shards", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    try:
        audit_data_addon(
            data_addon_path=args.data_addon_path,
            expected_version=args.expected_version,
            expected_max_per_spec=args.expected_max_per_spec,
            min_players=args.min_players,
            max_players=args.max_players,
            expected_chunk_count=args.expected_chunk_count,
            allow_temporary_folder_name=args.allow_temporary_folder_name,
            require_shards=args.require_shards,
            quiet=args.quiet,
        )
    except RuntimeError as exc:
        print(str(exc))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

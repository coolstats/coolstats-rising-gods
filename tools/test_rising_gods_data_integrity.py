#!/usr/bin/env python3
"""Validate the generated Rising Gods data addon.

This is the cross-platform equivalent of the PowerShell integrity audit used by
the Windows updater and release validator.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Dict, List, Set


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


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require_file(path: Path, label: str) -> None:
    if not path.is_file():
        raise RuntimeError(f"Missing {label}: {path}")


def require_contains(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise RuntimeError(message)


def require_match(text: str, pattern: str, message: str) -> None:
    if not re.search(pattern, text):
        raise RuntimeError(message)


def toc_metadata_int(text: str, key: str) -> int:
    match = re.search(rf"^##\s+{re.escape(key)}:\s*(\d+)\s*$", text, flags=re.MULTILINE)
    if not match:
        raise RuntimeError(f"Rising Gods data TOC is missing {key}.")
    return int(match.group(1))


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


def audit_data_addon(
    data_addon_path: Path,
    expected_version: str = "",
    expected_max_per_spec: int = 600,
    min_players: int = 6000,
    max_players: int = 20000,
    expected_chunk_count: int = 0,
    allow_temporary_folder_name: bool = False,
    quiet: bool = False,
) -> Dict[str, int]:
    addon_path = data_addon_path.resolve()
    temporary_name = re.match(r"^coolstats_Data_RisingGods\.__coolstats_update_tmp(_\d+)?$", addon_path.name)
    if addon_path.name != "coolstats_Data_RisingGods" and not (allow_temporary_folder_name and temporary_name):
        raise RuntimeError(f"Data addon folder must be named coolstats_Data_RisingGods: {addon_path}")
    if not addon_path.is_dir():
        raise RuntimeError(f"Missing Rising Gods data addon folder: {addon_path}")

    toc_path = addon_path / "coolstats_Data_RisingGods.toc"
    log_dir = addon_path / "data" / "logs" / "icc"
    header_path = log_dir / "coolstats_uwu_data.lua"
    require_file(toc_path, "Rising Gods data TOC")
    require_file(header_path, "Rising Gods data header")
    if not log_dir.is_dir():
        raise RuntimeError(f"Missing Rising Gods ICC log data directory: {log_dir}")

    unexpected_files = [
        path
        for path in addon_path.rglob("*")
        if path.is_file() and path.suffix.lower() not in {".toc", ".lua"}
    ]
    if unexpected_files:
        joined = ", ".join(str(path) for path in unexpected_files)
        raise RuntimeError(f"Unexpected non-addon files in data addon: {joined}")

    toc_text = read_text(toc_path)
    require_contains(
        toc_text,
        "## Title: |cff00c0ffcoolstats|r Data - Rising-Gods",
        "Rising Gods data TOC title is missing or incorrect.",
    )
    require_contains(toc_text, "## RequiredDeps: coolstats", "Rising Gods data TOC must depend on coolstats.")
    require_contains(toc_text, "## LoadOnDemand: 1", "Rising Gods data TOC must stay load-on-demand.")
    require_contains(
        toc_text,
        "## X-coolstats-Realm: Rising-Gods",
        "Rising Gods realm metadata is missing or incorrect.",
    )
    require_contains(
        toc_text,
        "## X-coolstats-Phase: icc",
        "Rising Gods phase metadata is missing or incorrect.",
    )
    if expected_version:
        require_contains(
            toc_text,
            f"## Version: {expected_version}",
            f"Rising Gods data TOC version does not match {expected_version}.",
        )

    toc_player_count = toc_metadata_int(toc_text, "X-coolstats-PlayerCount")
    toc_chunk_count = toc_metadata_int(toc_text, "X-coolstats-PlayerChunks")
    calculated_chunk_count = expected_player_chunk_count(toc_player_count)
    if toc_chunk_count != calculated_chunk_count:
        raise RuntimeError(
            f"Rising Gods data TOC has {toc_chunk_count} chunks for {toc_player_count} players; "
            f"expected {calculated_chunk_count}."
        )
    if expected_chunk_count <= 0:
        expected_chunk_count = toc_chunk_count
    elif expected_chunk_count != toc_chunk_count:
        raise RuntimeError(
            f"Rising Gods data TOC chunk count {toc_chunk_count} does not match expected {expected_chunk_count}."
        )

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

    header_text = read_text(header_path)
    require_contains(header_text, 'realm = "Rising-Gods"', "Generated header is not for Rising-Gods.")
    require_contains(header_text, 'phaseId = "icc"', "Generated header is not for the ICC phase.")
    require_contains(
        header_text,
        'defaultRaidName = "Icecrown Citadel"',
        "Generated header is missing the ICC default raid.",
    )
    require_contains(
        header_text,
        'source = "https://uwu-logs.xyz/top_points"',
        "Generated header is missing the UwU top-points source.",
    )
    require_contains(
        header_text,
        'topSource = "https://uwu-logs.xyz/top"',
        "Generated header is missing the UwU top source.",
    )
    require_contains(
        header_text,
        'characterSource = "https://uwu-logs.xyz/character"',
        "Generated header is missing the UwU character source.",
    )
    require_match(
        header_text,
        rf"maxPerSpec\s*=\s*{expected_max_per_spec},",
        f"Generated header maxPerSpec does not match {expected_max_per_spec}.",
    )
    require_match(
        header_text,
        r'generatedAt\s*=\s*"\d{4}-\d{2}-\d{2}T',
        "Generated header is missing an ISO generatedAt timestamp.",
    )
    require_contains(
        header_text,
        "players = {},",
        "Generated header must initialize an empty players table before chunks load.",
    )
    require_match(
        header_text,
        rf"totalPlayers\s*=\s*{toc_player_count},",
        "Generated header totalPlayers does not match TOC metadata.",
    )
    require_match(
        header_text,
        rf"playerChunkCount\s*=\s*{toc_chunk_count},",
        "Generated header playerChunkCount does not match TOC metadata.",
    )
    load_steps_match = re.search(r"playerLoadSteps\s*=\s*\{([^}]*)\}", header_text)
    if not load_steps_match:
        raise RuntimeError("Generated header is missing playerLoadSteps.")
    load_steps = [int(value.strip()) for value in load_steps_match.group(1).split(",") if value.strip()]
    if len(load_steps) != toc_chunk_count + 1:
        raise RuntimeError(
            f"Generated header playerLoadSteps has {len(load_steps)} entries; expected {toc_chunk_count + 1}."
        )
    if load_steps[0] != 0 or load_steps[-1] != toc_player_count:
        raise RuntimeError(f"Generated header playerLoadSteps must start at 0 and end at {toc_player_count}.")
    for index in range(1, len(load_steps)):
        if load_steps[index] < load_steps[index - 1]:
            raise RuntimeError("Generated header playerLoadSteps must be non-decreasing.")

    for index, boss in enumerate(REQUIRED_BOSSES, start=1):
        require_contains(header_text, f'[{index}] = "{boss}"', f"Generated header is missing boss {index}: {boss}")

    player_keys: Set[str] = set()
    chunk_counts: List[int] = []
    row_pattern = re.compile(r'(?m)^[\t ]+\["([^"]+)"\][\t ]*=')
    for chunk in chunk_files:
        text = read_text(chunk)
        chunk_index_match = re.search(r"(\d\d)\.lua$", chunk.name)
        if not chunk_index_match:
            raise RuntimeError(f"Unexpected chunk filename: {chunk.name}")
        chunk_index = int(chunk_index_match.group(1))
        expected_start = load_steps[chunk_index - 1] + 1
        require_match(
            text,
            rf"local\s+chunkStartIndex\s*=\s*{expected_start}",
            f"{chunk.name} has an incorrect chunkStartIndex guard.",
        )
        require_contains(text, "ShouldSkipUwUDataChunk", f"{chunk.name} is missing the chunk-skip guard.")
        require_contains(text, "local chunk = {", f"{chunk.name} does not define a chunk table.")
        require_contains(text, "coolstatsUwUData.players", f"{chunk.name} does not merge into coolstatsUwUData.players.")
        require_contains(text, "for key, player in pairs(chunk) do", f"{chunk.name} does not merge chunk rows safely.")
        if re.search(r'", 0, \d+, \d+, nil,', text):
            raise RuntimeError(f"Generated data contains rankless player rows in {chunk.name}.")

        matches = row_pattern.findall(text)
        if not matches:
            raise RuntimeError(f"Generated chunk {chunk.name} has no player rows.")
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
        "chunks": len(chunk_files),
        "min_chunk": min_chunk,
        "max_chunk": max_chunk,
        "max_per_spec": expected_max_per_spec,
    }
    if not quiet:
        print(
            "Rising Gods data integrity passed: "
            f"players={player_count} chunks={len(chunk_files)} "
            f"minChunk={min_chunk} maxChunk={max_chunk} maxPerSpec={expected_max_per_spec}"
        )
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-addon-path", required=True, type=Path)
    parser.add_argument("--expected-version", default="")
    parser.add_argument("--expected-max-per-spec", type=int, default=600)
    parser.add_argument("--min-players", type=int, default=6000)
    parser.add_argument("--max-players", type=int, default=20000)
    parser.add_argument("--expected-chunk-count", type=int, default=0)
    parser.add_argument("--allow-temporary-folder-name", action="store_true")
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
            quiet=args.quiet,
        )
    except RuntimeError as exc:
        print(str(exc))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

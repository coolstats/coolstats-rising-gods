#!/usr/bin/env python3
"""Generate the coolstats UwU Logs tooltip dataset.

The game addon consumes Lua directly, so this script writes both:
- realm_data/coolstats_Data_RisingGods/data/logs/icc/coolstats_uwu_data.lua for WoW
- data/uwu_logs_rising_gods.json for inspection/history

Weekly refresh policy:
- refresh the current top N rows for every class/spec leaderboard
- enrich those active players with any other spec rows available in the same leaderboard responses
- refresh ranked-player boss details from bulk boss leaderboards, not one character at a time
- preserve the per-character endpoint only as a targeted/manual fallback
- keep the generated Rising Gods package ranked-player-only; boss leaderboards must not create rankless players
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


POINTS_ENDPOINT = "https://uwu-logs.xyz/top_points"
TOP_ENDPOINT = "https://uwu-logs.xyz/top"
CHARACTER_ENDPOINT = "https://uwu-logs.xyz/character"
REPO_ROOT = Path(__file__).resolve().parents[1]
ADDON_ROOT = REPO_ROOT if (REPO_ROOT / "coolstats.toc").is_file() else REPO_ROOT / "coolstats"
DEFAULT_BOSS_CACHE_DIR = ADDON_ROOT / "data"
DEFAULT_WEEKLY_BOSS_MAX_AGE_DAYS = 1
DEFAULT_MIN_PLAYERS = 6000
DEFAULT_MAX_PER_SPEC = 600
DEFAULT_BULK_TOP_LIMIT = 10000
DEFAULT_BULK_CHECKPOINT_EVERY = 10
DEFAULT_DUPLICATE_WORKERS = 8
LUA_PLAYER_TARGET_CHUNK_SIZE = 3000
LUA_PLAYER_MIN_CHUNK_COUNT = 6
LUA_PLAYER_MAX_CHUNK_COUNT = 16
PROFILE_VALIDATION_LIMIT = 10
ADDON_VERSION_OVERRIDE = None

CLASSES = [
    "Death Knight",
    "Druid",
    "Hunter",
    "Mage",
    "Paladin",
    "Priest",
    "Rogue",
    "Shaman",
    "Warlock",
    "Warrior",
]

PLAYER_NAME_ALIASES = {}

SPECS = {
    0: {1: "Blood", 2: "Frost", 3: "Unholy"},
    1: {1: "Balance", 2: "Feral Combat", 3: "Restoration"},
    2: {1: "Beast Mastery", 2: "Marksmanship", 3: "Survival"},
    3: {1: "Arcane", 2: "Fire", 3: "Frost"},
    4: {1: "Holy", 2: "Protection", 3: "Retribution"},
    5: {1: "Discipline", 2: "Holy", 3: "Shadow"},
    6: {1: "Assassination", 2: "Combat", 3: "Subtlety"},
    7: {1: "Elemental", 2: "Enhancement", 3: "Restoration"},
    8: {1: "Affliction", 2: "Demonology", 3: "Destruction"},
    9: {1: "Arms", 2: "Fury", 3: "Protection"},
}

ULDUAR_ENCOUNTERS = [
    ("Ignis the Furnace Master", "25N"),
    ("Razorscale", "25N"),
    ("XT-002 Deconstructor", "25H"),
    ("Assembly of Iron", "25H"),
    ("Kologarn", "25N"),
    ("Auriaya", "25N"),
    ("Hodir", "25N"),
    ("Thorim", "25H"),
    ("Freya", "25H"),
    ("Mimiron", "25H"),
    ("General Vezax", "25H"),
    ("Yogg-Saron", "25H"),
    ("Algalon the Observer", "25N"),
    ("Emalon the Storm Watcher", "25N"),
]

ONYXIA_TOC_ENCOUNTERS = [
    ("Northrend Beasts", "25H"),
    ("Lord Jaraxxus", "25H"),
    ("Faction Champions", "25H"),
    ("Twin Val'kyr", "25H"),
    ("Anub'arak", "25H"),
    ("Koralon the Flame Watcher", "25N"),
]

ONYXIA_TOC_RETAINED_BOSSES = [
    "Algalon the Observer",
]

ICC_ERA_ENCOUNTERS = [
    ("Lord Marrowgar", "25H"),
    ("Lady Deathwhisper", "25H"),
    ("Deathbringer Saurfang", "25H"),
    ("Festergut", "25H"),
    ("Rotface", "25H"),
    ("Professor Putricide", "25H"),
    ("Blood Prince Council", "25H"),
    ("Blood-Queen Lana'thel", "25H"),
    ("Sindragosa", "25H"),
    ("The Lich King", "25H"),
    ("Toravon the Ice Watcher", "25N"),
    ("Halion", "25H"),
    ("Anub'arak", "25H"),
]

REALM_DEFAULT_PHASES = {
    "risinggods": "icc",
}

REALM_PHASE_PROFILES = {
    "risinggods": {
        "icc": {
            "phase_id": "icc",
            "default_raid_name": "Icecrown Citadel",
            "encounters": ICC_ERA_ENCOUNTERS,
            "addon_name": "coolstats_Data_RisingGods",
            "data_slug": "rising_gods",
            "preserve_previous_players": False,
            "include_boss_only_players": False,
        },
    },
}

BOSS_ORDER = []
ENCOUNTERS = []
RETAINED_BOSSES = []

RANKS_PENALTY = (
    (100, 0.0001),
    (200, 0.00009),
    (300, 0.00008),
    (400, 0.00007),
    (500, 0.00006),
    (1000, 0.00005),
    (2000, 0.00004),
    (10000, 0.00003),
    (75000, 0.00001),
    (10**9, 0.0),
)


def log(message: str) -> None:
    print(message, flush=True)


def format_name_preview(names, limit: int = 25) -> str:
    values = sorted(str(name) for name in names if str(name))
    if not values:
        return "none"
    preview = ", ".join(values[:limit])
    remaining = len(values) - limit
    if remaining > 0:
        preview += f", ... (+{remaining} more)"
    return f"{len(values)} total: {preview}"


def normalize_name(name: str) -> str:
    return "".join(str(name).strip().lower().split())


def normalize_server_key(server: str) -> str:
    return "".join(character for character in str(server).strip().lower() if character.isalnum())


def configure_realm_profile(server: str, phase_id: str | None = None) -> dict:
    server_key = normalize_server_key(server)
    phase_profiles = REALM_PHASE_PROFILES.get(server_key)
    if not phase_profiles:
        supported = ", ".join(sorted(REALM_PHASE_PROFILES))
        raise ValueError(f"Unsupported server profile {server!r}; expected one of: {supported}")
    selected_phase = normalize_name(phase_id) if phase_id else get_active_phase_id(server)
    profile = phase_profiles.get(selected_phase)
    if not profile:
        supported = ", ".join(sorted(phase_profiles))
        raise ValueError(f"Unsupported phase {phase_id!r} for {server}; expected one of: {supported}")
    ENCOUNTERS[:] = profile["encounters"]
    RETAINED_BOSSES[:] = profile.get("retained_bosses") or []
    BOSS_ORDER[:] = [boss_name for boss_name, _ in ENCOUNTERS] + list(RETAINED_BOSSES)
    return profile


def default_lua_path(server: str, profile: dict) -> Path:
    addon_name = profile["addon_name"]
    return ADDON_ROOT / "realm_data" / addon_name / "data" / "logs" / profile["phase_id"] / "coolstats_uwu_data.lua"


def default_json_path(server: str, profile: dict) -> Path:
    server_key = normalize_server_key(server)
    phase_suffix = "" if profile["phase_id"] == REALM_DEFAULT_PHASES[server_key] else f"_{profile['phase_id']}"
    return ADDON_ROOT / "data" / f"uwu_logs_{profile['data_slug']}{phase_suffix}.json"


def read_core_addon_version() -> str:
    if ADDON_VERSION_OVERRIDE:
        return ADDON_VERSION_OVERRIDE
    toc_path = ADDON_ROOT / "coolstats.toc"
    try:
        for line in toc_path.read_text(encoding="utf-8").splitlines():
            if line.startswith("## Version:"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return "0.0.0"


def get_realm_manifest_path(server: str) -> Path:
    server_key = normalize_server_key(server)
    default_phase = REALM_DEFAULT_PHASES[server_key]
    addon_name = REALM_PHASE_PROFILES[server_key][default_phase]["addon_name"]
    return ADDON_ROOT / "realm_data" / addon_name / f"{addon_name}.toc"


def get_active_phase_id(server: str) -> str:
    server_key = normalize_server_key(server)
    profiles = REALM_PHASE_PROFILES.get(server_key) or {}
    toc_path = get_realm_manifest_path(server)
    try:
        for line in toc_path.read_text(encoding="utf-8").splitlines():
            if line.startswith("## X-coolstats-Phase:"):
                phase_id = normalize_name(line.split(":", 1)[1])
                if phase_id in profiles:
                    return phase_id
    except OSError:
        pass
    return REALM_DEFAULT_PHASES[server_key]


def get_lua_player_chunk_count(player_count: int | None) -> int:
    player_count = max(0, int(player_count or 0))
    if player_count <= 0:
        return 1
    chunk_count = max(1, (player_count + LUA_PLAYER_TARGET_CHUNK_SIZE - 1) // LUA_PLAYER_TARGET_CHUNK_SIZE)
    if player_count >= DEFAULT_MIN_PLAYERS:
        chunk_count = max(LUA_PLAYER_MIN_CHUNK_COUNT, chunk_count)
    return min(LUA_PLAYER_MAX_CHUNK_COUNT, chunk_count)


def write_data_addon_manifest(
    lua_path: Path,
    server: str,
    phase_id: str,
    profile: dict,
    player_count: int | None = None,
    chunk_count: int | None = None,
) -> Path | None:
    addon_root = lua_path.parents[3]
    addon_name = profile["addon_name"]
    if addon_root.name != addon_name:
        raise ValueError(f"Realm data output must live under an addon folder named {addon_name}: {lua_path}")

    chunk_count = int(chunk_count or get_lua_player_chunk_count(player_count))
    chunk_files = sorted(lua_path.parent.glob(f"{lua_path.stem}_[0-9][0-9]{lua_path.suffix}"))
    if len(chunk_files) != chunk_count:
        raise ValueError(f"Realm data output has {len(chunk_files)} chunks for {server}, expected {chunk_count}: {lua_path.parent}")
    data_files = [lua_path]
    data_files.extend(chunk_files)
    if not all(path.is_file() for path in data_files):
        raise ValueError(f"Realm data output is incomplete for {server}: {lua_path}")

    toc_path = addon_root / f"{addon_name}.toc"
    lines = [
        "## Interface: 30300",
        f"## Title: |cff00c0ffcoolstats|r Data - {server}",
        f"## Notes: Realm-specific UwU Logs data for {server}.",
        "## Author: coolstats",
        f"## Version: {read_core_addon_version()}",
        "## DefaultState: Enabled",
        "## LoadOnDemand: 1",
        "## RequiredDeps: coolstats",
        f"## X-coolstats-Realm: {server}",
        f"## X-coolstats-Phase: {phase_id}",
        f"## X-coolstats-PlayerCount: {int(player_count or 0)}",
        f"## X-coolstats-PlayerChunks: {chunk_count}",
        "",
    ]
    lines.extend(str(path.relative_to(addon_root)).replace("/", "\\") for path in data_files)
    toc_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return toc_path


def canonical_player_name(name: str) -> str:
    stripped = str(name).strip()
    return PLAYER_NAME_ALIASES.get(normalize_name(stripped), stripped)


def canonical_player_key(name: str) -> str:
    return normalize_name(canonical_player_name(name))


def lua_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def lua_string_or_nil(value: str | None) -> str:
    return lua_string(value) if value is not None else "nil"


def lua_number_or_nil(value, integer: bool = True) -> str:
    if value is None:
        return "nil"
    try:
        number = float(value)
    except (TypeError, ValueError):
        return "nil"
    if integer:
        return str(int(round(number)))
    return f"{number:.2f}".rstrip("0").rstrip(".")


def decode_response(raw: bytes) -> str:
    if raw.startswith(b"\x1f\x8b"):
        raw = gzip.decompress(raw)
    return raw.decode("utf-8")


def post_json(endpoint: str, payload: dict, timeout: int, retries: int):
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    request = Request(
        endpoint,
        data=body,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "coolstats-uwu-updater/1.0",
        },
        method="POST",
    )

    for attempt in range(retries + 1):
        try:
            with urlopen(request, timeout=timeout) as response:
                raw = response.read()
            data = json.loads(decode_response(raw))
            return data
        except (HTTPError, URLError, TimeoutError, UnicodeDecodeError, gzip.BadGzipFile) as exc:
            if attempt >= retries:
                raise
            retry_after = None
            if isinstance(exc, HTTPError) and exc.code == 429:
                retry_after = exc.headers.get("Retry-After")
            try:
                delay = float(retry_after) if retry_after else None
            except (TypeError, ValueError):
                delay = None
            time.sleep(delay or (2 + attempt * 2 if isinstance(exc, HTTPError) and exc.code == 429 else 1 + attempt))


def fetch_points(server: str, class_i: int, spec_i: int, timeout: int, retries: int) -> list[list]:
    data = post_json(
        POINTS_ENDPOINT,
        {"server": server, "class_i": class_i, "spec_i": spec_i},
        timeout,
        retries,
    )
    if not isinstance(data, list):
        raise ValueError(f"Unexpected response shape for class={class_i} spec={spec_i}")
    return data


def fetch_character(server: str, name: str, spec_i: int, timeout: int, retries: int) -> dict:
    data = post_json(
        CHARACTER_ENDPOINT,
        {"server": server, "name": name, "spec_i": spec_i},
        timeout,
        retries,
    )
    if not isinstance(data, dict):
        raise ValueError(f"Unexpected character response shape for {name}")
    return data


def fetch_top(
    server: str,
    boss_name: str,
    mode: str,
    class_i: int,
    spec_i: int,
    limit: int,
    timeout: int,
    retries: int,
) -> list[list]:
    data = post_json(
        TOP_ENDPOINT,
        {
            "server": server,
            "boss": boss_name,
            "mode": mode,
            "best_only": False,
            "class_i": class_i,
            "spec_i": spec_i,
            "limit": limit,
            "externals": True,
        },
        timeout,
        retries,
    )
    if not isinstance(data, list):
        raise ValueError(f"Unexpected top response shape for {boss_name} class={class_i} spec={spec_i}")
    return data


def point_score_to_centi(value) -> int | None:
    if value is None:
        return None
    try:
        return int(round(float(value)))
    except (TypeError, ValueError):
        return None


def percent_score_to_centi(value) -> int | None:
    if value is None:
        return None
    try:
        return int(round(float(value) * 100))
    except (TypeError, ValueError):
        return None


def parse_points_row(row: list, class_i: int, spec_i: int, rank: int) -> dict | None:
    if len(row) < 2:
        return None

    display_name = canonical_player_name(row[0])
    key = canonical_player_key(display_name)
    if not key or key.startswith("unknown-"):
        return None

    try:
        score_centi = int(round(float(row[1]) * 100))
    except (TypeError, ValueError):
        return None

    raw_points = int(row[2]) if len(row) > 2 and row[2] is not None else 0
    return {
        "key": key,
        "name": display_name,
        "class_i": class_i,
        "spec_i": spec_i,
        "rank": rank,
        "score_centi": score_centi,
        "raw_points": raw_points,
    }


def ranking_row_identity(row: dict) -> tuple[str, int, int]:
    return (row["key"], row["class_i"], row["spec_i"])


def find_ambiguous_ranking_groups(rows_by_spec: list[list[dict]]) -> dict[tuple[str, int, int], list[dict]]:
    rows_by_identity: dict[tuple[str, int, int], list[dict]] = {}
    identities_by_key: dict[str, set[tuple[str, int, int]]] = {}
    for parsed_rows in rows_by_spec:
        for row in parsed_rows:
            identity = ranking_row_identity(row)
            rows_by_identity.setdefault(identity, []).append(row)
            identities_by_key.setdefault(row["key"], set()).add(identity)

    ambiguous_identities = {
        identity
        for identity, rows in rows_by_identity.items()
        if len(rows) > 1
    }
    for identities in identities_by_key.values():
        class_ids = {identity[1] for identity in identities}
        if len(class_ids) > 1:
            ambiguous_identities.update(identities)

    return {
        identity: rows_by_identity[identity]
        for identity in ambiguous_identities
    }


def character_overall_score_centi(character: dict) -> int | None:
    return point_score_to_centi(character.get("overall_points"))


def character_overall_rank(character: dict) -> int | None:
    try:
        return int(character.get("overall_rank"))
    except (TypeError, ValueError):
        return None


def select_current_duplicate_ranking_row(rows: list[dict], character: dict) -> dict | None:
    if not rows:
        return None
    class_i = rows[0]["class_i"]
    try:
        character_class_i = int(character.get("class_i"))
    except (TypeError, ValueError):
        return None
    if character_class_i != class_i:
        return None

    expected_score = character_overall_score_centi(character)
    expected_rank = character_overall_rank(character)
    if expected_score is None or expected_score <= 0 or expected_rank is None:
        return None

    exact_matches = [
        row
        for row in rows
        if row["rank"] == expected_rank and abs(row["score_centi"] - expected_score) <= 1
    ]
    if exact_matches:
        return exact_matches[0]

    score_matches = [
        row
        for row in rows
        if abs(row["score_centi"] - expected_score) <= 1
    ]
    if score_matches:
        return min(score_matches, key=lambda row: abs(row["rank"] - expected_rank))
    return None


def resolve_duplicate_ranking_rows(
    server: str,
    rows_by_spec: list[list[dict]],
    timeout: int,
    retries: int,
    sleep: float,
    workers: int = DEFAULT_DUPLICATE_WORKERS,
) -> tuple[dict[tuple[str, int, int], dict | None], set[str], dict]:
    ambiguous_groups = find_ambiguous_ranking_groups(rows_by_spec)
    choices: dict[tuple[str, int, int], dict | None] = {}
    repaired_keys: set[str] = set()
    summary = {
        "groups": len(ambiguous_groups),
        "resolved": 0,
        "skipped": 0,
        "failed": 0,
        "boss_repair_targets": 0,
    }
    if not ambiguous_groups:
        return choices, repaired_keys, summary

    items = sorted(ambiguous_groups.items(), key=lambda item: (item[0][0], item[0][1], item[0][2]))
    workers = max(1, min(int(workers or 1), len(items)))
    log(f"duplicate rankings: checking {len(items)} ambiguous name/spec groups with {workers} workers")

    def resolve_one(item: tuple[tuple[str, int, int], list[dict]]) -> tuple[tuple[str, int, int], dict | None, tuple[str, str | None]]:
        identity, rows = item
        key, class_i, spec_i = identity
        name = rows[0]["name"]
        try:
            character = fetch_character(server, name, spec_i, timeout, retries)
        except (HTTPError, URLError, TimeoutError, ValueError) as exc:
            return identity, None, (
                "failed",
                f"warning: failed duplicate ranking repair for {name} {CLASSES[class_i]} {SPECS[class_i].get(spec_i, spec_i)}: {exc}",
            )
        selected = select_current_duplicate_ranking_row(rows, character)
        if selected:
            return identity, selected, ("resolved", None)
        return identity, None, (
            "skipped",
            f"warning: skipped ambiguous duplicate ranking for {name} {CLASSES[class_i]} {SPECS[class_i].get(spec_i, spec_i)}",
        )

    results = []
    if workers == 1:
        for item in items:
            if sleep > 0:
                time.sleep(sleep)
            results.append(resolve_one(item))
    else:
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {executor.submit(resolve_one, item): item[0] for item in items}
            for future in as_completed(futures):
                results.append(future.result())

    warning_count = 0
    for identity, selected, outcome in sorted(results, key=lambda item: (item[0][0], item[0][1], item[0][2])):
        choices[identity] = selected
        status, message = outcome or ("skipped", None)
        if selected:
            repaired_keys.add(identity[0])
        if status in summary:
            summary[status] += 1
        if message and warning_count < 20:
            log(message)
            warning_count += 1

    summary["boss_repair_targets"] = len(repaired_keys)
    log(
        "duplicate rankings: "
        f"{summary['resolved']} resolved, "
        f"{summary['skipped']} skipped, "
        f"{summary['failed']} failed, "
        f"{summary['boss_repair_targets']} boss repair targets"
    )
    return choices, repaired_keys, summary


def is_selected_ranking_row(row: dict, duplicate_choices: dict[tuple[str, int, int], dict | None]) -> bool:
    identity = ranking_row_identity(row)
    if identity not in duplicate_choices:
        return True
    return duplicate_choices[identity] is row


def top_row_dps(useful_amount: float, duration: float) -> float | None:
    if duration <= 0:
        return None
    if duration > 10000:
        return useful_amount * 1000 / duration
    return useful_amount / duration


def parse_top_row(row: list, rank_raids: int) -> dict | None:
    if len(row) < 6:
        return None
    display_name = canonical_player_name(row[3])
    key = canonical_player_key(display_name)
    if not key or key.startswith("unknown-"):
        return None
    try:
        duration = float(row[1])
        useful_amount = float(row[4])
    except (TypeError, ValueError):
        return None
    dps = top_row_dps(useful_amount, duration)
    if dps is None:
        return None

    guid = row[2] if row[2] is not None else key
    return {
        "key": key,
        "name": display_name,
        "guid": str(guid),
        "rank_raids": rank_raids,
        "dps": dps,
    }


def rank_formula_score(rank: int) -> float:
    if rank <= 1:
        return 1.0
    score = 1.0
    previous_limit = 1
    for limit, penalty in RANKS_PENALTY:
        if rank <= previous_limit:
            break
        ranks_in_bucket = min(rank, limit) - previous_limit
        if ranks_in_bucket > 0:
            score -= ranks_in_bucket * penalty
        previous_limit = limit
    return max(0.0, min(1.0, score))


def bounded_rank_score(rank: int, population: int) -> float:
    if rank <= 1:
        return 1.0
    if population <= 1:
        return 0.0
    return max(0.0, min(1.0, (population - rank) / (population - 1)))


def boss_score_centi(rank_players: int, rank_raids: int, player_count: int, raid_count: int, dps: float, top_dps: float) -> int:
    player_score = bounded_rank_score(rank_players, player_count)
    raid_score = rank_formula_score(rank_raids) if raid_count >= 10000 else bounded_rank_score(rank_raids, raid_count)
    dps_score = max(0.0, min(1.0, dps / top_dps)) if top_dps > 0 else 0.0
    return int(round(max(player_score, raid_score, dps_score) * 10000))


def apply_points_row(player: dict, row: dict) -> None:
    spec_i = row["spec_i"]
    player["specs"][spec_i] = row["score_centi"]
    player["spec_ranks"][spec_i] = row["rank"]
    if row["score_centi"] > player["score_centi"]:
        player["name"] = row["name"]
        player["class_i"] = row["class_i"]
        player["best_spec_i"] = spec_i
        player["score_centi"] = row["score_centi"]
        player["raw_points"] = row["raw_points"]
        player["spec_rank"] = row["rank"]


def default_boss_cache_path(server: str, profile: dict) -> Path:
    server_key = normalize_server_key(server)
    phase_suffix = "" if profile["phase_id"] == REALM_DEFAULT_PHASES[server_key] else f"_{profile['phase_id']}"
    return DEFAULT_BOSS_CACHE_DIR / f"uwu_character_boss_cache_{profile['data_slug']}{phase_suffix}.json"


def load_boss_cache(path: Path | None, server: str) -> dict:
    if not path or not path.is_file():
        return {"server": server, "entries": {}}
    try:
        cache = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"server": server, "entries": {}}
    if cache.get("server") != server or not isinstance(cache.get("entries"), dict):
        return {"server": server, "entries": {}}
    normalize_boss_cache_aliases(cache["entries"])
    return cache


def normalize_boss_cache_aliases(cache_entries: dict) -> None:
    for entry_key in list(cache_entries):
        if ":" not in entry_key:
            continue
        name_key, spec_i = entry_key.rsplit(":", 1)
        canonical_key = f"{canonical_player_key(name_key)}:{spec_i}"
        if canonical_key == entry_key:
            continue
        entry = cache_entries.pop(entry_key)
        if isinstance(entry, dict):
            entry["name"] = canonical_player_name(name_key)
        cache_entries.setdefault(canonical_key, entry)


def write_boss_cache(path: Path | None, cache: dict) -> None:
    if not path:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(cache.get("entries"), dict):
        normalize_boss_cache_aliases(cache["entries"])
    cache["updated_at"] = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    path.write_text(json.dumps(cache, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def get_boss_cache_key_for_spec(player: dict, spec_i: int) -> str:
    return f"{canonical_player_key(player['name'])}:{spec_i}"


def get_boss_cache_key(player: dict) -> str:
    spec_i = player.get("best_spec_i", player.get("spec_i"))
    return get_boss_cache_key_for_spec(player, spec_i)


def get_cached_spec_i(cached: dict | None, default_spec_i: int | None = None) -> int | None:
    if not cached:
        return default_spec_i
    try:
        return int(cached.get("spec_i") or default_spec_i)
    except (TypeError, ValueError):
        return default_spec_i


def parse_utc_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def is_boss_cache_fresh(cached: dict | None, max_age_days: float | None, now: datetime) -> bool:
    if not cached or not isinstance(cached.get("bosses"), dict):
        return False
    if max_age_days is None:
        return False
    fetched_at = parse_utc_datetime(cached.get("fetched_at"))
    if not fetched_at:
        return False
    return now - fetched_at <= timedelta(days=max_age_days)


def find_boss_cache_entry(cache_entries: dict, player: dict, allow_name_fallback: bool) -> tuple[str | None, dict | None]:
    cache_key = get_boss_cache_key(player)
    cached = cache_entries.get(cache_key)
    if cached or not allow_name_fallback:
        return cache_key, cached

    name_prefix = f"{canonical_player_key(player['name'])}:"
    for entry_key, candidate in cache_entries.items():
        if entry_key.startswith(name_prefix):
            return entry_key, candidate
    return cache_key, None


def merge_cached_spec_bosses(player: dict, refreshed_spec_bosses: dict, cache_entries: dict | None) -> dict:
    if not cache_entries:
        return refreshed_spec_bosses
    for spec_i in sorted(player.get("specs") or {player.get("best_spec_i"): True}):
        if spec_i is None:
            continue
        cache_key = get_boss_cache_key_for_spec(player, spec_i)
        cached = cache_entries.get(cache_key)
        if not cached or not isinstance(cached.get("bosses"), dict):
            continue
        cached_bosses = {
            boss_name: boss
            for boss_name, boss in cached["bosses"].items()
            if isinstance(boss, dict)
        }
        if not cached_bosses:
            continue
        merged = dict(cached_bosses)
        merged.update(refreshed_spec_bosses.get(spec_i) or {})
        refreshed_spec_bosses[spec_i] = merged
    return refreshed_spec_bosses


def summarize_active_boss_cache(data: dict, cache_entries: dict | None, max_age_days: float | None) -> dict:
    summary = {
        "fresh": 0,
        "stale": 0,
        "missing": 0,
        "total": 0,
        "max_age_days": max_age_days,
    }
    if not cache_entries:
        summary["missing"] = sum(1 for player in data["players"].values() if player.get("active", True))
        summary["total"] = summary["missing"]
        return summary

    now = datetime.now(timezone.utc)
    for player in data["players"].values():
        if not player.get("active", True):
            continue
        spec_indices = sorted(player.get("specs") or {player.get("best_spec_i"): True})
        for spec_i in spec_indices:
            summary["total"] += 1
            cached = cache_entries.get(get_boss_cache_key_for_spec(player, spec_i))
            if not cached:
                summary["missing"] += 1
            elif is_boss_cache_fresh(cached, max_age_days, now):
                summary["fresh"] += 1
            else:
                summary["stale"] += 1
    return summary


def collect_scores(
    server: str,
    max_per_spec: int,
    timeout: int,
    retries: int,
    sleep: float,
    duplicate_workers: int = DEFAULT_DUPLICATE_WORKERS,
) -> dict:
    players = {}
    fetched = []
    failed_leaderboards = []
    rows_by_spec = []

    for class_i, class_name in enumerate(CLASSES):
        for spec_i, spec_name in SPECS[class_i].items():
            try:
                rows = fetch_points(server, class_i, spec_i, timeout, retries)
            except (HTTPError, URLError, TimeoutError, ValueError) as exc:
                log(f"warning: failed {class_name} {spec_name}: {exc}")
                rows = []
                failed_leaderboards.append(f"{class_name} {spec_name}")

            parsed_rows = []
            retained = 0
            for rank, row in enumerate(rows, 1):
                parsed = parse_points_row(row, class_i, spec_i, rank)
                if not parsed:
                    continue
                parsed_rows.append(parsed)

            rows_by_spec.append(parsed_rows)
            fetched.append(
                {
                    "class": class_name,
                    "spec": spec_name,
                    "rows": len(rows),
                    "retained": retained,
                }
            )
            log(f"{class_name:12} {spec_name:14} {len(rows):5} rows")

            if sleep > 0:
                time.sleep(sleep)

    duplicate_choices, duplicate_repair_keys, duplicate_summary = resolve_duplicate_ranking_rows(
        server,
        rows_by_spec,
        timeout,
        retries,
        sleep,
        duplicate_workers,
    )

    active_keys = set()
    duplicate_boss_repair_keys = set()
    for index, parsed_rows in enumerate(rows_by_spec):
        filtered_rows = [
            row
            for row in parsed_rows
            if is_selected_ranking_row(row, duplicate_choices)
        ]
        rows_by_spec[index] = filtered_rows
        retained = 0
        for row in filtered_rows:
            if row["rank"] <= max_per_spec:
                active_keys.add(row["key"])
                retained += 1
                if row["key"] in duplicate_repair_keys:
                    duplicate_boss_repair_keys.add(row["key"])
        fetched[index]["retained"] = retained

    for parsed_rows in rows_by_spec:
        for row in parsed_rows:
            key = row["key"]
            if key not in active_keys:
                continue
            player = players.setdefault(
                key,
                {
                    "name": row["name"],
                    "class_i": row["class_i"],
                    "best_spec_i": row["spec_i"],
                    "score_centi": row["score_centi"],
                    "raw_points": row["raw_points"],
                    "spec_rank": row["rank"],
                    "specs": {},
                    "spec_ranks": {},
                    "active": True,
                },
            )
            apply_points_row(player, row)

    return {
        "players": players,
        "fetched": fetched,
        "failed_leaderboards": failed_leaderboards,
        "boss_names": [],
        "active_player_keys": active_keys,
        "duplicate_rankings": duplicate_summary,
        "duplicate_boss_repair_keys": duplicate_boss_repair_keys,
    }


def json_bosses_to_internal(bosses_payload: dict | None) -> dict:
    bosses = {}
    for boss_name, boss in (bosses_payload or {}).items():
        if not isinstance(boss, dict):
            continue
        if boss.get("score_centi") is not None:
            boss_score_centi = point_score_to_centi(boss.get("score_centi"))
        else:
            boss_score_centi = percent_score_to_centi(boss.get("score"))
        if boss_score_centi is None:
            continue
        bosses[boss_name] = {
            "score_centi": boss_score_centi,
            "rank_players": boss.get("rank_players"),
            "rank_raids": boss.get("rank_raids"),
            "dps": boss.get("dps"),
        }
    return bosses


def json_player_to_internal(key: str, player: dict) -> dict | None:
    try:
        class_i = int(player["class_i"])
        spec_i = int(player["spec_i"])
        player_score_centi = int(player["score_centi"])
    except (KeyError, TypeError, ValueError):
        return None
    try:
        spec_rank = int(player["spec_rank"]) if player.get("spec_rank") is not None else None
    except (TypeError, ValueError):
        spec_rank = None
    if class_i not in range(len(CLASSES)) or spec_i not in SPECS[class_i]:
        return None

    reverse_specs = {spec_name: spec_index for spec_index, spec_name in SPECS[class_i].items()}
    specs = {}
    spec_ranks = {}
    for spec_name, score in (player.get("specs") or {}).items():
        spec_index = reverse_specs.get(spec_name)
        score_value = percent_score_to_centi(score)
        if spec_index and score_value is not None:
            specs[spec_index] = score_value
    if spec_i in specs:
        player_score_centi = specs[spec_i]
    for spec_name, rank in (player.get("spec_ranks") or {}).items():
        spec_index = reverse_specs.get(spec_name)
        if spec_index:
            try:
                spec_ranks[spec_index] = int(rank)
            except (TypeError, ValueError):
                pass

    bosses = json_bosses_to_internal(player.get("bosses"))
    spec_bosses = {}
    for spec_name, spec_boss_payload in (player.get("spec_bosses") or {}).items():
        spec_index = reverse_specs.get(spec_name)
        if spec_index:
            parsed_bosses = json_bosses_to_internal(spec_boss_payload)
            if parsed_bosses:
                spec_bosses[spec_index] = parsed_bosses
    if bosses and spec_i not in spec_bosses:
        spec_bosses[spec_i] = bosses

    phase_history = {}
    for phase_id, historical in (player.get("phase_history") or {}).items():
        if not isinstance(historical, dict):
            continue
        score_centi = point_score_to_centi(historical.get("score_centi"))
        rank = historical.get("rank")
        try:
            rank = int(rank) if rank is not None else None
        except (TypeError, ValueError):
            rank = None
        if score_centi is not None:
            phase_history[normalize_name(phase_id)] = {
                "score_centi": score_centi,
                "rank": rank,
            }

    return {
        "name": canonical_player_name(player.get("name") or key),
        "class_i": class_i,
        "best_spec_i": spec_i,
        "score_centi": player_score_centi,
        "raw_points": int(player.get("raw_points") or 0),
        "spec_rank": spec_rank,
        "specs": specs or {spec_i: player_score_centi},
        "spec_ranks": spec_ranks or ({spec_i: spec_rank} if spec_rank is not None else {}),
        "bosses": bosses,
        "spec_bosses": spec_bosses,
        "phase_history": phase_history,
        "active": bool(player.get("active", False)),
    }


def load_previous_json_players(path: Path, server: str) -> tuple[dict, list[str]]:
    if not path.is_file():
        return {}, []
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}, []
    if payload.get("server") != server or not isinstance(payload.get("players"), dict):
        return {}, []

    source_phase_id = normalize_name(payload.get("phase_id"))
    players = {}
    for key, player in payload["players"].items():
        converted = json_player_to_internal(key, player)
        if converted:
            had_phase_history = bool(converted.get("phase_history"))
            if (
                source_phase_id
                and converted.get("score_centi", 0) > 0
                and (converted.get("active") or not had_phase_history)
            ):
                converted.setdefault("phase_history", {}).setdefault(
                    source_phase_id,
                    {
                        "score_centi": converted["score_centi"],
                        "rank": converted["spec_rank"],
                    },
                )
            players[canonical_player_key(converted["name"])] = converted
    return players, list(payload.get("bosses") or [])


def fill_player_bosses_from_cache(player: dict, boss_cache_entries: dict | None) -> bool:
    if not boss_cache_entries:
        return False
    changed = False
    spec_bosses = player.setdefault("spec_bosses", {})

    for spec_i in sorted(player.get("specs") or {}):
        if spec_i in spec_bosses:
            continue
        cached = boss_cache_entries.get(get_boss_cache_key_for_spec(player, spec_i))
        if cached and isinstance(cached.get("bosses"), dict):
            spec_bosses[spec_i] = cached["bosses"]
            if spec_i == player.get("best_spec_i") and not player.get("bosses"):
                player["bosses"] = cached["bosses"]
            changed = True

    if not player.get("bosses"):
        cached = boss_cache_entries.get(get_boss_cache_key(player))
    else:
        cached = None
    if not cached and not player.get("bosses"):
        name_prefix = f"{canonical_player_key(player['name'])}:"
        for cache_key, candidate in boss_cache_entries.items():
            if cache_key.startswith(name_prefix):
                cached = candidate
                break
    if cached and isinstance(cached.get("bosses"), dict):
        player["bosses"] = cached["bosses"]
        spec_i = get_cached_spec_i(cached, player.get("best_spec_i"))
        if spec_i:
            spec_bosses.setdefault(spec_i, cached["bosses"])
        return True
    return changed


def merge_previous_players(
    data: dict,
    previous_players: dict,
    previous_boss_names: list[str],
    boss_cache_entries: dict | None = None,
) -> None:
    current_players = data["players"]
    active_keys = data.get("active_player_keys") or set(current_players)
    active_bosses_refreshed = bool(data.get("bosses_refreshed_from_top"))
    for key, player in current_players.items():
        player["active"] = key in active_keys
        previous = previous_players.get(key)
        if previous and previous.get("phase_history"):
            player.setdefault("phase_history", {}).update(previous["phase_history"])
        if previous and not active_bosses_refreshed:
            if previous.get("spec_bosses"):
                spec_bosses = player.setdefault("spec_bosses", {})
                for spec_i, bosses in previous["spec_bosses"].items():
                    spec_bosses.setdefault(spec_i, bosses)
            if not player.get("bosses"):
                best_bosses = previous.get("bosses") or player.get("spec_bosses", {}).get(player.get("best_spec_i"))
                if best_bosses:
                    player["bosses"] = best_bosses
            elif previous.get("bosses"):
                for boss_name, boss in previous["bosses"].items():
                    player["bosses"].setdefault(boss_name, boss)
        if previous and RETAINED_BOSSES:
            previous_spec_bosses = previous.get("spec_bosses") or {}
            player_spec_bosses = player.setdefault("spec_bosses", {})
            for spec_i, previous_bosses in previous_spec_bosses.items():
                retained = {
                    boss_name: boss
                    for boss_name, boss in previous_bosses.items()
                    if boss_name in RETAINED_BOSSES
                }
                if retained:
                    player_spec_bosses.setdefault(spec_i, {}).update(retained)
            previous_bosses = previous.get("bosses") or {}
            retained = {
                boss_name: boss
                for boss_name, boss in previous_bosses.items()
                if boss_name in RETAINED_BOSSES
            }
            if retained:
                player.setdefault("bosses", {}).update(retained)
        fill_player_bosses_from_cache(player, boss_cache_entries)

    restored = 0
    for key, player in previous_players.items():
        if key in current_players:
            continue
        player["active"] = False
        fill_player_bosses_from_cache(player, boss_cache_entries)
        current_players[key] = player
        restored += 1

    if previous_boss_names:
        boss_names_seen = set(data.get("boss_names") or [])
        boss_names_seen.update(previous_boss_names)
        extra_bosses = sorted(boss_names_seen - set(BOSS_ORDER))
        data["boss_names"] = [name for name in BOSS_ORDER if name in boss_names_seen] + extra_bosses
    if restored:
        log(f"preserved {restored} previous players outside current top lists")


def merge_retained_bosses(target: dict, source: dict | None) -> dict:
    for boss_name, boss in (source or {}).items():
        if boss_name in RETAINED_BOSSES:
            target.setdefault(boss_name, boss)
    return target


def boss_result_sort_key(boss: dict | None) -> tuple:
    boss = boss or {}

    def inverse_rank(value) -> int:
        try:
            return -int(value)
        except (TypeError, ValueError):
            return -(10**9)

    try:
        score_centi = int(boss.get("score_centi") or 0)
    except (TypeError, ValueError):
        score_centi = 0
    try:
        dps = float(boss.get("dps") or 0)
    except (TypeError, ValueError):
        dps = 0
    return (
        score_centi,
        inverse_rank(boss.get("rank_players")),
        inverse_rank(boss.get("rank_raids")),
        dps,
    )


def select_boss_only_best_spec(player: dict) -> None:
    if not player.get("boss_only"):
        return
    current_bosses = set(BOSS_ORDER) - set(RETAINED_BOSSES)
    candidates = []
    for spec_i, bosses in (player.get("spec_bosses") or {}).items():
        current_results = [
            boss
            for boss_name, boss in (bosses or {}).items()
            if boss_name in current_bosses
        ]
        if not current_results:
            continue
        candidates.append(
            (
                max(boss_result_sort_key(boss) for boss in current_results),
                len(current_results),
                -spec_i,
                spec_i,
            )
        )
    if candidates:
        player["best_spec_i"] = max(candidates)[3]


def coherent_player_bosses(player: dict) -> dict:
    """Return one specialization's boss data; never synthesize a cross-spec set."""
    best_spec_bosses = (player.get("spec_bosses") or {}).get(player.get("best_spec_i"))
    return dict(best_spec_bosses or {})


def rebuild_player_boss_aggregates(data: dict) -> None:
    for player in data["players"].values():
        select_boss_only_best_spec(player)
        player["bosses"] = coherent_player_bosses(player)


def retained_boss_snapshot(players: dict, boss_name: str) -> dict:
    snapshot = {}
    for key, player in players.items():
        candidates = []
        aggregate = (player.get("bosses") or {}).get(boss_name)
        if aggregate:
            candidates.append(aggregate)
        for bosses in (player.get("spec_bosses") or {}).values():
            candidate = (bosses or {}).get(boss_name)
            if candidate:
                candidates.append(candidate)
        if candidates:
            snapshot[key] = max(candidates, key=boss_result_sort_key)
    return snapshot


def retained_boss_snapshot_sha256(snapshot: dict) -> str:
    canonical = {
        key: {
            "score_centi": boss.get("score_centi"),
            "rank_players": boss.get("rank_players"),
            "rank_raids": boss.get("rank_raids"),
            "dps": boss.get("dps"),
        }
        for key, boss in sorted(snapshot.items())
    }
    payload = json.dumps(canonical, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def canonical_boss_result(boss: dict) -> dict:
    return {
        "score_centi": boss.get("score_centi"),
        "rank_players": boss.get("rank_players"),
        "rank_raids": boss.get("rank_raids"),
        "dps": boss.get("dps"),
    }


def retained_boss_lock_snapshot(players: dict, boss_name: str) -> dict:
    snapshot = {}
    for key, player in sorted(players.items()):
        specs = {
            str(spec_i): canonical_boss_result(bosses[boss_name])
            for spec_i, bosses in sorted((player.get("spec_bosses") or {}).items())
            if boss_name in (bosses or {})
        }
        if specs:
            snapshot[key] = specs
    return snapshot


def retained_boss_lock_record_count(snapshot: dict) -> int:
    return sum(len(player_specs) for player_specs in snapshot.values())


def retained_boss_lock_sha256(snapshot: dict) -> str:
    payload = json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def validate_retained_boss_lock(players: dict, lock: dict, source_label: str) -> None:
    boss_name = lock["boss_name"]
    snapshot = retained_boss_lock_snapshot(players, boss_name)
    actual_player_count = len(snapshot)
    actual_record_count = retained_boss_lock_record_count(snapshot)
    actual_sha256 = retained_boss_lock_sha256(snapshot)
    expected_player_count = int(lock["player_count"])
    expected_record_count = int(lock["record_count"])
    expected_sha256 = str(lock["sha256"]).lower()
    if (
        actual_player_count != expected_player_count
        or actual_record_count != expected_record_count
        or actual_sha256 != expected_sha256
    ):
        raise ValueError(
            f"{boss_name} historical lock failed for {source_label}: "
            f"expected {expected_player_count} players / {expected_record_count} records / {expected_sha256}, "
            f"found {actual_player_count} players / {actual_record_count} records / {actual_sha256}. "
            "Refusing to write data."
        )


def build_top_boss_updates(
    rows: list[list],
    active_names: dict[str, str],
    top_limit: int,
    include_boss_only_players: bool = False,
) -> tuple[dict[str, dict], dict[str, str], int, int]:
    parsed_rows = []
    for rank_raids, row in enumerate(rows, 1):
        parsed = parse_top_row(row, rank_raids)
        if parsed:
            parsed_rows.append(parsed)
    if not parsed_rows:
        return {}, {}, 0, 0

    top_dps = max(row["dps"] for row in parsed_rows)
    seen_guids = set()
    unique_entries = []
    for row in parsed_rows:
        if row["guid"] in seen_guids:
            continue
        seen_guids.add(row["guid"])
        unique_entries.append(row)

    player_count = len(unique_entries)
    raid_count = len(parsed_rows)
    updates = {}
    update_names = {}
    for rank_players, row in enumerate(unique_entries, 1):
        key = active_names.get(row["key"])
        if key is None:
            if not include_boss_only_players:
                continue
            key = row["key"]
        if key in updates:
            continue
        updates[key] = {
            "score_centi": boss_score_centi(rank_players, row["rank_raids"], player_count, raid_count, row["dps"], top_dps),
            "rank_players": rank_players,
            "rank_raids": row["rank_raids"],
            "dps": round(row["dps"], 2),
        }
        update_names[key] = row["name"]
    return updates, update_names, len(parsed_rows), len(unique_entries)


def ensure_boss_leaderboard_player(
    data: dict,
    key: str,
    name: str,
    class_i: int,
    spec_i: int,
) -> tuple[dict | None, bool]:
    player = data["players"].get(key)
    created = False
    if player is None:
        player = {
            "name": name,
            "class_i": class_i,
            "best_spec_i": spec_i,
            "score_centi": 0,
            "raw_points": 0,
            "spec_rank": None,
            "specs": {spec_i: 0},
            "spec_ranks": {},
            "bosses": {},
            "spec_bosses": {},
            "phase_history": {},
            "active": False,
            "boss_only": True,
        }
        data["players"][key] = player
        created = True
    elif player["class_i"] != class_i:
        return None, False
    else:
        player.setdefault("specs", {}).setdefault(spec_i, 0)
    return player, created


def player_sort_key(item: tuple[str, dict]) -> tuple:
    key, player = item
    spec_rank = player.get("spec_rank")
    return (
        player["class_i"],
        player["best_spec_i"],
        spec_rank if spec_rank is not None else 10**9,
        key,
    )


def player_load_score(player: dict) -> int:
    scores = [int(player.get("score_centi") or 0)]
    for history in (player.get("phase_history") or {}).values():
        scores.append(int(history.get("score_centi") or 0))
    for boss in (player.get("bosses") or {}).values():
        scores.append(int(boss.get("score_centi") or 0))
    for bosses in (player.get("spec_bosses") or {}).values():
        for boss in (bosses or {}).values():
            scores.append(int(boss.get("score_centi") or 0))
    return max(scores or [0])


def player_load_rank(player: dict) -> int:
    ranks = []
    spec_rank = player.get("spec_rank")
    if spec_rank is not None:
        ranks.append(int(spec_rank))
    for history in (player.get("phase_history") or {}).values():
        rank = history.get("rank")
        if rank is not None:
            ranks.append(int(rank))
    for boss in (player.get("bosses") or {}).values():
        rank = boss.get("rank_players") or boss.get("rank_raids")
        if rank is not None:
            ranks.append(int(rank))
    return min(ranks or [10**9])


def player_load_order_key(item: tuple[str, dict]) -> tuple:
    key, player = item
    return (
        -player_load_score(player),
        player_load_rank(player),
        0 if player.get("active", True) else 1,
        key,
    )


def player_group_tranche_key(item: tuple[str, dict]) -> tuple:
    key, player = item
    spec_rank = player.get("spec_rank")
    return (
        spec_rank is None,
        spec_rank if spec_rank is not None else 10**9,
        -player_load_score(player),
        player_load_rank(player),
        key,
    )


def build_player_chunks(player_items: list[tuple[str, dict]], chunk_count: int) -> list[list[tuple[str, dict]]]:
    chunk_count = max(1, int(chunk_count or 1))
    groups: dict[tuple[int, int], list[tuple[str, dict]]] = {}
    for item in player_items:
        _key, player = item
        groups.setdefault(
            (int(player.get("class_i") or 0), int(player.get("best_spec_i") or 0)),
            [],
        ).append(item)

    chunks: list[list[tuple[str, dict]]] = [[] for _ in range(chunk_count)]
    for group_key in sorted(groups):
        group = sorted(groups[group_key], key=player_group_tranche_key)
        group_size = len(group)
        if group_size <= 0:
            continue
        for index, item in enumerate(group):
            chunk_index = min(chunk_count - 1, (index * chunk_count) // group_size)
            chunks[chunk_index].append(item)

    for index in range(len(chunks)):
        chunks[index].sort(key=player_sort_key)
    return chunks


def write_bulk_progress(
    cache_path: Path | None,
    cache: dict,
    done: int,
    total: int,
    failed: int,
    last_request: str,
    updated_boss_rows: int,
) -> None:
    if not cache_path:
        return
    cache["bulk_progress"] = {
        "done": done,
        "total": total,
        "failed": failed,
        "last_request": last_request,
        "updated_boss_rows": updated_boss_rows,
        "updated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
    }
    write_boss_cache(cache_path, cache)


def add_bulk_top_bosses(
    server: str,
    data: dict,
    timeout: int,
    retries: int,
    cache_path: Path | None,
    sleep: float,
    top_limit: int,
    checkpoint_every: int,
) -> None:
    include_inactive_players = bool(data.get("include_inactive_boss_players"))
    include_boss_only_players = bool(data.get("include_boss_only_players"))
    players = {
        key: player
        for key, player in data["players"].items()
        if include_inactive_players or player.get("active", True)
    }
    active_by_spec: dict[tuple[int, int], dict[str, str]] = {}
    for key, player in players.items():
        for spec_i in player.get("specs") or {player["best_spec_i"]: True}:
            active_by_spec.setdefault((player["class_i"], spec_i), {})[canonical_player_key(player["name"])] = key

    cache = load_boss_cache(cache_path, server)
    cache_entries = cache["entries"]
    staged_bosses = {key: {} for key in players}
    total = len(ENCOUNTERS) * sum(len(specs) for specs in SPECS.values())
    done = 0
    failed = 0
    updated_boss_rows = 0
    created_boss_players = set()
    class_conflicts = set()
    encounter_rows = {boss_name: 0 for boss_name, _ in ENCOUNTERS}
    checkpoint_every = max(1, checkpoint_every)

    scope_label = "ranked players only" if not include_boss_only_players else "ranked plus boss-only players"
    log(f"bulk bosses: {total} leaderboard calls at limit {top_limit}; {scope_label}; no per-player character calls")
    for boss_name, mode in ENCOUNTERS:
        for class_i, class_name in enumerate(CLASSES):
            for spec_i, spec_name in SPECS[class_i].items():
                done += 1
                label = f"{boss_name} {mode} {class_name} {spec_name}"
                try:
                    rows = fetch_top(server, boss_name, mode, class_i, spec_i, top_limit, timeout, retries)
                    updates, update_names, raid_rows, unique_rows = build_top_boss_updates(
                        rows,
                        active_by_spec.get((class_i, spec_i), {}),
                        top_limit,
                        include_boss_only_players,
                    )
                except (HTTPError, URLError, TimeoutError, ValueError) as exc:
                    failed += 1
                    if failed <= 20:
                        log(f"warning: failed bulk bosses for {label}: {exc}")
                    rows = []
                    updates = {}
                    raid_rows = 0
                    unique_rows = 0
                else:
                    encounter_rows[boss_name] += len(rows)
                    for key, boss_data in updates.items():
                        player, created = ensure_boss_leaderboard_player(
                            data,
                            key,
                            update_names[key],
                            class_i,
                            spec_i,
                        )
                        if player is None:
                            existing = data["players"].get(key)
                            existing_class = (
                                CLASSES[existing["class_i"]]
                                if existing and existing.get("class_i") in range(len(CLASSES))
                                else "unknown"
                            )
                            class_conflicts.add(
                                f"{update_names[key]} ({existing_class} history vs {class_name} current)"
                            )
                            continue
                        players[key] = player
                        staged_bosses.setdefault(key, {})
                        if created:
                            created_boss_players.add(key)
                        staged_bosses[key].setdefault(spec_i, {})[boss_name] = boss_data
                        updated_boss_rows += 1

                percent = done / total * 100
                log(
                    f"bulk bosses {done:3}/{total} ({percent:5.1f}%) "
                    f"{label}: {len(rows):5} rows, {unique_rows:5} players, {len(updates):3} matched"
                )
                if done == total or done % checkpoint_every == 0:
                    write_bulk_progress(cache_path, cache, done, total, failed, label, updated_boss_rows)
                if sleep > 0:
                    time.sleep(sleep)

    fetched_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    if failed == 0:
        for key, player in players.items():
            refreshed_spec_bosses = staged_bosses.get(key, {})
            merge_cached_spec_bosses(player, refreshed_spec_bosses, cache_entries)
            if RETAINED_BOSSES:
                for spec_i, existing_bosses in (player.get("spec_bosses") or {}).items():
                    retained = {
                        boss_name: boss
                        for boss_name, boss in existing_bosses.items()
                        if boss_name in RETAINED_BOSSES
                    }
                    if retained:
                        refreshed_spec_bosses.setdefault(spec_i, {}).update(retained)
            player["spec_bosses"] = refreshed_spec_bosses
            player["bosses"] = coherent_player_bosses(player)
            for spec_i, bosses in player["spec_bosses"].items():
                cache_entries[get_boss_cache_key_for_spec(player, spec_i)] = {
                    "name": player["name"],
                    "spec_i": spec_i,
                    "bosses": bosses,
                    "fetched_at": fetched_at,
                    "source": TOP_ENDPOINT,
                    "top_limit": top_limit,
                }
        data["bosses_refreshed_from_top"] = True
    else:
        for key, spec_bosses in staged_bosses.items():
            if not spec_bosses:
                continue
            player = players[key]
            player_spec_bosses = player.setdefault("spec_bosses", {})
            for spec_i, bosses in spec_bosses.items():
                merged = dict((player_spec_bosses.get(spec_i) or {}))
                merged.update(bosses)
                player_spec_bosses[spec_i] = merged
                if spec_i == player["best_spec_i"]:
                    player["bosses"] = merged
                cache_entries[get_boss_cache_key_for_spec(player, spec_i)] = {
                    "name": player["name"],
                    "spec_i": spec_i,
                    "bosses": merged,
                    "bulk_progress_at": fetched_at,
                    "source": TOP_ENDPOINT,
                    "top_limit": top_limit,
                }
        data["bosses_refreshed_from_top"] = False

    cache["bulk_progress"] = {
        "done": done,
        "total": total,
        "failed": failed,
        "updated_boss_rows": updated_boss_rows,
        "completed_at": fetched_at,
    }
    write_boss_cache(cache_path, cache)
    data["boss_names"] = list(BOSS_ORDER)
    data["bulk_boss_failed"] = failed
    data["bulk_boss_requests"] = total
    data["bulk_boss_rows"] = updated_boss_rows
    data["bulk_boss_encounter_rows"] = encounter_rows
    data["missing_boss_encounters"] = [
        boss_name
        for boss_name, _ in ENCOUNTERS
        if encounter_rows.get(boss_name, 0) <= 0
    ]
    log(
        f"bulk bosses complete: {updated_boss_rows} boss rows updated, "
        f"{len(created_boss_players)} boss-only players added, "
        f"{len(class_conflicts)} class conflicts skipped, "
        f"{failed} failed requests"
    )
    if class_conflicts:
        log("warning: ambiguous reused player names skipped: " + format_name_preview(class_conflicts))


def add_character_bosses(
    server: str,
    data: dict,
    timeout: int,
    retries: int,
    workers: int,
    limit: int | None,
    cache_path: Path | None,
    sleep: float,
    refresh_active: bool,
    max_age_days: float | None,
    target_names: set[str] | None,
) -> None:
    players = list(data["players"].items())
    players.sort(key=player_sort_key)

    boss_names_seen = set(BOSS_ORDER)
    cache = load_boss_cache(cache_path, server)
    cache_entries = cache["entries"]
    pending = []
    cached_count = 0
    refresh_count = 0
    now = datetime.now(timezone.utc)
    target_names = target_names or set()
    found_targets = set()

    for item in players:
        key, player = item
        targeted = key in target_names
        if targeted:
            found_targets.add(key)
        cache_key, cached = find_boss_cache_entry(cache_entries, player, allow_name_fallback=not refresh_active and not targeted)
        if cached and isinstance(cached.get("bosses"), dict):
            player["bosses"] = cached["bosses"]
            spec_i = get_cached_spec_i(cached, player.get("best_spec_i"))
            if spec_i:
                player.setdefault("spec_bosses", {}).setdefault(spec_i, cached["bosses"])
            boss_names_seen.update(cached["bosses"].keys())
            cached_count += 1
            if targeted or (refresh_active and not is_boss_cache_fresh(cached, max_age_days, now)):
                pending.append(item)
                refresh_count += 1
        else:
            pending.append(item)

    if target_names:
        missing_targets = sorted(target_names - found_targets)
        if missing_targets:
            log(f"warning: boss refresh targets not in active top lists: {', '.join(missing_targets)}")
        pending.sort(key=lambda item: (0 if item[0] in target_names else 1))

    if limit is not None:
        pending = pending[:limit]

    total = len(pending)
    if total <= 0:
        extra_bosses = sorted(boss_names_seen - set(BOSS_ORDER))
        data["boss_names"] = [name for name in BOSS_ORDER if name in boss_names_seen] + extra_bosses
        data["character_failed"] = 0
        log(f"character bosses: using {cached_count} cached entries, 0 to fetch")
        return

    def fetch_one(item):
        key, player = item
        if sleep > 0:
            time.sleep(sleep)
        character = fetch_character(server, player["name"], player["best_spec_i"], timeout, retries)
        bosses = {}
        for boss_name, boss_data in (character.get("bosses") or {}).items():
            if not isinstance(boss_data, dict):
                continue
            score_centi = point_score_to_centi(boss_data.get("points"))
            if score_centi is None:
                continue
            boss_names_seen.add(boss_name)
            bosses[boss_name] = {
                "score_centi": score_centi,
                "rank_players": boss_data.get("rank_players"),
                "rank_raids": boss_data.get("rank_raids"),
                "dps": boss_data.get("dps_max"),
            }
        return key, bosses

    done = 0
    failed = 0
    log(
        f"character bosses: using {cached_count} cached entries, "
        f"fetching {total} {'stale/missing' if refresh_active else 'missing'}"
        + (f" ({refresh_count} stale active candidates)" if refresh_count else "")
    )
    with ThreadPoolExecutor(max_workers=max(1, workers)) as executor:
        futures = {executor.submit(fetch_one, item): item[0] for item in pending}
        for future in as_completed(futures):
            key = futures[future]
            try:
                _, bosses = future.result()
            except (HTTPError, URLError, TimeoutError, ValueError) as exc:
                failed += 1
                if failed <= 20:
                    log(f"warning: failed character bosses for {data['players'][key]['name']}: {exc}")
            else:
                data["players"][key]["bosses"] = bosses
                player = data["players"][key]
                player.setdefault("spec_bosses", {})[player["best_spec_i"]] = bosses
                cache_entries[get_boss_cache_key(player)] = {
                    "name": player["name"],
                    "spec_i": player["best_spec_i"],
                    "bosses": bosses,
                    "fetched_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
                }
            done += 1
            if done == total or done % 100 == 0:
                write_boss_cache(cache_path, cache)
            if done == total or done % 250 == 0:
                log(f"character bosses {done:5}/{total} fetched ({failed} failed)")

    write_boss_cache(cache_path, cache)
    extra_bosses = sorted(boss_names_seen - set(BOSS_ORDER))
    data["boss_names"] = [name for name in BOSS_ORDER if name in boss_names_seen] + extra_bosses
    data["character_failed"] = failed


def serializable_bosses(bosses: dict | None) -> dict:
    return {
        boss_name: {
            "score": boss["score_centi"] / 100,
            "score_centi": boss["score_centi"],
            "rank_players": boss.get("rank_players"),
            "rank_raids": boss.get("rank_raids"),
            "dps": boss.get("dps"),
        }
        for boss_name, boss in sorted((bosses or {}).items())
    }


def get_player_spec_bosses(player: dict) -> dict:
    spec_bosses = dict(player.get("spec_bosses") or {})
    if player.get("bosses") and player["best_spec_i"] not in spec_bosses:
        spec_bosses[player["best_spec_i"]] = player["bosses"]
    return spec_bosses


def filter_data_to_current_profile(data: dict) -> None:
    allowed_bosses = set(BOSS_ORDER)
    boss_names_seen = set(data.get("boss_names") or [])
    data["boss_names"] = [boss_name for boss_name in BOSS_ORDER if boss_name in boss_names_seen]
    for player in data["players"].values():
        player["bosses"] = {
            boss_name: boss
            for boss_name, boss in (player.get("bosses") or {}).items()
            if boss_name in allowed_bosses
        }
        player["spec_bosses"] = {
            spec_i: {
                boss_name: boss
                for boss_name, boss in bosses.items()
                if boss_name in allowed_bosses
            }
            for spec_i, bosses in (player.get("spec_bosses") or {}).items()
        }


def write_json(path: Path, server: str, max_per_spec: int, generated_at: str, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    serializable_players = {
        key: {
            "name": player["name"],
            "score": player["score_centi"] / 100,
            "score_centi": player["score_centi"],
            "class": CLASSES[player["class_i"]],
            "class_i": player["class_i"],
            "spec": SPECS[player["class_i"]][player["best_spec_i"]],
            "spec_i": player["best_spec_i"],
            "spec_rank": player["spec_rank"],
            "specs": {
                SPECS[player["class_i"]][spec_i]: score / 100
                for spec_i, score in sorted(player["specs"].items())
            },
            "spec_ranks": {
                SPECS[player["class_i"]][spec_i]: rank
                for spec_i, rank in sorted(player["spec_ranks"].items())
            },
            "active": bool(player.get("active", True)),
            "phase_history": {
                phase_id: {
                    "score": historical["score_centi"] / 100,
                    "score_centi": historical["score_centi"],
                    "rank": historical.get("rank"),
                }
                for phase_id, historical in sorted((player.get("phase_history") or {}).items())
            },
            "bosses": serializable_bosses(player.get("bosses")),
            "spec_bosses": {
                SPECS[player["class_i"]][spec_i]: serializable_bosses(bosses)
                for spec_i, bosses in sorted(get_player_spec_bosses(player).items())
                if spec_i in SPECS[player["class_i"]]
            },
        }
        for key, player in sorted(data["players"].items())
    }
    payload = {
        "generated_at": generated_at,
        "server": server,
        "phase_id": data.get("phase_id"),
        "default_raid_name": data.get("default_raid_name"),
        "historical_overall_phase_id": data.get("historical_overall_phase_id"),
        "historical_overall_label": data.get("historical_overall_label"),
        "source": POINTS_ENDPOINT,
        "top_source": TOP_ENDPOINT,
        "character_source": CHARACTER_ENDPOINT,
        "max_per_spec": max_per_spec,
        "bosses": data.get("boss_names") or [],
        "players": serializable_players,
        "active_players": sum(1 for player in data["players"].values() if player.get("active", True)),
        "stale_players": sum(1 for player in data["players"].values() if not player.get("active", True)),
        "boss_refresh": data.get("boss_refresh"),
        "fetched": data["fetched"],
        "failed_leaderboards": data.get("failed_leaderboards") or [],
        "character_failed": data.get("character_failed", 0),
        "bulk_boss_failed": data.get("bulk_boss_failed", 0),
        "bulk_boss_requests": data.get("bulk_boss_requests", 0),
        "bulk_boss_rows": data.get("bulk_boss_rows", 0),
        "bulk_boss_encounter_rows": data.get("bulk_boss_encounter_rows"),
        "missing_boss_encounters": data.get("missing_boss_encounters"),
        "duplicate_rankings": data.get("duplicate_rankings"),
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_lua(path: Path, server: str, max_per_spec: int, generated_at: str, data: dict, chunk_count: int | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sorted_players = sorted(
        data["players"].items(),
        key=player_sort_key,
    )
    chunk_count = int(chunk_count or get_lua_player_chunk_count(len(sorted_players)))
    player_chunks = build_player_chunks(sorted_players, chunk_count)
    player_load_order = [key for key, _player in sorted(sorted_players, key=player_load_order_key)]
    player_load_steps = [0]
    for chunk in player_chunks:
        player_load_steps.append(player_load_steps[-1] + len(chunk))

    lines = [
        "-- Auto-generated by tools/update_uwu_logs.py; do not edit by hand.",
        "coolstatsUwUData = {",
        f"\tgeneratedAt = {lua_string(generated_at)},",
        f"\trealm = {lua_string(server)},",
        f"\tphaseId = {lua_string(data.get('phase_id') or 'ulduar')},",
        f"\tdefaultRaidName = {lua_string(data.get('default_raid_name') or 'Ulduar')},",
        f"\thistoricalOverallPhaseId = {lua_string_or_nil(data.get('historical_overall_phase_id'))},",
        f"\thistoricalOverallLabel = {lua_string_or_nil(data.get('historical_overall_label'))},",
        f"\tsource = {lua_string(POINTS_ENDPOINT)},",
        f"\ttopSource = {lua_string(TOP_ENDPOINT)},",
        f"\tcharacterSource = {lua_string(CHARACTER_ENDPOINT)},",
        f"\tmaxPerSpec = {max_per_spec},",
        f"\ttotalPlayers = {len(sorted_players)},",
        f"\tplayerChunkCount = {chunk_count},",
        "\tplayerLoadSteps = { " + ", ".join(str(value) for value in player_load_steps) + " },",
        "\tclasses = {",
    ]

    for class_i, class_name in enumerate(CLASSES):
        lines.append(f"\t\t[{class_i}] = {lua_string(class_name)},")
    lines.append("\t},")
    lines.append("\tspecs = {")
    for class_i in range(len(CLASSES)):
        spec_parts = ", ".join(
            f"[{spec_i}] = {lua_string(spec_name)}"
            for spec_i, spec_name in SPECS[class_i].items()
        )
        lines.append(f"\t\t[{class_i}] = {{ {spec_parts} }},")
    lines.append("\t},")
    lines.append("\tbosses = {")
    boss_index_by_name = {}
    for index, boss_name in enumerate(data.get("boss_names") or [], 1):
        boss_index_by_name[boss_name] = index
        lines.append(f"\t\t[{index}] = {lua_string(boss_name)},")
    lines.append("\t},")
    lines.append("\t-- player = { displayName, scoreCenti, classIndex, specIndex, specRank, perSpecScoreCenti, perSpecRank, bossData, perSpecBossData, historicalOverall, currentPhaseRanked }")
    lines.append("\t-- bossData = { [bossIndex] = { scoreCenti, playerRank, raidRank, dps } }")
    lines.append("\t-- perSpecBossData = { [specIndex] = bossData }")
    lines.append("\t-- historicalOverall = { scoreCenti, rank }")
    lines.append("\tplayers = {},")
    lines.append("}")
    lines.append("if coolstats and coolstats.ShouldBuildUwUDataPlayerAllowList and coolstats.ShouldBuildUwUDataPlayerAllowList(coolstatsUwUData) then")
    lines.append("\tcoolstats.BuildUwUDataPlayerAllowList(coolstatsUwUData, {")
    for key in player_load_order:
        lines.append(f"\t\t{lua_string(key)},")
    lines.append("\t})")
    lines.append("end")

    def lua_boss_data(bosses: dict | None) -> str:
        return ", ".join(
            f"[{boss_index_by_name[boss_name]}] = {{ "
            f"{boss['score_centi']}, "
            f"{lua_number_or_nil(boss.get('rank_players'))}, "
            f"{lua_number_or_nil(boss.get('rank_raids'))}, "
            f"{lua_number_or_nil(boss.get('dps'))} "
            f"}}"
            for boss_name, boss in sorted(
                (bosses or {}).items(),
                key=lambda item: boss_index_by_name.get(item[0], 999),
            )
            if boss_name in boss_index_by_name
        )

    player_lines = {}
    for key, player in sorted_players:
        specs = ", ".join(
            f"[{spec_i}] = {score}"
            for spec_i, score in sorted(player["specs"].items())
        )
        spec_ranks = ", ".join(
            f"[{spec_i}] = {rank}"
            for spec_i, rank in sorted(player["spec_ranks"].items())
        )
        boss_data = lua_boss_data(player.get("bosses"))
        spec_bosses = get_player_spec_bosses(player)
        spec_boss_data = ", ".join(
            f"[{spec_i}] = {{ {lua_boss_data(bosses)} }}"
            for spec_i, bosses in sorted(spec_bosses.items())
        )
        historical = (player.get("phase_history") or {}).get(data.get("historical_overall_phase_id"))
        historical_data = (
            f"{{ {historical['score_centi']}, {lua_number_or_nil(historical.get('rank'))} }}"
            if historical
            else "nil"
        )
        current_phase_ranked = "true" if player.get("active", True) else "false"
        player_lines[key] = (
            "\t\t"
            f"[{lua_string(key)}] = {{ {lua_string(player['name'])}, "
            f"{player['score_centi']}, {player['class_i']}, {player['best_spec_i']}, "
            f"{lua_number_or_nil(player.get('spec_rank'))}, {{ {specs} }}, {{ {spec_ranks} }}, {{ {boss_data} }}, {{ {spec_boss_data} }}, "
            f"{historical_data}, {current_phase_ranked} }},"
        )

    path.write_text("\n".join(lines), encoding="utf-8")
    active_chunk_paths = {
        path.with_name(f"{path.stem}_{chunk_index + 1:02d}{path.suffix}")
        for chunk_index in range(chunk_count)
    }
    chunk_start = 1
    for chunk_index in range(chunk_count):
        chunk_path = path.with_name(f"{path.stem}_{chunk_index + 1:02d}{path.suffix}")
        chunk_keys = [key for key, _player in player_chunks[chunk_index]]
        chunk_players = [player_lines[key] for key in chunk_keys]
        chunk_end = chunk_start + len(chunk_players) - 1
        chunk_lines = [
            "-- Auto-generated by tools/update_uwu_logs.py; do not edit by hand.",
            f"local chunkStartIndex = {chunk_start}",
            "if coolstats and coolstats.ShouldSkipUwUDataChunk and coolstats.ShouldSkipUwUDataChunk(coolstatsUwUData, chunkStartIndex) then",
            "\treturn",
            "end",
            "local chunk = {",
            *chunk_players,
            "}",
            "if coolstats and coolstats.InsertUwUDataChunk then",
            "\tcoolstats.InsertUwUDataChunk(coolstatsUwUData, chunk)",
            "elseif coolstatsUwUData and coolstatsUwUData.players then",
            "\tfor key, player in pairs(chunk) do",
            "\t\tcoolstatsUwUData.players[key] = player",
            "\tend",
            "end",
            "chunk = nil",
        ]
        chunk_path.write_text("\n".join(chunk_lines), encoding="utf-8")
        chunk_start = chunk_end + 1

    for stale_chunk_path in path.parent.glob(f"{path.stem}_[0-9][0-9]{path.suffix}"):
        if stale_chunk_path not in active_chunk_paths:
            stale_chunk_path.unlink()


def validate_realm_profile(server: str, timeout: int, retries: int, sleep: float) -> bool:
    candidates = [
        (3, 1),
        (9, 2),
        (5, 3),
        (0, 3),
        (7, 1),
    ]
    missing = []
    log(f"validating {server} profile: {len(ENCOUNTERS)} encounters")
    for boss_name, mode in ENCOUNTERS:
        found = False
        attempts = []
        for class_i, spec_i in candidates:
            try:
                rows = fetch_top(server, boss_name, mode, class_i, spec_i, PROFILE_VALIDATION_LIMIT, timeout, retries)
                attempts.append(f"{CLASSES[class_i]} {SPECS[class_i][spec_i]}={len(rows)}")
                if rows:
                    found = True
                    break
            except (HTTPError, URLError, TimeoutError, ValueError) as exc:
                attempts.append(f"{CLASSES[class_i]} {SPECS[class_i][spec_i]}={type(exc).__name__}")
            if sleep > 0:
                time.sleep(sleep)
        log(f"  {'ok' if found else 'missing':7} {boss_name} {mode}: {', '.join(attempts)}")
        if not found:
            missing.append(boss_name)
    if missing:
        log(f"error: {server} profile is missing leaderboard data for: {', '.join(missing)}")
        return False
    log(f"{server} profile validation passed")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--weekly", action="store_true", help="Run the weekly update: top players per spec plus bulk boss leaderboards.")
    parser.add_argument("--weekly-full", action="store_true", help="Alias for --weekly; kept for older command history.")
    parser.add_argument("--validate-profile", action="store_true", help="Validate the configured realm boss roster and modes without writing data.")
    parser.add_argument("--server", default="Rising-Gods")
    parser.add_argument("--phase", default=None, help="Use a prepared phase profile instead of the realm's active phase (for example: --server Onyxia --phase toc).")
    parser.add_argument("--activate-phase", action="store_true", help="Rewrite the realm data addon's manifest for the selected phase. Required when promoting a staged phase.")
    parser.add_argument("--max-per-spec", "--max-per-class", dest="max_per_spec", type=int, default=DEFAULT_MAX_PER_SPEC)
    parser.add_argument("--timeout", type=int, default=45)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--sleep", type=float, default=0.05)
    parser.add_argument("--include-bosses", action="store_true", help="Fetch best-spec per-boss parse scores from bulk top leaderboards.")
    parser.add_argument("--character-bosses", action="store_true", help="Use the legacy one-character-at-a-time boss endpoint.")
    parser.add_argument("--bulk-top-limit", type=int, default=DEFAULT_BULK_TOP_LIMIT, choices=[10, 100, 1000, 10000, 50000])
    parser.add_argument("--bulk-checkpoint-every", type=int, default=DEFAULT_BULK_CHECKPOINT_EVERY)
    parser.add_argument("--duplicate-workers", type=int, default=DEFAULT_DUPLICATE_WORKERS, help="Parallel workers for ambiguous duplicate-name verification.")
    parser.add_argument("--boss-workers", type=int, default=1)
    parser.add_argument("--boss-limit", type=int, default=None, help="Maximum character-detail requests; applies with --character-bosses or targeted post-bulk repair.")
    parser.add_argument("--character-timeout", type=int, default=12)
    parser.add_argument("--character-retries", type=int, default=1)
    parser.add_argument("--character-sleep", type=float, default=1.0)
    parser.add_argument("--boss-cache", type=Path, default=None, help="Cache file for incremental character boss data.")
    parser.add_argument("--no-boss-cache", action="store_true")
    parser.add_argument("--refresh-active-bosses", action="store_true", help="Refresh cached boss data for active top-list players instead of only filling missing entries.")
    parser.add_argument("--boss-max-age-days", type=float, default=None, help="With --refresh-active-bosses, skip active boss cache entries newer than this many days.")
    parser.add_argument("--boss-name", action="append", default=[], help="Force one active character to the front of the boss-detail refresh queue. Can be repeated.")
    parser.add_argument("--min-players", type=int, default=1, help="Abort before writing if the fresh active player count is below this.")
    parser.add_argument("--no-preserve-previous", action="store_true", help="Do not carry previous JSON players that fell out of the current top lists.")
    parser.add_argument("--previous-json", type=Path, default=None, help="Read preserved stale players from this JSON instead of --json-output.")
    parser.add_argument("--lua-output", type=Path, default=None)
    parser.add_argument("--json-output", type=Path, default=None)
    parser.add_argument("--addon-version", default=None, help="Version to write into the generated data addon TOC.")
    args = parser.parse_args()

    global ADDON_VERSION_OVERRIDE
    if args.addon_version:
        ADDON_VERSION_OVERRIDE = str(args.addon_version).strip() or None

    try:
        realm_profile = configure_realm_profile(args.server, args.phase)
    except ValueError as exc:
        parser.error(str(exc))
    if args.lua_output is None:
        args.lua_output = default_lua_path(args.server, realm_profile)
    if args.json_output is None:
        args.json_output = default_json_path(args.server, realm_profile)

    if args.validate_profile:
        return 0 if validate_realm_profile(args.server, args.timeout, args.retries, args.sleep) else 1

    if args.weekly or args.weekly_full:
        args.include_bosses = True
        args.refresh_active_bosses = True
        args.min_players = max(
            args.min_players,
            realm_profile.get("minimum_active_players", DEFAULT_MIN_PLAYERS),
        )
        args.character_timeout = max(args.character_timeout, 30)
        args.character_retries = max(args.character_retries, 4)
        if args.boss_max_age_days is None:
            args.boss_max_age_days = DEFAULT_WEEKLY_BOSS_MAX_AGE_DAYS

    if realm_profile.get("preserve_previous_players") is False:
        args.no_preserve_previous = True

    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    previous_players, previous_boss_names = ({}, [])
    if not args.no_preserve_previous:
        previous_json_path = args.previous_json or args.json_output
        server_key = normalize_server_key(args.server)
        if (
            args.previous_json is None
            and not previous_json_path.is_file()
            and realm_profile["phase_id"] != REALM_DEFAULT_PHASES[server_key]
        ):
            baseline_profile = REALM_PHASE_PROFILES[server_key][REALM_DEFAULT_PHASES[server_key]]
            baseline_json_path = default_json_path(args.server, baseline_profile)
            if baseline_json_path.is_file():
                previous_json_path = baseline_json_path
                log(f"seeding staged {realm_profile['phase_id']} history from {baseline_json_path}")
        previous_players, previous_boss_names = load_previous_json_players(previous_json_path, args.server)
        retained_boss_lock = realm_profile.get("retained_boss_lock")
        if retained_boss_lock:
            validate_retained_boss_lock(previous_players, retained_boss_lock, str(previous_json_path))
            log(
                f"verified immutable {retained_boss_lock['boss_name']} history: "
                f"{retained_boss_lock['player_count']} players"
            )
    elif realm_profile.get("retained_boss_lock"):
        log("error: this phase requires its retained historical boss lock; --no-preserve-previous is not allowed")
        return 1

    data = collect_scores(args.server, args.max_per_spec, args.timeout, args.retries, args.sleep, args.duplicate_workers)
    data["phase_id"] = realm_profile["phase_id"]
    data["default_raid_name"] = realm_profile["default_raid_name"]
    data["historical_overall_phase_id"] = realm_profile.get("historical_overall_phase_id")
    data["historical_overall_label"] = realm_profile.get("historical_overall_label")
    data["include_boss_only_players"] = bool(realm_profile.get("include_boss_only_players"))
    active_player_count = len(data["players"])
    if (args.weekly or args.weekly_full) and data.get("failed_leaderboards"):
        log(
            "error: refusing to write weekly realm data because these rankings requests failed: "
            + ", ".join(data["failed_leaderboards"])
        )
        return 1
    if active_player_count < args.min_players:
        log(
            f"error: only {active_player_count} fresh active players collected; "
            f"minimum is {args.min_players}. Refusing to overwrite generated files."
        )
        return 1

    phase_transition_merged = False
    historical_phase_id = realm_profile.get("historical_overall_phase_id")
    if previous_players and historical_phase_id:
        merge_previous_players(data, previous_players, previous_boss_names)
        data["include_inactive_boss_players"] = True
        phase_transition_merged = True

    boss_cache = None
    if args.include_bosses:
        boss_cache = None if args.no_boss_cache else args.boss_cache or default_boss_cache_path(args.server, realm_profile)
        manual_boss_targets = {canonical_player_key(name) for name in args.boss_name if canonical_player_key(name)}
        duplicate_boss_targets = set(data.get("duplicate_boss_repair_keys") or set())
        boss_targets = set(manual_boss_targets)
        boss_targets.update(duplicate_boss_targets)
        if duplicate_boss_targets:
            log("automatic duplicate-name boss repair: " + format_name_preview(duplicate_boss_targets))
        use_character_bosses = args.character_bosses or (bool(boss_targets) and not (args.weekly or args.weekly_full))
        if use_character_bosses:
            add_character_bosses(
                args.server,
                data,
                args.character_timeout,
                args.character_retries,
                args.boss_workers,
                args.boss_limit,
                boss_cache,
                args.character_sleep,
                args.refresh_active_bosses,
                args.boss_max_age_days,
                boss_targets,
            )
        else:
            if args.boss_limit is not None:
                log("note: --boss-limit is only used by targeted character repair after bulk mode")
            add_bulk_top_bosses(
                args.server,
                data,
                args.timeout,
                args.retries,
                boss_cache,
                args.sleep,
                args.bulk_top_limit,
                args.bulk_checkpoint_every,
            )
            if boss_targets:
                target_limit = max(args.boss_limit or 0, len(boss_targets))
                log("targeted character boss repair after bulk mode: " + format_name_preview(boss_targets))
                add_character_bosses(
                    args.server,
                    data,
                    args.character_timeout,
                    args.character_retries,
                    args.boss_workers,
                    target_limit,
                    boss_cache,
                    args.character_sleep,
                    True,
                    None,
                    boss_targets,
                )
        missing_encounters = data.get("missing_boss_encounters") or []
        if missing_encounters:
            log(
                "error: refusing to write realm data because these configured encounters "
                f"returned no leaderboard rows: {', '.join(missing_encounters)}"
            )
            return 1
    boss_cache_entries = None
    if boss_cache:
        boss_cache_entries = load_boss_cache(boss_cache, args.server).get("entries")
    if previous_players and not phase_transition_merged:
        merge_previous_players(data, previous_players, previous_boss_names, boss_cache_entries)
    if boss_cache_entries:
        boss_summary = summarize_active_boss_cache(data, boss_cache_entries, args.boss_max_age_days)
        data["boss_refresh"] = boss_summary
        log(
            "active boss cache: "
            f"{boss_summary['fresh']} fresh, "
            f"{boss_summary['stale']} stale, "
            f"{boss_summary['missing']} missing "
            f"of {boss_summary['total']}"
        )
    rebuild_player_boss_aggregates(data)
    filter_data_to_current_profile(data)
    retained_boss_lock = realm_profile.get("retained_boss_lock")
    if retained_boss_lock:
        try:
            validate_retained_boss_lock(data["players"], retained_boss_lock, "generated output")
        except ValueError as exc:
            log(f"error: {exc}")
            return 1
    chunk_count = get_lua_player_chunk_count(len(data["players"]))
    write_lua(args.lua_output, args.server, args.max_per_spec, generated_at, data, chunk_count)
    write_json(args.json_output, args.server, args.max_per_spec, generated_at, data)
    active_phase_id = get_active_phase_id(args.server)
    should_write_manifest = realm_profile["phase_id"] == active_phase_id or args.activate_phase
    manifest_path = (
        write_data_addon_manifest(args.lua_output, args.server, realm_profile["phase_id"], realm_profile, len(data["players"]), chunk_count)
        if should_write_manifest
        else None
    )

    log(f"wrote {args.lua_output}")
    log(f"wrote {args.json_output}")
    log(f"Lua player chunks: {chunk_count} (~{LUA_PLAYER_TARGET_CHUNK_SIZE} players target, max {LUA_PLAYER_MAX_CHUNK_COUNT})")
    if manifest_path:
        log(f"wrote {manifest_path}")
    elif realm_profile["phase_id"] != active_phase_id:
        log(
            f"staged {args.server} {realm_profile['phase_id']} data without changing the active {active_phase_id} manifest; "
            "use --activate-phase when the realm transitions"
        )
    log(f"active players retained: {active_player_count}")
    log(f"players written: {len(data['players'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

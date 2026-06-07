#!/usr/bin/env python3
"""Generate the coolstats UwU Logs tooltip dataset.

The game addon consumes Lua directly, so this script writes both:
- coolstats/realm_data/coolstats_Data_<Realm>/data/logs/<phase>/coolstats_uwu_data.lua for WoW
- coolstats/data/uwu_logs_onyxia.json for inspection/history

Weekly refresh policy:
- refresh the current top N rows for every class/spec leaderboard
- enrich those active players with any other spec rows available in the same leaderboard responses
- refresh active-player boss details from bulk boss leaderboards, not one character at a time
- preserve the per-character endpoint only as a targeted/manual fallback
- preserve previous JSON players that are no longer active, but do not refresh them
"""

from __future__ import annotations

import argparse
import gzip
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
DEFAULT_JSON_PATH = ADDON_ROOT / "data" / "uwu_logs_onyxia.json"
DEFAULT_BOSS_CACHE_DIR = ADDON_ROOT / "data"
DEFAULT_WEEKLY_BOSS_MAX_AGE_DAYS = 1
DEFAULT_MIN_PLAYERS = 6000
DEFAULT_BULK_TOP_LIMIT = 10000
DEFAULT_BULK_CHECKPOINT_EVERY = 10
LUA_PLAYER_CHUNK_COUNT = 2
PROFILE_VALIDATION_LIMIT = 10

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

PLAYER_NAME_ALIASES = {
    "mireijr": "Zebedy",
}

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

REALM_PROFILES = {
    "onyxia": {
        "phase_id": "ulduar",
        "default_raid_name": "Ulduar",
        "encounters": ULDUAR_ENCOUNTERS,
    },
    "icecrown": {
        "phase_id": "icc",
        "default_raid_name": "Icecrown Citadel",
        "encounters": ICC_ERA_ENCOUNTERS,
    },
    "lordaeron": {
        "phase_id": "icc",
        "default_raid_name": "Icecrown Citadel",
        "encounters": ICC_ERA_ENCOUNTERS,
    },
}

BOSS_ORDER = []
ENCOUNTERS = []

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


def normalize_name(name: str) -> str:
    return "".join(str(name).strip().lower().split())


def configure_realm_profile(server: str) -> dict:
    profile = REALM_PROFILES.get(normalize_name(server))
    if not profile:
        supported = ", ".join(sorted(REALM_PROFILES))
        raise ValueError(f"Unsupported server profile {server!r}; expected one of: {supported}")
    ENCOUNTERS[:] = profile["encounters"]
    BOSS_ORDER[:] = [boss_name for boss_name, _ in ENCOUNTERS]
    return profile


def default_lua_path(server: str, profile: dict) -> Path:
    addon_name = f"coolstats_Data_{str(server).strip()}"
    return ADDON_ROOT / "realm_data" / addon_name / "data" / "logs" / profile["phase_id"] / "coolstats_uwu_data.lua"


def default_json_path(server: str) -> Path:
    server_key = normalize_name(server)
    if server_key == "onyxia":
        return DEFAULT_JSON_PATH
    return ADDON_ROOT / "data" / f"uwu_logs_{server_key}.json"


def read_core_addon_version() -> str:
    toc_path = ADDON_ROOT / "coolstats.toc"
    try:
        for line in toc_path.read_text(encoding="utf-8").splitlines():
            if line.startswith("## Version:"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return "0.0.0"


def write_data_addon_manifest(lua_path: Path, server: str, phase_id: str) -> Path | None:
    addon_root = lua_path.parents[3]
    addon_name = f"coolstats_Data_{str(server).strip()}"
    if addon_root.name != addon_name:
        raise ValueError(f"Realm data output must live under an addon folder named {addon_name}: {lua_path}")

    data_files = [lua_path]
    data_files.extend(sorted(lua_path.parent.glob(f"{lua_path.stem}_[0-9][0-9]{lua_path.suffix}")))
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


def default_boss_cache_path(server: str) -> Path:
    return DEFAULT_BOSS_CACHE_DIR / f"uwu_character_boss_cache_{normalize_name(server)}.json"


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


def collect_scores(server: str, max_per_spec: int, timeout: int, retries: int, sleep: float) -> dict:
    players = {}
    fetched = []
    failed_leaderboards = []
    rows_by_spec = []
    active_keys = set()

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
                if rank <= max_per_spec:
                    active_keys.add(parsed["key"])
                    retained += 1

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
        spec_rank = int(player["spec_rank"])
    except (KeyError, TypeError, ValueError):
        return None
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

    return {
        "name": canonical_player_name(player.get("name") or key),
        "class_i": class_i,
        "best_spec_i": spec_i,
        "score_centi": player_score_centi,
        "raw_points": int(player.get("raw_points") or 0),
        "spec_rank": spec_rank,
        "specs": specs or {spec_i: player_score_centi},
        "spec_ranks": spec_ranks or {spec_i: spec_rank},
        "bosses": bosses,
        "spec_bosses": spec_bosses,
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

    players = {}
    for key, player in payload["players"].items():
        converted = json_player_to_internal(key, player)
        if converted:
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


def build_top_boss_updates(rows: list[list], active_names: dict[str, str], top_limit: int) -> tuple[dict[str, dict], int, int]:
    parsed_rows = []
    for rank_raids, row in enumerate(rows, 1):
        parsed = parse_top_row(row, rank_raids)
        if parsed:
            parsed_rows.append(parsed)
    if not parsed_rows:
        return {}, 0, 0

    top_dps = max(row["dps"] for row in parsed_rows)
    seen_guids = set()
    unique_entries = []
    for row in parsed_rows:
        if row["guid"] in seen_guids:
            continue
        seen_guids.add(row["guid"])
        unique_entries.append(row)

    player_count = 10000 if top_limit >= 10000 and len(parsed_rows) >= 10000 else min(10000, len(unique_entries))
    raid_count = len(parsed_rows)
    updates = {}
    for rank_players, row in enumerate(unique_entries, 1):
        key = active_names.get(row["key"])
        if not key:
            continue
        updates[key] = {
            "score_centi": boss_score_centi(rank_players, row["rank_raids"], player_count, raid_count, row["dps"], top_dps),
            "rank_players": rank_players,
            "rank_raids": row["rank_raids"],
            "dps": round(row["dps"], 2),
        }
    return updates, len(parsed_rows), len(unique_entries)


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
    players = {
        key: player
        for key, player in data["players"].items()
        if player.get("active", True)
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
    encounter_rows = {boss_name: 0 for boss_name, _ in ENCOUNTERS}
    checkpoint_every = max(1, checkpoint_every)

    log(f"bulk bosses: {total} leaderboard calls at limit {top_limit}; no per-player character calls")
    for boss_name, mode in ENCOUNTERS:
        for class_i, class_name in enumerate(CLASSES):
            for spec_i, spec_name in SPECS[class_i].items():
                done += 1
                label = f"{boss_name} {mode} {class_name} {spec_name}"
                try:
                    rows = fetch_top(server, boss_name, mode, class_i, spec_i, top_limit, timeout, retries)
                    updates, raid_rows, unique_rows = build_top_boss_updates(rows, active_by_spec.get((class_i, spec_i), {}), top_limit)
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
                        staged_bosses[key].setdefault(spec_i, {})[boss_name] = boss_data
                    updated_boss_rows += len(updates)

                percent = done / total * 100
                log(
                    f"bulk bosses {done:3}/{total} ({percent:5.1f}%) "
                    f"{label}: {len(rows):5} rows, {unique_rows:5} players, {len(updates):3} active"
                )
                if done == total or done % checkpoint_every == 0:
                    write_bulk_progress(cache_path, cache, done, total, failed, label, updated_boss_rows)
                if sleep > 0:
                    time.sleep(sleep)

    fetched_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    if failed == 0:
        for key, player in players.items():
            player["spec_bosses"] = staged_bosses.get(key, {})
            player["bosses"] = player["spec_bosses"].get(player["best_spec_i"], {})
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
    log(f"bulk bosses complete: {updated_boss_rows} active boss rows updated, {failed} failed requests")


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
    players.sort(key=lambda item: (item[1]["class_i"], item[1]["best_spec_i"], item[1]["spec_rank"], item[0]))

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
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_lua(path: Path, server: str, max_per_spec: int, generated_at: str, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "-- Auto-generated by tools/update_uwu_logs.py; do not edit by hand.",
        "coolstatsUwUData = {",
        f"\tgeneratedAt = {lua_string(generated_at)},",
        f"\trealm = {lua_string(server)},",
        f"\tphaseId = {lua_string(data.get('phase_id') or 'ulduar')},",
        f"\tdefaultRaidName = {lua_string(data.get('default_raid_name') or 'Ulduar')},",
        f"\tsource = {lua_string(POINTS_ENDPOINT)},",
        f"\ttopSource = {lua_string(TOP_ENDPOINT)},",
        f"\tcharacterSource = {lua_string(CHARACTER_ENDPOINT)},",
        f"\tmaxPerSpec = {max_per_spec},",
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
    lines.append("\t-- player = { displayName, scoreCenti, classIndex, specIndex, specRank, perSpecScoreCenti, perSpecRank, bossData, perSpecBossData }")
    lines.append("\t-- bossData = { [bossIndex] = { scoreCenti, playerRank, raidRank, dps } }")
    lines.append("\t-- perSpecBossData = { [specIndex] = bossData }")
    lines.append("\tplayers = {},")
    lines.append("}")

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

    sorted_players = sorted(
        data["players"].items(),
        key=lambda item: (item[1]["class_i"], item[1]["best_spec_i"], item[1]["spec_rank"], item[0]),
    )
    player_lines = []
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
        player_lines.append(
            "\t\t"
            f"[{lua_string(key)}] = {{ {lua_string(player['name'])}, "
            f"{player['score_centi']}, {player['class_i']}, {player['best_spec_i']}, "
            f"{player['spec_rank']}, {{ {specs} }}, {{ {spec_ranks} }}, {{ {boss_data} }}, {{ {spec_boss_data} }} }},"
        )

    path.write_text("\n".join(lines), encoding="utf-8")
    active_chunk_paths = {
        path.with_name(f"{path.stem}_{chunk_index + 1:02d}{path.suffix}")
        for chunk_index in range(LUA_PLAYER_CHUNK_COUNT)
    }
    chunk_size = max(1, (len(player_lines) + LUA_PLAYER_CHUNK_COUNT - 1) // LUA_PLAYER_CHUNK_COUNT)
    for chunk_index in range(LUA_PLAYER_CHUNK_COUNT):
        chunk_path = path.with_name(f"{path.stem}_{chunk_index + 1:02d}{path.suffix}")
        chunk_players = player_lines[chunk_index * chunk_size:(chunk_index + 1) * chunk_size]
        chunk_lines = [
            "-- Auto-generated by tools/update_uwu_logs.py; do not edit by hand.",
            "local chunk = {",
            *chunk_players,
            "}",
            "if coolstatsUwUData and coolstatsUwUData.players then",
            "\tfor key, player in pairs(chunk) do",
            "\t\tcoolstatsUwUData.players[key] = player",
            "\tend",
            "end",
        ]
        chunk_path.write_text("\n".join(chunk_lines), encoding="utf-8")

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
    parser.add_argument("--weekly", action="store_true", help="Run the weekly update: top 400 per spec plus bulk boss leaderboards.")
    parser.add_argument("--weekly-full", action="store_true", help="Alias for --weekly; kept for older command history.")
    parser.add_argument("--validate-profile", action="store_true", help="Validate the configured realm boss roster and modes without writing data.")
    parser.add_argument("--server", default="Onyxia")
    parser.add_argument("--max-per-spec", "--max-per-class", dest="max_per_spec", type=int, default=400)
    parser.add_argument("--timeout", type=int, default=45)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--sleep", type=float, default=0.05)
    parser.add_argument("--include-bosses", action="store_true", help="Fetch best-spec per-boss parse scores from bulk top leaderboards.")
    parser.add_argument("--character-bosses", action="store_true", help="Use the legacy one-character-at-a-time boss endpoint.")
    parser.add_argument("--bulk-top-limit", type=int, default=DEFAULT_BULK_TOP_LIMIT, choices=[10, 100, 1000, 10000, 50000])
    parser.add_argument("--bulk-checkpoint-every", type=int, default=DEFAULT_BULK_CHECKPOINT_EVERY)
    parser.add_argument("--boss-workers", type=int, default=1)
    parser.add_argument("--boss-limit", type=int, default=None, help="Maximum character-detail requests; only applies with --character-bosses.")
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
    args = parser.parse_args()

    try:
        realm_profile = configure_realm_profile(args.server)
    except ValueError as exc:
        parser.error(str(exc))
    if args.lua_output is None:
        args.lua_output = default_lua_path(args.server, realm_profile)
    if args.json_output is None:
        args.json_output = default_json_path(args.server)

    if args.validate_profile:
        return 0 if validate_realm_profile(args.server, args.timeout, args.retries, args.sleep) else 1

    if args.weekly or args.weekly_full:
        args.include_bosses = True
        args.refresh_active_bosses = True
        args.min_players = max(args.min_players, DEFAULT_MIN_PLAYERS)
        args.character_timeout = max(args.character_timeout, 30)
        args.character_retries = max(args.character_retries, 4)
        if args.boss_max_age_days is None:
            args.boss_max_age_days = DEFAULT_WEEKLY_BOSS_MAX_AGE_DAYS

    generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    previous_players, previous_boss_names = ({}, [])
    if not args.no_preserve_previous:
        previous_json_path = args.previous_json or args.json_output
        previous_players, previous_boss_names = load_previous_json_players(previous_json_path, args.server)

    data = collect_scores(args.server, args.max_per_spec, args.timeout, args.retries, args.sleep)
    data["phase_id"] = realm_profile["phase_id"]
    data["default_raid_name"] = realm_profile["default_raid_name"]
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

    boss_cache = None
    if args.include_bosses:
        boss_cache = None if args.no_boss_cache else args.boss_cache or default_boss_cache_path(args.server)
        boss_targets = {canonical_player_key(name) for name in args.boss_name if canonical_player_key(name)}
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
            if boss_targets:
                log("note: --boss-name is only used by --character-bosses; bulk mode refreshes every active top player")
            if args.boss_limit is not None:
                log("note: --boss-limit is ignored in bulk mode")
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
    if previous_players:
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
    filter_data_to_current_profile(data)
    write_lua(args.lua_output, args.server, args.max_per_spec, generated_at, data)
    write_json(args.json_output, args.server, args.max_per_spec, generated_at, data)
    manifest_path = write_data_addon_manifest(args.lua_output, args.server, realm_profile["phase_id"])

    log(f"wrote {args.lua_output}")
    log(f"wrote {args.json_output}")
    if manifest_path:
        log(f"wrote {manifest_path}")
    log(f"active players retained: {active_player_count}")
    log(f"players written: {len(data['players'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

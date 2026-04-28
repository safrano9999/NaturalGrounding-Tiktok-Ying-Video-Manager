"""Core helpers for the NaturalGrounding CITADEL/REPOS WebUI."""

from __future__ import annotations

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
CONFIG_FILE = Path(os.environ.get("NG_CONFIG_FILE", BASE_DIR / "config" / "db_config.env"))
VIDEOS_DIR = Path(os.environ.get("VIDEOS_DIR", BASE_DIR / "VIDEOS"))
SCRIPTS = [
    "NATURAL_MANAGER.sh",
    "NATURAL_PRESORT.sh",
    "NATURAL_PLAYLIST.sh",
    "NATURAL_NEWACCOUNTS.sh",
    "NATURAL_CLEANUP.sh",
    "NATURAL_HEALTH_CHECK.sh",
]

def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default).strip()

def _count_files(path: Path, suffix: str) -> int:
    if not path.exists():
        return 0
    return sum(1 for _ in path.rglob(f"*{suffix}"))

def dashboard() -> dict:
    scripts = [{"name": s, "exists": (BASE_DIR / s).is_file()} for s in SCRIPTS]
    return {
        "service": "NaturalGrounding",
        "base_dir": str(BASE_DIR),
        "config_file": str(CONFIG_FILE),
        "config_exists": CONFIG_FILE.is_file(),
        "videos_dir": str(VIDEOS_DIR),
        "videos_exists": VIDEOS_DIR.is_dir(),
        "video_count": _count_files(VIDEOS_DIR, ".mp4"),
        "json_count": _count_files(VIDEOS_DIR, ".info.json"),
        "db": {
            "backend": _env("DB_BACKEND", "postgres"),
            "host": _env("DB_HOST", "localhost"),
            "port": _env("DB_PORT", "5432"),
            "name": _env("DB_NAME", "build"),
            "user": _env("DB_USER", "build"),
            "password_set": bool(_env("DB_PW")),
        },
        "scripts": scripts,
    }

def run_health_check(timeout: int = 20) -> dict:
    # Python-native healthcheck for the web UI path (no shell dependency).
    import db

    checks: list[str] = []
    ok = True

    if not VIDEOS_DIR.is_dir():
        ok = False
        checks.append(f"videos_dir missing: {VIDEOS_DIR}")
    else:
        checks.append(f"videos_dir ok: {VIDEOS_DIR}")

    try:
        value = db.query_scalar("SELECT 1")
        if str(value) in {"1", "1.0"} or value == 1:
            checks.append("db ok: SELECT 1")
        else:
            ok = False
            checks.append(f"db unexpected scalar: {value!r}")
    except Exception as exc:
        ok = False
        checks.append(f"db error: {exc}")

    return {
        "ok": ok,
        "returncode": 0 if ok else 1,
        "output": "\n".join(checks)[-8000:],
        "timeout": timeout,
    }

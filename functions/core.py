"""Core helpers for the NaturalGrounding CITADEL/REPOS WebUI."""

from __future__ import annotations

import os
import subprocess
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
            "host": _env("DB_HOST", "127.0.0.1"),
            "port": _env("DB_PORT", "3306"),
            "name": _env("DB_NAME", "NaturalGrounding-Tiktok-Ying-Video-Manager"),
            "user": _env("DB_USER", "NaturalGrounding-Tiktok-Ying-Video-Manager"),
            "password_set": bool(_env("DB_PW")),
        },
        "scripts": scripts,
    }

def run_health_check(timeout: int = 20) -> dict:
    script = BASE_DIR / "NATURAL_HEALTH_CHECK.sh"
    if not script.is_file():
        return {"ok": False, "returncode": 127, "output": "NATURAL_HEALTH_CHECK.sh not found"}
    proc = subprocess.run(
        ["bash", str(script)],
        cwd=str(BASE_DIR),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )
    return {"ok": proc.returncode == 0, "returncode": proc.returncode, "output": proc.stdout[-8000:]}

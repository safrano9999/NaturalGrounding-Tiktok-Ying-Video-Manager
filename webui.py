"""NaturalGrounding — FastAPI WebUI for REPOS/CITADEL."""

from __future__ import annotations

import html
import json
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR / "functions"))

try:
    from python_header import get, get_port  # type: ignore
except ModuleNotFoundError:  # local development outside a REPOS image
    import os

    def get(key: str, default: str = "") -> str:
        return os.environ.get(key, default).strip()

    def get_port(key: str, default: int = 850) -> int:
        raw = os.environ.get(key, str(default)).strip()
        return int(raw or default)

import uvicorn
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, JSONResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles

import core

app = FastAPI(title="NaturalGrounding")

_static = BASE_DIR / "static"
if _static.is_dir():
    app.mount("/static", StaticFiles(directory=str(_static)), name="static")


def _render(data: dict) -> str:
    scripts = "".join(
        f"<li class='{ 'ok' if s['exists'] else 'bad' }'>{html.escape(s['name'])}</li>"
        for s in data["scripts"]
    )
    db = data["db"]
    raw = html.escape(json.dumps(data, indent=2))
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>NaturalGrounding</title>
<link rel="icon" href="/static/favicon.svg">
<style>
:root {{ color-scheme: dark; --bg:#10141b; --card:#171d27; --line:#2a3443; --text:#e6edf3; --muted:#8b98a8; --ok:#45c46f; --bad:#ff6b6b; --blue:#65a9ff; }}
body {{ margin:0; font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif; background:var(--bg); color:var(--text); padding:28px; }}
main {{ max-width:1100px; margin:0 auto; }}
h1 {{ margin:0 0 6px; color:var(--blue); }}
.sub {{ color:var(--muted); margin-bottom:24px; }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(240px,1fr)); gap:14px; }}
.card {{ background:var(--card); border:1px solid var(--line); border-radius:14px; padding:16px; }}
.label {{ color:var(--muted); font-size:12px; text-transform:uppercase; letter-spacing:.06em; }}
.value {{ font-size:24px; font-weight:700; margin-top:6px; }}
.ok {{ color:var(--ok); }} .bad {{ color:var(--bad); }}
ul {{ padding-left:20px; }} code, pre {{ background:#0b0f15; border:1px solid var(--line); border-radius:10px; }}
pre {{ padding:14px; overflow:auto; }}
a {{ color:var(--blue); }}
</style>
</head>
<body><main>
<h1>NaturalGrounding</h1>
<div class="sub">REPOS/CITADEL service module · mounted by CITADEL Gateway at <code>/naturalgrounding</code></div>
<section class="grid">
  <div class="card"><div class="label">Videos</div><div class="value">{data['video_count']}</div><div class="sub">MP4 files in {html.escape(data['videos_dir'])}</div></div>
  <div class="card"><div class="label">Metadata</div><div class="value">{data['json_count']}</div><div class="sub">yt-dlp info JSON files</div></div>
  <div class="card"><div class="label">Config</div><div class="value {'ok' if data['config_exists'] else 'bad'}">{'present' if data['config_exists'] else 'env/file missing'}</div><div class="sub">{html.escape(data['config_file'])}</div></div>
  <div class="card"><div class="label">Database</div><div class="value {'ok' if db['password_set'] else 'bad'}">{html.escape(db['host'])}:{html.escape(db['port'])}</div><div class="sub">{html.escape(db['name'])} as {html.escape(db['user'])}</div></div>
</section>
<section class="card" style="margin-top:14px">
  <div class="label">CLI scripts</div><ul>{scripts}</ul>
</section>
<section class="card" style="margin-top:14px">
  <div class="label">API</div>
  <p><a href="/api/status">/api/status</a> · <a href="/api/health">/api/health</a></p>
</section>
<section class="card" style="margin-top:14px"><div class="label">Raw status</div><pre>{raw}</pre></section>
</main></body></html>"""


@app.get("/", response_class=HTMLResponse)
def index():
    return HTMLResponse(_render(core.dashboard()))


@app.get("/api/status")
def api_status():
    return core.dashboard()


@app.get("/api/health")
def api_health():
    try:
        result = core.run_health_check()
    except Exception as exc:  # includes timeout
        result = {"ok": False, "returncode": 1, "output": str(exc)}
    status = 200 if result.get("ok") else 503
    return JSONResponse(result, status_code=status)


@app.get("/healthz")
def healthz():
    return PlainTextResponse("ok\n")


if __name__ == "__main__":
    uvicorn.run(app, host=get("HOST", "0.0.0.0"), port=get_port("NATURALGROUNDING_PORT", 850))

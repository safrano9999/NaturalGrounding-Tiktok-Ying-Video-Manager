"""NaturalGrounding — FastAPI WebUI for REPOS/CITADEL."""

from __future__ import annotations

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
from fastapi import FastAPI, Request, Query
from fastapi.responses import HTMLResponse, JSONResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles
from jinja2 import Environment, FileSystemLoader

import core
import api

from pydantic import BaseModel
from fastapi import BackgroundTasks

import live
import db
import setup

app = FastAPI(title="NaturalGrounding")

_static = BASE_DIR / "static"
if _static.is_dir():
    app.mount("/static", StaticFiles(directory=str(_static)), name="static")

# Mount VIDEOS directory so files can be streamed to the browser.
# Starlette's StaticFiles automatically supports HTTP Range requests.
if core.VIDEOS_DIR.is_dir():
    app.mount("/videos", StaticFiles(directory=str(core.VIDEOS_DIR)), name="videos")

# Setup Jinja2 templates
_jinja = Environment(loader=FileSystemLoader(str(BASE_DIR / "templates")))


@app.get("/", response_class=HTMLResponse)
def index():
    data = core.dashboard()
    tmpl = _jinja.get_template("index.html")
    return HTMLResponse(tmpl.render(data=data))


@app.get("/api/status")
def api_status():
    return core.dashboard()


@app.get("/api/videos")
def api_videos(status: str = Query("sehr_gut,gut,e3"), mode: str = Query("any")):
    return api.get_videos(status, mode)



class RateRequest(BaseModel):
    video_id: str
    account: str
    tiktok_url: str
    rating: str

@app.get("/api/live/queue")
def api_live_queue(limit: int = 3):
    return live.fetch_live_batch(limit)

@app.post("/api/live/rate")
def api_live_rate(req: RateRequest, background_tasks: BackgroundTasks):
    if db.db_backend_name() == "postgresql":
        upsert_sql = (
            "INSERT INTO videos (video_id, account, status, is_physical, init_ytdlp) "
            "VALUES (%s, %s, %s, 0, 1) "
            "ON CONFLICT (video_id) DO UPDATE SET "
            "account = EXCLUDED.account, status = EXCLUDED.status, "
            "is_physical = EXCLUDED.is_physical, init_ytdlp = EXCLUDED.init_ytdlp"
        )
    else:
        upsert_sql = (
            "INSERT INTO videos (video_id, account, status, is_physical, init_ytdlp) "
            "VALUES (%s, %s, %s, 0, 1) "
            "ON DUPLICATE KEY UPDATE status=%s"
        )

    valid_ratings = ['sehr_gut', 'gut', 'e3']
    if req.rating in valid_ratings:
        # Save as non-physical so it doesn't show up in discovery again while downloading
        args = (req.video_id, req.account, req.rating, req.rating)
        if db.db_backend_name() == "postgresql":
            args = (req.video_id, req.account, req.rating)
        db.execute(upsert_sql, args)
        background_tasks.add_task(live.download_rated_video, req.video_id, req.account, req.tiktok_url, req.rating)
        return {"status": "downloading"}
    elif req.rating == 'unbrauchbar':
        args = (req.video_id, req.account, 'unbrauchbar', 'unbrauchbar')
        if db.db_backend_name() == "postgresql":
            args = (req.video_id, req.account, 'unbrauchbar')
        db.execute(upsert_sql, args)
        return {"status": "ignored"}
    return {"status": "skipped"}


@app.get("/api/setup/schema")
def api_setup_schema():
    return JSONResponse(setup.get_schema_data())

@app.post("/api/setup/save")
async def api_setup_save(request: Request):
    data = await request.json()
    res, status = setup.save_config(data)
    return JSONResponse(res, status_code=status)

@app.get("/api/health")
def api_health():
    try:
        result = core.run_health_check()
    except Exception as exc:  # includes timeout
        result = {"ok": False, "returncode": 1, "output": str(exc)}
    status_code = 200 if result.get("ok") else 503
    return JSONResponse(result, status_code=status_code)


@app.get("/healthz")
def healthz():
    return PlainTextResponse("ok\n")


if __name__ == "__main__":
    uvicorn.run(app, host=get("HOST", "0.0.0.0"), port=get_port("NATURALGROUNDING_PORT", 850))

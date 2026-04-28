![NG](NG_2026.png)

# 🎥 Natural Grounding TikTok Video Manager

A dual-architecture tool (FastAPI Web + Bash CLI) designed to download, curate, and stream TikTok videos to build a personal "Natural Grounding" library.

---

## 🌿 Background & Theory

Natural Grounding is a practice by Rion Williams (2007) - the idea is simple: immersive, repeated viewing of women with authentic, uninhibited feminine energy recalibrates your attraction baseline away from the manufactured Western standard.

### 🧘 How it works
You sit down, put on a playlist of curated videos, and just watch - relaxed, no agenda. No analysis, no overthinking. You let the energy of naturally feminine women sink in. Over time this builds a real internal reference point for what genuine femininity looks and feels like.

**TikTok is the modern equivalent** of Williams' original Thai pop VCDs - millions of short clips, where that unfiltered natural energy still surfaces constantly. The challenge is finding and curating it efficiently. That's what this tool does.

---

## 🏗️ Architecture & Dual Interface

This repository supports two completely isolated, yet compatible interfaces sharing the same MariaDB instance and `VIDEOS/` folder:

1. **The Classic CLI (Bash + `mpv`)**: Blazing fast, hotkey-driven video sorting using local native tools.
2. **The FastAPI WebUI (CITADEL-ready)**: A modern browser-based dashboard with dynamic streaming, live discovery, and a schema-driven configuration wizard.

---

## ⚙️ Technical Overview & Functions

### 🌐 1. Python / FastAPI Web Backend (`webui.py` & `functions/`)

The new WebUI acts as a drop-in service module for the `CITADEL` Gateway, running on port `850`. 

* **`webui.py` (Core Router)**: 
  Mounts the FastAPI app, the Jinja2 HTML templates, and crucially, serves the local MP4 storage (`VIDEOS/`) via `StaticFiles`. This enables native **HTTP Range Requests**, allowing seamless scrubbing and memory-efficient streaming of videos directly to the browser.
* **`functions/live.py` (Live Discovery Mode)**: 
  Instead of blindly downloading videos, this module uses `yt-dlp` to dynamically scrape active TikTok accounts *in-memory*. It extracts the raw CDN `.mp4` URLs and streams them instantly to the WebUI. If the user rates a video positively, it triggers a `BackgroundTasks` runner to physically download and ingest the video into the database without blocking the UI.
* **`functions/api.py`**: 
  Assembles playlists on the fly based on the user's active filters (e.g., specific tags, rating status). Returns a shuffled JSON queue to the frontend player.
* **`functions/core.py`**: 
  Provides telemetry, file counts, database connection checks, and health-status endpoints for the CITADEL dashboard.
* **`functions/setup.py` & `configure.py` (`prettyconfi`)**: 
  Powered by the `prettyconfi` library. Defines the configuration schema once (`config/setup.toml`) and uses it to render both an interactive CLI setup wizard (`configure.py`) and an automatic Web Setup form if credentials are missing upon first boot.

### 🖥️ 2. The Classic Bash CLI (`NATURAL_*.sh`)

For users who prefer the terminal, the original shell scripts remain fully intact. They have been wrapped with `lib/runtime_env.sh` to seamlessly inherit database credentials provided by the CITADEL container environment, falling back to local `.env` configurations.

* `./NATURAL_MANAGER.sh` — Batch downloads new videos via `yt-dlp`.
* `./NATURAL_PRESORT.sh` — Feeds downloaded videos into `mpv` for high-speed hotkey rating.
* `./NATURAL_PLAYLIST.sh` — Interactive CLI builder to query the MariaDB and queue playlists.
* `./NATURAL_NEWACCOUNTS.sh` — Whitelist/Blacklist TikTok account sources.
* `./NATURAL_CLEANUP.sh` & `./clear_db.sh` — Trigger MariaDB stored procedures to prune unwanted files and optimize storage.

---

## 🏷️ Video Classification (MariaDB)

| Status | Meaning |
|--------|---------|
| `pending` | Not yet classified |
| `sehr_gut` | 🌟 Strong natural energy - primary grounding material |
| `gut` | ✅ Good natural energy |
| `e3` | 🎭 Entertainment tier - enjoyable, mixed energy |
| `unbrauchbar` | ❌ Rejected (Physically deleted during Cleanup, but ID kept in DB to prevent re-download) |

---

## 🏰 Deployment: REPOS / CITADEL Integration

This project natively plugs into the `REPOS` architecture.

**Repository-local integration files:**
* `CONTAINER/module.toml` — Meta-definitions, exposed ports (`850`), env var prompts, and volume persistence maps.
* `CONTAINER/runtime.toml` — `supervisord` instructions specifying `python3 webui.py` as the autostart target.
* `CONTAINER/env_example` — Env template for standalone runs.

When selected through the `REPOS` builder, `CITADEL` automatically detects the sibling module, adds the `webui.py` FastAPI app to its router, and mounts the manager at:
`http://<gateway-ip>:800/naturalgrounding`

*(Stand-alone runs are possible via `python3 configure.py` followed by `uvicorn webui:app`)*.

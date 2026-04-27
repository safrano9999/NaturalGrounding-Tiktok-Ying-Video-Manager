import os
import datetime
from pathlib import Path
import yt_dlp
from . import db

VIDEOS_DIR = Path(os.environ.get("VIDEOS_DIR", Path(__file__).resolve().parent.parent / "VIDEOS"))

def sync_video(info_dict, filepath):
    v_id = info_dict.get('id')
    v_user = info_dict.get('uploader') or info_dict.get('uploader_id')
    
    if not v_id or not v_user:
        return
        
    v_dur = info_dict.get('duration') or 0
    v_width = info_dict.get('width') or 0
    v_height = info_dict.get('height') or 0
    v_views = info_dict.get('view_count') or 0
    v_desc = info_dict.get('description') or ""
    
    # parse YYYYMMDD
    raw_date = info_dict.get('upload_date')
    v_date = None
    if raw_date and len(raw_date) == 8:
        v_date = f"{raw_date[:4]}-{raw_date[4:6]}-{raw_date[6:]}"
        
    # Relative path from base dir
    try:
        rel_path = str(Path(filepath).relative_to(VIDEOS_DIR.parent))
    except ValueError:
        rel_path = str(filepath) # fallback if not relative
        
    # Ensure account exists
    acc = db.query_scalar("SELECT COUNT(*) FROM accounts WHERE username = %s", (v_user,))
    if not acc:
        db.execute("INSERT INTO accounts (username, is_valid) VALUES (%s, 1)", (v_user,))
        print(f"Added account: @{v_user}")
        
    sql = """
        INSERT INTO videos (
            video_id, duration, width, height, view_count,
            upload_date, description, rel_path, account,
            init_ytdlp, id_zeitpunkt_ytdlp, status, is_physical
        ) VALUES (
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s,
            1, NOW(), 'pending', 1
        ) ON DUPLICATE KEY UPDATE
            view_count = VALUES(view_count),
            id_zeitpunkt_ytdlp = NOW(),
            is_physical = 1,
            description = VALUES(description)
    """
    db.execute(sql, (
        v_id, v_dur, v_width, v_height, v_views,
        v_date, v_desc, rel_path, v_user
    ))
    print(f"Synced: {v_id} @{v_user} ({v_dur}s {v_width}x{v_height})")

class SyncPostProcessor(yt_dlp.postprocessor.PostProcessor):
    def run(self, info):
        filepath = info.get('filepath') or info.get('__files_to_move', {}).get(info.get('requested_downloads', [{}])[0].get('filepath')) or info.get('filename')
        sync_video(info, filepath)
        return [], info

def run_manager(max_new=2, skip_limit=100):
    VIDEOS_DIR.mkdir(parents=True, exist_ok=True)
    
    accounts = db.query("""
        SELECT a.username, COUNT(v.video_id) as v_count
        FROM accounts a
        LEFT JOIN videos v ON a.username = v.account
        WHERE a.is_valid = 1
        GROUP BY a.username
        ORDER BY a.username
    """)
    
    for row in accounts:
        user = row['username']
        v_count = row['v_count']
        print(f"-------------------------------------------------------")
        print(f"@{user} ({v_count} videos in DB)")
        
        if v_count >= skip_limit:
            print("   Limit reached. Skipping.")
            continue
            
        # Build skip list dynamically (in-memory if possible, or via archive file)
        archive_file = VIDEOS_DIR.parent / "config" / "skip_list.txt"
        archive_file.parent.mkdir(exist_ok=True)
        
        existing = db.query("SELECT video_id FROM videos WHERE account = %s AND video_id IS NOT NULL", (user,))
        with open(archive_file, "w") as f:
            for v in existing:
                f.write(f"tiktok {v['video_id']}\n")
                
        # Optional: append global archive.txt if exists
        global_archive = VIDEOS_DIR.parent / "archive.txt"
        if global_archive.exists():
            with open(global_archive, "r") as gf:
                with open(archive_file, "a") as f:
                    f.write(gf.read())
                    
        print(f"   Skip list: {len(existing)} already in DB")
        
        ydl_opts = {
            'outtmpl': str(VIDEOS_DIR / '%(uploader)s' / '%(id)s.%(ext)s'),
            'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/mp4',
            'writeinfojson': True,
            'max_downloads': max_new,
            'download_archive': str(archive_file),
            'no_post_overwrites': True,
            'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }
        
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.add_post_processor(SyncPostProcessor())
                ydl.download([f"https://www.tiktok.com/@{user}"])
        except yt_dlp.utils.MaxDownloadsReached:
            pass
        except Exception as e:
            print(f"Error downloading @{user}: {e}")
            
        if archive_file.exists():
            archive_file.unlink()

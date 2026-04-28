import os
import random
from pathlib import Path
import yt_dlp
try:
    from . import db
except ImportError:
    import db

VIDEOS_DIR = Path(os.environ.get("VIDEOS_DIR", Path(__file__).resolve().parent.parent / "VIDEOS"))

def fetch_live_batch(limit=3):
    accounts = db.query("SELECT username FROM accounts WHERE is_valid = 1")
    if not accounts:
        return {"error": "Keine aktiven Accounts gefunden."}
    
    random.shuffle(accounts)
    
    ydl_opts = {
        'quiet': True,
        'extract_flat': False,
        'playlist_end': 5,
        'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    }
    
    batch = []
    for acc in accounts:
        user = acc['username']
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(f"https://www.tiktok.com/@{user}", download=False)
                entries = info.get('entries', []) if 'entries' in info else [info]
                
                for e in entries:
                    if not e: continue
                    v_id = e.get('id')
                    
                    existing = db.query_scalar("SELECT COUNT(*) FROM videos WHERE video_id = %s", (v_id,))
                    if existing == 0:
                        stream_url = e.get('url')
                        if not stream_url:
                            for f in e.get('formats', []):
                                if f.get('vcodec') != 'none' and f.get('acodec') != 'none':
                                    stream_url = f.get('url')
                                    break
                            if not stream_url and e.get('formats'):
                                stream_url = e.get('formats')[-1].get('url')

                        if stream_url:
                            batch.append({
                                'video_id': v_id,
                                'account': user,
                                'duration': e.get('duration', 0),
                                'description': e.get('description', ''),
                                'stream_url': stream_url,
                                'tiktok_url': e.get('webpage_url', f"https://www.tiktok.com/@{user}/video/{v_id}")
                            })
                    if len(batch) >= limit:
                        return {"videos": batch}
        except Exception as e:
            print(f"Error fetching live for {user}: {e}")
            
        if len(batch) >= limit:
            break
            
    return {"videos": batch}

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
    
    raw_date = info_dict.get('upload_date')
    v_date = None
    if raw_date and len(raw_date) == 8:
        v_date = f"{raw_date[:4]}-{raw_date[4:6]}-{raw_date[6:]}"
        
    try:
        rel_path = str(Path(filepath).relative_to(VIDEOS_DIR.parent))
    except ValueError:
        rel_path = str(filepath)
        
    acc = db.query_scalar("SELECT COUNT(*) FROM accounts WHERE username = %s", (v_user,))
    if not acc:
        db.execute("INSERT INTO accounts (username, is_valid) VALUES (%s, 1)", (v_user,))
        print(f"Added account: @{v_user}")
        
    if db.db_backend_name() == "postgresql":
        sql = """
            INSERT INTO videos (
                video_id, duration, width, height, view_count,
                upload_date, description, rel_path, account,
                init_ytdlp, id_zeitpunkt_ytdlp, status, is_physical
            ) VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s,
                1, NOW(), 'pending', 1
            ) ON CONFLICT (video_id) DO UPDATE SET
                view_count = EXCLUDED.view_count,
                id_zeitpunkt_ytdlp = NOW(),
                is_physical = EXCLUDED.is_physical,
                description = EXCLUDED.description
        """
    else:
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
    print(f"Synced background video: {v_id} @{v_user}")

class SyncPostProcessor(yt_dlp.postprocessor.PostProcessor):
    def run(self, info):
        filepath = info.get('filepath') or info.get('__files_to_move', {}).get(info.get('requested_downloads', [{}])[0].get('filepath')) or info.get('filename')
        sync_video(info, filepath)
        return [], info

def download_rated_video(video_id, account, tiktok_url, rating):
    ydl_opts = {
        'outtmpl': str(VIDEOS_DIR / '%(uploader)s' / '%(id)s.%(ext)s'),
        'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/mp4',
        'writeinfojson': True,
        'no_post_overwrites': True,
        'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.add_post_processor(SyncPostProcessor())
            ydl.download([tiktok_url])
        db.execute("UPDATE videos SET status = %s WHERE video_id = %s", (rating, video_id))
        print(f"Background download finished for {video_id} -> {rating}")
    except Exception as e:
        print(f"Failed to download rated video {video_id}: {e}")

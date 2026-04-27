import random
import yt_dlp
from . import db
from . import manager

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
                    
                    # Only return if not already in the DB
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

def download_rated_video(video_id, account, tiktok_url, rating):
    ydl_opts = {
        'outtmpl': str(manager.VIDEOS_DIR / '%(uploader)s' / '%(id)s.%(ext)s'),
        'format': 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/mp4',
        'writeinfojson': True,
        'no_post_overwrites': True,
        'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.add_post_processor(manager.SyncPostProcessor())
            ydl.download([tiktok_url])
        # override 'pending' status set by SyncPostProcessor to the actual user rating
        db.execute("UPDATE videos SET status = %s WHERE video_id = %s", (rating, video_id))
        print(f"Background download finished for {video_id} -> {rating}")
    except Exception as e:
        print(f"Failed to download rated video {video_id}: {e}")

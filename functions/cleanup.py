import os
from pathlib import Path
from . import db

def run_cleanup():
    print("=======================================================")
    print("   🧹 FRÜHJAHRSPUTZ - CLEANUP")
    print("=======================================================")
    print("\nVideos to be deleted:\n")
    
    preview = db.query("CALL get_cleanup_preview();")
    for row in preview:
        print(f"@{row.get('account')} : {row.get('count')} videos")
        
    total = db.query_scalar("""
        SELECT COUNT(*) 
        FROM videos v
        LEFT JOIN accounts a ON v.account = a.username
        WHERE (v.status = 'unbrauchbar' AND v.is_physical = 1)
           OR (v.status = 'pending' AND v.is_physical = 1 AND a.is_valid = 0)
    """)
    
    print("=======================================================")
    print(f"📦 GESAMT ZU LÖSCHEN: {total} Dateien")
    print("=======================================================")
    
    if total == 0:
        print("✨ Alles sauber! Nichts zu löschen.")
        return
        
    ans = input("Frühjahrsputz starten? (y/n): ").strip().lower()
    if ans != 'y':
        print("Abgebrochen.")
        return
        
    print("\n🧹 Starte Cleanup...\n")
    deleted_count = 0
    videos = db.query("CALL get_cleanup_videos();")
    
    for v in videos:
        v_id = v['id']
        v_path = Path(v['rel_path'])
        v_account = v['account']
        v_status = v['status']
        
        # 1. Delete file
        if v_path.is_file():
            v_path.unlink()
            json_path = v_path.with_suffix('.info.json')
            if json_path.is_file():
                json_path.unlink()
            print(f"  ✓ @{v_account} [{v_status}]: {v_path.name}")
        else:
            print(f"  ⚠ Fehlt bereits: {v_path.name}")
            
        # 2. Mark DB
        db.execute("CALL mark_video_deleted(%s)", (v_id,))
        deleted_count += 1
        
    print("\n=======================================================")
    print("✅ FRÜHJAHRSPUTZ ABGESCHLOSSEN!")
    print("=======================================================\n")
    
    summary = db.query("CALL get_cleanup_summary();")
    for row in summary:
        print(row)
        
    # disk usage
    videos_dir = Path(os.environ.get("VIDEOS_DIR", "VIDEOS"))
    if videos_dir.is_dir():
        import subprocess
        print("\n💾 Speicherplatz:")
        subprocess.run(["du", "-sh", str(videos_dir)])
        
def clear_db():
    print("Truncating queues and deleting physical data records...")
    db.execute("TRUNCATE TABLE playlist_queue")
    db.execute("TRUNCATE TABLE presort_queue")
    db.execute("UPDATE presort_state SET current_pos = 1 WHERE id = 1")
    db.execute("DELETE FROM videos")
    db.execute("DELETE FROM accounts")
    
    print("Presort:", db.query_scalar("SELECT COUNT(*) FROM presort_queue"))
    print("Playlist:", db.query_scalar("SELECT COUNT(*) FROM playlist_queue"))
    print("Videos:", db.query_scalar("SELECT COUNT(*) FROM videos"))
    print("Accounts:", db.query_scalar("SELECT COUNT(*) FROM accounts"))

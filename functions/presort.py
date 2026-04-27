import sys
import subprocess
from . import db

def run_presort():
    print("=======================================================")
    print("   NATURAL GROUNDING - PRESORT")
    print("=======================================================")
    
    # Check queue length
    count = db.query_scalar("SELECT COUNT(*) FROM presort_queue")
    if count == 0:
        print("Queue is empty. Building new presort queue...")
        db.execute("CALL fill_presort_queue();")
        count = db.query_scalar("SELECT COUNT(*) FROM presort_queue")
        if count == 0:
            print("No new videos to sort!")
            return
            
    print(f"Videos in queue: {count}")
    
    while True:
        # Get current state
        row = db.query("SELECT current_pos, (SELECT COUNT(*) FROM presort_queue) as total FROM presort_state WHERE id=1")[0]
        actual_pos = row['current_pos']
        total = row['total']
        
        if actual_pos > total:
            print("Presort Queue Finished! Starting over...")
            db.execute("UPDATE presort_state SET current_pos = 1 WHERE id = 1")
            continue
            
        print(f"\n--- Video {actual_pos} of {total} ---")
        
        v = db.query("""
            SELECT q.video_id, q.sort_order, v.rel_path, v.status, v.mode1, v.mode2, v.account 
            FROM presort_queue q 
            JOIN videos v ON q.video_id = v.id 
            WHERE q.sort_order = %s
        """, (actual_pos,))
        
        if not v:
            print(f"Error finding video at pos {actual_pos}. Advancing...")
            db.execute("UPDATE presort_state SET current_pos = current_pos + 1")
            continue
            
        v = v[0]
        v_id = v['video_id']
        print(f"Account: @{v['account']} | Status: {v['status']} | Flags: [{v['mode1']}/{v['mode2']}]")
        
        mpv_cmd = [
            "mpv",
            "--loop",
            "--force-window=immediate",
            "--keep-open",
            "--quiet",
            "--osd-level=1",
            "--osd-msg1=@${account} | ${duration}s | ${width}x${height}",
            v['rel_path']
        ]
        
        try:
            # We don't block input, let mpv run in foreground
            subprocess.run(mpv_cmd)
        except KeyboardInterrupt:
            print("\nAborted.")
            break
            
        # After mpv closes, ask for status
        action_done = False
        while not action_done:
            ans = input("Rate [S=SehrGut G=Gut E=E3 B=Bad] | Flag [1=Mode1 2=Mode2] | [W=Skip R=Replay Q=Quit]: ").strip().lower()
            
            if ans == 'q':
                print("Exiting...")
                return
            elif ans == 's':
                db.execute("UPDATE videos SET status='sehr_gut' WHERE id=%s", (v_id,))
                db.execute("UPDATE presort_state SET current_pos = %s", (actual_pos + 1,))
                print(" ✓ Sehr Gut")
                action_done = True
            elif ans == 'g':
                db.execute("UPDATE videos SET status='gut' WHERE id=%s", (v_id,))
                db.execute("UPDATE presort_state SET current_pos = %s", (actual_pos + 1,))
                print(" ✓ Gut")
                action_done = True
            elif ans == 'e':
                db.execute("UPDATE videos SET status='e3' WHERE id=%s", (v_id,))
                db.execute("UPDATE presort_state SET current_pos = %s", (actual_pos + 1,))
                print(" ✓ E3")
                action_done = True
            elif ans == 'b':
                db.execute("UPDATE videos SET status='unbrauchbar' WHERE id=%s", (v_id,))
                db.execute("UPDATE presort_state SET current_pos = %s", (actual_pos + 1,))
                print(" ✓ BAD")
                action_done = True
            elif ans == 'w':
                db.execute("UPDATE presort_state SET current_pos = %s", (actual_pos + 1,))
                print(" ⏭ SKIPPED")
                action_done = True
            elif ans == 'r':
                print(" ⟳ REPLAY")
                action_done = True
            elif ans == '1':
                db.execute("UPDATE videos SET mode1 = NOT mode1 WHERE id=%s", (v_id,))
                print(" [MODE1 TOGGLED]")
            elif ans == '2':
                db.execute("UPDATE videos SET mode2 = NOT mode2 WHERE id=%s", (v_id,))
                print(" [MODE2 TOGGLED]")
            else:
                print("Invalid choice.")

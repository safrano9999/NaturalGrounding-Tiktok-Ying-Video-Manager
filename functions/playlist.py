import os
from . import db

def run_playlist():
    print("========================================================")
    print("         PLAYLIST MANAGER")
    print("========================================================")
    
    state = db.query("SELECT current_pos, (SELECT COUNT(*) FROM playlist_queue) as total_size, (SELECT COUNT(*) FROM playlist_queue WHERE sort_order >= current_pos) as remaining FROM presort_state WHERE id=1")[0]
    
    total = state['total_size']
    if total == 0:
        print("Queue Status: EMPTY (no videos loaded)\nYou need to initialize a new queue.")
        flow = 'n'
    else:
        print("Queue Status:")
        print(f"  Total videos:     {total}")
        print(f"  Current position: {state['current_pos']}")
        print(f"  Remaining:        {state['remaining']} videos\n")
        
        if state['remaining'] <= 0:
            print("Queue is finished! Initialize a new one.")
            flow = 'n'
        else:
            flow = input("Action: [c]ontinue where you left off or [n]ew queue? ").strip().lower()
            
    if flow == 'n':
        # Load config
        cfg = db.query("SELECT * FROM playlist_config WHERE id=1")[0]
        
        print("\n--- STATUS FILTERS ---")
        sg = input(f"Include Sehr Gut? [{cfg['use_sehr_gut']}]: ").strip() or cfg['use_sehr_gut']
        g = input(f"Include Gut? [{cfg['use_gut']}]: ").strip() or cfg['use_gut']
        e3 = input(f"Include E3? [{cfg['use_e3_status']}]: ").strip() or cfg['use_e3_status']
        p = input(f"Include Pending? [{cfg['use_pending']}]: ").strip() or cfg['use_pending']
        
        print("\n--- FLAG FILTERS ---")
        m1 = input(f"Require Mode1? [{cfg['use_mode1']}]: ").strip() or cfg['use_mode1']
        m2 = input(f"Require Mode2? [{cfg['use_mode2']}]: ").strip() or cfg['use_mode2']
        
        print("\n--- TECHNICAL FILTERS ---")
        tgt = input(f"Min duration? [{cfg['time_gt']}]: ").strip() or cfg['time_gt']
        tlt = input(f"Max duration? [{cfg['time_lt']}]: ").strip() or cfg['time_lt']
        mw = input(f"Min width? [{cfg['min_width']}]: ").strip() or cfg['min_width']
        orot = input(f"Only rotated (1/0)? [{cfg['only_rot']}]: ").strip() or cfg['only_rot']
        
        print("\n--- LIMITS ---")
        mu = input(f"Max used count? [{cfg['max_used']}]: ").strip() or cfg['max_used']
        mpa = input(f"Max per account? [{cfg['max_per_acc']}]: ").strip() or cfg['max_per_acc']
        
        # update config
        db.execute("""
            UPDATE playlist_config SET 
            use_sehr_gut=%s, use_gut=%s, use_e3_status=%s, use_pending=%s,
            use_mode1=%s, use_mode2=%s, time_gt=%s, time_lt=%s, min_width=%s,
            only_rot=%s, max_used=%s, max_per_acc=%s WHERE id=1
        """, (sg, g, e3, p, m1, m2, tgt, tlt, mw, orot, mu, mpa))
        
        print("✓ Configuration saved\nBuilding playlist queue...")
        db.execute("CALL fill_playlist_queue();")
        count = db.query_scalar("SELECT COUNT(*) FROM playlist_queue")
        print(f"Generated playlist with {count} videos.")
        if count == 0:
            return
            
    print("\nStarting playback...")
    # we would iterate over playlist_queue similar to presort and run mpv.

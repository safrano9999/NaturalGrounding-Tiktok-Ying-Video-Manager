from . import db

def get_videos(status_filter: str, mode_filter: str):
    # Parse status
    if status_filter == 'all':
        status_in = [] # no filter
    else:
        status_in = [s.strip() for s in status_filter.split(',') if s.strip()]
        
    query = "SELECT id, video_id, account, status, mode1, mode2, rel_path, duration, width, height FROM videos WHERE is_physical = 1"
    params = []
    
    if status_in:
        placeholders = ', '.join(['%s'] * len(status_in))
        query += f" AND status IN ({placeholders})"
        params.extend(status_in)
        
    if mode_filter == 'mode1':
        query += " AND mode1 = 1"
    elif mode_filter == 'mode2':
        query += " AND mode2 = 1"
        
    # Backend-specific random function (MySQL/MariaDB: RAND, PostgreSQL: RANDOM)
    query += f" ORDER BY {db.random_order_sql()} LIMIT 200"
    
    videos = db.query(query, params)
    return {"videos": videos}

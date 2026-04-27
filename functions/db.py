import os
import pymysql
from pathlib import Path

# Try to load env if outside REPOS runtime
CONFIG_FILE = Path(os.environ.get("NG_CONFIG_FILE", Path(__file__).resolve().parent.parent / "config" / "db_config.env"))
if CONFIG_FILE.is_file():
    from dotenv import load_dotenv
    load_dotenv(CONFIG_FILE)

def get_connection():
    return pymysql.connect(
        host=os.environ.get("DB_HOST", "127.0.0.1"),
        port=int(os.environ.get("DB_PORT", 3306)),
        user=os.environ.get("DB_USER", "NaturalGrounding-Tiktok-Ying-Video-Manager"),
        password=os.environ.get("DB_PW", ""),
        database=os.environ.get("DB_NAME", "NaturalGrounding-Tiktok-Ying-Video-Manager"),
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True
    )

def query(sql, args=None):
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql, args)
            return cursor.fetchall()

def execute(sql, args=None):
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql, args)
            return cursor.rowcount

def query_scalar(sql, args=None):
    with get_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute(sql, args)
            row = cursor.fetchone()
            if row:
                return list(row.values())[0]
            return None

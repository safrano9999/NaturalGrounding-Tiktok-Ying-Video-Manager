import os
from pathlib import Path

import pymysql

try:
    import psycopg
    from psycopg.rows import dict_row
except Exception:  # pragma: no cover - optional at runtime
    psycopg = None
    dict_row = None


# Try to load env if outside REPOS runtime
CONFIG_FILE = Path(
    os.environ.get(
        "NG_CONFIG_FILE",
        Path(__file__).resolve().parent.parent / "config" / "db_config.env",
    )
)
if CONFIG_FILE.is_file():
    from dotenv import load_dotenv

    load_dotenv(CONFIG_FILE)


def _normalize_backend(raw: str) -> str:
    value = (raw or "").strip().lower()
    if value in {"postgres", "postgresql", "psql"}:
        return "postgresql"
    if value in {"mysql", "mariadb"}:
        return "mysql"
    return ""


def _backend() -> str:
    explicit = _normalize_backend(os.environ.get("DB_BACKEND", ""))
    if explicit:
        return explicit
    # Fallback by port for compatibility with existing envs.
    try:
        port = int(str(os.environ.get("DB_PORT", "5432")).strip() or "5432")
    except (TypeError, ValueError):
        port = 5432
    return "postgresql" if port == 5432 else "mysql"


def db_backend_name() -> str:
    return _backend()


def random_order_sql() -> str:
    return "RANDOM()" if _backend() == "postgresql" else "RAND()"


def _mysql_connection():
    return pymysql.connect(
        host=os.environ.get("DB_HOST", "localhost"),
        port=int(os.environ.get("DB_PORT", 3306)),
        user=os.environ.get("DB_USER", "build"),
        password=os.environ.get("DB_PW", ""),
        database=os.environ.get("DB_NAME", "build"),
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )


def _postgres_connection():
    if psycopg is None or dict_row is None:
        raise RuntimeError(
            "PostgreSQL backend requested but psycopg is not installed. "
            "Install dependency: psycopg[binary]."
        )
    return psycopg.connect(
        host=os.environ.get("DB_HOST", "127.0.0.1"),
        port=int(os.environ.get("DB_PORT", 5432)),
        user=os.environ.get("DB_USER", "build"),
        password=os.environ.get("DB_PW", ""),
        dbname=os.environ.get("DB_NAME", "build"),
        autocommit=True,
        row_factory=dict_row,
    )


def get_connection():
    if _backend() == "postgresql":
        return _postgres_connection()
    return _mysql_connection()


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

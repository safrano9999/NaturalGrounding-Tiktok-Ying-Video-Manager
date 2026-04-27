from . import db

def process_account(username: str, is_valid: int):
    current = db.query_scalar("SELECT is_valid FROM accounts WHERE username = %s", (username,))
    if current is not None:
        if current == is_valid:
            return f"[SKIP] {username} is already {is_valid}"
        else:
            db.execute("UPDATE accounts SET is_valid = %s WHERE username = %s", (is_valid, username))
            return f"[UPDATE] {username} changed to {is_valid}"
    else:
        db.execute("INSERT INTO accounts (username, is_valid) VALUES (%s, %s)", (username, is_valid))
        return f"[NEU] {username} added as {is_valid}"

def get_stats():
    total = db.query_scalar("SELECT COUNT(*) FROM accounts")
    active = db.query_scalar("SELECT COUNT(*) FROM accounts WHERE is_valid = 1")
    blacklisted = db.query_scalar("SELECT COUNT(*) FROM accounts WHERE is_valid = 0")
    return {"total": total, "active": active, "blacklisted": blacklisted}

#!/bin/bash
# =============================================================================
# sync.sh - Syncs yt-dlp JSON metadata to MariaDB
# =============================================================================

set -euo pipefail

# SCRIPT_DIR works here because yt-dlp calls sync.sh with absolute path
# (from --exec "after_move:$SCRIPT_DIR/sync.sh ...") so BASH_SOURCE[0] is absolute
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/db_config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Config not found: $CONFIG_FILE" >&2
    exit 1
fi

source "$CONFIG_FILE"

JSON_FILE="${1:-}"
if [[ -z "$JSON_FILE" ]] || [[ ! -f "$JSON_FILE" ]]; then
    echo "ERROR: JSON file not found: '$JSON_FILE'" >&2
    exit 1
fi

do_sql() {
    mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -N -s -e "$1" 2>&1
}
sql_escape() { echo "${1//\'/\'\'}"; }

V_ID=$(jq    -r '.id          // empty' "$JSON_FILE")
V_USER=$(jq  -r '.uploader // .uploader_id // empty' "$JSON_FILE")

[[ -z "$V_ID"   ]] && echo "ERROR: No id in $JSON_FILE"       >&2 && exit 1
[[ -z "$V_USER" ]] && echo "ERROR: No uploader in $JSON_FILE" >&2 && exit 1

V_DUR=$(jq    -r '.duration    // 0'  "$JSON_FILE")
V_WIDTH=$(jq  -r '.width       // 0'  "$JSON_FILE")
V_HEIGHT=$(jq -r '.height      // 0'  "$JSON_FILE")
V_VIEWS=$(jq  -r '.view_count  // 0'  "$JSON_FILE")
V_DESC=$(sql_escape "$(jq -r '.description // ""' "$JSON_FILE")")

V_DATE=$(jq -r '.upload_date // empty' "$JSON_FILE")
SQL_DATE=$( [[ -n "$V_DATE" ]] \
    && echo "'$(echo "$V_DATE" | sed -E 's/(....)(..)(..)/\1-\2-\3/')'" \
    || echo "NULL" )

V_PATH="VIDEOS/$V_USER/$V_ID.mp4"

ACCOUNT_EXISTS=$(do_sql "SELECT COUNT(*) FROM accounts WHERE username = '$V_USER';")
if [[ "$ACCOUNT_EXISTS" -eq 0 ]]; then
    do_sql "INSERT INTO accounts (username, is_valid) VALUES ('$V_USER', 1);" > /dev/null
    echo "Added account: @$V_USER"
fi

do_sql "INSERT INTO videos (
    video_id, duration, width, height, view_count,
    upload_date, description, rel_path, account,
    init_ytdlp, id_zeitpunkt_ytdlp, status, is_physical
) VALUES (
    '$V_ID', $V_DUR, $V_WIDTH, $V_HEIGHT, $V_VIEWS,
    $SQL_DATE, '$V_DESC', '$V_PATH', '$V_USER',
    1, NOW(), 'pending', 1
) ON DUPLICATE KEY UPDATE
    view_count         = $V_VIEWS,
    id_zeitpunkt_ytdlp = NOW(),
    is_physical        = 1,
    description        = '$V_DESC';" > /dev/null

echo "Synced: $V_ID @$V_USER (${V_DUR}s ${V_WIDTH}x${V_HEIGHT})"

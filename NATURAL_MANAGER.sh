#!/bin/bash
# =============================================================================
# NATURAL_MANAGER.sh - TikTok Video Downloader
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/db_config.env"

BASE_DL_DIR="$SCRIPT_DIR/VIDEOS"
TEMP_ARCHIVE="$SCRIPT_DIR/config/skip_list.txt"

mkdir -p "$BASE_DL_DIR"

clear
echo "======================================================="
echo "   NATURAL GROUNDING VIDEO MANAGER"
echo "======================================================="

read -p "How many new videos per account? (default 2): " MAX_NEW
MAX_NEW=${MAX_NEW:-2}

read -p "Skip accounts with how many videos? (default 100): " SKIP_LIMIT
SKIP_LIMIT=${SKIP_LIMIT:-100}

echo ""
echo "Starting download run..."
echo ""

VIDEOS_BEFORE=$(mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -N -s -e "SELECT COUNT(*) FROM videos;")

ACCOUNTS_DATA=$(mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -N -s -e "
    SELECT a.username, COUNT(v.video_id) as v_count
    FROM accounts a
    LEFT JOIN videos v ON a.username = v.account
    WHERE a.is_valid = 1
    GROUP BY a.username
    ORDER BY a.username;")

while read -r USER V_COUNT; do
    V_COUNT=${V_COUNT:-0}
    echo "-------------------------------------------------------"
    echo "@$USER ($V_COUNT videos in DB)"

    if [[ "$V_COUNT" -ge "$SKIP_LIMIT" ]]; then
        echo "   Limit reached. Skipping."
        continue
    fi

    mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -N -s -e "
        SELECT CONCAT('tiktok ', video_id)
        FROM videos
        WHERE account = '$USER'
          AND video_id IS NOT NULL;" > "$TEMP_ARCHIVE" 2>/dev/null

    cat "$SCRIPT_DIR/archive.txt" >> "$TEMP_ARCHIVE" 2>/dev/null

    echo "   Skip list: $(wc -l < "$TEMP_ARCHIVE") already in DB"

    yt-dlp \
        --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        --format "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/mp4" \
        --write-info-json \
        --no-post-overwrites \
        --download-archive "$TEMP_ARCHIVE" \
        --max-downloads "$MAX_NEW" \
        --exec "after_move:$SCRIPT_DIR/sync.sh %(infojson_filename)q" \
        -o "$BASE_DL_DIR/%(uploader)s/%(id)s.%(ext)s" \
        "https://www.tiktok.com/@$USER"

    rm -f "$TEMP_ARCHIVE"

done <<< "$ACCOUNTS_DATA"

echo ""
echo "======================================================="
echo "Download run completed!"
echo "======================================================="

VIDEOS_AFTER=$(mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -N -s -e "SELECT COUNT(*) FROM videos;")
NEW_THIS_RUN=$((VIDEOS_AFTER - VIDEOS_BEFORE))

mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -e "
    SELECT
        COUNT(*) as total_videos,
        $NEW_THIS_RUN as new_this_run,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as to_classify
    FROM videos;"

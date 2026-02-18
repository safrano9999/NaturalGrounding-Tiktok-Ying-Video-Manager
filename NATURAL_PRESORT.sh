#!/bin/bash
# =============================================================================
# presort_manager.sh - Video classification and rating
# Matches style of playlist_manager.sh
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/db_config.env"

do_sql() {
    mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -N -s -e "$1"
}

# =============================================================================
# STEP 1: SHOW CURRENT QUEUE STATUS
# =============================================================================

clear
echo "========================================================"
echo "         PRESORT MANAGER - VIDEO CLASSIFICATION"
echo "========================================================"

STATE_DATA=$(do_sql "SELECT current_pos, (SELECT COUNT(*) FROM presort_queue), (SELECT COUNT(*) FROM presort_queue WHERE queue_pos >= (SELECT current_pos FROM presort_state WHERE id=1)) FROM presort_state WHERE id=1;")
read CURRENT_POS TOTAL_SIZE REMAINING <<< "$STATE_DATA"

GLOBAL_PENDING=$(do_sql "SELECT COUNT(*) FROM videos v JOIN accounts a ON v.account = a.username WHERE v.status = 'pending' AND a.is_valid = 1 AND v.is_physical = 1;")

if [[ $TOTAL_SIZE -eq 0 ]]; then
    echo "Queue Status: EMPTY (no videos loaded)"
    echo ""
    echo "Pending videos available: $GLOBAL_PENDING"
    echo "You need to initialize a new queue."
    FLOW_CHOICE="i"
else
    echo "Queue Status:"
    echo "  Total videos:     $TOTAL_SIZE"
    echo "  Current position: $CURRENT_POS"
    echo "  Remaining:        $REMAINING videos"
    echo ""
    echo "Pending videos available: $GLOBAL_PENDING"
    echo ""

    if [[ $REMAINING -le 0 ]]; then
        echo "Queue is finished! Initialize a new one."
        FLOW_CHOICE="i"
    else
        read -p "Action: [c]ontinue where you left off or [i]nit new queue? " FLOW_CHOICE
    fi
fi

# =============================================================================
# STEP 2: INITIALIZE NEW QUEUE IF REQUESTED
# =============================================================================

if [[ "$FLOW_CHOICE" == "i" ]]; then
    echo ""
    echo "Rebuilding presort queue from all pending videos..."
    do_sql "CALL refresh_presort_queue();"

    STATE_DATA=$(do_sql "SELECT current_pos, (SELECT COUNT(*) FROM presort_queue), (SELECT COUNT(*) FROM presort_queue WHERE queue_pos >= 1) FROM presort_state WHERE id=1;")
    read CURRENT_POS TOTAL_SIZE REMAINING <<< "$STATE_DATA"

    echo "✓ Queue created: $TOTAL_SIZE videos loaded"

    if [[ $TOTAL_SIZE -eq 0 ]]; then
        echo ""
        echo "No pending videos found from valid accounts!"
        exit 0
    fi

    CURRENT_POS=1
fi

# =============================================================================
# STEP 3: CLASSIFICATION LOOP
# =============================================================================

echo ""
echo "Starting classification..."
echo "Press [q] at any time to quit and save progress"
echo ""
read -p "Press ENTER to begin..."

B_CAPS_COUNT=0

while true; do
    # Reload position and count ACTUAL remaining videos
    STATE_DATA=$(do_sql "SELECT current_pos, (SELECT COUNT(*) FROM presort_queue), (SELECT COUNT(*) FROM presort_queue WHERE queue_pos >= (SELECT current_pos FROM presort_state WHERE id=1)) FROM presort_state WHERE id=1;")
    read CUR_POS TOTAL_SIZE REMAINING <<< "$STATE_DATA"

    # Check if finished
    if [[ $REMAINING -le 0 ]] || [[ $TOTAL_SIZE -eq 0 ]]; then
        echo ""
        echo "========================================================"
        echo "         END OF QUEUE"
        echo "========================================================"
        break
    fi

    # Get next available video - CRITICAL: Check is_valid!
    QUERY="SELECT v.id, v.rel_path, v.account, v.upload_date, v.view_count, v.description, pq.queue_pos FROM videos v JOIN presort_queue pq ON v.id = pq.video_id JOIN accounts a ON v.account = a.username WHERE pq.queue_pos >= $CUR_POS AND a.is_valid = 1 ORDER BY pq.queue_pos LIMIT 1;"
    DATA=$(do_sql "$QUERY")

    if [[ -z "$DATA" ]]; then
        echo ""
        echo "⚠ No more videos found in queue from position $CUR_POS"
        echo "This usually means:"
        echo "  - Remaining videos are from blacklisted accounts"
        echo "  - Queue needs rebuilding"
        echo ""
        echo "Run with 'init' to rebuild the queue."
        break
    fi

    V_ID=$(echo "$DATA" | cut -f1)
    V_PATH=$(echo "$DATA" | cut -f2)
    V_ACC=$(echo "$DATA" | cut -f3)
    V_DATE=$(echo "$DATA" | cut -f4)
    V_VIEWS=$(echo "$DATA" | cut -f5)
    V_DESC=$(echo "$DATA" | cut -f6)
    ACTUAL_POS=$(echo "$DATA" | cut -f7)

    # Check file exists
    if [[ ! -f "$V_PATH" ]]; then
        echo "⚠ File not found: $V_PATH (skipping)"
        do_sql "UPDATE presort_state SET current_pos = $((ACTUAL_POS + 1));"
        continue
    fi

    # Display video info
    clear

    # Calculate how many we've processed
    PROCESSED=$((ACTUAL_POS - CURRENT_POS))

    echo "========================================================"
    echo "  PRESORT CLASSIFICATION"
    echo "  Processed: $PROCESSED | Remaining: $REMAINING"
    echo "========================================================"
    echo "👤 Account:    @$V_ACC"
    echo "📅 Uploaded:   $V_DATE"
    echo "👁️  Views:      $V_VIEWS"
    echo "📝 Desc:       $V_DESC"
    echo "----------------------------------------------------"

    # Auto-detect audio output (pulse first - more compatible)
    if [[ -S "${XDG_RUNTIME_DIR}/pulse/native" ]]; then
        AO="--ao=pulse"
    elif [[ -S "${XDG_RUNTIME_DIR}/pipewire-0" ]]; then
        AO="--ao=pipewire"
    else
        AO=""
    fi

    # Play video
    mpv --ontop --loop=inf --fullscreen $AO "$V_PATH"

    echo ""
    echo "CLASSIFY:"
    echo "[s]Sehr Gut | [g]Gut | [e]E3 | [b]Bad | [w]Skip for now"
    echo ""
    echo "FLAGS (can combine with status):"
    echo "[1]Mode1 toggle | [2]Mode2 toggle"
    echo ""
    echo "ACTIONS:"
    echo "[t/z]Rotate | [r]Replay | [B]Blacklist account | [q]QUIT"
    echo "----------------------------------------------------"
    echo -n "Decision: "

    ACTION_DONE=false
    while [[ "$ACTION_DONE" == false ]]; do
        read -n 1 -s key
        case "$key" in
            # STATUS CHOICES (permanent classification)
            s|S)
                do_sql "UPDATE videos SET status='sehr_gut' WHERE id=$V_ID;"
                do_sql "UPDATE presort_state SET current_pos = $((ACTUAL_POS + 1));"
                echo " ✓ SEHR GUT"
                ACTION_DONE=true ;;
            g|G)
                do_sql "UPDATE videos SET status='gut' WHERE id=$V_ID;"
                do_sql "UPDATE presort_state SET current_pos = $((ACTUAL_POS + 1));"
                echo " ✓ GUT"
                ACTION_DONE=true ;;
            e|E)
                do_sql "UPDATE videos SET status='e3' WHERE id=$V_ID;"
                do_sql "UPDATE presort_state SET current_pos = $((ACTUAL_POS + 1));"
                echo " ✓ E3"
                ACTION_DONE=true ;;
            b)
                do_sql "UPDATE videos SET status='unbrauchbar' WHERE id=$V_ID;"
                do_sql "UPDATE presort_state SET current_pos = $((ACTUAL_POS + 1));"
                echo " ✓ BAD"
                ACTION_DONE=true ;;

            # SKIP (decide later)
            w|W)
                do_sql "UPDATE presort_state SET current_pos = $((ACTUAL_POS + 1));"
                echo " ⏭ SKIPPED"
                ACTION_DONE=true ;;

            # REPLAY
            r|R)
                echo " ⟳ REPLAY"
                ACTION_DONE=true ;;

            # FLAG TOGGLES (can be combined with any status)
            1)
                CURRENT=$(do_sql "SELECT mode1 FROM videos WHERE id=$V_ID;")
                if [[ "$CURRENT" == "1" ]]; then
                    do_sql "UPDATE videos SET mode1=0 WHERE id=$V_ID;"
                    echo -n " [MODE1 OFF] "
                else
                    do_sql "UPDATE videos SET mode1=1 WHERE id=$V_ID;"
                    echo -n " [MODE1 ON] "
                fi ;;
            2)
                CURRENT=$(do_sql "SELECT mode2 FROM videos WHERE id=$V_ID;")
                if [[ "$CURRENT" == "1" ]]; then
                    do_sql "UPDATE videos SET mode2=0 WHERE id=$V_ID;"
                    echo -n " [MODE2 OFF] "
                else
                    do_sql "UPDATE videos SET mode2=1 WHERE id=$V_ID;"
                    echo -n " [MODE2 ON] "
                fi ;;

            # ROTATION
            t|T)
                echo -n " 🔄 Rotating left..."
                if ffmpeg -i "$V_PATH" -vf "transpose=2" -c:v libx264 -preset ultrafast -crf 18 -c:a copy "${V_PATH}.tmp.mp4" -y 2>/tmp/ffmpeg_err.txt; then
                    mv "${V_PATH}.tmp.mp4" "$V_PATH"
                    do_sql "UPDATE videos SET is_transformed=1 WHERE id=$V_ID;"
                    echo " ✓ Rotated - classify now:"
                else
                    rm -f "${V_PATH}.tmp.mp4"
                    echo " ✗ FAILED: $(tail -1 /tmp/ffmpeg_err.txt)"
                fi
                mpv --ontop --loop=inf --fullscreen $AO "$V_PATH" ;;
            z|Z)
                echo -n " 🔄 Rotating right..."
                if ffmpeg -i "$V_PATH" -vf "transpose=1" -c:v libx264 -preset ultrafast -crf 18 -c:a copy "${V_PATH}.tmp.mp4" -y 2>/tmp/ffmpeg_err.txt; then
                    mv "${V_PATH}.tmp.mp4" "$V_PATH"
                    do_sql "UPDATE videos SET is_transformed=1 WHERE id=$V_ID;"
                    echo " ✓ Rotated - classify now:"
                else
                    rm -f "${V_PATH}.tmp.mp4"
                    echo " ✗ FAILED: $(tail -1 /tmp/ffmpeg_err.txt)"
                fi
                mpv --ontop --loop=inf --fullscreen $AO "$V_PATH" ;;

            # BLACKLIST ACCOUNT
            B)
                ((B_CAPS_COUNT++))
                if [[ $B_CAPS_COUNT -ge 2 ]]; then
                    do_sql "UPDATE accounts SET is_valid=0 WHERE username='$V_ACC';"
                    do_sql "UPDATE presort_state SET current_pos = $((ACTUAL_POS + 1));"
                    echo " 🚫 @$V_ACC BLACKLISTED"
                    B_CAPS_COUNT=0
                    ACTION_DONE=true
                else
                    echo -n " (Press B again to blacklist @$V_ACC!) "
                fi ;;

            # QUIT
            q|Q)
                echo ""
                echo ""
                echo "Exiting classification mode..."
                break 2 ;;
        esac
    done

    sleep 0.3  # Brief pause before next video
done

# =============================================================================
# STEP 4: SUMMARY
# =============================================================================

# Get final position
FINAL_POS=$(do_sql "SELECT current_pos FROM presort_state WHERE id=1;")

# Count classified videos
CLASSIFIED=$(do_sql "SELECT COUNT(*) FROM videos WHERE status != 'pending';")

echo ""
echo "========================================================"
echo "         CLASSIFICATION FINISHED"
echo "========================================================"
echo "Total classified: $CLASSIFIED videos"
echo ""
echo "Status breakdown:"

# Show counts
do_sql "SELECT status, COUNT(*) as count FROM videos WHERE status != 'pending' GROUP BY status ORDER BY count DESC;" | while IFS=$'\t' read -r status count; do
    echo "  $status: $count"
done

echo "========================================================"

exit 0

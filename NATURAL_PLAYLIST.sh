#!/bin/bash
# =============================================================================
# playlist_manager.sh - REDESIGNED with cleaner logic
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/db_config.env"

do_sql() {
    mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -N -s -e "$1"
}

show_config() {
    echo "========================================================"
    echo "      PLAYLIST CONFIGURATION"
    echo "========================================================"
    echo "STATUS FILTERS:"
    echo "  Sehr Gut:         ${U_SG:-NULL}"
    echo "  Gut:              ${U_G:-NULL}"
    echo "  E3:               ${U_E3:-NULL}"
    echo "  Pending:          ${U_P:-NULL}"
    echo ""
    echo "FLAG FILTERS:"
    echo "  Mode 1:           ${U_M1:-NULL}"
    echo "  Mode 2:           ${U_M2:-NULL}"
    echo ""
    echo "TECHNICAL FILTERS:"
    echo "  Min Duration:     ${T_GT:-NULL} sec"
    echo "  Max Duration:     ${T_LT:-NULL} sec"
    echo "  Min Width:        ${M_W:-NULL} px"
    echo "  Only Rotated:     ${O_R:-NULL}"
    echo ""
    echo "LIMITS:"
    echo "  Max Used Count:   ${M_U:-NULL}"
    echo "  Max per Account:  ${M_PA:-NULL}"
    echo "  Work Mode:        ${W_MODE:-NULL}"
    echo "========================================================"
}

# =============================================================================
# STEP 1: SHOW CURRENT QUEUE STATUS
# =============================================================================

clear
echo "========================================================"
echo "         PLAYLIST MANAGER"
echo "========================================================"

STATE_DATA=$(do_sql "SELECT current_pos, (SELECT COUNT(*) FROM playlist_queue), (SELECT COUNT(*) FROM playlist_queue WHERE sort_order >= (SELECT current_pos FROM presort_state WHERE id=1)) FROM presort_state WHERE id=1;")
read CURRENT_POS TOTAL_SIZE REMAINING <<< "$STATE_DATA"

if [[ $TOTAL_SIZE -eq 0 ]]; then
    echo "Queue Status: EMPTY (no videos loaded)"
    echo ""
    echo "You need to initialize a new queue."
    FLOW_CHOICE="n"
else
    echo "Queue Status:"
    echo "  Total videos:     $TOTAL_SIZE"
    echo "  Current position: $CURRENT_POS"
    echo "  Remaining:        $REMAINING videos"
    echo ""

    if [[ $REMAINING -le 0 ]]; then
        echo "Queue is finished! Initialize a new one."
        FLOW_CHOICE="n"
    else
        read -p "Action: [c]ontinue where you left off or [n]ew queue? " FLOW_CHOICE
    fi
fi

# =============================================================================
# STEP 2: HANDLE CONFIG (ONLY IF NEW INIT)
# =============================================================================

if [[ "$FLOW_CHOICE" == "n" ]]; then
    echo ""
    echo "========================================================"
    echo "         INITIALIZING NEW QUEUE"
    echo "========================================================"

    # Load current config
    CONFIG_DATA=$(do_sql "SELECT use_sehr_gut, use_gut, use_e3_status, use_pending, use_mode1, use_mode2, time_gt, time_lt, min_width, only_rot, max_used, max_per_acc, worklist_mode FROM playlist_config WHERE id=1;")
    read U_SG U_G U_E3 U_P U_M1 U_M2 T_GT T_LT M_W O_R M_U M_PA W_MODE <<< "$CONFIG_DATA"

    echo ""
    show_config
    echo ""

    read -p "Config: [g]keep current, [d]load defaults, or [v]change? " CONFIG_CHOICE
    echo ""

    if [[ "$CONFIG_CHOICE" == "d" ]]; then
        echo "Loading default settings..."
        do_sql "TRUNCATE TABLE playlist_config;"
        do_sql "INSERT INTO playlist_config (id) VALUES (1);"

        CONFIG_DATA=$(do_sql "SELECT use_sehr_gut, use_gut, use_e3_status, use_pending, use_mode1, use_mode2, time_gt, time_lt, min_width, only_rot, max_used, max_per_acc, worklist_mode FROM playlist_config WHERE id=1;")
        read U_SG U_G U_E3 U_P U_M1 U_M2 T_GT T_LT M_W O_R M_U M_PA W_MODE <<< "$CONFIG_DATA"

        echo "✓ Defaults loaded"

    elif [[ "$CONFIG_CHOICE" == "v" ]]; then
        echo "--- STATUS FILTERS ---"
        read -p "Include Sehr Gut? [$U_SG]: " VAL; U_SG=${VAL:-$U_SG}
        read -p "Include Gut? [$U_G]: " VAL; U_G=${VAL:-$U_G}
        read -p "Include E3? [$U_E3]: " VAL; U_E3=${VAL:-$U_E3}
        read -p "Include Pending? [$U_P]: " VAL; U_P=${VAL:-$U_P}
        echo ""
        echo "--- FLAG FILTERS ---"
        read -p "Require Mode1? [$U_M1]: " VAL; U_M1=${VAL:-$U_M1}
        read -p "Require Mode2? [$U_M2]: " VAL; U_M2=${VAL:-$U_M2}
        echo ""
        echo "--- TECHNICAL FILTERS ---"
        read -p "Min duration (sec)? [$T_GT]: " VAL; T_GT=${VAL:-$T_GT}
        read -p "Max duration (sec)? [$T_LT]: " VAL; T_LT=${VAL:-$T_LT}
        read -p "Min width (px)? [$M_W]: " VAL; M_W=${VAL:-$M_W}
        read -p "Only rotated? (1/0) [$O_R]: " VAL; O_R=${VAL:-$O_R}
        echo ""
        echo "--- LIMITS ---"
        read -p "Max used count? [$M_U]: " VAL; M_U=${VAL:-$M_U}
        read -p "Max per account? [$M_PA]: " VAL; M_PA=${VAL:-$M_PA}

        # Save to database
        U_SG_S=${U_SG:-NULL}; U_G_S=${U_G:-NULL}; U_E3_S=${U_E3:-NULL}; U_P_S=${U_P:-NULL}
        U_M1_S=${U_M1:-NULL}; U_M2_S=${U_M2:-NULL}
        T_GT_S=${T_GT:-NULL}; T_LT_S=${T_LT:-NULL}; M_W_S=${M_W:-NULL}
        O_R_S=${O_R:-NULL}; M_U_S=${M_U:-NULL}; M_PA_S=${M_PA:-NULL}

        do_sql "UPDATE playlist_config SET
            use_sehr_gut=$U_SG_S, use_gut=$U_G_S, use_e3_status=$U_E3_S, use_pending=$U_P_S,
            use_mode1=$U_M1_S, use_mode2=$U_M2_S,
            time_gt=$T_GT_S, time_lt=$T_LT_S, min_width=$M_W_S,
            only_rot=$O_R_S, max_used=$M_U_S, max_per_acc=$M_PA_S WHERE id=1;"

        echo ""
        echo "✓ Configuration saved"
    fi

    # Initialize new queue
    echo ""
    echo "Building playlist queue..."
    do_sql "CALL fill_playlist_queue();"

    STATE_DATA=$(do_sql "SELECT current_pos, (SELECT COUNT(*) FROM playlist_queue), (SELECT COUNT(*) FROM playlist_queue WHERE sort_order >= 1) FROM presort_state WHERE id=1;")
    read CURRENT_POS TOTAL_SIZE REMAINING <<< "$STATE_DATA"

    echo "✓ Queue created: $TOTAL_SIZE videos loaded"

    if [[ $TOTAL_SIZE -eq 0 ]]; then
        echo ""
        echo "No videos match your current filters!"
        echo "Adjust your config and try again."
        exit 0
    fi

    CURRENT_POS=1

    # ASK: Quick export or select?
    echo ""
    echo "========================================================"
    echo "  $TOTAL_SIZE videos ready based on your config"
    echo "========================================================"
    read -p "Export all to M3U now OR select interactively? [e/s]: " QUICK_CHOICE

    if [[ "$QUICK_CHOICE" == "e" ]]; then
        # Quick export all
        TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
        M3U_FILE="playlist_auto_${TIMESTAMP}.m3u"

        do_sql "SELECT rel_path FROM playlist_queue ORDER BY sort_order;" > "$M3U_FILE"

        echo ""
        echo "========================================================"
        echo "✓ M3U GENERATED: $M3U_FILE"
        echo "  Contains: $TOTAL_SIZE videos"
        echo "========================================================"
        exit 0
    fi
fi

# =============================================================================
# STEP 3: INTERACTIVE SELECTION MODE
# =============================================================================

echo ""
echo "Starting interactive selection..."
echo "Press [q] at any time to quit"
echo ""
read -p "Press ENTER to begin..."

# Track selected videos
SELECTED_VIDEOS=()
B_CAPS_COUNT=0
QUIT_EARLY=false

while true; do
    # Reload position and count ACTUAL remaining videos
    STATE_DATA=$(do_sql "SELECT current_pos, (SELECT COUNT(*) FROM playlist_queue), (SELECT COUNT(*) FROM playlist_queue WHERE sort_order >= (SELECT current_pos FROM presort_state WHERE id=1)) FROM presort_state WHERE id=1;")
    read CUR_POS TOTAL_SIZE REMAINING <<< "$STATE_DATA"

    # Check if finished
    if [[ $REMAINING -le 0 ]] || [[ $TOTAL_SIZE -eq 0 ]]; then
        echo ""
        echo "========================================================"
        echo "         END OF QUEUE"
        echo "========================================================"
        break
    fi

    # Get next available video (handles gaps in sort_order)
    QUERY="SELECT v.id, v.rel_path, v.account, v.description, v.used_count, v.status, q.sort_order FROM videos v JOIN playlist_queue q ON v.id = q.video_id WHERE q.sort_order >= $CUR_POS ORDER BY q.sort_order LIMIT 1;"
    DATA=$(do_sql "$QUERY")

    if [[ -z "$DATA" ]]; then
        echo ""
        echo "⚠ No more videos found in queue from position $CUR_POS"
        echo "This usually means:"
        echo "  - Videos were deleted (blacklisted accounts)"
        echo "  - Queue needs rebuilding"
        echo ""
        echo "Run with 'new init' to rebuild the queue."
        break
    fi

    V_ID=$(echo "$DATA" | cut -f1)
    V_PATH=$(echo "$DATA" | cut -f2)
    V_ACC=$(echo "$DATA" | cut -f3)
    V_DESC=$(echo "$DATA" | cut -f4)
    V_USED=$(echo "$DATA" | cut -f5)
    V_STATUS=$(echo "$DATA" | cut -f6)
    ACTUAL_POS=$(echo "$DATA" | cut -f7)

    # Check file exists
    if [[ ! -f "$V_PATH" ]]; then
        echo "⚠ File not found: $V_PATH (skipping)"
        do_sql "UPDATE presort_state SET current_pos = current_pos + 1;"
        continue
    fi

    # Display video info
    clear

    # Calculate how many we've processed in this session
    PROCESSED=$((ACTUAL_POS - CURRENT_POS))

    echo "========================================================"
    echo "  PLAYLIST SELECTION"
    echo "  Processed: $PROCESSED | Remaining: $REMAINING"
    echo "  Selected so far: ${#SELECTED_VIDEOS[@]} videos"
    echo "========================================================"
    echo "👤 Account:    @$V_ACC"
    echo "📊 Status:     $V_STATUS"
    echo "🔄 Used:       $V_USED times"
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
    echo "[y]YES add to playlist | [n]NO skip | [w]Wait (decide later)"
    echo "[t/z]Rotate | [B]Blacklist account | [q]QUIT & save"
    echo "----------------------------------------------------"
    echo -n "Decision: "

    ACTION_DONE=false
    while [[ "$ACTION_DONE" == false ]]; do
        read -n 1 -s key
        case "$key" in
            y|Y)
                # Add to selected list
                SELECTED_VIDEOS+=("$V_PATH")
                do_sql "UPDATE videos SET used_count = used_count + 1, last_used = NOW() WHERE id=$V_ID;"
                do_sql "UPDATE presort_state SET current_pos = $((ACTUAL_POS + 1));"
                echo " ✓ ADDED"
                ACTION_DONE=true ;;
            n|N)
                # Skip, increment used count
                do_sql "UPDATE videos SET used_count = used_count + 1, last_used = NOW() WHERE id=$V_ID;"
                do_sql "UPDATE presort_state SET current_pos = $((ACTUAL_POS + 1));"
                echo " ✗ SKIPPED"
                ACTION_DONE=true ;;
            w|W)
                # Wait/decide later - just move pointer
                do_sql "UPDATE presort_state SET current_pos = $((ACTUAL_POS + 1));"
                echo " ⏭ WAIT"
                ACTION_DONE=true ;;
            r|R)
                # Restart (replay video)
                echo " ⟳ REPLAY"
                ACTION_DONE=true ;;

            # Rotation
            t|T)
                echo -n " 🔄 Rotating left..."
                ffmpeg -i "$V_PATH" -vf "transpose=2" -c:v libx264 -preset ultrafast -crf 18 -c:a copy "${V_PATH}.tmp" -y &>/dev/null
                mv "${V_PATH}.tmp" "$V_PATH"
                do_sql "UPDATE videos SET is_transformed=1 WHERE id=$V_ID;"
                echo " ✓"
                ACTION_DONE=true ;;
            z|Z)
                echo -n " 🔄 Rotating right..."
                ffmpeg -i "$V_PATH" -vf "transpose=1" -c:v libx264 -preset ultrafast -crf 18 -c:a copy "${V_PATH}.tmp" -y &>/dev/null
                mv "${V_PATH}.tmp" "$V_PATH"
                do_sql "UPDATE videos SET is_transformed=1 WHERE id=$V_ID;"
                echo " ✓"
                ACTION_DONE=true ;;

            # Blacklist account
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

            # Quit
            q|Q)
                echo ""
                echo ""
                echo "Exiting selection mode early..."
                QUIT_EARLY=true
                break 2 ;;
        esac
    done

    sleep 0.3  # Brief pause before next video
done

# =============================================================================
# STEP 4: CREATE M3U FROM SELECTED VIDEOS
# =============================================================================

echo ""
echo "========================================================"
echo "         RUN FINISHED"
echo "========================================================"
echo "Videos selected: ${#SELECTED_VIDEOS[@]}"
echo ""

if [[ ${#SELECTED_VIDEOS[@]} -eq 0 ]]; then
    echo "No videos selected. No playlist created."
    exit 0
fi

# If quit early, ASK. If finished naturally, auto-generate
if [[ "${QUIT_EARLY:-false}" == "true" ]]; then
    read -p "Create M3U from selected videos? (y/n): " CREATE_M3U
    if [[ "$CREATE_M3U" != "y" ]]; then
        echo "No playlist created."
        exit 0
    fi
fi

# Create M3U
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
M3U_FILE="playlist_selected_${TIMESTAMP}.m3u"

# Write selected videos to M3U
printf '%s\n' "${SELECTED_VIDEOS[@]}" > "$M3U_FILE"

echo "✓ M3U GENERATED: $M3U_FILE"
echo "  Contains: ${#SELECTED_VIDEOS[@]} videos"
echo "========================================================"

exit 0

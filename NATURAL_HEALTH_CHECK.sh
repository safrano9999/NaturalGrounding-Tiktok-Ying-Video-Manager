#!/bin/bash
# =============================================================================
# health_check.sh - System health monitoring
# Checks database connection, file integrity, queue status, and account stats
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config/db_config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}ERROR: Configuration file not found: $CONFIG_FILE${NC}" >&2
    exit 1
fi

source "$CONFIG_FILE"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

do_sql() {
    mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -N -s -e "$1" 2>/dev/null
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# =============================================================================
# HEALTH CHECKS
# =============================================================================

EXIT_CODE=0

print_header "NATURAL GROUNDING VIDEO MANAGER - HEALTH CHECK"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"

# -----------------------------------------------------------------------------
# 1. DATABASE CONNECTION
# -----------------------------------------------------------------------------
print_header "1. Database Connection"

if mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -e "SELECT 1" &>/dev/null; then
    print_ok "Database connection successful"
    DB_VERSION=$(mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" -N -s -e "SELECT VERSION();")
    echo "   Server: $DB_HOST | Version: $DB_VERSION"
else
    print_error "Database connection FAILED"
    EXIT_CODE=1
    exit $EXIT_CODE
fi

# -----------------------------------------------------------------------------
# 2. TABLE STRUCTURE
# -----------------------------------------------------------------------------
print_header "2. Table Structure"

REQUIRED_TABLES=("accounts" "videos" "presort_queue" "playlist_queue" "playlist_config" "presort_state")
MISSING_TABLES=()

for table in "${REQUIRED_TABLES[@]}"; do
    if do_sql "SHOW TABLES LIKE '$table';" | grep -q "$table"; then
        print_ok "Table '$table' exists"
    else
        print_error "Table '$table' MISSING"
        MISSING_TABLES+=("$table")
        EXIT_CODE=1
    fi
done

if [[ ${#MISSING_TABLES[@]} -gt 0 ]]; then
    echo ""
    print_error "Missing tables found! Run corrected_schema.sql or migration.sql"
fi

# Check for critical columns in videos table
CRITICAL_COLS=("video_id" "height" "view_count" "upload_date" "description" "init_ytdlp")
MISSING_COLS=()

for col in "${CRITICAL_COLS[@]}"; do
    if do_sql "SHOW COLUMNS FROM videos LIKE '$col';" | grep -q "$col"; then
        :  # Column exists
    else
        MISSING_COLS+=("$col")
    fi
done

if [[ ${#MISSING_COLS[@]} -gt 0 ]]; then
    print_warning "Videos table missing columns: ${MISSING_COLS[*]}"
    echo "   Run migration.sql to add them"
    EXIT_CODE=1
fi

# Check presort_queue structure
if do_sql "SHOW COLUMNS FROM presort_queue LIKE 'queue_pos';" | grep -q "queue_pos"; then
    print_ok "presort_queue has queue_pos column (required!)"
else
    print_error "presort_queue MISSING queue_pos column!"
    echo "   This will break presort_sql.sh - run migration.sql"
    EXIT_CODE=1
fi

# -----------------------------------------------------------------------------
# 3. ACCOUNT STATISTICS
# -----------------------------------------------------------------------------
print_header "3. Account Statistics"

TOTAL_ACCOUNTS=$(do_sql "SELECT COUNT(*) FROM accounts;")
ACTIVE_ACCOUNTS=$(do_sql "SELECT COUNT(*) FROM accounts WHERE is_valid = 1;")
BLACKLISTED=$(do_sql "SELECT COUNT(*) FROM accounts WHERE is_valid = 0;")

echo "Total accounts:      $TOTAL_ACCOUNTS"
echo "Active accounts:     $ACTIVE_ACCOUNTS"
echo "Blacklisted:         $BLACKLISTED"

if [[ $ACTIVE_ACCOUNTS -eq 0 ]]; then
    print_warning "No active accounts! Add some with NEW_ACCOUNT.sh"
fi

# -----------------------------------------------------------------------------
# 4. VIDEO STATISTICS
# -----------------------------------------------------------------------------
print_header "4. Video Statistics"

TOTAL_VIDEOS=$(do_sql "SELECT COUNT(*) FROM videos;")
PHYSICAL_VIDEOS=$(do_sql "SELECT COUNT(*) FROM videos WHERE is_physical = 1;")

# Pending videos - only from VALID accounts
PENDING_VALID=$(do_sql "SELECT COUNT(*) FROM videos v JOIN accounts a ON v.account = a.username WHERE v.status = 'pending' AND a.is_valid = 1 AND v.is_physical = 1;")
PENDING_BLOCKED=$(do_sql "SELECT COUNT(*) FROM videos v JOIN accounts a ON v.account = a.username WHERE v.status = 'pending' AND a.is_valid = 0;")
PENDING_TOTAL=$(do_sql "SELECT COUNT(*) FROM videos WHERE status = 'pending';")

SEHR_GUT=$(do_sql "SELECT COUNT(*) FROM videos WHERE status = 'sehr_gut';")
GUT=$(do_sql "SELECT COUNT(*) FROM videos WHERE status = 'gut';")
E3=$(do_sql "SELECT COUNT(*) FROM videos WHERE status = 'e3';")
UNBRAUCHBAR=$(do_sql "SELECT COUNT(*) FROM videos WHERE status = 'unbrauchbar';")

echo "Total videos:        $TOTAL_VIDEOS"
echo "Physical on disk:    $PHYSICAL_VIDEOS"
echo ""
echo "Status breakdown:"
echo "  Pending (valid):   $PENDING_VALID"
if [[ $PENDING_BLOCKED -gt 0 ]]; then
    echo "  Pending (blocked): $PENDING_BLOCKED"
fi
echo "  Sehr gut:          $SEHR_GUT"
echo "  Gut:               $GUT"
echo "  E3:                $E3"
echo "  Unbrauchbar:       $UNBRAUCHBAR"

if [[ $TOTAL_VIDEOS -eq 0 ]]; then
    print_warning "No videos in database! Run NATURAL_MANAGER.sh to download some"
fi

# Show pending breakdown by account (valid only)
if [[ $PENDING_VALID -gt 0 ]]; then
    echo ""
    echo "Pending videos by account (valid only):"
    do_sql "SELECT v.account, COUNT(*) as count FROM videos v JOIN accounts a ON v.account = a.username WHERE v.status = 'pending' AND a.is_valid = 1 AND v.is_physical = 1 GROUP BY v.account ORDER BY count DESC LIMIT 10;" | 
    while IFS=$'\t' read -r account count; do
        echo "  @$account: $count videos"
    done
fi

# -----------------------------------------------------------------------------
# 5. FILE INTEGRITY CHECK
# -----------------------------------------------------------------------------
print_header "5. File Integrity Check"

echo "Checking if database videos exist on disk..."

MISSING_FILES=0
FOUND_FILES=0

# Sample check (first 100 videos) - full check would be slow
SAMPLE_SIZE=100
VIDEO_PATHS=$(do_sql "SELECT rel_path FROM videos WHERE is_physical = 1 LIMIT $SAMPLE_SIZE;")

while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    
    if [[ -f "$path" ]]; then
        ((FOUND_FILES++))
    else
        ((MISSING_FILES++))
        if [[ $MISSING_FILES -le 5 ]]; then
            print_warning "Missing: $path"
        fi
    fi
done <<< "$VIDEO_PATHS"

TOTAL_CHECKED=$((FOUND_FILES + MISSING_FILES))

if [[ $MISSING_FILES -gt 0 ]]; then
    print_warning "Found $MISSING_FILES missing files out of $TOTAL_CHECKED checked"
    echo "   Consider running: UPDATE videos SET is_physical=0 WHERE id IN (...);"
else
    print_ok "All $TOTAL_CHECKED sampled files exist on disk"
fi

# -----------------------------------------------------------------------------
# 6. QUEUE STATUS
# -----------------------------------------------------------------------------
print_header "6. Queue Status"

# Presort queue
PRESORT_TOTAL=$(do_sql "SELECT COUNT(*) FROM presort_queue;")
PRESORT_POS=$(do_sql "SELECT current_pos FROM presort_state WHERE id = 1;")
PRESORT_REMAINING=$((PRESORT_TOTAL - PRESORT_POS + 1))

echo "Presort Queue:"
echo "  Total videos:      $PRESORT_TOTAL"
echo "  Current position:  $PRESORT_POS"
echo "  Remaining:         $PRESORT_REMAINING"

if [[ $PRESORT_TOTAL -eq 0 ]] && [[ $PENDING_VALID -gt 0 ]]; then
    print_warning "Presort queue empty but $PENDING_VALID pending videos exist (from valid accounts)"
    echo "   Run presort_sql.sh and choose 'init' to populate queue"
fi

# Playlist queue
PLAYLIST_TOTAL=$(do_sql "SELECT COUNT(*) FROM playlist_queue;")
PLAYLIST_POS=$(do_sql "SELECT current_pos FROM presort_state WHERE id = 1;")
PLAYLIST_REMAINING=$((PLAYLIST_TOTAL - PLAYLIST_POS + 1))

echo ""
echo "Playlist Queue:"
echo "  Total videos:      $PLAYLIST_TOTAL"
echo "  Current position:  $PLAYLIST_POS"
echo "  Remaining:         $PLAYLIST_REMAINING"

if [[ $PLAYLIST_TOTAL -eq 0 ]] && [[ $SEHR_GUT -gt 0 || $GUT -gt 0 ]]; then
    print_warning "Playlist queue empty but rated videos exist"
    echo "   Run playlist_sql_fallback.sh and choose 'init' to populate queue"
fi

# -----------------------------------------------------------------------------
# 7. DISK USAGE
# -----------------------------------------------------------------------------
print_header "7. Disk Usage"

if [[ -d "VIDEOS" ]]; then
    DISK_USAGE=$(du -sh VIDEOS 2>/dev/null | cut -f1)
    VIDEO_COUNT=$(find VIDEOS -type f -name "*.mp4" 2>/dev/null | wc -l)
    echo "VIDEOS directory:    $DISK_USAGE ($VIDEO_COUNT .mp4 files)"
    
    # Check if disk is getting full
    DISK_FREE=$(df -h VIDEOS | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $DISK_FREE -gt 90 ]]; then
        print_warning "Disk usage is ${DISK_FREE}% - consider cleaning up"
    else
        print_ok "Disk usage: ${DISK_FREE}%"
    fi
else
    print_warning "VIDEOS directory not found"
fi

# -----------------------------------------------------------------------------
# 8. RECENT ACTIVITY
# -----------------------------------------------------------------------------
print_header "8. Recent Activity"

RECENT_DOWNLOADS=$(do_sql "SELECT COUNT(*) FROM videos WHERE DATE(id_zeitpunkt_ytdlp) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY);")
RECENT_PRESORTS=$(do_sql "SELECT COUNT(*) FROM videos WHERE status != 'pending' AND DATE(updated_at) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY);")
RECENT_USAGE=$(do_sql "SELECT COUNT(*) FROM videos WHERE DATE(last_used) >= DATE_SUB(CURDATE(), INTERVAL 7 DAY);")

echo "Last 7 days:"
echo "  Videos downloaded: $RECENT_DOWNLOADS"
echo "  Videos presorted:  $RECENT_PRESORTS"
echo "  Videos used:       $RECENT_USAGE"

# -----------------------------------------------------------------------------
# 9. TOP ACCOUNTS
# -----------------------------------------------------------------------------
print_header "9. Top Accounts by Video Count (Valid Only)"

do_sql "SELECT a.username, COUNT(v.id) as count FROM accounts a LEFT JOIN videos v ON a.username = v.account WHERE a.is_valid = 1 GROUP BY a.username ORDER BY count DESC LIMIT 5;" | 
while IFS=$'\t' read -r username count; do
    echo "  @$username: $count videos"
done

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
print_header "SUMMARY"

if [[ $EXIT_CODE -eq 0 ]]; then
    print_ok "System health check passed!"
else
    print_error "System health check found issues (see above)"
fi

echo ""
exit $EXIT_CODE

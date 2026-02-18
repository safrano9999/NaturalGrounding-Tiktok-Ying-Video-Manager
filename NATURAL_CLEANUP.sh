#!/bin/bash
# =============================================================================
# cleanup.sh - FRÜHJAHRSPUTZ (mit SQL Procedures)
# SQL-Logik in der Datenbank, Shell nur für Dateien
# =============================================================================

source ./config/db_config.env

do_sql() {
    mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" "$@"
}

echo "======================================================="
echo "   🧹 FRÜHJAHRSPUTZ - CLEANUP"
echo "======================================================="
echo ""

# =============================================================================
# VORSCHAU (aus DB-Procedure)
# =============================================================================

echo "Videos die gelöscht werden:"
echo ""

do_sql -e "CALL get_cleanup_preview();"

echo ""
TOTAL=$(do_sql -N -s -e "
SELECT COUNT(*) 
FROM videos v
LEFT JOIN accounts a ON v.account = a.username
WHERE (v.status = 'unbrauchbar' AND v.is_physical = 1)
   OR (v.status = 'pending' AND v.is_physical = 1 AND a.is_valid = 0);")

echo "======================================================="
echo "📦 GESAMT ZU LÖSCHEN: $TOTAL Dateien"
echo "======================================================="
echo ""

if [[ "$TOTAL" -eq 0 ]]; then
    echo "✨ Alles sauber! Nichts zu löschen."
    exit 0
fi

read -p "Frühjahrsputz starten? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    echo "Abgebrochen."
    exit 0
fi

# =============================================================================
# CLEANUP (Videos aus DB-Procedure holen)
# =============================================================================

echo ""
echo "🧹 Starte Cleanup..."
echo ""

DELETED_COUNT=0

# Hole Liste aus Procedure
do_sql -N -s -e "CALL get_cleanup_videos();" | \
while IFS=$'\t' read -r V_ID V_PATH V_ACCOUNT V_STATUS; do
    
    # 1. Lösche Datei von HDD
    if [[ -f "$V_PATH" ]]; then
        rm -f "$V_PATH"
        rm -f "${V_PATH%.mp4}.info.json"
        echo "  ✓ @$V_ACCOUNT [$V_STATUS]: $(basename "$V_PATH")"
    else
        echo "  ⚠ Fehlt bereits: $(basename "$V_PATH")"
    fi
    
    # 2. Markiere in DB als gelöscht (via Procedure)
    do_sql -e "CALL mark_video_deleted($V_ID);" 2>/dev/null
    
    ((DELETED_COUNT++))
done

# =============================================================================
# ZUSAMMENFASSUNG (aus DB-Procedure)
# =============================================================================

echo ""
echo "======================================================="
echo "✅ FRÜHJAHRSPUTZ ABGESCHLOSSEN!"
echo "======================================================="
echo ""

do_sql -e "CALL get_cleanup_summary();"

echo ""
echo "💾 Speicherplatz:"
du -sh VIDEOS/ 2>/dev/null || echo "VIDEOS/ leer"

echo ""
echo "ℹ️  DB-Einträge bleiben erhalten → Kein Re-Download!"
echo ""

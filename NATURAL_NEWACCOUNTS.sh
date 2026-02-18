#!/bin/bash

# Pfad zur Config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/db_config.env"

# Prüfen ob Config existiert
if [ ! -f "$CONFIG_FILE" ]; then
    echo "FEHLER: $CONFIG_FILE nicht gefunden!"
    exit 1
fi

# Sourcen der Variablen (DB_HOST, DB_NAME, DB_USER, DB_PW)
source "$CONFIG_FILE"

# Modus-Check
VALID_VALUE=1
MODUS_TEXT="AKTIVIEREN (is_valid=1)"
[[ "$*" == *"--blacklist"* ]] && VALID_VALUE=0 && MODUS_TEXT="BLACKLIST (is_valid=0)"

process_account() {
    local acc=$1

    # 1. Prüfen, ob der Account schon existiert und was sein aktueller Status ist
    # Wir holen uns direkt den aktuellen is_valid Wert
    local current_status=$(mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -N -s -e "SELECT is_valid FROM accounts WHERE username = '$acc';")

    if [ -n "$current_status" ]; then
        # Account existiert bereits
        if [ "$current_status" -eq "$VALID_VALUE" ]; then
            echo "--> [SKIP] $acc ist bereits auf $MODUS_TEXT"
        else
            # Status hat sich geändert -> UPDATE (ID bleibt gleich!)
            local query="UPDATE accounts SET is_valid = $VALID_VALUE WHERE username = '$acc';"
            mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -e "$query"
            echo "--> [UPDATE] $acc von $current_status auf $VALID_VALUE gesetzt"
        fi
    else
        # Account existiert noch nicht -> INSERT (ID geht hoch!)
        local query="INSERT INTO accounts (username, is_valid) VALUES ('$acc', $VALID_VALUE);"
        mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -e "$query"
        echo "--> [NEU] $acc angelegt als $MODUS_TEXT"
    fi
}

# Input-Logik (Datei oder Manuell)
INPUT_FILE=""
for arg in "$@"; do [[ -f "$arg" ]] && INPUT_FILE="$arg" && break; done

echo "--- Modus: $MODUS_TEXT via $DB_HOST ---"

if [ -n "$INPUT_FILE" ]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        clean_name=$(echo "$line" | sed 's/\[.*\] //g' | xargs)
        [[ -z "$clean_name" || "$clean_name" =~ ^# ]] && continue
        process_account "$clean_name"
    done < "$INPUT_FILE"
else
    echo "Tippe Namen + ENTER (q zum Beenden):"
    while read -p "> " manual_acc && [[ "$manual_acc" != "q" ]]; do
        [[ -n "$manual_acc" ]] && process_account "$manual_acc"
    done
fi

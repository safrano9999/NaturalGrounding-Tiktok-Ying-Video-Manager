#!/usr/bin/env bash
# Shared runtime bootstrap for NaturalGrounding scripts.
#
# REPOS injects DB_* values as container env vars. Bare-metal installs can keep
# using config/db_config.env. Existing environment values win over file values.

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

CONFIG_FILE="${NG_CONFIG_FILE:-$SCRIPT_DIR/config/db_config.env}"
_RUNTIME_KEYS=(DB_HOST DB_PORT DB_NAME DB_USER DB_PW VIDEOS_DIR NG_CONFIG_FILE)

# Preserve env injected by REPOS/container before sourcing a legacy file.
for key in "${_RUNTIME_KEYS[@]}"; do
    if [[ -v $key ]]; then
        printf -v "__NG_PRE_${key}" '%s' "${!key}"
    fi
done

if [[ -f "$CONFIG_FILE" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    set +a
fi

for key in "${_RUNTIME_KEYS[@]}"; do
    pre="__NG_PRE_${key}"
    if [[ -v $pre ]]; then
        printf -v "$key" '%s' "${!pre}"
        export "$key"
        unset "$pre"
    fi
done
unset key pre _RUNTIME_KEYS

: "${DB_HOST:=127.0.0.1}"
: "${DB_PORT:=3306}"
: "${DB_NAME:=NaturalGrounding-Tiktok-Ying-Video-Manager}"
: "${DB_USER:=NaturalGrounding-Tiktok-Ying-Video-Manager}"
: "${VIDEOS_DIR:=$SCRIPT_DIR/VIDEOS}"

missing=()
for key in DB_HOST DB_NAME DB_USER DB_PW; do
    if [[ -z "${!key:-}" ]]; then
        missing+=("$key")
    fi
done

if (( ${#missing[@]} > 0 )); then
    echo "ERROR: Missing database settings: ${missing[*]}" >&2
    echo "Set them via REPOS env or create $CONFIG_FILE" >&2
    return 1 2>/dev/null || exit 1
fi

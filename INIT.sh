#!/bin/bash
# =============================================================================
# init.sh - Simple deployment for Natural Grounding Video Manager
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "======================================================="
echo "  NATURAL GROUNDING VIDEO MANAGER - INIT"
echo "======================================================="
echo ""

# Create config directory
mkdir -p config VIDEOS tmp

# Check for config file
if [[ ! -f "config/db_config.env" ]]; then
    echo -e "${YELLOW}No config found. Creating from template...${NC}"

    if [[ -f "config/db_config.env.example" ]]; then
        cp config/db_config.env.example config/db_config.env
    else
        # Create default config
        cat > config/db_config.env << 'DBCONF'
DB_HOST=localhost
DB_NAME=NaturalGrounding-Tiktok-Ying-Video-Manager
DB_USER=nguser
DB_PW=ngpass
DBCONF
    fi

    echo -e "${GREEN}✓${NC} Created config/db_config.env"
    echo ""
    echo "Edit config/db_config.env with your credentials, then run:"
    echo "  ./init.sh"
    exit 0
fi

# Load config
source ./config/db_config.env

echo "Database: $DB_NAME @ $DB_HOST"
echo ""

# Test connection
echo "Testing database connection..."
if ! mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" -e "SELECT 1;" &>/dev/null; then
    echo -e "${RED}✗ Connection failed!${NC}"
    echo "Check config/db_config.env"
    exit 1
fi

echo -e "${GREEN}✓${NC} Connected to database"

# Import schema
if [[ -f "schema.sql" ]]; then
    echo "Importing schema..."
    sed 's/DEFINER=[^ ]* //g' schema.sql | mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME"
    echo -e "${GREEN}✓${NC} Schema imported"
else
    echo -e "${RED}✗ schema.sql not found!${NC}"
    exit 1
fi

# Make scripts executable
chmod +x NATURAL_*.sh sync.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}=======================================================${NC}"
echo -e "${GREEN}  ✓ READY!${NC}"
echo -e "${GREEN}=======================================================${NC}"
echo ""
echo "Next: ./NATURAL_NEWACCOUNTS.sh"
echo ""

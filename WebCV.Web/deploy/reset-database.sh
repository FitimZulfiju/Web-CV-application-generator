#!/bin/bash
# WebCV Database Reset Script
# Purpose: Stops SQL Server container and deletes database volume for clean migration setup
# Usage: ./reset-database.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="${1:-webcv-sqlserver}"
VOLUME_NAME="${2:-deploywebcv_webcv_sql_data}"

log() {
    echo -e "${2}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

echo -e "${CYAN}========================================"
echo "WebCV Database Reset Script"
echo -e "========================================${NC}"
echo ""

# Check if Docker is available
log "[1/4] Checking Docker availability..." "$YELLOW"
if ! command -v docker &> /dev/null; then
    log "✗ Docker is not installed or not in PATH" "$RED"
    exit 1
fi
log "✓ Docker is available" "$GREEN"

# Check if container exists
echo ""
log "[2/4] Checking if container '$CONTAINER_NAME' exists..." "$YELLOW"
if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    log "✓ Container found" "$GREEN"
    
    # Stop container if running
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log "  → Stopping container..." "$YELLOW"
        docker stop "$CONTAINER_NAME" > /dev/null
        log "  ✓ Container stopped" "$GREEN"
    else
        log "  → Container already stopped" "$GRAY"
    fi
    
    # Remove container
    log "  → Removing container..." "$YELLOW"
    docker rm "$CONTAINER_NAME" > /dev/null
    log "  ✓ Container removed" "$GREEN"
else
    log "  → Container not found (already clean)" "$GRAY"
fi

# Check if volume exists
echo ""
log "[3/4] Checking if volume '$VOLUME_NAME' exists..." "$YELLOW"
if docker volume ls --format "{{.Name}}" | grep -q "^${VOLUME_NAME}$"; then
    log "✓ Volume found" "$GREEN"
    log "  → Removing volume..." "$YELLOW"
    docker volume rm "$VOLUME_NAME" > /dev/null
    log "  ✓ Volume removed" "$GREEN"
else
    log "  → Volume not found (already clean)" "$GRAY"
fi

# Summary
echo ""
log "[4/4] Cleanup Summary" "$YELLOW"
echo -e "${CYAN}========================================"
log "✓ SQL Server container removed" "$GREEN"
log "✓ Database volume deleted" "$GREEN"
log "✓ Ready for fresh database creation" "$GREEN"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo -e "${NC}1. Start your application: docker-compose up -d"
echo -e "${NC}2. Run migrations: dotnet ef database update"
echo ""
log "Database reset complete! 🎉" "$GREEN"

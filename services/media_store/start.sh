#!/bin/bash

################################################################################
#                    CL Server - Start Media Store Service
################################################################################
#
# This script starts the Media Store service.
#
# Usage:
#   ./start.sh              # Start with AUTH_DISABLED=true
#   ./start.sh --with-auth  # Start with authentication enabled
#
# Environment Variables (Required):
#   CL_VENV_DIR - Path to directory containing virtual environments
#   CL_SERVER_DIR - Path to data directory
#
# Service:
#   - Media Store Service on port 8001
#   - Includes database migrations
#
################################################################################

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common utilities (local to this service)
source "$SCRIPT_DIR/common.sh"

# Service configuration
SERVICE_NAME="Media_Store"
SERVICE_PATH="services/media_store"
SERVICE_ENV_NAME="media_store"
PORT=8001
AUTH_DISABLED="true"

# Parse command line arguments
if [[ "$1" == "--with-auth" ]]; then
    AUTH_DISABLED="false"
    echo -e "${BLUE}Starting Media Store service WITH authentication enabled${NC}"
else
    echo -e "${BLUE}Starting Media Store service with AUTH_DISABLED=true (no authentication required)${NC}"
fi

echo ""

################################################################################
# Validate environment variables
################################################################################

echo "Validating environment variables..."
echo ""

if ! validate_venv_dir; then
    exit 1
fi

echo ""

if ! validate_cl_server_dir; then
    exit 1
fi

echo ""

# Ensure logs directory exists
LOGS_DIR=$(ensure_logs_dir)
if [ $? -ne 0 ]; then
    echo -e "${RED}[✗] Failed to create logs directory${NC}"
    exit 1
fi

echo ""

################################################################################
# Run Database Migrations
################################################################################

if ! run_migrations "$SERVICE_NAME" "$PROJECT_ROOT/$SERVICE_PATH" "$SERVICE_ENV_NAME"; then
    echo -e "${RED}[✗] Failed to run migrations${NC}"
    exit 1
fi

echo ""

################################################################################
# Start Media Store Service
################################################################################

print_header "Starting Media Store Service"

if start_service "$SERVICE_NAME" "$PROJECT_ROOT/$SERVICE_PATH" "$PORT" "$AUTH_DISABLED" "$SERVICE_ENV_NAME"; then
    # Service stopped normally
    echo ""
    echo -e "${YELLOW}[*] Media Store service stopped${NC}"
else
    # Service failed to start
    echo ""
    echo -e "${RED}[✗] Failed to start Media Store service${NC}"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

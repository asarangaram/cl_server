#!/bin/bash

################################################################################
#                     CL Server - Start Inference Service
################################################################################
#
# This script starts the Inference service.
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
#   - Inference Service on port 8002
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
SERVICE_NAME="Inference"
SERVICE_PATH="services/inference"
SERVICE_ENV_NAME="inference"
PORT=8002
AUTH_DISABLED="true"

# Parse command line arguments
if [[ "$1" == "--with-auth" ]]; then
    AUTH_DISABLED="false"
    echo -e "${BLUE}Starting Inference service WITH authentication enabled${NC}"
else
    echo -e "${BLUE}Starting Inference service with AUTH_DISABLED=true (no authentication required)${NC}"
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
# Start Inference Service
################################################################################

print_header "Starting Inference Service"

if start_service "$SERVICE_NAME" "$PROJECT_ROOT/$SERVICE_PATH" "$PORT" "$AUTH_DISABLED" "$SERVICE_ENV_NAME"; then
    # Service stopped normally
    echo ""
    echo -e "${YELLOW}[*] Inference service stopped${NC}"
else
    # Service failed to start
    echo ""
    echo -e "${RED}[✗] Failed to start Inference service${NC}"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

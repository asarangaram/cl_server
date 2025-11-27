#!/bin/bash

################################################################################
#                    CL Server - Start Inference Worker
################################################################################
#
# This script starts the Inference Worker process for processing queued jobs.
#
# Usage:
#   ./worker.sh  # Start worker process
#
# Environment Variables (Required):
#   CL_VENV_DIR - Path to directory containing virtual environments
#   CL_SERVER_DIR - Path to data directory
#
# Service:
#   - Inference Worker (connects to inference service on port 8002)
#
# Note:
#   The inference service must be running before starting the worker.
#   Start the service with: ./start.sh
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
SERVICE_NAME="Inference Worker"
SERVICE_PATH="services/inference"
SERVICE_ENV_NAME="inference"

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

################################################################################
# Start Inference Worker
################################################################################

print_header "Starting Inference Worker"

# Setup venv
setup_venv "$PROJECT_ROOT/$SERVICE_PATH" "$SERVICE_ENV_NAME"

echo -e "${GREEN}[✓] Starting Inference Worker${NC}"
echo -e "${BLUE}[*] Press Ctrl+C to stop${NC}"
echo ""

# Trap to handle shutdown
trap 'echo -e "\n${YELLOW}[*] Inference Worker stopped${NC}"; exit 0' SIGTERM SIGINT

# Start Worker in foreground
CL_SERVER_DIR="$CL_SERVER_DIR" AUTH_DISABLED=true python -m src.worker

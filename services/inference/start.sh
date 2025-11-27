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
# Start Inference Service and Worker
################################################################################

print_header "Starting Inference Service and Worker"

# Setup venv (needed for both service and worker)
setup_venv "$PROJECT_ROOT/$SERVICE_PATH" "$SERVICE_ENV_NAME"

# Check if port is already in use
if check_port $PORT; then
    echo -e "${RED}[✗] Error: Port $PORT is already in use${NC}"
    echo -e "${YELLOW}    To kill the process: lsof -ti:$PORT | xargs kill -9${NC}"
    exit 1
fi

echo -e "${GREEN}[✓] Starting Inference Service on port $PORT${NC}"
echo -e "${GREEN}[✓] Starting Inference Worker${NC}"
echo -e "${BLUE}[*] Press Ctrl+C to stop both services${NC}"
echo ""

# Store PIDs for cleanup
declare -a PIDS=()

# Trap to handle shutdown
trap 'shutdown_services' SIGTERM SIGINT

shutdown_services() {
    echo ""
    echo -e "${YELLOW}[*] Shutting down services...${NC}"
    for pid in "${PIDS[@]}"; do
        if kill -0 $pid 2>/dev/null; then
            echo -e "${BLUE}[*] Stopping process $pid...${NC}"
            kill -TERM $pid 2>/dev/null || true
            # Wait up to 5 seconds for graceful shutdown
            for i in {1..50}; do
                if ! kill -0 $pid 2>/dev/null; then
                    break
                fi
                sleep 0.1
            done
            # Force kill if still running
            kill -9 $pid 2>/dev/null || true
        fi
    done
    echo -e "${YELLOW}[*] Services stopped${NC}"
    exit 0
}

# Start FastAPI service in background
if [ "$AUTH_DISABLED" == "true" ]; then
    CL_SERVER_DIR="$CL_SERVER_DIR" AUTH_DISABLED=true python "$PROJECT_ROOT/$SERVICE_PATH/main.py" > "$LOGS_DIR/inference_service.log" 2>&1 &
else
    CL_SERVER_DIR="$CL_SERVER_DIR" python "$PROJECT_ROOT/$SERVICE_PATH/main.py" > "$LOGS_DIR/inference_service.log" 2>&1 &
fi
SERVICE_PID=$!
PIDS+=($SERVICE_PID)
echo -e "${GREEN}[✓] Inference Service started (PID: $SERVICE_PID)${NC}"

# Give the service a moment to initialize
sleep 3

# Check if service is running before starting worker
if ! kill -0 $SERVICE_PID 2>/dev/null; then
    echo -e "${RED}[✗] Inference Service failed to start${NC}"
    echo -e "${YELLOW}[!] Check logs: $LOGS_DIR/inference_service.log${NC}"
    exit 1
fi

# Start Worker in background (optional - doesn't block service)
echo -e "${BLUE}[*] Attempting to start Inference Worker...${NC}"
CL_SERVER_DIR="$CL_SERVER_DIR" AUTH_DISABLED=true python -m src.worker > "$LOGS_DIR/inference_worker.log" 2>&1 &
WORKER_PID=$!
PIDS+=($WORKER_PID)

# Give worker a moment to start
sleep 1
if kill -0 $WORKER_PID 2>/dev/null; then
    echo -e "${GREEN}[✓] Inference Worker started (PID: $WORKER_PID)${NC}"
else
    echo -e "${YELLOW}[!] Inference Worker failed to start (worker logs: $LOGS_DIR/inference_worker.log)${NC}"
    echo -e "${YELLOW}[!] Service will continue without worker - jobs will queue but not process${NC}"
    WORKER_PID=""
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Service logs: $LOGS_DIR/inference_service.log${NC}"
echo -e "${BLUE}Worker logs:  $LOGS_DIR/inference_worker.log${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Monitor processes
while true; do
    # Check if service is still running
    if ! kill -0 $SERVICE_PID 2>/dev/null; then
        echo -e "${RED}[✗] Inference Service died unexpectedly${NC}"
        shutdown_services
    fi

    # Check if worker is still running (if it was started)
    if [ -n "$WORKER_PID" ]; then
        if ! kill -0 $WORKER_PID 2>/dev/null; then
            echo -e "${YELLOW}[!] Inference Worker died, attempting restart...${NC}"
            sleep 2
            CL_SERVER_DIR="$CL_SERVER_DIR" AUTH_DISABLED=true python -m src.worker > "$LOGS_DIR/inference_worker.log" 2>&1 &
            WORKER_PID=$!
            sleep 1
            if kill -0 $WORKER_PID 2>/dev/null; then
                echo -e "${GREEN}[✓] Inference Worker restarted (PID: $WORKER_PID)${NC}"
            else
                echo -e "${YELLOW}[!] Inference Worker failed to restart${NC}"
                WORKER_PID=""
            fi
        fi
    fi

    sleep 1
done

#!/bin/bash

################################################################################
#                     CL Server - Start All Services
################################################################################
#
# This script starts all microservices by calling their individual
# start scripts. Each service is started in its own background process.
#
# Usage:
#   ./start_all.sh              # Start all services with AUTH_DISABLED=true
#   ./start_all.sh --with-auth  # Start with authentication enabled
#
# Environment Variables (Required):
#   CL_VENV_DIR - Path to directory containing virtual environments
#   CL_SERVER_DIR - Path to data directory
#
# Services started:
#   - Authentication Service on port 8000
#   - Media Store Service on port 8001
#   - Inference Service on port 8002
#   - Inference Worker (job processing, no dedicated port)
#
# Logs are stored in: $CL_SERVER_DIR/run_logs/
#
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
SERVICES_STARTED=0
SERVICES_FAILED=0
AUTH_FLAG=""

# Parse command line arguments
if [[ "$1" == "--with-auth" ]]; then
    AUTH_FLAG="--with-auth"
    echo -e "${BLUE}Starting all services WITH authentication enabled${NC}"
else
    echo -e "${BLUE}Starting all services with AUTH_DISABLED=true (no authentication required)${NC}"
fi

echo ""

################################################################################
# Validate CL_SERVER_DIR
################################################################################

if [ -z "$CL_SERVER_DIR" ]; then
    echo -e "${RED}[✗] Error: CL_SERVER_DIR environment variable must be set${NC}"
    echo -e "${YELLOW}    Example: export CL_SERVER_DIR=/path/to/data${NC}"
    exit 1
fi

if [ ! -w "$CL_SERVER_DIR" ]; then
    echo -e "${RED}[✗] Error: No write permission for CL_SERVER_DIR: $CL_SERVER_DIR${NC}"
    echo -e "${YELLOW}    Please ensure the directory exists and you have write permissions${NC}"
    exit 1
fi

echo -e "${GREEN}[✓] CL_SERVER_DIR is set and writable: $CL_SERVER_DIR${NC}"

echo ""

################################################################################
# Validate CL_VENV_DIR
################################################################################

if [ -z "$CL_VENV_DIR" ]; then
    echo -e "${RED}[✗] Error: CL_VENV_DIR environment variable must be set${NC}"
    echo -e "${YELLOW}    Example: export CL_VENV_DIR=/path/to/venv${NC}"
    exit 1
fi

if [ ! -w "$(dirname "$CL_VENV_DIR")" ]; then
    echo -e "${RED}[✗] Error: No write permission for parent of CL_VENV_DIR: $CL_VENV_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}[✓] CL_VENV_DIR is set and writable: $CL_VENV_DIR${NC}"

echo ""

################################################################################
# Create logs directory
################################################################################

LOGS_DIR="$CL_SERVER_DIR/run_logs"

if [ ! -d "$LOGS_DIR" ]; then
    echo -e "${BLUE}[*] Creating logs directory: $LOGS_DIR${NC}"
    if ! mkdir -p "$LOGS_DIR" 2>/dev/null; then
        echo -e "${RED}[✗] Failed to create logs directory${NC}"
        exit 1
    fi
    echo -e "${GREEN}[✓] Logs directory created${NC}"
fi

echo ""

################################################################################
# Start all services
################################################################################

print_header() {
    local title=$1
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    ${title}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_header "Starting All Services"

echo "Starting services in background..."
echo "Logs directory: $LOGS_DIR"
echo ""

################################################################################
# Function to start a service in background (for orchestration)
################################################################################
start_service_background() {
    local service_name=$1
    local service_script=$2

    echo -e "${BLUE}[*] $service_name${NC}"

    # Run the service script in background, redirecting output to log file
    # The script itself runs the service in foreground, so we wrap it in background
    # Pass environment variables to the service script
    ( export CL_VENV_DIR="$CL_VENV_DIR"; export CL_SERVER_DIR="$CL_SERVER_DIR"; bash "$service_script" $AUTH_FLAG > "$LOGS_DIR/${service_name}.log" 2>&1 ) &

    # Store the PID
    local pid=$!
    PIDS+=($pid)
    SERVICES_STARTED=$((SERVICES_STARTED + 1))

    echo -e "${GREEN}     ✓ Started (PID: $pid)${NC}"
}

# Track pids for status monitoring
PIDS=()

# Start all services
echo "Launching services..."
echo ""

start_service_background "Authentication" "$PROJECT_ROOT/services/authentication/start.sh"
sleep 2

start_service_background "Media_Store" "$PROJECT_ROOT/services/media_store/start.sh"
sleep 2

start_service_background "Inference" "$PROJECT_ROOT/services/inference/start.sh"
sleep 1

start_service_background "Inference_Worker" "$PROJECT_ROOT/services/inference/worker.sh"

echo ""
echo "Waiting for services to fully start..."
sleep 3

################################################################################
# Summary
################################################################################

print_header "Startup Summary"

# Check which services are actually running
AUTH_PORT=8000
MEDIA_STORE_PORT=8001
INFERENCE_PORT=8002

AUTH_RUNNING=0
MEDIA_RUNNING=0
INFERENCE_RUNNING=0

if lsof -Pi :$AUTH_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    AUTH_RUNNING=1
fi

if lsof -Pi :$MEDIA_STORE_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    MEDIA_RUNNING=1
fi

if lsof -Pi :$INFERENCE_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    INFERENCE_RUNNING=1
fi

TOTAL_RUNNING=$((AUTH_RUNNING + MEDIA_RUNNING + INFERENCE_RUNNING))

if [ $TOTAL_RUNNING -eq 3 ]; then
    echo -e "${GREEN}[✓] All services started successfully!${NC}"
    echo ""
    echo "Services running:"
    echo -e "  ${GREEN}✓ Authentication Service${NC}     → http://0.0.0.0:8000/docs"
    echo -e "  ${GREEN}✓ Media Store Service${NC}        → http://127.0.0.1:8001/docs"
    echo -e "  ${GREEN}✓ Inference Service${NC}          → http://127.0.0.1:8002/docs"
    echo -e "  ${GREEN}✓ Inference Worker${NC}           (job processing)"
    echo ""
    echo "Authentication Mode:"
    if [ -z "$AUTH_FLAG" ]; then
        echo -e "  ${YELLOW}⚠ AUTH_DISABLED=true (No authentication required)${NC}"
    else
        echo -e "  ${GREEN}✓ Authentication enabled${NC}"
    fi
    echo ""
    echo "Logs directory: $LOGS_DIR"
    echo ""
    echo "To view logs:"
    echo "  tail -f $LOGS_DIR/Authentication.log"
    echo "  tail -f $LOGS_DIR/Media_Store.log"
    echo "  tail -f $LOGS_DIR/Inference.log"
    echo "  tail -f $LOGS_DIR/Inference_Worker.log"
    echo ""
    echo "To stop services:"
    echo "  ./stop_all.sh"
    echo ""
else
    echo -e "${RED}[✗] Only $TOTAL_RUNNING/3 services started (plus Inference Worker)${NC}"
    echo ""
    echo "Services status:"
    if [ $AUTH_RUNNING -eq 1 ]; then
        echo -e "  ${GREEN}✓ Authentication Service${NC}     (Port 8000)"
    else
        echo -e "  ${RED}✗ Authentication Service${NC}     (Port 8000)"
    fi
    if [ $MEDIA_RUNNING -eq 1 ]; then
        echo -e "  ${GREEN}✓ Media Store Service${NC}        (Port 8001)"
    else
        echo -e "  ${RED}✗ Media Store Service${NC}        (Port 8001)"
    fi
    if [ $INFERENCE_RUNNING -eq 1 ]; then
        echo -e "  ${GREEN}✓ Inference Service${NC}          (Port 8002)"
    else
        echo -e "  ${RED}✗ Inference Service${NC}          (Port 8002)"
    fi
    echo ""
    echo "Logs directory: $LOGS_DIR"
    echo ""
    echo "Check logs for details:"
    if [ $AUTH_RUNNING -eq 0 ]; then
        echo "  tail -f $LOGS_DIR/Authentication.log"
    fi
    if [ $MEDIA_RUNNING -eq 0 ]; then
        echo "  tail -f $LOGS_DIR/Media_Store.log"
    fi
    if [ $INFERENCE_RUNNING -eq 0 ]; then
        echo "  tail -f $LOGS_DIR/Inference.log"
    fi
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

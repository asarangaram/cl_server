#!/bin/bash

################################################################################
#                     CoLAN Server - Start All Services Script
################################################################################
#
# This script starts all three microservices with proper environment setup.
# Each service is started in its own background process.
#
# Usage:
#   ./start_all.sh              # Start all services with AUTH_DISABLED=true
#   ./start_all.sh --with-auth  # Start with authentication enabled
#
# Services started:
#   - Authentication Service on port 8000
#   - Media Store Service on port 8001
#   - Inference Service on port 8002
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
AUTH_DISABLED="true"
SERVICES_STARTED=0

# Parse command line arguments
if [[ "$1" == "--with-auth" ]]; then
    AUTH_DISABLED="false"
    echo -e "${BLUE}Starting services WITH authentication enabled${NC}"
else
    echo -e "${BLUE}Starting services with AUTH_DISABLED=true (no authentication required)${NC}"
fi

echo ""

################################################################################
# Validate CL_SERVER_DIR environment variable
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
# Function to check if port is in use
################################################################################
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

################################################################################
# Function to run database migrations
################################################################################
run_migrations() {
    local service_name=$1
    local service_path=$2

    echo -e "${BLUE}[*] Running database migrations for ${service_name}...${NC}"

    cd "$PROJECT_ROOT/$service_path"

    # Check if venv exists
    if [ ! -d "venv" ]; then
        python -m venv venv
        source venv/bin/activate
        pip install -q -e . 2>/dev/null || true
    else
        source venv/bin/activate
    fi

    # Run migrations if alembic.ini exists
    if [ -f "alembic.ini" ]; then
        if CL_SERVER_DIR="$CL_SERVER_DIR" alembic upgrade head > /dev/null 2>&1; then
            echo -e "${GREEN}    ✓ Migrations completed${NC}"
        else
            echo -e "${YELLOW}    ⚠ Migration warning (may not be critical)${NC}"
        fi
    fi
}

################################################################################
# Function to start a service
################################################################################
start_service() {
    local service_name=$1
    local service_path=$2
    local port=$3
    local auth_flag=$4

    echo -e "${BLUE}[*] Starting ${service_name}...${NC}"

    # Check if port is already in use
    if check_port $port; then
        echo -e "${RED}[✗] Error: Port $port is already in use${NC}"
        echo -e "${YELLOW}    To kill the process: lsof -ti:$port | xargs kill -9${NC}"
        return 1
    fi

    # Navigate to service directory
    cd "$PROJECT_ROOT/$service_path"

    # Check if venv exists
    if [ ! -d "venv" ]; then
        echo -e "${YELLOW}[!] Virtual environment not found. Creating...${NC}"
        python -m venv venv
        source venv/bin/activate
        pip install -q -e . 2>/dev/null || true
    else
        source venv/bin/activate
    fi

    # Start the service in background
    if [ "$auth_flag" == "true" ]; then
        CL_SERVER_DIR="$CL_SERVER_DIR" AUTH_DISABLED=true python main.py > "${PROJECT_ROOT}/.${service_name}.log" 2>&1 &
    else
        CL_SERVER_DIR="$CL_SERVER_DIR" python main.py > "${PROJECT_ROOT}/.${service_name}.log" 2>&1 &
    fi

    local pid=$!
    sleep 2

    # Check if process is still running
    if ! kill -0 $pid 2>/dev/null; then
        echo -e "${RED}[✗] Failed to start ${service_name}${NC}"
        echo -e "${YELLOW}    Check log: tail -f ${PROJECT_ROOT}/.${service_name}.log${NC}"
        return 1
    fi

    echo -e "${GREEN}[✓] ${service_name} started (PID: $pid, Port: $port)${NC}"
    echo "    Log file: ${PROJECT_ROOT}/.${service_name}.log"
    SERVICES_STARTED=$((SERVICES_STARTED + 1))
    return 0
}

################################################################################
# Start all services
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    Starting All Services${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Start Authentication Service
start_service "Authentication" "services/authentication" "8000" "$AUTH_DISABLED"
echo ""

# Run migrations for Media Store (required on first run)
run_migrations "Media_Store" "services/media_store"
echo ""

# Start Media Store Service
start_service "Media_Store" "services/media_store" "8001" "$AUTH_DISABLED"
echo ""

# Start Inference Service
start_service "Inference" "services/inference" "8002" "$AUTH_DISABLED"
echo ""

################################################################################
# Summary
################################################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    Startup Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ $SERVICES_STARTED -eq 3 ]; then
    echo -e "${GREEN}[✓] All 3 services started successfully!${NC}"
    echo ""
    echo "Services running:"
    echo -e "  ${GREEN}✓ Authentication Service${NC}     → http://0.0.0.0:8000/docs"
    echo -e "  ${GREEN}✓ Media Store Service${NC}        → http://127.0.0.1:8001/docs"
    echo -e "  ${GREEN}✓ Inference Service${NC}          → http://127.0.0.1:8002/docs"
    echo ""
    echo "Authentication Mode:"
    if [ "$AUTH_DISABLED" == "true" ]; then
        echo -e "  ${YELLOW}⚠ AUTH_DISABLED=true (No authentication required)${NC}"
    else
        echo -e "  ${GREEN}✓ Authentication enabled${NC}"
    fi
    echo ""
    echo "To view logs:"
    echo "  tail -f .Authentication.log"
    echo "  tail -f .Media_Store.log"
    echo "  tail -f .Inference.log"
    echo ""
    echo "To stop services:"
    echo "  ./stop_all.sh"
    echo ""
else
    echo -e "${RED}[✗] Only $SERVICES_STARTED/3 services started${NC}"
    echo ""
    echo "Some services failed to start. Check the logs:"
    echo "  tail -f .Authentication.log"
    echo "  tail -f .Media_Store.log"
    echo "  tail -f .Inference.log"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

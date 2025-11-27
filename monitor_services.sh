#!/bin/bash

################################################################################
#                    CL Server - Services Monitor
################################################################################
#
# This script monitors all services in the CL Server cluster and displays
# their status in a formatted table.
#
# Services monitored:
#   1. Authentication Service (port 8000)
#   2. Media Store Service (port 8001)
#   3. Inference Service (port 8002)
#   4. MQTT Broker (port 1883)
#   5. Qdrant Vector Store (port 6333)
#   6. Inference Worker (process check)
#
# Usage:
#   ./monitor_services.sh              # Run once
#   watch -n 2 ./monitor_services.sh   # Auto-refresh every 2 seconds
#
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Service definitions
declare -a SERVICES=(
    "Authentication:8000"
    "Media Store:8001"
    "Inference Service:8002"
    "MQTT Broker:1883"
    "Qdrant Vector Store:6333"
)

# Helper function to check if port is listening
check_port() {
    local port=$1
    timeout 2 bash -c "cat < /dev/null > /dev/tcp/127.0.0.1/$port" 2>/dev/null
    return $?
}

# Helper function to check if inference worker is running
check_worker() {
    pgrep -f "python -m src.worker" > /dev/null 2>&1
    return $?
}

# Helper function to get container health
check_container_health() {
    local container_name=$1
    local health_status=$(docker inspect "$container_name" 2>/dev/null | grep -A 5 '"Health"' | grep '"Status"' | head -1 | cut -d'"' -f4)

    if [ -z "$health_status" ]; then
        echo "unknown"
    else
        echo "$health_status"
    fi
}

# Clear screen for watch command compatibility
clear

# Print header
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    CL Server Services Status Monitor${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Print service status table header
printf "%-25s %-12s %-15s\n" "Service" "Port" "Status"
echo -e "${BLUE}───────────────────────────────────────────────────────────────────────────${NC}"

# Check each service
passed=0
failed=0

for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r service_name port <<< "$service_info"

    if check_port "$port"; then
        status_text="✓ RUNNING"
        status_color="$GREEN"
        ((passed++))
    else
        status_text="✗ STOPPED"
        status_color="$RED"
        ((failed++))
    fi

    printf "%-25s %-12s ${status_color}%-15s${NC}\n" "$service_name" "localhost:$port" "$status_text"
done

# Check Inference Worker
echo ""
echo -e "${BLUE}───────────────────────────────────────────────────────────────────────────${NC}"

if check_worker; then
    worker_status="✓ RUNNING"
    worker_color="$GREEN"
    ((passed++))
else
    worker_status="✗ STOPPED"
    worker_color="$RED"
    ((failed++))
fi

printf "%-25s %-12s ${worker_color}%-15s${NC}\n" "Inference Worker" "process" "$worker_status"

# Check Docker Container Health
echo ""
echo -e "${BLUE}───────────────────────────────────────────────────────────────────────────${NC}"

# Check MQTT Container Health
mqtt_health=$(check_container_health "cl-server-mqtt-broker")

if [ "$mqtt_health" = "healthy" ]; then
    mqtt_status="✓ HEALTHY"
    mqtt_color="$GREEN"
elif [ "$mqtt_health" = "unhealthy" ]; then
    mqtt_status="✗ UNHEALTHY"
    mqtt_color="$RED"
else
    mqtt_status="? UNKNOWN"
    mqtt_color="$YELLOW"
fi

printf "%-25s %-12s ${mqtt_color}%-15s${NC}\n" "MQTT Container" "docker" "$mqtt_status"

# Check Qdrant Container Health
qdrant_health=$(check_container_health "qdrant-vector-store")

if [ "$qdrant_health" = "healthy" ]; then
    qdrant_status="✓ HEALTHY"
    qdrant_color="$GREEN"
elif [ "$qdrant_health" = "unhealthy" ]; then
    qdrant_status="✗ UNHEALTHY"
    qdrant_color="$RED"
else
    qdrant_status="? UNKNOWN"
    qdrant_color="$YELLOW"
fi

printf "%-25s %-12s ${qdrant_color}%-15s${NC}\n" "Qdrant Container" "docker" "$qdrant_status"

# Print summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}✓ All services are running and healthy!${NC}"
    exit_code=0
else
    echo -e "${RED}✗ $failed service(s) not running${NC}"
    exit_code=1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""

exit $exit_code

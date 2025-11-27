#!/bin/bash

################################################################################
#                     CoLAN Server - Stop All Services Script
################################################################################
#
# This script safely stops all running microservices by killing them via PID.
# It lists the PIDs before killing them for safety and transparency.
#
# Usage:
#   ./stop_all.sh    # Stop all running services
#
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    Stopping All Services${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Get list of running Python processes (excluding this script and grep)
pids=$(ps aux | grep "python main.py" | grep -v grep | awk '{print $2}')

if [ -z "$pids" ]; then
    echo -e "${YELLOW}[!] No services currently running${NC}"
    echo ""
    exit 0
fi

# Display PIDs that will be killed
echo -e "${BLUE}[*] Found running services:${NC}"
echo ""
ps aux | grep "python main.py" | grep -v grep | while read line; do
    pid=$(echo "$line" | awk '{print $2}')
    cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++)printf "%s ",$i; print ""}')
    echo -e "  PID: ${BLUE}$pid${NC} - $cmd"
done
echo ""

# Ask for confirmation
read -p "Do you want to kill these services? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[!] Cancelled${NC}"
    exit 0
fi

# Kill each PID individually
echo ""
echo -e "${BLUE}[*] Killing services...${NC}"
killed_count=0
for pid in $pids; do
    if kill -9 "$pid" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Killed PID: $pid${NC}"
        killed_count=$((killed_count + 1))
    else
        echo -e "  ${RED}✗ Failed to kill PID: $pid${NC}"
    fi
done

sleep 1

# Verify all services are stopped
remaining=$(ps aux | grep "python main.py" | grep -v grep | wc -l)

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

if [ "$remaining" -eq 0 ]; then
    echo -e "${GREEN}[✓] All $killed_count services stopped successfully!${NC}"
    echo ""
else
    echo -e "${YELLOW}[!] Warning: $remaining service(s) still running${NC}"
    echo ""
    ps aux | grep "python main.py" | grep -v grep
    echo ""
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

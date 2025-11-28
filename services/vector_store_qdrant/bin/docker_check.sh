#!/bin/bash

################################################################################
# Ensure Docker Desktop is running and engine is ready
################################################################################

ensure_docker_running() {

    # Check if docker engine is ready
    docker_ready() {
        docker info >/dev/null 2>&1
    }

    # Already ready?
    if docker_ready; then
        echo "[✓] Docker is running"
        return 0
    fi

    echo "[*] Starting Docker Desktop…"
    # macOS: launch Docker.app
    open -a Docker

    echo "[*] Waiting for Docker to initialize…"

    # Maximum wait: 2 minutes
    local timeout=120
    local waited=0

    # Poll every 3 seconds
    while ! docker_ready; do
        sleep 3
        waited=$((waited + 3))

        echo "    → Docker not ready yet... ($waited/$timeout sec)"

        if [ $waited -ge $timeout ]; then
            echo "[✗] ERROR: Docker did not start within $timeout seconds"
            return 1
        fi
    done

    echo "[✓] Docker is ready"
    return 0
}

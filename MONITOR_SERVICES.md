# Services Monitor Script

The `monitor_services.sh` script provides real-time monitoring of all services in the CL Server cluster.

## Services Monitored

The script monitors 8 key services and containers:

1. **Authentication Service** (port 8000)
2. **Media Store Service** (port 8001)
3. **Inference Service** (port 8002)
4. **MQTT Broker** (port 1883)
5. **Qdrant Vector Store** (port 6333)
6. **Inference Worker** (background process)
7. **MQTT Container Health** (Docker health check status)
8. **Qdrant Container Health** (Docker health check status)

## Usage

### Single Run
Check service status once:
```bash
./monitor_services.sh
```

### Auto-Refresh with watch (Recommended)
Monitor services with automatic refresh every 2 seconds:
```bash
watch -n 2 ./monitor_services.sh
```

To exit `watch`, press `q`.

### Verbose Mode with Longer Refresh
Refresh every 5 seconds:
```bash
watch -n 5 ./monitor_services.sh
```

## Output Format

The script displays a formatted table with:
- **Service Name**: Name of the service
- **Port**: Port number or process type
- **Status**:
  - `✓ RUNNING` (green) - Service is accessible
  - `✗ STOPPED` (red) - Service is not responding
  - `✓ HEALTHY` (green) - Docker container is healthy
  - `✗ UNHEALTHY` (red) - Docker container is unhealthy
  - `? UNKNOWN` (yellow) - Health status cannot be determined

### Example Output
```
═══════════════════════════════════════════════════════════════════════════
                    CL Server Services Status Monitor
═══════════════════════════════════════════════════════════════════════════

Timestamp: 2025-11-27 22:14:38

Service                   Port         Status
───────────────────────────────────────────────────────────────────────────
Authentication            localhost:8000 ✓ RUNNING
Media Store               localhost:8001 ✓ RUNNING
Inference Service         localhost:8002 ✓ RUNNING
MQTT Broker               localhost:1883 ✓ RUNNING
Qdrant Vector Store       localhost:6333 ✓ RUNNING

───────────────────────────────────────────────────────────────────────────
Inference Worker          process      ✓ RUNNING

───────────────────────────────────────────────────────────────────────────
MQTT Container            docker       ✓ HEALTHY
Qdrant Container          docker       ✓ HEALTHY

═══════════════════════════════════════════════════════════════════════════
✓ All services are running and healthy!
═══════════════════════════════════════════════════════════════════════════
```

## Exit Codes

- `0`: All services are running and healthy
- `1`: One or more services are not running or unhealthy

This allows the script to be used in conditional statements or monitoring scripts.

## What Each Check Does

### Port Connectivity Checks (Services 1-5)
- Attempts to establish a TCP connection to each service port
- Timeout: 2 seconds per connection attempt
- Indicates if the service is listening and responding

### Inference Worker Check
- Uses `pgrep` to find running Python worker processes
- Command pattern: `python -m src.worker`
- Confirms the background worker is active

### MQTT Container Health Check
- Queries Docker daemon for MQTT container (`cl-server-mqtt-broker`) health status
- Shows the Docker health check status
- Requires Docker to be running

### Qdrant Container Health Check
- Queries Docker daemon for Qdrant container (`qdrant-vector-store`) health status
- Shows the Docker health check status
- Requires Docker to be running

## Troubleshooting

### Script Won't Execute
Make sure the script is executable:
```bash
chmod +x monitor_services.sh
```

### Services Showing as STOPPED
- Verify services are actually running with `start_all.sh`
- Check for firewall issues blocking localhost connections
- Ensure ports are not already in use

### MQTT/Qdrant Health Shows UNKNOWN
- Verify Docker daemon is running
- Check container names:
  - MQTT container: `cl-server-mqtt-broker`
  - Qdrant container: `qdrant-vector-store`
- Run `docker ps` to confirm container status
- Verify containers have health check configured in docker-compose.yml

### worker.sh Requirements
The Inference Worker check will fail if:
- The worker process is not running
- Worker needs to be started with `./services/inference/worker.sh`
- Qdrant must be running before starting the worker

## Integration with Monitoring Systems

The script can be integrated into monitoring systems:

```bash
# Check if all services are healthy
if ./monitor_services.sh > /dev/null 2>&1; then
    echo "All services OK"
else
    echo "Some services are down"
    # Send alert, restart services, etc.
fi
```

## Files

- **Script**: `monitor_services.sh`
- **Documentation**: `MONITOR_SERVICES.md` (this file)

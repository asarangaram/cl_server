# Startup Scripts Documentation

## Overview

The CL Server startup scripts have been refactored for modularity and flexibility. Each microservice has its own startup script with centralized virtual environment management and data storage configuration.

## Key Features

- **Centralized Virtual Environments**: All venvs stored in a configurable `CL_VENV_DIR` location
- **Configurable Data Storage**: Data and logs stored in configurable `CL_SERVER_DIR` location
- **Self-Contained Services**: Each service includes its own startup script and utilities
- **Mandatory Environment Variables**: `CL_VENV_DIR` and `CL_SERVER_DIR` must be explicitly set (no defaults)
- **Clear Error Messages**: Scripts abort with helpful messages if required variables are not set

## Script Structure

### Main Orchestration Script
**File:** `start_all.sh`

The main script that orchestrates starting all services. It:
- Validates both `CL_VENV_DIR` and `CL_SERVER_DIR` environment variables
- Creates the logs directory at `$CL_SERVER_DIR/run_logs`
- Launches individual service start scripts in background
- Waits for all services to start
- Provides a summary of which services are running
- Offers helpful commands for viewing logs and stopping services

**Usage:**
```bash
export CL_VENV_DIR=/path/to/venv
export CL_SERVER_DIR=/path/to/data
./start_all.sh                  # Start all with AUTH_DISABLED=true
./start_all.sh --with-auth      # Start with authentication enabled
```

### Shared Utilities
**Files:**
- `services/authentication/common.sh`
- `services/media_store/common.sh`
- `services/inference/common.sh`

Each service has its own copy of common utilities, making them self-contained. Contains reusable functions:
- `validate_venv_dir()` - Validate CL_VENV_DIR environment variable
- `validate_cl_server_dir()` - Validate CL_SERVER_DIR environment variable
- `check_port()` - Check if a port is in use
- `ensure_logs_dir()` - Create logs directory at $CL_SERVER_DIR/run_logs
- `setup_venv()` - Setup Python virtual environment in centralized location
- `run_migrations()` - Run database migrations
- `start_service()` - Start a service in foreground
- `print_header()` - Print formatted headers
- `print_section()` - Print formatted section titles

### Individual Service Scripts

#### Authentication Service
**File:** `services/authentication/start.sh`
- Starts the Authentication service on port 8000
- No database migrations needed
- Accepts `--with-auth` flag for authentication mode

**Usage:**
```bash
export CL_VENV_DIR=/path/to/venv
export CL_SERVER_DIR=/path/to/data
cd services/authentication
./start.sh
```

#### Media Store Service
**File:** `services/media_store/start.sh`
- Starts the Media Store service on port 8001
- Runs database migrations before starting
- Accepts `--with-auth` flag for authentication mode

**Usage:**
```bash
export CL_VENV_DIR=/path/to/venv
export CL_SERVER_DIR=/path/to/data
cd services/media_store
./start.sh
```

#### Inference Service
**File:** `services/inference/start.sh`
- Starts the Inference service on port 8002
- No database migrations needed
- Accepts `--with-auth` flag for authentication mode

**Usage:**
```bash
export CL_VENV_DIR=/path/to/venv
export CL_SERVER_DIR=/path/to/data
cd services/inference
./start.sh
```

## Starting Services

### Start All Services at Once
```bash
export CL_VENV_DIR=/path/to/venv
export CL_SERVER_DIR=/path/to/data
./start_all.sh
```

### Start Individual Services
```bash
# Set required environment variables
export CL_VENV_DIR=/path/to/venv
export CL_SERVER_DIR=/path/to/data

# Start each service separately from its directory
cd services/authentication && ./start.sh
cd services/media_store && ./start.sh
cd services/inference && ./start.sh
```

### Enable Authentication
```bash
export CL_VENV_DIR=/path/to/venv
export CL_SERVER_DIR=/path/to/data
./start_all.sh --with-auth

# Or start individual services with auth
cd services/authentication && ./start.sh --with-auth
```

## Environment Variables

### CL_VENV_DIR (Required)
The directory where all virtual environments are stored. Virtual environments for each service will be created as subdirectories:
- `{CL_VENV_DIR}/authentication_env`
- `{CL_VENV_DIR}/media_store_env`
- `{CL_VENV_DIR}/inference_env`

**Important:** This variable MUST be set before running any service. If not set, all scripts will abort with an error.

**Benefits:**
- Move the venv directory to different locations (e.g., faster storage, different drive)
- Share venvs across projects by pointing to a central location
- Keep venvs separate from source code
- Flexibility in resource organization

**Example:**
```bash
export CL_VENV_DIR=/path/to/venv
export CL_VENV_DIR=$HOME/.cl_server/venv
export CL_VENV_DIR=/mnt/fast_storage/venv
```

### CL_SERVER_DIR (Required)
The directory where service data and databases are stored. Logs are automatically created in `{CL_SERVER_DIR}/run_logs/`.

**Important:** This variable MUST be set before running any service.

**Example:**
```bash
export CL_SERVER_DIR=/path/to/data
export CL_SERVER_DIR=$HOME/.cl_server/data
export CL_SERVER_DIR=/var/lib/cl_server
```

### AUTH_DISABLED (Optional)
Controls authentication mode:
- `AUTH_DISABLED=true` - No authentication required (default via scripts)
- Not set - Authentication enabled (when using `--with-auth` flag)

The scripts automatically set this environment variable based on the `--with-auth` flag.

## Viewing Logs

Logs are stored in `$CL_SERVER_DIR/run_logs/` and are automatically created on first use.

When using `start_all.sh`, all service output (startup and runtime) is captured in unified log files:
```bash
# View individual service logs
tail -f $CL_SERVER_DIR/run_logs/Authentication.log
tail -f $CL_SERVER_DIR/run_logs/Media_Store.log
tail -f $CL_SERVER_DIR/run_logs/Inference.log

# Follow all service logs at once
tail -f $CL_SERVER_DIR/run_logs/*.log
```

When running individual services directly (e.g., `cd services/authentication && ./start.sh`), output appears in the terminal but is also captured in the log file.

## Virtual Environment Management

Each service's virtual environment is stored in:
```
{CL_VENV_DIR}/
├── authentication_env/
├── media_store_env/
└── inference_env/
```

Virtual environments are created automatically on first use by the `setup_venv()` function. The function:
1. Checks if the venv already exists
2. Creates one if it doesn't
3. Installs/upgrades dependencies from the service's `pyproject.toml`
4. Activates the venv before starting the service

To force recreation of a virtual environment:
```bash
rm -rf $CL_VENV_DIR/{service_name}_env
# Next run will recreate it
```

## Database Migrations

The Media Store service automatically runs database migrations on startup. If you see a migration warning, it's usually not critical and the service will still function.

To manually run migrations:
```bash
export CL_VENV_DIR=/path/to/venv
export CL_SERVER_DIR=/path/to/data
source $CL_VENV_DIR/media_store_env/bin/activate
cd services/media_store
alembic upgrade head
```

## Port Configuration

| Service | Port | URL |
|---------|------|-----|
| Authentication | 8000 | http://0.0.0.0:8000/docs |
| Media Store | 8001 | http://127.0.0.1:8001/docs |
| Inference | 8002 | http://127.0.0.1:8002/docs |

### Checking Port Usage

If a port is already in use, the script will show an error:
```bash
# Kill a process using a port (e.g., port 8000)
lsof -ti:8000 | xargs kill -9
```

## Stopping Services

To stop all services:
```bash
./stop_all.sh
```

Or manually kill processes:
```bash
# Kill by port
lsof -ti:8000 | xargs kill -9
lsof -ti:8001 | xargs kill -9
lsof -ti:8002 | xargs kill -9

# Or by name
pkill -f "python.*authentication.*main.py"
pkill -f "python.*media_store.*main.py"
pkill -f "python.*inference.*main.py"
```

## Troubleshooting

### CL_VENV_DIR not set
```bash
export CL_VENV_DIR=/path/to/venv
# Then run the service script
```

### CL_SERVER_DIR not set
```bash
export CL_SERVER_DIR=/path/to/data
mkdir -p $CL_SERVER_DIR
# Then run the service script
```

### Service fails to start
Check the service log:
```bash
tail -f $CL_SERVER_DIR/run_logs/Authentication.log
tail -f $CL_SERVER_DIR/run_logs/Media_Store.log
tail -f $CL_SERVER_DIR/run_logs/Inference.log
```

### Port already in use
```bash
# Find process using the port
lsof -i :8001

# Kill it
lsof -ti:8001 | xargs kill -9
```

### Permission denied when running scripts
Make the scripts executable:
```bash
chmod +x start_all.sh services/*/start.sh
```

### Virtual environment issues
Delete the venv and let the script recreate it:
```bash
rm -rf $CL_VENV_DIR/authentication_env
rm -rf $CL_VENV_DIR/media_store_env
rm -rf $CL_VENV_DIR/inference_env
# Next run will recreate them
```

## File Organization

```
cl_server/
├── start_all.sh                    # Main orchestration script
├── stop_all.sh                     # Service cleanup script
├── services/
│   ├── authentication/
│   │   ├── common.sh              # Shared utilities (local copy)
│   │   ├── start.sh               # Auth service startup
│   │   ├── main.py
│   │   ├── pyproject.toml
│   │   └── src/
│   ├── media_store/
│   │   ├── common.sh              # Shared utilities (local copy)
│   │   ├── start.sh               # Media store startup
│   │   ├── main.py
│   │   ├── pyproject.toml
│   │   └── src/
│   └── inference/
│       ├── common.sh              # Shared utilities (local copy)
│       ├── start.sh               # Inference startup
│       ├── main.py
│       ├── pyproject.toml
│       └── src/

{CL_VENV_DIR}/
├── authentication_env/             # Virtual environment for authentication service
├── media_store_env/                # Virtual environment for media store service
└── inference_env/                  # Virtual environment for inference service

{CL_SERVER_DIR}/
└── run_logs/
    ├── Authentication.log          # Authentication service output
    ├── Media_Store.log             # Media Store service output
    └── Inference.log               # Inference service output
```

## Summary

The refactored startup scripts provide:
- **Flexibility** - Configure venv and data locations as needed
- **Clarity** - Each service has its own startup script
- **Reliability** - Mandatory environment variables prevent common mistakes
- **Maintainability** - Self-contained services with clear responsibilities
- **Debugging** - Better logs and error messages

This structure makes it easier for developers to:
- Work with individual services during development
- Organize resources efficiently (fast storage for venvs, network storage for data)
- Start all services for integration testing
- Deploy to different environments with different storage configurations

# CoLAN Server - Services Setup Guide

This guide explains how to set up and start all microservices in the CoLAN Server project. The system consists of three main services:

1. **Authentication Service** (Port: 8000)
2. **Media Store Service** (Port: 8001)
3. **Inference Service** (Port: 8002)

> **Note:** Each service runs on a unique port and can be run simultaneously on the same machine.

## Quick Start

### Prerequisites

- Python 3.11+
- pip and virtualenv
- Mosquitto MQTT broker (for inference event listening)

> All commands assume you are in the project root directory unless otherwise noted.

### Environment Setup

**IMPORTANT:** You must set the `CL_SERVER_DIR` environment variable before starting services. This specifies where all persistent data (databases, media files, vector store, keys) will be stored.

```bash
# Set the data directory (required)
export CL_SERVER_DIR=/path/to/your/data/directory

# The directory will be created if it doesn't exist, but must have write permissions
# Example:
export CL_SERVER_DIR=$HOME/.cl_server_data
```

### Using the Start Script (Recommended)

The easiest way to start all services:

```bash
# Set the data directory (required)
export CL_SERVER_DIR=$HOME/.cl_server_data

# Make the script executable (first time only)
chmod +x start_all.sh

# Start all services with AUTH_DISABLED=true (no authentication required)
./start_all.sh

# Or start with authentication enabled
./start_all.sh --with-auth
```

---

## 1. Authentication Service

**Location:** `services/authentication/`

**Purpose:** JWT-based user authentication and authorization

**Default Port:** 8000
**Default Admin User:** admin
**Default Admin Password:** admin_password

### Option A: WITH Authentication (Production)

#### Step 1: Navigate to authentication service directory
```bash
cd services/authentication
```

#### Step 2: Create and activate virtual environment
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

#### Step 3: Install dependencies
```bash
pip install -e .
```

#### Step 4: Set environment variables (optional)
```bash
export DATABASE_URL="sqlite:///./auth.db"      # Custom database path
export ADMIN_USERNAME="admin"                  # Custom admin username
export ADMIN_PASSWORD="admin_password"         # Custom admin password
```

> **Note:** If not set, defaults will be used. Variables are read on service startup.

#### Step 5: Run migrations (if first time)
```bash
alembic upgrade head
```

#### Step 6: Start the service
```bash
python main.py
```

**Expected Output:**
```
INFO:     Started server process
INFO:     Application startup complete
INFO:     Uvicorn running on http://0.0.0.0:8000
```

### Option B: WITH Authentication DISABLED (Demo/Development)

#### Steps 1-5
Same as Option A

#### Step 6: Start with AUTH_DISABLED flag
```bash
AUTH_DISABLED=true python main.py
```

> When `AUTH_DISABLED=true`, all authentication requirements are bypassed. No JWT token is required for API calls.

### Environment Variables

| Variable | Default | Effect |
|----------|---------|--------|
| `AUTH_DISABLED` | false | Disables all authentication checks when true |
| `DATABASE_URL` | `sqlite:///./auth.db` | Database connection string (supports SQLite, PostgreSQL, MySQL, etc.) |
| `ADMIN_USERNAME` | admin | Username for the default admin user |
| `ADMIN_PASSWORD` | admin_password | Password for the default admin user |

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/docs` | API documentation (Swagger UI) |
| POST | `/users/` | Create new user |
| POST | `/auth/login` | Login and get JWT token |
| GET | `/auth/validate` | Validate JWT token |
| GET | `/users/me` | Get current user info |

---

## 2. Media Store Service

**Location:** `services/media_store/`

**Purpose:** Image and media file storage with metadata management

**Default Port:** 8001
**Default Database:** `data/media_store.db` (SQLite)

### Option A: WITH Authentication

#### Step 1: Navigate to media_store service directory
```bash
cd services/media_store
```

#### Step 2: Create and activate virtual environment
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

#### Step 3: Install dependencies
```bash
pip install -e .
pip install python-magic-bin  # Required for file type detection
```

#### Step 4: Set environment variables (if needed)
```bash
# CL_SERVER_DIR is REQUIRED - set it before starting
export CL_SERVER_DIR=$HOME/.cl_server_data

# Optional - Override default paths (defaults derive from CL_SERVER_DIR)
# export DATABASE_URL="sqlite:///$CL_SERVER_DIR/media_store.db"
# export MEDIA_STORAGE_DIR="$CL_SERVER_DIR/media"
# export PUBLIC_KEY_PATH="$CL_SERVER_DIR/public_key.pem"
export READ_AUTH_ENABLED=false                  # Allow read without auth
```

#### Step 5: Run database migrations (IMPORTANT - First time only)
```bash
alembic upgrade head
```

#### Step 6: Generate or provide JWT public key for authentication
- If using authentication service, get the public key from authentication service
- Place it at: `$CL_SERVER_DIR/public_key.pem`
- Or set `PUBLIC_KEY_PATH` environment variable (defaults to `$CL_SERVER_DIR/public_key.pem`)

#### Step 7: Start the service
```bash
python main.py
```

**Expected Output:**
```
INFO:     Started server process
INFO:     Application startup complete
INFO:     Uvicorn running on http://127.0.0.1:8001
```

### Option B: WITH Authentication DISABLED (Demo/Development)

#### Steps 1-5
Same as Option A

#### Step 6: Start with AUTH_DISABLED flag
```bash
AUTH_DISABLED=true python main.py
```

> When `AUTH_DISABLED=true`:
> - No JWT token required for uploads/downloads
> - Public key file is not needed
> - All users treated as authenticated

### Environment Variables

| Variable | Default | Effect |
|----------|---------|--------|
| `CL_SERVER_DIR` | **(required)** | Root directory for all persistent data |
| `AUTH_DISABLED` | false | Disables authentication checks when true |
| `READ_AUTH_ENABLED` | false | Requires authentication for read operations when true |
| `DATABASE_URL` | `sqlite:///$CL_SERVER_DIR/media_store.db` | SQLAlchemy database URL (derived from CL_SERVER_DIR) |
| `MEDIA_STORAGE_DIR` | `$CL_SERVER_DIR/media` | Directory where uploaded media files are stored (derived from CL_SERVER_DIR) |
| `PUBLIC_KEY_PATH` | `$CL_SERVER_DIR/public_key.pem` | Path to JWT public key for token validation (derived from CL_SERVER_DIR) |

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/docs` | API documentation |
| POST | `/entity/` | Upload image/create entity |
| GET | `/entity/{entity_id}` | Get entity details |
| GET | `/entity/{entity_id}/image` | Get image file |
| POST | `/entity/{entity_id}/face-detection-results` | Accept face detection results |

### First Time Setup

Database migrations are **REQUIRED** for first-time setup:

```bash
alembic upgrade head
```

This creates the necessary tables in the SQLite database.

---

## 3. Inference Service

**Location:** `services/inference/`

**Purpose:** ML model inference for image embeddings and face detection

**Default Port:** 8002

**Default Models:**
- Image Embedding: CLIP ViT-B/32
- Face Detection: RetinaFace

**Vector Storage:** Qdrant database

### Option A: WITH Authentication

#### Step 1: Navigate to inference service directory
```bash
cd services/inference
```

#### Step 2: Create and activate virtual environment
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

#### Step 3: Install dependencies
```bash
pip install -e .
```

> **Note:** This may take a long time due to torch and other ML dependencies. If torch fails on macOS, see [Troubleshooting](#troubleshooting-inference) section below.

#### Step 4: Set environment variables (if needed)
```bash
# CL_SERVER_DIR is REQUIRED - set it before starting
export CL_SERVER_DIR=$HOME/.cl_server_data

# Optional - Override default paths (defaults derive from CL_SERVER_DIR)
# export PUBLIC_KEY_PATH="$CL_SERVER_DIR/public_key.pem"
# export VECTOR_STORE_PATH="$CL_SERVER_DIR/vector_store/qdrant"
export QDRANT_URL="http://localhost:6333"       # Qdrant vector DB
export MQTT_BROKER="localhost"                   # MQTT broker address
export MQTT_PORT=1883                            # MQTT broker port
```

#### Step 5: Set up vector database (Qdrant)

Run Qdrant vector database (requires Docker or standalone installation):

```bash
docker run -p 6333:6333 qdrant/qdrant:latest
```

Or download from: https://qdrant.tech/

#### Step 6: Ensure MQTT broker is running

Default: `localhost:1883`

Install Mosquitto if not present:

```bash
# macOS
brew install mosquitto && brew services start mosquitto

# Linux
sudo apt-get install mosquitto && sudo systemctl start mosquitto

# Windows
# Download from https://mosquitto.org/
```

#### Step 7: Start the service
```bash
python main.py
```

**Expected Output:**
```
INFO:     Started server process
INFO:     Application startup complete
INFO:     Uvicorn running on http://127.0.0.1:8002
```

### Option B: WITH Authentication DISABLED (Demo/Development)

#### Steps 1-6
Same as Option A

#### Step 7: Start with AUTH_DISABLED flag
```bash
AUTH_DISABLED=true python main.py
```

> When `AUTH_DISABLED=true`:
> - No JWT token required for job creation
> - Public key file is not needed

### Environment Variables

| Variable | Default | Effect |
|----------|---------|--------|
| `CL_SERVER_DIR` | **(required)** | Root directory for all persistent data |
| `AUTH_DISABLED` | false | Disables authentication checks when true |
| `PUBLIC_KEY_PATH` | `$CL_SERVER_DIR/public_key.pem` | Path to JWT public key for token validation (derived from CL_SERVER_DIR) |
| `VECTOR_STORE_PATH` | `$CL_SERVER_DIR/vector_store/qdrant` | Path to Qdrant vector store (derived from CL_SERVER_DIR) |
| `QDRANT_URL` | `http://localhost:6333` | Connection URL for Qdrant vector database |
| `MQTT_BROKER` | localhost | Hostname/IP of MQTT broker (Mosquitto) |
| `MQTT_PORT` | 1883 | Port number of MQTT broker |

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/docs` | API documentation |
| POST | `/jobs/` | Create inference job |
| GET | `/jobs/{job_id}` | Get job status |
| GET | `/jobs/{job_id}/result` | Get job result |
| GET | `/jobs/` | List jobs |

### MQTT Event Topics

When a job completes, events are published to:

```
inference/job/{job_id}/completed
```

Subscribe to this topic to receive job completion notifications.

### Troubleshooting (Inference)

**Q: PyTorch installation fails on macOS**

A: Install using conda instead of pip:

```bash
conda install pytorch torchvision torchaudio -c pytorch
pip install fastapi uvicorn httpx qdrant-client paho-mqtt
```

**Q: ImportError: No module named 'torch'**

A: Torch is not installed. Install using conda or:

```bash
pip install torch torchvision torchaudio
```

**Q: Cannot connect to Qdrant**

A: Ensure Qdrant is running:

```bash
docker ps | grep qdrant

# If not running, start it:
docker run -p 6333:6333 qdrant/qdrant:latest
```

**Q: Cannot connect to MQTT broker**

A: Ensure Mosquitto is running:

```bash
ps aux | grep mosquitto

# If not running, start it:
mosquitto  # or brew services start mosquitto
```

---

## Running All Services Together

To run all services in development mode (without authentication):

```bash
# Terminal 1 - Authentication
cd services/authentication
source venv/bin/activate
AUTH_DISABLED=true python main.py

# Terminal 2 - Media Store
cd services/media_store
source venv/bin/activate
AUTH_DISABLED=true python main.py

# Terminal 3 - Inference
cd services/inference
source venv/bin/activate
AUTH_DISABLED=true python main.py
```

Then, you can use the CLI clients in `demos/inferences/`:

```bash
# Terminal 4 - Image Embedding
cd demos/inferences
source venv/bin/activate
python image_embedding_client.py <image_path> --media-store localhost:8001

# Terminal 5 - Face Detection
cd demos/inferences
source venv/bin/activate
python face_detection_client.py <image_path> --media-store localhost:8001
```

### Or use the start script

```bash
./start_all.sh
```

---

## Environment Setup Summary

For each service, the typical workflow is:

1. Navigate to service directory: `cd services/{SERVICE_NAME}/`
2. Create venv (if needed): `python -m venv venv`
3. Activate venv: `source venv/bin/activate`
4. Install dependencies: `pip install -e .`
5. Set flags (optional): `export AUTH_DISABLED=true`
6. Start service: `python main.py`

---

## Common Flags & Options

### AUTH_DISABLED=true

- Disables all authentication checks across all services
- Useful for development and testing
- **NOT** recommended for production

### reload=true (in uvicorn)

- Automatically reloads service when code changes
- Already enabled in all main.py files
- Can be disabled by modifying main.py `uvicorn.run()` call

### --host and --port options

- Can be modified in main.py or via environment variables
- Default hosts: `0.0.0.0` (auth), `127.0.0.1` (media_store, inference)
- Default ports: `8000` (auth), `8001` (media_store), `8002` (inference)

---

## Database Migrations

Alembic is used for database schema management.

### Initial Setup (required on first run)

```bash
source venv/bin/activate
alembic upgrade head
```

### Create a new migration after code changes

```bash
alembic revision --autogenerate -m "Description of changes"
```

### View migration history

```bash
alembic current   # Show current schema version
alembic history   # Show all migrations
```

---

## Verification

After starting services, verify they are running:

```bash
# Check authentication (port 8000)
curl http://0.0.0.0:8000/docs

# Check media_store (port 8001)
curl http://127.0.0.1:8001/docs

# Check inference (port 8002)
curl http://127.0.0.1:8002/docs
```

If you see HTML API documentation, the service is running correctly.

---

## More Information

For detailed API documentation and workflow examples, see:

- [services/inference/README.md](services/inference/README.md) - Inference service workflows
- [demos/inferences/plan.md](demos/inferences/plan.md) - CLI client implementation details
- [CLAUDE.md](CLAUDE.md) - Project architecture overview

For CLI client usage:

```bash
cd demos/inferences
python image_embedding_client.py --help
python face_detection_client.py --help
```

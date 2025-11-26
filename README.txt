================================================================================
                    CoLAN Server - Services Setup Guide
================================================================================

This guide explains how to set up and start all microservices in the CoLAN
Server project. The system consists of three main services:

  1. Authentication Service (Port: 8000)
  2. Media Store Service (Port: 8001)
  3. Inference Service (Port: 8002)

Note: Each service runs on a unique port and can be run simultaneously on the
same machine.

================================================================================
                              QUICK START
================================================================================

Prerequisites:
  - Python 3.11+
  - pip and virtualenv
  - Mosquitto MQTT broker (for inference event listening)

All commands assume you are in the project root directory unless otherwise noted.


================================================================================
           1. AUTHENTICATION SERVICE (services/authentication/)
================================================================================

Purpose: JWT-based user authentication and authorization

Default Port: 8000
Default Admin User: admin
Default Admin Password: admin_password

---
OPTION A: WITH AUTHENTICATION (Recommended for Production)
---

Step 1: Navigate to authentication service directory
  $ cd services/authentication

Step 2: Create and activate virtual environment (if not exists)
  $ python -m venv venv
  $ source venv/bin/activate  # On Windows: venv\Scripts\activate

Step 3: Install dependencies
  $ pip install -e .

Step 4: Set environment variables (optional)
  $ export DATABASE_URL="sqlite:///./auth.db"    # Custom database path
  $ export ADMIN_USERNAME="admin"                # Custom admin username
  $ export ADMIN_PASSWORD="admin_password"       # Custom admin password

  Note: If not set, defaults will be used. Variables are read on service startup.

Step 5: Run migrations (if first time)
  $ source venv/bin/activate
  $ alembic upgrade head

Step 6: Start the service
  $ source venv/bin/activate
  $ python main.py

Expected Output:
  INFO:     Started server process
  INFO:     Application startup complete
  INFO:     Uvicorn running on http://0.0.0.0:8000

---
OPTION B: WITH AUTHENTICATION DISABLED (Demo/Development Mode)
---

Step 1-5: Same as Option A (Setup & migrate)

Step 6: Start the service with AUTH_DISABLED flag
  $ source venv/bin/activate
  $ AUTH_DISABLED=true python main.py

Note: When AUTH_DISABLED=true, all authentication requirements are bypassed.
      No JWT token is required for API calls.

---
ENVIRONMENT VARIABLES
---

AUTH_DISABLED
  Values: true/false (default: false)
  Effect: Disables all authentication checks when true

DATABASE_URL
  Default: sqlite:///./auth.db
  Format: Database connection string (supports SQLite, PostgreSQL, MySQL, etc.)
  Example: postgresql://user:password@localhost/auth_db

ADMIN_USERNAME
  Default: admin
  Effect: Username for the default admin user created on startup

ADMIN_PASSWORD
  Default: admin_password
  Effect: Password for the default admin user created on startup

---
API ENDPOINTS
---

  GET  /docs              - API documentation (Swagger UI)
  POST /users/            - Create new user
  POST /auth/login        - Login and get JWT token
  GET  /auth/validate     - Validate JWT token
  GET  /users/me          - Get current user info


================================================================================
           2. MEDIA STORE SERVICE (services/media_store/)
================================================================================

Purpose: Image and media file storage with metadata management

Default Port: 8001
Default Database: data/media_store.db (SQLite)

---
OPTION A: WITH AUTHENTICATION
---

Step 1: Navigate to media_store service directory
  $ cd services/media_store

Step 2: Create and activate virtual environment (if not exists)
  $ python -m venv venv
  $ source venv/bin/activate  # On Windows: venv\Scripts\activate

Step 3: Install dependencies
  $ pip install -e .
  $ pip install python-magic-bin  # Required for file type detection

Step 4: Set environment variables (optional)
  $ export DATABASE_DIR="../data"                    # Database location
  $ export MEDIA_STORAGE_DIR="../data/media_store"  # Media file storage location
  $ export PUBLIC_KEY_PATH="../data/public_key.pem" # JWT public key path
  $ export READ_AUTH_ENABLED=false                  # Allow read without auth

Step 5: Run database migrations (IMPORTANT - First time only)
  $ source venv/bin/activate
  $ alembic upgrade head

Step 6: Generate or provide JWT public key for authentication
  - If using authentication service, get the public key from authentication service
  - Place it at: ../data/public_key.pem
  - Or set PUBLIC_KEY_PATH environment variable

Step 7: Start the service
  $ source venv/bin/activate
  $ python main.py

Expected Output:
  INFO:     Started server process
  INFO:     Application startup complete
  INFO:     Uvicorn running on http://127.0.0.1:8001

---
OPTION B: WITH AUTHENTICATION DISABLED (Demo/Development Mode)
---

Step 1-5: Same as Option A (Setup & migrate)

Step 6: Start the service with AUTH_DISABLED flag
  $ source venv/bin/activate
  $ AUTH_DISABLED=true python main.py

Note: When AUTH_DISABLED=true:
  - No JWT token required for uploads/downloads
  - Public key file is not needed
  - All users treated as authenticated

---
ENVIRONMENT VARIABLES
---

AUTH_DISABLED
  Values: true/false (default: false)
  Effect: Disables authentication checks when true

READ_AUTH_ENABLED
  Values: true/false (default: false)
  Effect: Requires authentication for read operations when true
          (Write operations always require auth if AUTH_DISABLED=false)

DATABASE_DIR
  Default: ../data
  Effect: Directory where SQLite database is stored
  Note: Relative to services/media_store/ directory

DATABASE_URL
  Default: sqlite:///./data/media_store.db
  Format: SQLAlchemy database URL
  Example: postgresql://user:password@localhost/media_store

MEDIA_STORAGE_DIR
  Default: ../data/media_store
  Effect: Directory where uploaded media files are stored
  Note: Relative to services/media_store/ directory

PUBLIC_KEY_PATH
  Default: ../data/public_key.pem
  Effect: Path to JWT public key for token validation
  Note: Required if AUTH_DISABLED=false and authentication enabled

---
API ENDPOINTS
---

  GET  /docs                           - API documentation
  POST /entity/                        - Upload image/create entity
  GET  /entity/{entity_id}             - Get entity details
  GET  /entity/{entity_id}/image       - Get image file
  POST /entity/{entity_id}/face-detection-results - Accept face detection results

---
FIRST TIME SETUP
---

The database migrations are REQUIRED for first-time setup:
  $ source venv/bin/activate
  $ alembic upgrade head

This creates the necessary tables in the SQLite database.


================================================================================
           3. INFERENCE SERVICE (services/inference/)
================================================================================

Purpose: ML model inference for image embeddings and face detection

Default Port: 8002
Default Models:
  - Image Embedding: CLIP ViT-B/32
  - Face Detection: RetinaFace
Vector Storage: Qdrant database

---
OPTION A: WITH AUTHENTICATION
---

Step 1: Navigate to inference service directory
  $ cd services/inference

Step 2: Create and activate virtual environment (if not exists)
  $ python -m venv venv
  $ source venv/bin/activate  # On Windows: venv\Scripts\activate

Step 3: Install dependencies
  $ pip install -e .

  Note: This may take a long time due to torch and other ML dependencies.
        If torch fails on macOS, see Troubleshooting section below.

Step 4: Set environment variables (optional)
  $ export PUBLIC_KEY_PATH="../data/public_key.pem"  # JWT public key
  $ export QDRANT_URL="http://localhost:6333"       # Qdrant vector DB
  $ export MQTT_BROKER_HOST="localhost"              # MQTT broker address
  $ export MQTT_BROKER_PORT=1883                     # MQTT broker port

Step 5: Set up vector database (Qdrant)
  Run Qdrant vector database (requires Docker or standalone installation):
  $ docker run -p 6333:6333 qdrant/qdrant:latest

  Or download from: https://qdrant.tech/

Step 6: Ensure MQTT broker is running
  Default: localhost:1883
  Install Mosquitto if not present:
    macOS: brew install mosquitto && brew services start mosquitto
    Linux: sudo apt-get install mosquitto && sudo systemctl start mosquitto
    Windows: Download from https://mosquitto.org/

Step 7: Start the service
  $ source venv/bin/activate
  $ python main.py

Expected Output:
  INFO:     Started server process
  INFO:     Application startup complete
  INFO:     Uvicorn running on http://127.0.0.1:8002

---
OPTION B: WITH AUTHENTICATION DISABLED (Demo/Development Mode)
---

Step 1-6: Same as Option A (Setup & dependencies)

Step 7: Start the service with AUTH_DISABLED flag
  $ source venv/bin/activate
  $ AUTH_DISABLED=true python main.py

Note: When AUTH_DISABLED=true:
  - No JWT token required for job creation
  - Public key file is not needed

---
ENVIRONMENT VARIABLES
---

AUTH_DISABLED
  Values: true/false (default: false)
  Effect: Disables authentication checks when true

PUBLIC_KEY_PATH
  Default: ../data/public_key.pem
  Effect: Path to JWT public key for token validation
  Note: Required if AUTH_DISABLED=false

QDRANT_URL
  Default: http://localhost:6333
  Effect: Connection URL for Qdrant vector database
  Note: Must be running and accessible

MQTT_BROKER_HOST
  Default: localhost
  Effect: Hostname/IP of MQTT broker (Mosquitto)

MQTT_BROKER_PORT
  Default: 1883
  Effect: Port number of MQTT broker

---
API ENDPOINTS
---

  GET  /docs                    - API documentation
  POST /jobs/                   - Create inference job
  GET  /jobs/{job_id}           - Get job status
  GET  /jobs/{job_id}/result    - Get job result
  GET  /jobs/                   - List jobs

---
MQTT EVENT TOPICS
---

When a job completes, events are published to:
  inference/job/{job_id}/completed

Subscribe to this topic to receive job completion notifications.

---
TROUBLESHOOTING
---

Q: PyTorch installation fails on macOS
A: Install using conda instead of pip:
   $ conda install pytorch torchvision torchaudio -c pytorch
   Then install other requirements:
   $ pip install fastapi uvicorn httpx qdrant-client paho-mqtt

Q: ImportError: No module named 'torch'
A: Torch is not installed. Install using conda or:
   $ pip install torch torchvision torchaudio

Q: Cannot connect to Qdrant
A: Ensure Qdrant is running:
   $ docker ps | grep qdrant
   If not running, start it:
   $ docker run -p 6333:6333 qdrant/qdrant:latest

Q: Cannot connect to MQTT broker
A: Ensure Mosquitto is running:
   $ ps aux | grep mosquitto
   If not running, start it:
   $ mosquitto  # or brew services start mosquitto


================================================================================
                    RUNNING ALL SERVICES TOGETHER
================================================================================

To run all services in development mode (without authentication):

Terminal 1 - Authentication:
  $ cd services/authentication
  $ source venv/bin/activate
  $ AUTH_DISABLED=true python main.py

Terminal 2 - Media Store:
  $ cd services/media_store
  $ source venv/bin/activate
  $ AUTH_DISABLED=true python main.py

Terminal 3 - Inference:
  $ cd services/inference
  $ source venv/bin/activate
  $ AUTH_DISABLED=true python main.py

Then, you can use the CLI clients in demos/inferences/:

Terminal 4 - Image Embedding:
  $ cd demos/inferences
  $ source venv/bin/activate
  $ python image_embedding_client.py <image_path> --media-store localhost:8001

Terminal 5 - Face Detection:
  $ cd demos/inferences
  $ source venv/bin/activate
  $ python face_detection_client.py <image_path> --media-store localhost:8001


================================================================================
                    ENVIRONMENT SETUP SUMMARY
================================================================================

For each service, the typical workflow is:

1. cd services/{SERVICE_NAME}/
2. python -m venv venv                    (Create if not exists)
3. source venv/bin/activate               (Activate virtual environment)
4. pip install -e .                       (Install dependencies)
5. export AUTH_DISABLED=true              (Optional: disable authentication)
6. python main.py                         (Start the service)


================================================================================
                         COMMON FLAGS & OPTIONS
================================================================================

AUTH_DISABLED=true
  - Disables all authentication checks across all services
  - Useful for development and testing
  - NOT recommended for production

reload=true (in uvicorn)
  - Automatically reloads service when code changes
  - Already enabled in media_store and inference main.py files
  - Can be disabled by modifying main.py uvicorn.run() call

--host and --port options (in uvicorn)
  - Can be modified in main.py or via environment variables
  - Default hosts: 0.0.0.0 (auth), 127.0.0.1 (media_store, inference)
  - Default ports: 8001 (auth), 8000 (media_store), 8001 (inference)


================================================================================
                         DATABASE MIGRATIONS
================================================================================

Alembic is used for database schema management.

Initial Setup (required on first run):
  $ source venv/bin/activate
  $ alembic upgrade head

Create a new migration after code changes:
  $ alembic revision --autogenerate -m "Description of changes"

View migration history:
  $ alembic current         # Show current schema version
  $ alembic history         # Show all migrations


================================================================================
                              VERIFICATION
================================================================================

After starting services, verify they are running:

Check authentication (port 8000):
  $ curl http://0.0.0.0:8000/docs

Check media_store (port 8001):
  $ curl http://127.0.0.1:8001/docs

Check inference (port 8002):
  $ curl http://127.0.0.1:8002/docs

If you see HTML API documentation, the service is running correctly.


================================================================================
                            MORE INFORMATION
================================================================================

For detailed API documentation and workflow examples, see:
  - services/inference/README.md       (Inference service workflows)
  - demos/inferences/plan.md           (CLI client implementation details)
  - CLAUDE.md                          (Project architecture overview)

For CLI client usage:
  $ cd demos/inferences
  $ python image_embedding_client.py --help
  $ python face_detection_client.py --help

================================================================================

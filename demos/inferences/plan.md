# Inference Service Documentation & CLI Clients - Implementation Plan

## Overview
Create comprehensive documentation (README.md) for the inference service explaining two workflows (image_embedding, face_detection) from a client perspective, along with Python CLI client applications that upload images to media_store first, then call inference, and listen for MQTT completion events.

## User Requirements
- **Auth Mode**: Fix authentication in test mode (no tokens needed), don't mention in README
- **Virtual Environments**: Independent venv for each service/app
- **Workflow**: Upload image to media_store first → get ID → call inference with that ID
- **CLI Parameters**: `--media-store <host>:<port>`
- **Completion Detection**: Listen to MQTT for job completion events (timer-based timeout, no polling)
- **Workflows**: Only image_embedding and face_detection (exclude face_embedding for now)
- **Face Detection Results**: Create stub endpoint in media_store to accept and ignore face detection results
- **CLI Location**: Place CLI apps in `demos/inferences/` folder
- **Test Images**: Use images from `demos/images/` folder

## Quick Reference

### Commands to Run Services
```bash
# Media Store (port 8000)
source services/media_store/venv/bin/activate && python services/media_store/main.py

# Inference (port 8001)
source services/inference/venv/bin/activate && python services/inference/main.py

# CLI (from demos/inferences directory)
source venv/bin/activate && python image_embedding_client.py /path/to/image.jpg --media-store localhost:8000
```

### Files to Create
- `/services/inference/README.md`
- `/services/inference/venv/`
- `/services/media_store/venv/`
- `/demos/inferences/venv/`
- `/demos/inferences/__init__.py`
- `/demos/inferences/base_client.py`
- `/demos/inferences/image_embedding_client.py`
- `/demos/inferences/face_detection_client.py`
- `/demos/inferences/utils.py`
- `/demos/inferences/requirements.txt`

### Files to Modify
- `/services/inference/src/routes.py` - Add test mode auth bypass
- `/services/media_store/src/routes.py` - Add stub endpoint for face detection results

## Implementation Steps

1. **Part 0**: Add stub endpoint to media_store
2. **Part 1**: Create README.md with workflow documentation
3. **Part 2**: Create Python CLI client applications with:
   - base_client.py (common logic)
   - image_embedding_client.py (runnable)
   - face_detection_client.py (runnable)
4. **Part 3**: Fix authentication in test mode
5. **Part 4**: Setup virtual environments and dependencies

## How to Use This Plan

- **Reference during implementation**: Read this file in `demos/inferences/plan.md`
- **Update when requirements change**: Edit this file to reflect any plan changes
- **Track progress**: Update status in todo list as you complete tasks
- **Share with team**: Include this plan in version control for future reference

## Key Design Decisions

- **MQTT Event-Driven**: Uses MQTT for completion notification (no polling)
- **Independent Services**: Each service runs in its own venv, communicates only via HTTP/MQTT
- **Simple CLI**: Minimal dependencies (just requests + paho-mqtt)
- **Media Store Upload First**: Images must be uploaded to media_store before inference
- **No Auth in CLI**: Auth is handled at service level with test mode bypass

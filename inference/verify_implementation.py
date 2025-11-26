"""Verification script for AI Inference Service."""

import asyncio
import logging
import os
import sys
from pathlib import Path

import httpx
import numpy as np
from PIL import Image

# Add src to path
sys.path.append(str(Path(__file__).parent))

from src.inferences import (
    FaceDetectionInference,
    FaceEmbeddingInference,
    ImageEmbeddingInference,
)
from src.qdrant_manager import QdrantManager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

IMAGES_DIR = Path("../images/new Images")


async def verify_service_startup():
    """Verify that the service starts Qdrant automatically."""
    logger.info("1. Verifying Service Startup & Qdrant Auto-start")
    
    manager = QdrantManager()
    
    # Stop Qdrant first to test auto-start
    if manager.is_running():
        logger.info("Stopping Qdrant to test auto-start...")
        manager.stop()
        await asyncio.sleep(2)
    
    # Start Qdrant (simulating server startup)
    logger.info("Starting Qdrant via Manager...")
    if manager.start():
        logger.info("✅ Qdrant started successfully")
    else:
        logger.error("❌ Failed to start Qdrant")
        return False
        
    return True


async def verify_ml_flows():
    """Verify all three ML flows."""
    logger.info("\n2. Verifying ML Flows")
    
    # Get a test image
    image_files = list(IMAGES_DIR.glob("*.jpg")) + list(IMAGES_DIR.glob("*.png"))
    if not image_files:
        logger.error(f"No images found in {IMAGES_DIR}")
        return
    
    test_image_path = image_files[0]
    logger.info(f"Using test image: {test_image_path}")
    
    try:
        image = Image.open(test_image_path).convert("RGB")
        image_np = np.array(image)
    except Exception as e:
        logger.error(f"Failed to load image: {e}")
        return

    # 1. Image Embedding
    logger.info("\n--- Testing Image Embedding ---")
    try:
        img_infer = ImageEmbeddingInference()
        embedding = img_infer.infer(image_np, "test_image")
        
        if embedding is not None and embedding.shape == (512,):
            logger.info(f"✅ Image Embedding successful (shape: {embedding.shape})")
        else:
            logger.error("❌ Image Embedding failed")
    except Exception as e:
        logger.error(f"❌ Image Embedding error: {e}")

    # 2. Face Detection
    logger.info("\n--- Testing Face Detection ---")
    detected_faces = []
    try:
        face_det = FaceDetectionInference()
        faces = face_det.detect_faces(image_np)
        
        logger.info(f"Detected {len(faces)} faces")
        for face in faces:
            logger.info(f"  Face {face['face_index']}: Conf={face['confidence']:.4f}, BBox={face['bbox']}")
            
            # Create crop for next step
            bbox = face['bbox']
            x, y, w, h = int(bbox['x']), int(bbox['y']), int(bbox['width']), int(bbox['height'])
            # Ensure within bounds
            x, y = max(0, x), max(0, y)
            crop = image.crop((x, y, x + w, y + h))
            detected_faces.append(crop)
            
        if faces:
            logger.info("✅ Face Detection successful")
        else:
            logger.warning("⚠️ No faces detected (might be expected depending on image)")
            
    except Exception as e:
        logger.error(f"❌ Face Detection error: {e}")

    # 3. Face Embedding
    logger.info("\n--- Testing Face Embedding ---")
    try:
        face_emb = FaceEmbeddingInference()
        
        if not detected_faces:
            logger.warning("Skipping Face Embedding test (no faces detected)")
        else:
            # Test with valid single face crop
            logger.info("Testing with valid single face crop...")
            face_crop_np = np.array(detected_faces[0])
            embedding = face_emb.infer(face_crop_np, "valid_face")
            
            if embedding is not None and embedding.shape == (512,):
                logger.info(f"✅ Face Embedding successful for valid crop (shape: {embedding.shape})")
            else:
                logger.error("❌ Face Embedding failed for valid crop")
                
            # Test with full image (likely multiple faces or too large context)
            # Note: If the full image has exactly 1 face, this might actually succeed, 
            # but we want to verify it handles the input.
            logger.info("Testing with full image (checking validation)...")
            result = face_emb.infer(image_np, "full_image")
            if result is None:
                logger.info("✅ Validation logic working (rejected invalid input or multiple faces)")
            else:
                logger.info(f"ℹ️ Full image accepted (contains exactly 1 face)")

    except Exception as e:
        logger.error(f"❌ Face Embedding error: {e}")


async def main():
    if await verify_service_startup():
        await verify_ml_flows()

if __name__ == "__main__":
    asyncio.run(main())

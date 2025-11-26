"""Qdrant lifecycle management for automatic startup and shutdown."""

import logging
import subprocess
import time
from pathlib import Path

import httpx

logger = logging.getLogger(__name__)


class QdrantManager:
    """Manages Qdrant Docker container lifecycle."""

    def __init__(self, qdrant_url: str = "http://localhost:6333", max_wait: int = 30):
        """
        Initialize Qdrant manager.

        Args:
            qdrant_url: Qdrant server URL
            max_wait: Maximum seconds to wait for Qdrant to start
        """
        self.qdrant_url = qdrant_url
        self.max_wait = max_wait
        self.qdrant_dir = Path(__file__).parent.parent.parent / "vector_store_qdrant"
        self.start_script = self.qdrant_dir / "bin" / "vector_store_start"
        self.stop_script = self.qdrant_dir / "bin" / "vector_store_stop"

    def is_running(self) -> bool:
        """
        Check if Qdrant is running and healthy.

        Returns:
            True if Qdrant is accessible, False otherwise
        """
        try:
            response = httpx.get(f"{self.qdrant_url}/health", timeout=2.0)
            return response.status_code == 200
        except Exception:
            return False

    def start(self) -> bool:
        """
        Start Qdrant if not already running.

        Returns:
            True if Qdrant is running (was started or already running), False on failure
        """
        # Check if already running
        if self.is_running():
            logger.info("Qdrant is already running")
            return True

        logger.info("Starting Qdrant...")

        # Check if start script exists
        if not self.start_script.exists():
            logger.error(f"Start script not found: {self.start_script}")
            return False

        try:
            # Run start script
            result = subprocess.run(
                [str(self.start_script)],
                capture_output=True,
                text=True,
                timeout=60,
            )

            if result.returncode != 0:
                logger.error(f"Failed to start Qdrant: {result.stderr}")
                return False

            # Wait for Qdrant to be ready
            logger.info("Waiting for Qdrant to be ready...")
            for attempt in range(self.max_wait):
                if self.is_running():
                    logger.info("✓ Qdrant is ready")
                    return True
                time.sleep(1)

            logger.error(f"Qdrant failed to start within {self.max_wait} seconds")
            return False

        except subprocess.TimeoutExpired:
            logger.error("Qdrant start script timed out")
            return False
        except Exception as e:
            logger.error(f"Error starting Qdrant: {e}")
            return False

    def stop(self):
        """Stop Qdrant container."""
        if not self.is_running():
            logger.info("Qdrant is not running")
            return

        logger.info("Stopping Qdrant...")

        # Check if stop script exists
        if not self.stop_script.exists():
            logger.warning(f"Stop script not found: {self.stop_script}")
            return

        try:
            # Run stop script
            result = subprocess.run(
                [str(self.stop_script)],
                capture_output=True,
                text=True,
                timeout=30,
            )

            if result.returncode == 0:
                logger.info("✓ Qdrant stopped")
            else:
                logger.warning(f"Stop script returned non-zero: {result.stderr}")

        except subprocess.TimeoutExpired:
            logger.warning("Qdrant stop script timed out")
        except Exception as e:
            logger.warning(f"Error stopping Qdrant: {e}")


__all__ = ["QdrantManager"]

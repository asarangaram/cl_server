"""Media store client for fetching images and posting results."""

from __future__ import annotations

import logging
from io import BytesIO
from typing import Any, Optional

import httpx
from PIL import Image

from .config import MEDIA_STORE_STUB, MEDIA_STORE_URL

logger = logging.getLogger(__name__)


class MediaStoreClient:
    """Client for interacting with media_store service."""

    def __init__(self, base_url: Optional[str] = None, stub_mode: Optional[bool] = None):
        """
        Initialize media store client.

        Args:
            base_url: Base URL of media_store service
            stub_mode: Whether to use stub mode (defaults to config)
        """
        self.base_url = base_url or MEDIA_STORE_URL
        self.stub_mode = stub_mode if stub_mode is not None else MEDIA_STORE_STUB
        self.client = httpx.AsyncClient(timeout=30.0)

    async def fetch_image(self, media_store_id: str) -> Image.Image:
        """
        Fetch image from media_store.

        Args:
            media_store_id: ID of media in media_store

        Returns:
            PIL Image

        Raises:
            Exception: If image cannot be fetched
        """
        if self.stub_mode:
            # Stub: Return a test image
            logger.info(f"Stub mode: Generating test image for media_store_id={media_store_id}")
            return self._generate_test_image()

        try:
            url = f"{self.base_url}/entity/{media_store_id}/file"
            response = await self.client.get(url)
            response.raise_for_status()

            image = Image.open(BytesIO(response.content))
            return image

        except Exception as e:
            logger.error(f"Failed to fetch image from media_store: {e}")
            raise

    async def post_results(self, media_store_id: str, results: dict[str, Any]) -> dict:
        """
        Post inference results to media_store.

        Args:
            media_store_id: ID of media in media_store
            results: Results dictionary

        Returns:
            Response from media_store

        Raises:
            Exception: If posting fails
        """
        if self.stub_mode:
            # Stub: Just log and return success
            logger.info(
                f"Stub mode: Would post results to media_store_id={media_store_id}",
                extra={"results_keys": list(results.keys())},
            )
            return {"status": "accepted", "message": "Stub mode - results not actually posted"}

        try:
            url = f"{self.base_url}/inference/results/{media_store_id}"
            response = await self.client.post(url, json=results)
            response.raise_for_status()

            return response.json()

        except Exception as e:
            logger.error(f"Failed to post results to media_store: {e}")
            raise

    def _generate_test_image(self) -> Image.Image:
        """
        Generate a test image for stub mode.

        Returns:
            PIL Image (640x480 with random colors)
        """
        import numpy as np

        # Create a random test image
        arr = np.random.randint(0, 256, (480, 640, 3), dtype=np.uint8)
        return Image.fromarray(arr)

    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()


__all__ = ["MediaStoreClient"]

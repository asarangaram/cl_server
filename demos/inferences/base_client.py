"""
Base client for inference service interactions.

Handles:
- Image upload to media_store
- Job creation in inference service
- MQTT event listening for job completion
- Result retrieval via REST API
"""

import json
import threading
import time
from typing import Optional, Tuple

import paho.mqtt.client as mqtt
import requests

from utils import (
    read_image_file,
    construct_url,
    display_progress_message,
    display_error_message,
)


class InferenceClient:
    """Client for interacting with the inference service."""

    def __init__(
        self,
        media_store_host: str,
        media_store_port: int,
        inference_host: str = "localhost",
        inference_port: int = 8001,
        mqtt_host: str = "localhost",
        mqtt_port: int = 1883,
    ):
        """
        Initialize the inference client.

        Args:
            media_store_host: Media store service host
            media_store_port: Media store service port
            inference_host: Inference service host (default: localhost)
            inference_port: Inference service port (default: 8001)
            mqtt_host: MQTT broker host (default: localhost)
            mqtt_port: MQTT broker port (default: 1883)
        """
        self.media_store_url = construct_url(media_store_host, media_store_port)
        self.inference_url = construct_url(inference_host, inference_port)
        self.mqtt_host = mqtt_host
        self.mqtt_port = mqtt_port
        self.timeout_seconds = 5  # HTTP request timeout

    def upload_image_to_media_store(
        self,
        image_path: str,
        label: Optional[str] = None,
    ) -> int:
        """
        Upload an image to media_store and get its ID.

        Args:
            image_path: Path to the image file
            label: Optional label for the image

        Returns:
            Media store ID (integer)

        Raises:
            FileNotFoundError: If image file not found
            requests.RequestException: If upload fails
            ValueError: If response is invalid
        """
        display_progress_message(f"Uploading image to media_store...")

        try:
            image_data = read_image_file(image_path)
        except (FileNotFoundError, PermissionError) as e:
            raise FileNotFoundError(f"Cannot read image file: {e}")

        files = {
            "image": (image_path.split("/")[-1], image_data, "image/jpeg"),
        }
        data = {
            "is_collection": "false",
        }
        if label:
            data["label"] = label

        try:
            response = requests.post(
                f"{self.media_store_url}/entity/",
                files=files,
                data=data,
                timeout=self.timeout_seconds,
            )
            response.raise_for_status()
        except requests.exceptions.ConnectionError:
            raise requests.RequestException(
                f"Cannot connect to media_store at {self.media_store_url}. "
                "Make sure the service is running."
            )
        except requests.exceptions.Timeout:
            raise requests.RequestException(
                f"Timeout connecting to media_store at {self.media_store_url}"
            )
        except requests.exceptions.HTTPError as e:
            raise requests.RequestException(
                f"Media store error: {e.response.status_code} - {e.response.text}"
            )

        try:
            result = response.json()
            media_store_id = result.get("id")
            if not media_store_id:
                raise ValueError("Response does not contain 'id' field")
            return int(media_store_id)
        except (json.JSONDecodeError, ValueError) as e:
            raise ValueError(f"Invalid media_store response: {e}")

    def create_job(
        self,
        task_type: str,
        media_store_id: int,
        priority: int = 5,
    ) -> str:
        """
        Create an inference job.

        Args:
            task_type: Type of inference task (image_embedding, face_detection)
            media_store_id: ID of the image in media_store
            priority: Job priority (0-10, default 5)

        Returns:
            Job ID (UUID string)

        Raises:
            requests.RequestException: If job creation fails
            ValueError: If response is invalid
        """
        display_progress_message(
            f"Creating {task_type} job with media_store_id={media_store_id}..."
        )

        payload = {
            "media_store_id": media_store_id,
            "priority": priority,
        }

        try:
            response = requests.post(
                f"{self.inference_url}/job/{task_type}",
                json=payload,
                timeout=self.timeout_seconds,
            )
            response.raise_for_status()
        except requests.exceptions.ConnectionError:
            raise requests.RequestException(
                f"Cannot connect to inference service at {self.inference_url}. "
                "Make sure the service is running."
            )
        except requests.exceptions.Timeout:
            raise requests.RequestException(
                f"Timeout connecting to inference service at {self.inference_url}"
            )
        except requests.exceptions.HTTPError as e:
            error_detail = e.response.text
            if e.response.status_code == 400:
                raise ValueError(f"Invalid request: {error_detail}")
            elif e.response.status_code == 409:
                raise ValueError(f"Job already exists: {error_detail}")
            else:
                raise requests.RequestException(
                    f"Inference service error: {e.response.status_code} - {error_detail}"
                )

        try:
            result = response.json()
            job_id = result.get("job_id")
            if not job_id:
                raise ValueError("Response does not contain 'job_id' field")
            return job_id
        except (json.JSONDecodeError, ValueError) as e:
            raise ValueError(f"Invalid inference response: {e}")

    def fetch_job_result(self, job_id: str) -> dict:
        """
        Fetch the result of a completed job.

        Args:
            job_id: ID of the job

        Returns:
            Complete job response with results

        Raises:
            requests.RequestException: If fetch fails
        """
        try:
            response = requests.get(
                f"{self.inference_url}/job/{job_id}",
                timeout=self.timeout_seconds,
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            raise requests.RequestException(
                f"Failed to fetch job result: {e}"
            )

    def listen_for_job_completion(
        self,
        job_id: str,
        timeout_seconds: int = 300,
    ) -> dict:
        """
        Wait for job completion via MQTT event, with timeout.

        Args:
            job_id: ID of the job to wait for
            timeout_seconds: Maximum time to wait in seconds (default 300=5min)

        Returns:
            Complete job response with results

        Raises:
            TimeoutError: If job doesn't complete within timeout
            requests.RequestException: If fetching result fails
        """
        display_progress_message(
            f"Listening for job completion (timeout: {timeout_seconds}s)..."
        )

        event_received = threading.Event()

        def on_message(client, userdata, msg):
            """MQTT message callback."""
            if job_id in msg.topic:
                display_progress_message("Job completion event received!")
                event_received.set()

        def on_connect(client, userdata, flags, rc):
            """MQTT connection callback."""
            if rc != 0:
                display_error_message(f"MQTT connection failed with code {rc}")
            else:
                display_progress_message("Connected to MQTT broker")
                client.subscribe(f"inference/job/{job_id}/completed")

        def on_disconnect(client, userdata, rc):
            """MQTT disconnection callback."""
            if rc != 0:
                display_error_message(f"Unexpected MQTT disconnection: code {rc}")

        # Create MQTT client
        client = mqtt.Client()
        client.on_message = on_message
        client.on_connect = on_connect
        client.on_disconnect = on_disconnect

        try:
            # Connect to MQTT broker
            display_progress_message(f"Connecting to MQTT broker at {self.mqtt_host}:{self.mqtt_port}...")
            client.connect(
                self.mqtt_host,
                self.mqtt_port,
                keepalive=60,
            )
            client.loop_start()

            # Wait for event with timeout
            if event_received.wait(timeout=timeout_seconds):
                client.loop_stop()
                client.disconnect()

                # Event received - fetch result via REST API
                display_progress_message("Fetching job results...")
                result = self.fetch_job_result(job_id)
                return result
            else:
                client.loop_stop()
                client.disconnect()
                raise TimeoutError(
                    f"Job {job_id} did not complete within {timeout_seconds}s. "
                    "Try increasing --timeout"
                )

        except Exception as e:
            client.loop_stop()
            client.disconnect()
            if isinstance(e, TimeoutError):
                raise
            # MQTT errors - try fallback to polling
            display_error_message(f"MQTT error: {e}")
            raise requests.RequestException(
                f"Cannot connect to MQTT broker at {self.mqtt_host}:{self.mqtt_port}. "
                "Make sure the broker is running."
            )

    def run_workflow(
        self,
        task_type: str,
        image_path: str,
        label: Optional[str] = None,
        priority: int = 5,
        timeout_seconds: int = 300,
    ) -> dict:
        """
        Run a complete inference workflow.

        Steps:
        1. Upload image to media_store
        2. Create inference job
        3. Wait for completion via MQTT
        4. Fetch and return results

        Args:
            task_type: Type of inference (image_embedding, face_detection)
            image_path: Path to image file
            label: Optional label for the image
            priority: Job priority (0-10)
            timeout_seconds: Job timeout in seconds

        Returns:
            Complete job response with results

        Raises:
            Various exceptions from individual steps
        """
        # Step 1: Upload image
        media_store_id = self.upload_image_to_media_store(image_path, label)
        display_progress_message(f"Image uploaded with media_store_id={media_store_id}")

        # Step 2: Create job
        job_id = self.create_job(task_type, media_store_id, priority)
        display_progress_message(f"Job created with job_id={job_id}")

        # Step 3: Wait for completion
        result = self.listen_for_job_completion(job_id, timeout_seconds)

        return result

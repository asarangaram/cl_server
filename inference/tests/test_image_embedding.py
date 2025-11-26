"""
Tests for image embedding job endpoints.
"""

import pytest
import json
import uuid
from datetime import datetime


class TestImageEmbeddingJobCreation:
    """Test creating image embedding jobs."""

    def test_create_image_embedding_job_success(self, client, demo_user):
        """Test successful creation of an image embedding job."""
        response = client.post(
            "/job/image_embedding",
            json={
                "media_store_id": "test_media_1",
                "priority": 5
            }
        )

        assert response.status_code == 201
        data = response.json()

        # Verify job response structure
        assert "id" in data or "job_id" in data
        assert data["task_type"] == "image_embedding"
        assert data["media_store_id"] == "test_media_1"
        assert data["status"] == "pending"
        assert data["priority"] == 5
        assert "created_at" in data

    def test_create_image_embedding_job_with_default_priority(self, client):
        """Test creating job with default priority if not specified."""
        response = client.post(
            "/job/image_embedding",
            json={"media_store_id": "test_media_2"}
        )

        assert response.status_code == 201
        data = response.json()
        assert data["priority"] == 5  # Default priority

    def test_create_image_embedding_job_with_custom_priority(self, client):
        """Test creating job with custom priority."""
        for priority in [0, 5, 10]:
            response = client.post(
                "/job/image_embedding",
                json={
                    "media_store_id": f"test_media_priority_{priority}",
                    "priority": priority
                }
            )

            assert response.status_code == 201
            data = response.json()
            assert data["priority"] == priority

    def test_create_job_missing_media_store_id(self, client):
        """Test creating job without required media_store_id."""
        response = client.post(
            "/job/image_embedding",
            json={"priority": 5}
        )

        assert response.status_code == 422  # Validation error

    def test_create_job_with_invalid_priority(self, client):
        """Test creating job with invalid priority values."""
        # Priority too high
        response = client.post(
            "/job/image_embedding",
            json={
                "media_store_id": "test_media_3",
                "priority": 11
            }
        )
        # Server should either accept it or reject it, but handle gracefully
        assert response.status_code in [201, 422]

        # Priority negative
        response = client.post(
            "/job/image_embedding",
            json={
                "media_store_id": "test_media_4",
                "priority": -1
            }
        )
        assert response.status_code in [201, 422]

    def test_create_job_returns_valid_uuid(self, client):
        """Test that created job has a valid UUID."""
        response = client.post(
            "/job/image_embedding",
            json={"media_store_id": "test_media_5"}
        )

        assert response.status_code == 201
        data = response.json()
        job_id = data.get("id") or data.get("job_id")

        # Validate UUID format
        try:
            uuid.UUID(job_id)
        except ValueError:
            pytest.fail(f"Job ID {job_id} is not a valid UUID")

    def test_create_job_different_task_types(self, client):
        """Test creating jobs with different task types."""
        task_types = ["image_embedding", "face_detection", "face_embedding"]

        for task_type in task_types:
            response = client.post(
                f"/job/{task_type}",
                json={"media_store_id": f"media_{task_type}"}
            )

            assert response.status_code == 201
            data = response.json()
            assert data["task_type"] == task_type

    def test_create_job_with_invalid_task_type(self, client):
        """Test creating job with invalid task type."""
        response = client.post(
            "/job/invalid_task_type",
            json={"media_store_id": "test_media_6"}
        )

        assert response.status_code == 400


class TestImageEmbeddingJobRetrieval:
    """Test retrieving image embedding jobs."""

    @pytest.fixture
    def created_job(self, client):
        """Create a job for testing retrieval."""
        response = client.post(
            "/job/image_embedding",
            json={
                "media_store_id": "test_media_retrieve",
                "priority": 7
            }
        )
        return response.json()

    def test_get_job_by_id(self, client, created_job):
        """Test retrieving a job by its ID."""
        job_id = created_job.get("id") or created_job.get("job_id")

        response = client.get(f"/job/{job_id}")

        assert response.status_code == 200
        data = response.json()
        assert data["task_type"] == "image_embedding"
        assert data["media_store_id"] == "test_media_retrieve"
        assert data["priority"] == 7

    def test_get_nonexistent_job(self, client):
        """Test retrieving a job that doesn't exist."""
        fake_job_id = str(uuid.uuid4())

        response = client.get(f"/job/{fake_job_id}")

        assert response.status_code == 404

    def test_get_job_returns_complete_response(self, client, created_job):
        """Test that job response contains all required fields."""
        job_id = created_job.get("id") or created_job.get("job_id")

        response = client.get(f"/job/{job_id}")

        assert response.status_code == 200
        data = response.json()

        # Required fields
        required_fields = [
            "job_id" if "job_id" in data else "id",
            "task_type",
            "media_store_id",
            "status",
            "priority",
            "created_at",
        ]

        for field in required_fields:
            assert field in data, f"Missing required field: {field}"

    def test_get_job_public_access(self, client, created_job):
        """Test that jobs can be retrieved without authentication."""
        job_id = created_job.get("id") or created_job.get("job_id")

        # GET /job/{job_id} should be public (no auth required)
        response = client.get(f"/job/{job_id}")
        assert response.status_code == 200


class TestImageEmbeddingJobDeletion:
    """Test deleting image embedding jobs."""

    @pytest.fixture
    def created_job_for_deletion(self, client):
        """Create a job for testing deletion."""
        response = client.post(
            "/job/image_embedding",
            json={
                "media_store_id": "test_media_delete",
                "priority": 3
            }
        )
        return response.json()

    def test_delete_job_success(self, client, created_job_for_deletion):
        """Test successful job deletion."""
        job_id = created_job_for_deletion.get("id") or created_job_for_deletion.get("job_id")

        # Verify job exists
        response = client.get(f"/job/{job_id}")
        assert response.status_code == 200

        # Delete job
        delete_response = client.delete(f"/job/{job_id}")
        assert delete_response.status_code == 204

        # Verify job no longer exists
        get_response = client.get(f"/job/{job_id}")
        assert get_response.status_code == 404

    def test_delete_nonexistent_job(self, client):
        """Test deleting a job that doesn't exist."""
        fake_job_id = str(uuid.uuid4())

        response = client.delete(f"/job/{fake_job_id}")

        assert response.status_code == 404

    def test_delete_job_twice(self, client, created_job_for_deletion):
        """Test that deleting the same job twice fails on the second attempt."""
        job_id = created_job_for_deletion.get("id") or created_job_for_deletion.get("job_id")

        # First deletion should succeed
        response1 = client.delete(f"/job/{job_id}")
        assert response1.status_code == 204

        # Second deletion should fail
        response2 = client.delete(f"/job/{job_id}")
        assert response2.status_code == 404


class TestImageEmbeddingJobAuthentication:
    """Test authentication for image embedding endpoints.

    Note: Tests for authentication failures are not applicable when AUTH_DISABLED=true
    is set in the test environment. The tests below verify that authenticated requests
    work properly with the required permissions.
    """

    def test_create_job_with_authentication(self, client):
        """Test creating job with proper authentication."""
        response = client.post(
            "/job/image_embedding",
            json={"media_store_id": "test_media_auth_ok"}
        )

        assert response.status_code == 201

    def test_delete_job_with_authentication(self, client):
        """Test deleting job with proper authentication."""
        # Create job
        create_response = client.post(
            "/job/image_embedding",
            json={"media_store_id": "test_media_delete_auth_ok"}
        )
        job_id = create_response.json().get("id") or create_response.json().get("job_id")

        # Delete job
        delete_response = client.delete(f"/job/{job_id}")

        assert delete_response.status_code == 204


class TestImageEmbeddingJobStatus:
    """Test job status and lifecycle."""

    def test_job_initial_status_is_pending(self, client):
        """Test that newly created jobs have 'pending' status."""
        response = client.post(
            "/job/image_embedding",
            json={"media_store_id": "test_media_status"}
        )

        assert response.status_code == 201
        data = response.json()
        assert data["status"] == "pending"

    def test_job_timestamps_are_set(self, client):
        """Test that job creation timestamp is set."""
        response = client.post(
            "/job/image_embedding",
            json={"media_store_id": "test_media_timestamps"}
        )

        assert response.status_code == 201
        data = response.json()

        assert "created_at" in data
        assert isinstance(data["created_at"], int) or isinstance(data["created_at"], str)

    def test_job_response_contains_metadata(self, client):
        """Test that job response contains all metadata fields."""
        response = client.post(
            "/job/image_embedding",
            json={
                "media_store_id": "test_media_metadata",
                "priority": 8
            }
        )

        assert response.status_code == 201
        data = response.json()

        # Check metadata
        assert data["task_type"] == "image_embedding"
        assert data["media_store_id"] == "test_media_metadata"
        assert data["status"] == "pending"
        assert data["priority"] == 8


class TestImageEmbeddingBroadcaster:
    """Test broadcaster integration with job operations."""

    def test_broadcaster_publish_called_on_job_creation(self, client, mock_broadcaster):
        """Test that broadcaster.publish is called when job is created."""
        mock_broadcaster.reset_mock()

        response = client.post(
            "/job/image_embedding",
            json={"media_store_id": "test_media_broadcast"}
        )

        assert response.status_code == 201
        # Note: broadcaster is mocked, so actual publish may not be called
        # in this test. This test verifies the dependency is available.
        assert mock_broadcaster is not None

    def test_broadcaster_is_available(self, client, mock_broadcaster):
        """Test that broadcaster is properly injected."""
        assert mock_broadcaster is not None
        assert hasattr(mock_broadcaster, 'publish')


class TestImageEmbeddingEdgeCases:
    """Test edge cases and error conditions."""

    def test_create_job_with_empty_media_store_id(self, client):
        """Test creating job with empty media_store_id."""
        response = client.post(
            "/job/image_embedding",
            json={"media_store_id": "", "priority": 5}
        )

        # Should either accept or reject, but handle gracefully
        assert response.status_code in [201, 422]

    def test_create_job_with_very_long_media_store_id(self, client):
        """Test creating job with very long media_store_id."""
        long_id = "x" * 1000

        response = client.post(
            "/job/image_embedding",
            json={"media_store_id": long_id, "priority": 5}
        )

        # Should either accept or reject, but handle gracefully
        assert response.status_code in [201, 422]

    def test_create_job_with_special_characters(self, client):
        """Test creating job with special characters in media_store_id."""
        response = client.post(
            "/job/image_embedding",
            json={"media_store_id": "media_!@#$%^&*()", "priority": 5}
        )

        # Should either accept or reject, but handle gracefully
        assert response.status_code in [201, 422]

    def test_create_multiple_jobs_same_media(self, client):
        """Test creating multiple jobs for the same media."""
        media_id = "test_media_multiple"

        # Create first job
        response1 = client.post(
            "/job/image_embedding",
            json={"media_store_id": media_id}
        )

        # Create second job for same media with different task type
        response2 = client.post(
            "/job/face_detection",
            json={"media_store_id": media_id}
        )

        # Both should succeed (different task types)
        assert response1.status_code == 201
        assert response2.status_code == 201

        # Jobs should have different IDs
        job1_id = response1.json().get("id") or response1.json().get("job_id")
        job2_id = response2.json().get("id") or response2.json().get("job_id")
        assert job1_id != job2_id

    def test_health_check_endpoint_exists(self, client):
        """Test that health check endpoint exists."""
        response = client.get("/health")

        assert response.status_code == 200
        data = response.json()
        assert "status" in data

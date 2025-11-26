"""
Pytest configuration and fixtures for testing the inference microservice.
"""

import pytest
import sys
import os
from unittest.mock import MagicMock, AsyncMock, patch
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

# Set environment variables before any imports
os.environ['AUTH_DISABLED'] = 'true'

# Mock paho.mqtt before any imports that might use it
sys.modules['paho'] = MagicMock()
sys.modules['paho.mqtt'] = MagicMock()
sys.modules['paho.mqtt.client'] = MagicMock()


@pytest.fixture(scope="function")
def test_engine():
    """Create a test database engine with in-memory SQLite."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

    # Import models and create tables
    from src.models import Base

    Base.metadata.create_all(bind=engine)

    yield engine

    # Cleanup
    Base.metadata.drop_all(bind=engine)
    engine.dispose()


@pytest.fixture(scope="function")
def test_db_session(test_engine):
    """Create a test database session."""
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    session = TestingSessionLocal()

    yield session

    session.close()


@pytest.fixture(scope="function")
def mock_broadcaster():
    """Create a mock broadcaster for testing."""
    broadcaster = MagicMock()
    broadcaster.enabled = True
    broadcaster.publish = MagicMock()
    return broadcaster


@pytest.fixture(scope="function")
def mock_media_store_client():
    """Create a mock media store client."""
    client = AsyncMock()
    # Mock successful image fetch
    from PIL import Image
    import numpy as np

    # Create a test image
    test_image = Image.new('RGB', (224, 224), color='red')

    client.fetch_image = AsyncMock(return_value=test_image)
    client.post_results = AsyncMock(return_value={"status": "success"})
    client.close = AsyncMock()

    return client


@pytest.fixture(scope="function")
def mock_vector_core():
    """Create a mock VectorCore for testing."""
    core = MagicMock()
    core.add_file = MagicMock(return_value=True)
    return core


@pytest.fixture(scope="function")
def client(test_engine, mock_broadcaster):
    """Create a test client with mocked dependencies."""
    # Create session maker
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

    # Override the get_db dependency
    def override_get_db():
        try:
            db = TestingSessionLocal()
            yield db
        finally:
            db.close()

    # Mock security to bypass HTTPBearer requirement
    def mock_security():
        return MagicMock(credentials="test_token")

    # Import app and dependencies
    from src import app
    from src.database import get_db
    from src.broadcaster import get_broadcaster
    import src.auth as auth

    # Override dependencies
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_broadcaster] = lambda: mock_broadcaster
    app.dependency_overrides[auth.security] = mock_security

    # Create test client
    with TestClient(app) as test_client:
        yield test_client

    # Cleanup
    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
def auth_client(test_engine, mock_broadcaster):
    """Create a test client for testing authentication (with AUTH_DISABLED=true for testing purposes)."""
    # Note: In test environment, AUTH_DISABLED is set to 'true' to allow testing without JWT tokens.
    # This fixture can be used for tests that need authentication context.
    # Create session maker
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

    # Override the get_db dependency only
    def override_get_db():
        try:
            db = TestingSessionLocal()
            yield db
        finally:
            db.close()

    # Mock security to bypass HTTPBearer requirement
    def mock_security():
        return MagicMock(credentials="test_token")

    # Import app and dependencies
    from src import app
    from src.database import get_db
    from src.broadcaster import get_broadcaster
    import src.auth as auth

    # Override database and broadcaster
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_broadcaster] = lambda: mock_broadcaster
    app.dependency_overrides[auth.security] = mock_security

    # Create test client
    with TestClient(app) as test_client:
        yield test_client

    # Cleanup
    app.dependency_overrides.clear()


@pytest.fixture
def demo_user():
    """Create a demo user with ai_inference_support permission."""
    return {
        "sub": "demo_user",
        "permissions": ["ai_inference_support"],
        "is_admin": True,
    }


@pytest.fixture
def test_user():
    """Create a test user with ai_inference_support permission."""
    return {
        "sub": "test_user",
        "permissions": ["ai_inference_support"],
        "is_admin": False,
    }


@pytest.fixture
def unauthorized_user():
    """Create a user without required permissions."""
    return {
        "sub": "unauthorized_user",
        "permissions": [],
        "is_admin": False,
    }

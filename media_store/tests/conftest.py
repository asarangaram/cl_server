"""
Pytest configuration and fixtures for testing the CoLAN server.
"""

import os
import shutil
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool


@pytest.fixture(scope="session")
def test_images_dir():
    """Path to test images directory."""
    return Path("./images")


@pytest.fixture(scope="function")
def test_engine():
    """Create a test database engine."""
    # Use in-memory SQLite with StaticPool for thread safety
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    
    # Import models and create tables
    from server.models import Base
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
def client(test_engine, clean_media_dir):
    """Create a test client with a fresh database and test media directory."""
    # Create session maker
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    
    # Override the get_db dependency
    def override_get_db():
        try:
            db = TestingSessionLocal()
            yield db
        finally:
            db.close()
    
    # Import app and override dependency
    from server import app
    from server.database import get_db
    from server.services import EntityService
    
    app.dependency_overrides[get_db] = override_get_db
    
    # Monkey patch EntityService to use test media directory
    original_init = EntityService.__init__
    
    def patched_init(self, db, base_dir=None):
        original_init(self, db, base_dir=str(clean_media_dir))
    
    EntityService.__init__ = patched_init
    
    # Create test client
    with TestClient(app) as test_client:
        yield test_client
    
    # Cleanup
    EntityService.__init__ = original_init
    app.dependency_overrides.clear()


@pytest.fixture(scope="function")
def clean_media_dir():
    """Clean up media files directory before and after tests."""
    media_dir = Path("./test_media_files")
    
    # Clean before test
    if media_dir.exists():
        shutil.rmtree(media_dir)
    media_dir.mkdir(parents=True, exist_ok=True)
    
    yield media_dir
    
    # Clean after test
    if media_dir.exists():
        shutil.rmtree(media_dir)


@pytest.fixture
def sample_image(test_images_dir):
    """Get a sample image file for testing."""
    images = list(test_images_dir.glob("*.jpg"))
    if not images:
        pytest.skip("No test images found in ./images directory")
    return images[0]


@pytest.fixture
def sample_images(test_images_dir):
    """Get multiple sample images for testing."""
    images = list(test_images_dir.glob("*.jpg"))[:3]
    if len(images) < 2:
        pytest.skip("Not enough test images found in ./images directory")
    return images

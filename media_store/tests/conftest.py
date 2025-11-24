"""
Pytest configuration and fixtures for testing the CoLAN server.
"""

import os
import shutil
import sys
from pathlib import Path

# Add tests directory to Python path for test_config import
sys.path.insert(0, str(Path(__file__).parent))

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

from test_config import (
    IMAGES_DIR,
    TEST_IMAGES,
    TEST_MEDIA_DIR_NAME,
    TEST_DB_URL,
    get_all_test_images,
)


@pytest.fixture(scope="session")
def test_images_dir():
    """Path to test images directory (absolute path)."""
    return IMAGES_DIR


@pytest.fixture(scope="function")
def test_engine():
    """Create a test database engine with versioning support."""
    # Use in-memory SQLite with StaticPool for thread safety
    engine = create_engine(
        TEST_DB_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    
    # Import models and configure versioning BEFORE creating tables
    from server.models import Base
    from sqlalchemy.orm import configure_mappers
    
    # This must be called before create_all to ensure version tables are created
    configure_mappers()
    
    # Now create all tables including version tables
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
    media_dir = Path(f"./{TEST_MEDIA_DIR_NAME}")
    
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
    """Get a sample image file for testing (absolute path)."""
    images = get_all_test_images()
    if not images:
        pytest.skip(f"No test images found. Please add images to {test_images_dir} or update test_files.txt")
    return images[0]


@pytest.fixture
def sample_images(test_images_dir):
    """Get multiple sample images for testing (absolute paths)."""
    images = get_all_test_images()
    if len(images) < 2:
        pytest.skip(f"Not enough test images found. Please add at least 2 images to {test_images_dir} or update test_files.txt")
    return images[:3]  # Return up to 3 images

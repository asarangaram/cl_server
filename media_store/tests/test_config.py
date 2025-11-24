"""
Test configuration for media store tests.

This module provides centralized configuration for all tests, including:
- Test image file paths (absolute paths)
- Test file loading from test_files.txt
- Configuration constants
"""

from pathlib import Path
from typing import List

# Get the absolute path to the tests directory
TESTS_DIR = Path(__file__).parent.absolute()

# Get the absolute path to the media_store directory (parent of tests)
MEDIA_STORE_DIR = TESTS_DIR.parent

# Get the absolute path to the images directory (sibling of media_store)
IMAGES_DIR = MEDIA_STORE_DIR.parent / "images"

# Test files list path
TEST_FILES_LIST = TESTS_DIR / "test_files.txt"


def load_test_files() -> List[Path]:
    """
    Load test file paths from test_files.txt.
    
    Returns:
        List of absolute Path objects for test images
    """
    if not TEST_FILES_LIST.exists():
        return []
    
    test_files = []
    with open(TEST_FILES_LIST, 'r') as f:
        for line in f:
            line = line.strip()
            # Skip empty lines and comments
            if not line or line.startswith('#'):
                continue
            
            # Convert relative path to absolute
            # Paths in test_files.txt are relative to media_store directory
            file_path = MEDIA_STORE_DIR / line
            
            if file_path.exists():
                test_files.append(file_path.absolute())
    
    return test_files


def get_all_test_images() -> List[Path]:
    """
    Get all available test images.
    
    First tries to load from test_files.txt, then falls back to
    scanning the images directory for .jpg files.
    
    Returns:
        List of absolute Path objects for test images
    """
    # Try loading from test_files.txt first
    test_files = load_test_files()
    if test_files:
        return test_files
    
    # Fall back to scanning images directory
    if not IMAGES_DIR.exists():
        return []
    
    # Recursively find all .jpg and .jpeg files
    jpg_files = list(IMAGES_DIR.rglob("*.jpg")) + list(IMAGES_DIR.rglob("*.jpeg"))
    return [f.absolute() for f in jpg_files]


# Pre-load test images for convenience
TEST_IMAGES = get_all_test_images()

# Specific test images (if available)
PRIMARY_TEST_IMAGE = TEST_IMAGES[0] if len(TEST_IMAGES) > 0 else None
SECONDARY_TEST_IMAGE = TEST_IMAGES[1] if len(TEST_IMAGES) > 1 else None
TERTIARY_TEST_IMAGE = TEST_IMAGES[2] if len(TEST_IMAGES) > 2 else None

# Test configuration constants
TEST_MEDIA_DIR_NAME = "test_media_files"
TEST_DB_URL = "sqlite:///:memory:"

__all__ = [
    'TESTS_DIR',
    'MEDIA_STORE_DIR',
    'IMAGES_DIR',
    'TEST_FILES_LIST',
    'TEST_IMAGES',
    'PRIMARY_TEST_IMAGE',
    'SECONDARY_TEST_IMAGE',
    'TERTIARY_TEST_IMAGE',
    'TEST_MEDIA_DIR_NAME',
    'TEST_DB_URL',
    'load_test_files',
    'get_all_test_images',
]

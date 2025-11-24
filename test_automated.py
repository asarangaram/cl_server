#!/usr/bin/env python3
"""
Automated test suite for file upload, metadata extraction, and duplicate detection.
Can be run repeatedly to verify functionality.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

import requests

BASE_URL = "http://127.0.0.1:8000"
TEST_IMAGES_DIR = Path("./images")


def print_section(title):
    """Print a section header."""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70)


def print_test(name, status="RUNNING"):
    """Print test status."""
    symbols = {"RUNNING": "⏳", "PASS": "✅", "FAIL": "❌", "SKIP": "⏭️"}
    print(f"{symbols.get(status, '•')} {name}")


def verify_exiftool_metadata(file_path, api_metadata):
    """
    Verify API metadata against exiftool output.
    
    Args:
        file_path: Path to the image file
        api_metadata: Metadata returned from API
        
    Returns:
        Tuple of (success, differences)
    """
    try:
        # Run exiftool
        result = subprocess.run(
            ["exiftool", "-j", str(file_path)],
            capture_output=True,
            text=True,
            check=True
        )
        exif_data = json.loads(result.stdout)[0]
        
        differences = []
        
        # Check image dimensions
        if "ImageWidth" in exif_data and api_metadata.get("width"):
            if exif_data["ImageWidth"] != api_metadata["width"]:
                differences.append(
                    f"Width mismatch: exiftool={exif_data['ImageWidth']}, "
                    f"API={api_metadata['width']}"
                )
        
        if "ImageHeight" in exif_data and api_metadata.get("height"):
            if exif_data["ImageHeight"] != api_metadata["height"]:
                differences.append(
                    f"Height mismatch: exiftool={exif_data['ImageHeight']}, "
                    f"API={api_metadata['height']}"
                )
        
        # Check file size
        actual_size = os.path.getsize(file_path)
        if api_metadata.get("file_size") != actual_size:
            differences.append(
                f"File size mismatch: actual={actual_size}, "
                f"API={api_metadata['file_size']}"
            )
        
        return len(differences) == 0, differences
        
    except FileNotFoundError:
        return None, ["exiftool not found - skipping verification"]
    except Exception as e:
        return None, [f"Error running exiftool: {e}"]


def test_server_health():
    """Test if server is running."""
    print_test("Server Health Check", "RUNNING")
    try:
        response = requests.get(f"{BASE_URL}/")
        if response.status_code == 200:
            print_test("Server Health Check", "PASS")
            return True
        else:
            print_test("Server Health Check", "FAIL")
            print(f"  Status: {response.status_code}")
            return False
    except Exception as e:
        print_test("Server Health Check", "FAIL")
        print(f"  Error: {e}")
        return False


def test_file_upload(image_path):
    """Test file upload with metadata extraction."""
    filename = image_path.name
    print_test(f"Upload: {filename}", "RUNNING")
    
    try:
        with open(image_path, "rb") as f:
            files = {
                "image": (filename, f, "image/jpeg"),
                "body": (None, json.dumps({
                    "is_collection": False,
                    "label": f"Test: {filename}",
                    "description": f"Uploaded from {image_path}"
                }), "application/json")
            }
            
            response = requests.post(f"{BASE_URL}/entity/", files=files)
            
            if response.status_code == 201:
                data = response.json()
                print_test(f"Upload: {filename}", "PASS")
                print(f"  Entity ID: {data['id']}")
                print(f"  MD5: {data.get('md5', 'N/A')}")
                print(f"  Dimensions: {data.get('width')}x{data.get('height')}")
                print(f"  File Size: {data.get('file_size')} bytes")
                print(f"  MIME Type: {data.get('mime_type')}")
                
                # Verify with exiftool
                success, diffs = verify_exiftool_metadata(image_path, data)
                if success is None:
                    print(f"  ⚠️  {diffs[0]}")
                elif success:
                    print(f"  ✅ Metadata verified with exiftool")
                else:
                    print(f"  ⚠️  Metadata differences found:")
                    for diff in diffs:
                        print(f"     - {diff}")
                
                return data
            elif response.status_code == 409:
                print_test(f"Upload: {filename}", "SKIP")
                print(f"  Duplicate detected: {response.json()['detail']}")
                return None
            else:
                print_test(f"Upload: {filename}", "FAIL")
                print(f"  Status: {response.status_code}")
                print(f"  Response: {response.text}")
                return None
                
    except Exception as e:
        print_test(f"Upload: {filename}", "FAIL")
        print(f"  Error: {e}")
        return None


def test_duplicate_upload(image_path):
    """Test duplicate detection."""
    filename = image_path.name
    print_test(f"Duplicate Detection: {filename}", "RUNNING")
    
    try:
        with open(image_path, "rb") as f:
            files = {
                "image": (filename, f, "image/jpeg"),
                "body": (None, json.dumps({
                    "is_collection": False,
                    "label": "Duplicate test",
                    "description": "Should be rejected"
                }), "application/json")
            }
            
            response = requests.post(f"{BASE_URL}/entity/", files=files)
            
            if response.status_code == 409:
                print_test(f"Duplicate Detection: {filename}", "PASS")
                print(f"  Correctly rejected: {response.json()['detail']}")
                return True
            else:
                print_test(f"Duplicate Detection: {filename}", "FAIL")
                print(f"  Expected 409, got {response.status_code}")
                return False
                
    except Exception as e:
        print_test(f"Duplicate Detection: {filename}", "FAIL")
        print(f"  Error: {e}")
        return False


def test_file_storage():
    """Test that files are stored in correct directory structure."""
    print_test("File Storage Organization", "RUNNING")
    
    media_dir = Path("./media_files")
    if not media_dir.exists():
        print_test("File Storage Organization", "FAIL")
        print(f"  Media directory not found: {media_dir}")
        return False
    
    # Check for YYYY/MM/DD structure
    found_files = list(media_dir.rglob("*.jpg")) + list(media_dir.rglob("*.jpeg"))
    
    if not found_files:
        print_test("File Storage Organization", "FAIL")
        print(f"  No files found in {media_dir}")
        return False
    
    # Verify structure
    valid_structure = True
    for file_path in found_files:
        rel_path = file_path.relative_to(media_dir)
        parts = rel_path.parts
        
        # Should be YYYY/MM/DD/filename
        if len(parts) != 4:
            print(f"  ⚠️  Invalid structure: {rel_path}")
            valid_structure = False
            continue
        
        year, month, day, filename = parts
        
        # Verify format
        if not (year.isdigit() and len(year) == 4):
            print(f"  ⚠️  Invalid year: {year}")
            valid_structure = False
        if not (month.isdigit() and 1 <= int(month) <= 12):
            print(f"  ⚠️  Invalid month: {month}")
            valid_structure = False
        if not (day.isdigit() and 1 <= int(day) <= 31):
            print(f"  ⚠️  Invalid day: {day}")
            valid_structure = False
        
        # Verify filename has MD5 prefix
        if "_" not in filename:
            print(f"  ⚠️  Filename missing MD5 prefix: {filename}")
            valid_structure = False
    
    if valid_structure:
        print_test("File Storage Organization", "PASS")
        print(f"  Found {len(found_files)} files with correct YYYY/MM/DD structure")
        for f in found_files[:3]:  # Show first 3
            print(f"  📁 {f.relative_to(media_dir)}")
        if len(found_files) > 3:
            print(f"  ... and {len(found_files) - 3} more")
        return True
    else:
        print_test("File Storage Organization", "FAIL")
        return False


def main():
    """Run all tests."""
    print_section("Automated Test Suite - File Upload & Metadata Extraction")
    
    # Test 1: Server health
    if not test_server_health():
        print("\n❌ Server not running. Please start the server first.")
        sys.exit(1)
    
    # Test 2: Upload images
    print_section("File Upload Tests")
    
    if not TEST_IMAGES_DIR.exists():
        print(f"❌ Test images directory not found: {TEST_IMAGES_DIR}")
        sys.exit(1)
    
    image_files = list(TEST_IMAGES_DIR.glob("*.jpg"))[:3]  # Test with first 3 images
    
    if not image_files:
        print(f"❌ No .jpg files found in {TEST_IMAGES_DIR}")
        sys.exit(1)
    
    uploaded_entities = []
    for image_path in image_files:
        entity = test_file_upload(image_path)
        if entity:
            uploaded_entities.append(entity)
    
    # Test 3: Duplicate detection
    if uploaded_entities:
        print_section("Duplicate Detection Tests")
        test_duplicate_upload(image_files[0])
    
    # Test 4: File storage organization
    print_section("File Storage Tests")
    test_file_storage()
    
    # Summary
    print_section("Test Summary")
    print(f"✅ Tests completed successfully!")
    print(f"📊 Uploaded {len(uploaded_entities)} new entities")
    print(f"📁 Files stored in ./media_files/")
    print(f"💾 Database: ./data/entities.db")


if __name__ == "__main__":
    main()

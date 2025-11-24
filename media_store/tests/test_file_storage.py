"""
Tests for file storage organization and management.
"""

from pathlib import Path


class TestFileStorage:
    """Test file storage organization."""
    
    def test_file_storage_structure(self, client, sample_image, clean_media_dir):
        """Test that files are stored in YYYY/MM/DD structure."""
        with open(sample_image, "rb") as f:
            response = client.post(
                "/entity/",
                files={"image": (sample_image.name, f, "image/jpeg")},
                data={"is_collection": "false", "label": "Storage test"}
            )
        
        assert response.status_code == 201
        
        # Find the stored file
        stored_files = list(clean_media_dir.rglob("*.jpg"))
        assert len(stored_files) == 1
        
        stored_file = stored_files[0]
        rel_path = stored_file.relative_to(clean_media_dir)
        parts = rel_path.parts
        
        # Should be YYYY/MM/DD/filename
        assert len(parts) == 4
        year, month, day, filename = parts
        
        # Verify format
        assert year.isdigit() and len(year) == 4
        assert month.isdigit() and 1 <= int(month) <= 12
        assert day.isdigit() and 1 <= int(day) <= 31
        
        # Filename should have MD5 prefix
        assert "_" in filename
        md5_prefix = filename.split("_")[0]
        assert len(md5_prefix) == 32  # MD5 hash length
    
    def test_md5_prefix_in_filename(self, client, sample_image, clean_media_dir):
        """Test that filenames are prefixed with MD5 hash."""
        with open(sample_image, "rb") as f:
            response = client.post(
                "/entity/",
                files={"image": (sample_image.name, f, "image/jpeg")},
                data={"is_collection": "false", "label": "MD5 test"}
            )
        
        assert response.status_code == 201
        data = response.json()
        md5_hash = data["md5"]
        
        # Find the stored file
        stored_files = list(clean_media_dir.rglob("*.jpg"))
        assert len(stored_files) == 1
        
        filename = stored_files[0].name
        assert filename.startswith(md5_hash)
        assert sample_image.name in filename
    
    def test_multiple_files_organization(self, client, sample_images, clean_media_dir):
        """Test that multiple files are organized correctly."""
        for image_path in sample_images:
            with open(image_path, "rb") as f:
                response = client.post(
                    "/entity/",
                    files={"image": (image_path.name, f, "image/jpeg")},
                    data={"is_collection": "false", "label": f"Test {image_path.name}"}
                )
            assert response.status_code == 201
        
        # All files should be stored
        stored_files = list(clean_media_dir.rglob("*.jpg"))
        assert len(stored_files) == len(sample_images)
        
        # All should follow YYYY/MM/DD structure
        for stored_file in stored_files:
            rel_path = stored_file.relative_to(clean_media_dir)
            assert len(rel_path.parts) == 4
    
    def test_file_deletion_on_entity_update(self, client, sample_images, clean_media_dir):
        """Test that old file is deleted when entity is updated with new file."""
        if len(sample_images) < 2:
            return  # Skip if not enough images
        
        image1, image2 = sample_images[0], sample_images[1]
        
        # Upload first image
        with open(image1, "rb") as f:
            response1 = client.post(
                "/entity/",
                files={"image": (image1.name, f, "image/jpeg")},
                data={"is_collection": "false", "label": "Original"}
            )
        
        assert response1.status_code == 201
        entity_id = response1.json()["id"]
        md5_1 = response1.json()["md5"]
        
        # Verify first file exists
        files_before = list(clean_media_dir.rglob("*.jpg"))
        assert len(files_before) == 1
        assert md5_1 in str(files_before[0])
        
        # Update with second image
        with open(image2, "rb") as f:
            response2 = client.put(
                f"/entity/{entity_id}",
                files={"image": (image2.name, f, "image/jpeg")},
                data={"is_collection": "false", "label": "Updated"}
            )
        
        assert response2.status_code == 200
        md5_2 = response2.json()["md5"]
        
        # Verify only second file exists
        files_after = list(clean_media_dir.rglob("*.jpg"))
        assert len(files_after) == 1
        assert md5_2 in str(files_after[0])
        assert md5_1 not in str(files_after[0])

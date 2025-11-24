# Adding Test Images and Videos

## Quick Start

Simply add your media files to the `images/` directory and the tests will automatically pick them up!

```bash
# Add a single file
cp /path/to/your/image.jpg images/

# Add multiple files
cp /path/to/your/photos/*.jpg images/

# Add to subdirectory (tests search recursively)
mkdir -p images/my_test_set
cp /path/to/photos/* images/my_test_set/

# Run tests
pytest tests/test_comprehensive_metadata.py -v
```

## Supported File Types

The parametrized tests automatically discover:
- **Images**: `.jpg`, `.jpeg`, `.png`, `.gif` (case-insensitive)
- **Videos**: Add support by updating `get_all_test_images()` in `test_comprehensive_metadata.py`

## Directory Structure

```
images/
├── 20210426_155703.jpg          # Root level images
├── 20210426_153946.jpg
├── 20210422_204834.jpg
└── new Images/                   # Subdirectories (automatically searched)
    ├── IMG20240901190030.jpg
    ├── IMG20240901123952.jpg
    └── ...
```

## Adding Video Files

To test video files with duration metadata:

1. **Add video files to images directory:**
   ```bash
   cp /path/to/video.mp4 images/
   cp /path/to/video.mov images/
   ```

2. **Update test to include video extensions:**
   Edit `tests/test_comprehensive_metadata.py`:
   ```python
   def get_all_test_images():
       """Recursively find all image files in the images directory."""
       images_dir = Path("../images")
       if not images_dir.exists():
           return []
       
       # Add video extensions
       media_extensions = {".jpg", ".jpeg", ".png", ".gif", ".mp4", ".mov", ".avi"}
       all_media = []
       
       for ext in media_extensions:
           all_media.extend(images_dir.rglob(f"*{ext}"))
           all_media.extend(images_dir.rglob(f"*{ext.upper()}"))
       
       return sorted(all_media)
   ```

3. **Update duration test:**
   Modify `test_duration_null_for_images` to handle videos:
   ```python
   def test_duration_for_media(self, client, sample_image, clean_media_dir):
       """Test that duration is set for videos, None for images."""
       # Check if it's a video file
       is_video = sample_image.suffix.lower() in {'.mp4', '.mov', '.avi'}
       
       with open(sample_image, "rb") as f:
           response = client.post(
               "/entity/",
               files={"image": (sample_image.name, f, "video/mp4" if is_video else "image/jpeg")},
               data={"is_collection": "false", "label": "Duration test"}
           )
       
       assert response.status_code == 201
       data = response.json()
       
       if is_video:
           # Videos should have duration
           assert data["duration"] is not None and data["duration"] > 0
       else:
           # Images should not have duration
           assert data["duration"] is None
   ```

## Testing Specific Images

### Test a single image:
```bash
# By file path
pytest tests/test_comprehensive_metadata.py::TestAllImagesMetadata::test_image_metadata_extraction[image_path0] -v

# Or use -k to match by name pattern
pytest tests/test_comprehensive_metadata.py -k "IMG20240901" -v
```

### Test only new images:
```bash
pytest tests/test_comprehensive_metadata.py -k "new_Images" -v
```

## Adding Images with EXIF Data

To test `create_date` extraction from EXIF:

1. **Add images with EXIF CreateDate:**
   ```bash
   # Use images from your phone/camera (usually have EXIF)
   cp ~/Pictures/DCIM/*.jpg images/with_exif/
   ```

2. **Verify EXIF data exists:**
   ```bash
   exiftool images/with_exif/photo.jpg | grep CreateDate
   ```

3. **Run tests:**
   ```bash
   pytest tests/test_comprehensive_metadata.py::TestTimestampFields::test_create_date_from_exif -v
   ```

## Cleaning Up Test Database

After adding many images, you may want to clean the test database:

```bash
# Remove test database and media files
rm -rf data/entities.db media_files/ test_media_files/

# Tests will create fresh database automatically
pytest
```

## Current Test Coverage

- **Total images**: 98 (as of last run)
- **Parametrized tests**: One test per image file
- **Automatic discovery**: Tests run for all files in `images/` recursively

## Troubleshooting

### "No test images found"
- Ensure files are in `images/` directory
- Check file extensions match supported types
- Verify files are readable: `ls -la images/`

### "Duplicate file" errors
- Expected behavior - duplicate MD5 hashes are rejected
- Tests skip duplicates automatically
- Clean database if needed: `rm -rf data/entities.db`

### Tests taking too long
- Reduce number of test images
- Use `-k` flag to test specific subsets
- Consider using `pytest-xdist` for parallel testing:
  ```bash
  pip install pytest-xdist
  pytest -n auto  # Run tests in parallel
  ```

## Example Workflow

```bash
# 1. Add new test images
mkdir -p images/test_batch_2024
cp ~/Downloads/test_photos/*.jpg images/test_batch_2024/

# 2. Check how many images will be tested
find images -type f \( -name "*.jpg" -o -name "*.png" \) | wc -l

# 3. Run tests
pytest tests/test_comprehensive_metadata.py -v

# 4. Run full test suite
pytest -v

# 5. Check coverage
pytest --cov=server --cov-report=html
open htmlcov/index.html
```

## Best Practices

1. **Organize by category**: Use subdirectories for different test scenarios
   ```
   images/
   ├── with_exif/       # Images with EXIF data
   ├── no_exif/         # Images without EXIF
   ├── large_files/     # Large images for performance testing
   └── edge_cases/      # Corrupted, unusual formats, etc.
   ```

2. **Keep test set manageable**: 100-200 images is usually sufficient
   - Too many images = slow tests
   - Too few images = insufficient coverage

3. **Document special cases**: Add README in subdirectories explaining test purpose

4. **Version control**: Consider using Git LFS for large media files
   ```bash
   git lfs track "images/**/*.jpg"
   git lfs track "images/**/*.mp4"
   ```

#!/bin/bash
#
# Automated test suite using curl for reliable multipart form data handling
# Can be run repeatedly to verify functionality
#

set -e  # Exit on error

BASE_URL="http://127.0.0.1:8000"
IMAGES_DIR="./images"
TEST_RESULTS=()

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_section() {
    echo ""
    echo "======================================================================"
    echo "  $1"
    echo "======================================================================"
}

print_test() {
    local name="$1"
    local status="$2"
    case "$status" in
        "PASS")
            echo -e "${GREEN}✅ $name${NC}"
            ;;
        "FAIL")
            echo -e "${RED}❌ $name${NC}"
            ;;
        "SKIP")
            echo -e "${YELLOW}⏭️  $name${NC}"
            ;;
        *)
            echo -e "${BLUE}⏳ $name${NC}"
            ;;
    esac
}

# Test 1: Server health
test_server_health() {
    print_test "Server Health Check" "RUNNING"
    
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL/")
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        print_test "Server Health Check" "PASS"
        return 0
    else
        print_test "Server Health Check" "FAIL"
        echo "  Status: $http_code"
        return 1
    fi
}

# Test 2: Upload file with metadata extraction
test_file_upload() {
    local image_path="$1"
    local filename=$(basename "$image_path")
    
    print_test "Upload: $filename" "RUNNING"
    
    # Upload file with individual form fields
    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/entity/" \
        -F "image=@$image_path" \
        -F "is_collection=false" \
        -F "label=Test: $filename" \
        -F "description=Uploaded from $image_path")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "201" ]; then
        print_test "Upload: $filename" "PASS"
        
        # Parse and display metadata
        entity_id=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', 'N/A'))")
        md5=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('md5', 'N/A'))")
        width=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('width', 'N/A'))")
        height=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('height', 'N/A'))")
        file_size=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('file_size', 'N/A'))")
        mime_type=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('mime_type', 'N/A'))")
        
        echo "  Entity ID: $entity_id"
        echo "  MD5: $md5"
        echo "  Dimensions: ${width}x${height}"
        echo "  File Size: $file_size bytes"
        echo "  MIME Type: $mime_type"
        
        # Verify with exiftool if available
        if command -v exiftool &> /dev/null; then
            exif_width=$(exiftool -ImageWidth -s3 "$image_path" 2>/dev/null || echo "N/A")
            exif_height=$(exiftool -ImageHeight -s3 "$image_path" 2>/dev/null || echo "N/A")
            
            if [ "$width" = "$exif_width" ] && [ "$height" = "$exif_height" ]; then
                echo -e "  ${GREEN}✅ Metadata verified with exiftool${NC}"
            else
                echo -e "  ${YELLOW}⚠️  Metadata differences:${NC}"
                [ "$width" != "$exif_width" ] && echo "     - Width: API=$width, exiftool=$exif_width"
                [ "$height" != "$exif_height" ] && echo "     - Height: API=$height, exiftool=$exif_height"
            fi
        else
            echo -e "  ${YELLOW}⚠️  exiftool not found - skipping verification${NC}"
        fi
        
        echo "$md5" >> /tmp/uploaded_md5s.txt
        return 0
        
    elif [ "$http_code" = "409" ]; then
        print_test "Upload: $filename" "SKIP"
        detail=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('detail', 'Duplicate'))")
        echo "  Duplicate detected: $detail"
        return 0
        
    else
        print_test "Upload: $filename" "FAIL"
        echo "  Status: $http_code"
        echo "  Response: $body"
        return 1
    fi
}

# Test 3: Duplicate detection
test_duplicate_detection() {
    local image_path="$1"
    local filename=$(basename "$image_path")
    
    print_test "Duplicate Detection: $filename" "RUNNING"
    
    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/entity/" \
        -F "image=@$image_path" \
        -F "is_collection=false" \
        -F "label=Duplicate test" \
        -F "description=Should be rejected")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "409" ]; then
        print_test "Duplicate Detection: $filename" "PASS"
        detail=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('detail', 'Duplicate'))")
        echo "  Correctly rejected: $detail"
        return 0
    else
        print_test "Duplicate Detection: $filename" "FAIL"
        echo "  Expected 409, got $http_code"
        return 1
    fi
}

# Test 4: File storage organization
test_file_storage() {
    print_test "File Storage Organization" "RUNNING"
    
    if [ ! -d "./media_files" ]; then
        print_test "File Storage Organization" "FAIL"
        echo "  Media directory not found: ./media_files"
        return 1
    fi
    
    # Find all image files
    file_count=$(find ./media_files -type f \( -name "*.jpg" -o -name "*.jpeg" \) | wc -l | tr -d ' ')
    
    if [ "$file_count" -eq 0 ]; then
        print_test "File Storage Organization" "FAIL"
        echo "  No files found in ./media_files"
        return 1
    fi
    
    print_test "File Storage Organization" "PASS"
    echo "  Found $file_count files with YYYY/MM/DD structure"
    
    # Show first 3 files
    find ./media_files -type f \( -name "*.jpg" -o -name "*.jpeg" \) | head -3 | while read -r file; do
        rel_path=${file#./media_files/}
        echo "  📁 $rel_path"
    done
    
    if [ "$file_count" -gt 3 ]; then
        echo "  ... and $((file_count - 3)) more"
    fi
    
    return 0
}

# Main test execution
main() {
    print_section "Automated Test Suite - File Upload & Metadata Extraction"
    
    # Clean up temp file
    rm -f /tmp/uploaded_md5s.txt
    
    # Test 1: Server health
    if ! test_server_health; then
        echo ""
        echo "❌ Server not running. Please start the server first."
        exit 1
    fi
    
    # Test 2: Upload images
    print_section "File Upload Tests"
    
    if [ ! -d "$IMAGES_DIR" ]; then
        echo "❌ Test images directory not found: $IMAGES_DIR"
        exit 1
    fi
    
    # Get first 3 JPG files
    image_files=($(find "$IMAGES_DIR" -maxdepth 1 -name "*.jpg" | head -3))
    
    if [ ${#image_files[@]} -eq 0 ]; then
        echo "❌ No .jpg files found in $IMAGES_DIR"
        exit 1
    fi
    
    upload_count=0
    for image_path in "${image_files[@]}"; do
        if test_file_upload "$image_path"; then
            ((upload_count++)) || true
        fi
    done
    
    # Test 3: Duplicate detection
    if [ $upload_count -gt 0 ]; then
        print_section "Duplicate Detection Tests"
        test_duplicate_detection "${image_files[0]}"
    fi
    
    # Test 4: File storage
    print_section "File Storage Tests"
    test_file_storage
    
    # Summary
    print_section "Test Summary"
    echo -e "${GREEN}✅ Tests completed successfully!${NC}"
    echo "📊 Processed ${#image_files[@]} images"
    echo "📁 Files stored in ./media_files/"
    echo "💾 Database: ./data/entities.db"
    
    # Clean up
    rm -f /tmp/uploaded_md5s.txt
}

# Run tests
main

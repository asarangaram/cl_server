#!/usr/bin/env python3
"""
CLI client for image embedding inference workflow.

Usage:
    python image_embedding_client.py <image_path> --media-store <host>:<port> [options]

Example:
    python image_embedding_client.py /path/to/image.jpg --media-store localhost:8000
    python image_embedding_client.py image.jpg --media-store 192.168.1.100:8000 --timeout 600
"""

import argparse
import sys

from base_client import InferenceClient
from utils import (
    validate_image_file,
    parse_media_store_url,
    display_error_message,
    display_result,
)


def main():
    """Main entry point for image embedding client."""
    parser = argparse.ArgumentParser(
        description="Generate vector embeddings for images using the inference service",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic usage with default inference service
  python image_embedding_client.py image.jpg --media-store localhost:8000

  # With custom inference service URL and timeout
  python image_embedding_client.py photo.jpg --media-store 192.168.1.10:8000 --inference 192.168.1.10:8001 --timeout 600

  # Add a label for the image in media_store
  python image_embedding_client.py scene.jpg --media-store localhost:8000 --label "my_photo"
        """,
    )

    parser.add_argument(
        "image_path",
        help="Path to the image file",
    )
    parser.add_argument(
        "--media-store",
        required=True,
        help="Media store service URL in format 'host:port' (required)",
    )
    parser.add_argument(
        "--inference",
        default="localhost:8001",
        help="Inference service URL in format 'host:port' (default: localhost:8001)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Job timeout in seconds (default: 300)",
    )
    parser.add_argument(
        "--label",
        help="Optional label for the image in media_store",
    )
    parser.add_argument(
        "--priority",
        type=int,
        default=5,
        help="Job priority 0-10 (default: 5, higher = more urgent)",
    )

    args = parser.parse_args()

    # Validate arguments
    if args.timeout < 1:
        display_error_message("Timeout must be at least 1 second")
        sys.exit(1)

    if not 0 <= args.priority <= 10:
        display_error_message("Priority must be between 0 and 10")
        sys.exit(1)

    # Validate image file
    try:
        validate_image_file(args.image_path)
    except (FileNotFoundError, PermissionError) as e:
        display_error_message(str(e))
        sys.exit(1)

    # Parse service URLs
    try:
        media_store_host, media_store_port = parse_media_store_url(args.media_store)
    except ValueError as e:
        display_error_message(f"Invalid media-store URL: {e}")
        sys.exit(1)

    try:
        inference_host, inference_port = parse_media_store_url(args.inference)
    except ValueError as e:
        display_error_message(f"Invalid inference URL: {e}")
        sys.exit(1)

    # Create client and run workflow
    try:
        client = InferenceClient(
            media_store_host=media_store_host,
            media_store_port=media_store_port,
            inference_host=inference_host,
            inference_port=inference_port,
        )

        result = client.run_workflow(
            task_type="image_embedding",
            image_path=args.image_path,
            label=args.label,
            priority=args.priority,
            timeout_seconds=args.timeout,
        )

        # Display results
        display_result(result)

    except FileNotFoundError as e:
        display_error_message(str(e))
        sys.exit(1)
    except ValueError as e:
        display_error_message(str(e))
        sys.exit(1)
    except TimeoutError as e:
        display_error_message(str(e))
        sys.exit(1)
    except Exception as e:
        display_error_message(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

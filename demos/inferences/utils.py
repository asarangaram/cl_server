"""
Utility functions for inference CLI clients.
"""

import json
import os


def format_json_output(data: dict, indent: int = 2) -> str:
    """
    Format a dictionary as pretty-printed JSON.

    Args:
        data: Dictionary to format
        indent: Indentation level

    Returns:
        Pretty-printed JSON string
    """
    return json.dumps(data, indent=indent)


def validate_image_file(file_path: str) -> bool:
    """
    Validate that an image file exists and is readable.

    Args:
        file_path: Path to the image file

    Returns:
        True if file exists and is readable

    Raises:
        FileNotFoundError: If file does not exist
        PermissionError: If file is not readable
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Image file not found: {file_path}")

    if not os.path.isfile(file_path):
        raise FileNotFoundError(f"Path is not a file: {file_path}")

    if not os.access(file_path, os.R_OK):
        raise PermissionError(f"File is not readable: {file_path}")

    return True


def read_image_file(file_path: str) -> bytes:
    """
    Read an image file as binary data.

    Args:
        file_path: Path to the image file

    Returns:
        Binary image data
    """
    with open(file_path, 'rb') as f:
        return f.read()


def construct_url(host: str, port: int, path: str = "") -> str:
    """
    Construct a URL from host, port, and optional path.

    Args:
        host: Hostname or IP
        port: Port number
        path: Optional path (should start with /)

    Returns:
        Constructed URL
    """
    base_url = f"http://{host}:{port}"
    if path:
        return base_url + path
    return base_url


def parse_media_store_url(url_string: str) -> tuple:
    """
    Parse a media store URL string in format "host:port".

    Args:
        url_string: URL string like "localhost:8000"

    Returns:
        Tuple of (host, port)

    Raises:
        ValueError: If URL format is invalid
    """
    if ':' not in url_string:
        raise ValueError(f"Invalid media store URL format: {url_string}. Expected 'host:port'")

    parts = url_string.split(':')
    if len(parts) != 2:
        raise ValueError(f"Invalid media store URL format: {url_string}. Expected 'host:port'")

    host = parts[0].strip()
    try:
        port = int(parts[1].strip())
    except ValueError:
        raise ValueError(f"Port must be an integer: {parts[1]}")

    if not host:
        raise ValueError("Host cannot be empty")

    if port < 1 or port > 65535:
        raise ValueError(f"Port must be between 1 and 65535: {port}")

    return host, port


def display_progress_message(message: str) -> None:
    """
    Display a progress message to the user.

    Args:
        message: Message to display
    """
    print(f"[*] {message}")


def display_success_message(message: str) -> None:
    """
    Display a success message to the user.

    Args:
        message: Message to display
    """
    print(f"[✓] {message}")


def display_error_message(message: str) -> None:
    """
    Display an error message to the user.

    Args:
        message: Message to display
    """
    print(f"[✗] Error: {message}")


def display_result(result: dict) -> None:
    """
    Display job results in formatted JSON.

    Args:
        result: Job result dictionary
    """
    print("\n[Result] Job completed successfully:\n")
    print(format_json_output(result))

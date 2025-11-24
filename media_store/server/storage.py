from __future__ import annotations

from datetime import datetime
from typing import Dict

# DEPRECATED: This module is deprecated. Use the service layer instead.
# Utility functions are kept for backward compatibility.


def _now_iso() -> str:
    """
    Return current UTC time in ISO-8601 format.
    
    DEPRECATED: Use EntityService._now_iso() instead.
    """
    return datetime.utcnow().isoformat() + "Z"


def _fake_file_metadata(file_bytes: bytes) -> Dict[str, int]:
    """
    Return dummy file metadata – size, dummy dimensions.
    
    DEPRECATED: Use EntityService._fake_file_metadata() instead.
    """
    return {"size": len(file_bytes), "height": 100, "width": 100}


__all__ = ["_now_iso", "_fake_file_metadata"]

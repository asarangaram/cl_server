"""Authentication and authorization utilities."""

from __future__ import annotations

import os
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security.http import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from .config import AUTH_DISABLED, PUBLIC_KEY_PATH

security = HTTPBearer()


def load_public_key() -> Optional[str]:
    """Load public key for JWT verification."""
    if AUTH_DISABLED:
        return None

    if not os.path.exists(PUBLIC_KEY_PATH):
        raise FileNotFoundError(f"Public key not found at {PUBLIC_KEY_PATH}")

    with open(PUBLIC_KEY_PATH, "r") as f:
        return f.read()


# Load public key at module level
try:
    PUBLIC_KEY = load_public_key()
except FileNotFoundError as e:
    if not AUTH_DISABLED:
        print(f"Warning: {e}. Authentication will fail unless AUTH_DISABLED=true")
    PUBLIC_KEY = None


def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """
    Verify JWT token and return payload.

    Args:
        credentials: HTTP Bearer credentials

    Returns:
        JWT payload dict

    Raises:
        HTTPException: If token is invalid or expired
    """
    if AUTH_DISABLED:
        # Demo mode: return mock payload
        return {
            "sub": "demo_user",
            "permissions": ["ai_inference_support"],
            "is_admin": False,
        }

    if PUBLIC_KEY is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication not configured properly",
        )

    try:
        payload = jwt.decode(credentials.credentials, PUBLIC_KEY, algorithms=["ES256"])
        return payload
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        ) from e


def require_permission(permission: str):
    """
    Dependency to check for specific permission.

    Args:
        permission: Required permission name

    Returns:
        Function that checks permission
    """

    def check_permission(payload: dict = Depends(verify_token)) -> dict:
        # Admin bypass
        if payload.get("is_admin", False):
            return payload

        # Check permission
        permissions = payload.get("permissions", [])
        if permission not in permissions:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Missing required permission: {permission}",
            )

        return payload

    return check_permission


def require_admin(payload: dict = Depends(verify_token)) -> dict:
    """
    Dependency to require admin access.

    Args:
        payload: JWT payload from verify_token

    Returns:
        JWT payload if user is admin

    Raises:
        HTTPException: If user is not admin
    """
    if not payload.get("is_admin", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return payload


__all__ = ["verify_token", "require_permission", "require_admin"]

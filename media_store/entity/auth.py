from __future__ import annotations

import os
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

from .config import PUBLIC_KEY_PATH, AUTH_DISABLED, READ_AUTH_ENABLED

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token", auto_error=False)

def get_public_key() -> str:
    """Load the public key from file.
    
    Raises HTTPException only if the file doesn't exist when actually needed.
    """
    if not os.path.exists(PUBLIC_KEY_PATH):
        # Return empty string if file doesn't exist - will fail later if token validation is attempted
        return ""
    with open(PUBLIC_KEY_PATH, "r") as f:
        return f.read()

async def get_current_user(token: Optional[str] = Depends(oauth2_scheme)) -> Optional[dict]:
    """Validate the JWT and return the user payload.
    
    Returns None if AUTH_DISABLED is True (demo mode).
    Returns None if token is not provided and auto_error is False.
    """
    # Demo mode: bypass authentication
    if AUTH_DISABLED:
        return None
    
    # No token provided
    if token is None:
        return None
    
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    public_key = get_public_key()
    
    # If public key is not available, reject the token
    if not public_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Public key not found. Authentication service might not be initialized."
        )
    
    try:
        payload = jwt.decode(token, public_key, algorithms=["ES256"])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        return payload
    except JWTError:
        raise credentials_exception

async def get_current_user_with_write_permission(
    current_user: Optional[dict] = Depends(get_current_user)
) -> Optional[dict]:
    """Validate that the user has write permissions.
    
    In demo mode (AUTH_DISABLED=True), always allows access.
    Otherwise, requires valid token with media_store_write permission or admin status.
    """
    # Demo mode: bypass permission check
    if AUTH_DISABLED:
        return None
    
    # Authentication required but no user provided
    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    permissions = current_user.get("permissions", [])
    if "media_store_write" not in permissions and not current_user.get("is_admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )
    return current_user

async def get_current_user_with_read_permission(
    current_user: Optional[dict] = Depends(get_current_user)
) -> Optional[dict]:
    """Validate that the user has read permissions.
    
    In demo mode (AUTH_DISABLED=True), always allows access.
    If READ_AUTH_ENABLED=False, allows access without authentication.
    If READ_AUTH_ENABLED=True, requires valid token with media_store_read permission or admin status.
    """
    # Demo mode: bypass permission check
    if AUTH_DISABLED:
        return None
    
    # Read auth not enabled: allow access
    if not READ_AUTH_ENABLED:
        return current_user  # May be None, but that's okay
    
    # Read auth enabled but no user provided
    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    permissions = current_user.get("permissions", [])
    if "media_store_read" not in permissions and not current_user.get("is_admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )
    return current_user


from __future__ import annotations

import os
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

from .config import PUBLIC_KEY_PATH

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")

def get_public_key() -> str:
    """Load the public key from file."""
    if not os.path.exists(PUBLIC_KEY_PATH):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Public key not found. Authentication service might not be initialized."
        )
    with open(PUBLIC_KEY_PATH, "r") as f:
        return f.read()

async def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    """Validate the JWT and return the user payload."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    public_key = get_public_key()
    
    try:
        payload = jwt.decode(token, public_key, algorithms=["ES256"])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        return payload
    except JWTError:
        raise credentials_exception

async def get_current_user_with_write_permission(
    current_user: dict = Depends(get_current_user)
) -> dict:
    """Validate that the user has write permissions."""
    permissions = current_user.get("permissions", [])
    if "media_store_write" not in permissions and not current_user.get("is_admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )
    return current_user

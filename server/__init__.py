from fastapi import FastAPI, HTTPException

from .database import init_db
from .routes import router

app = FastAPI(title="CoLAN server", version="v1")


@app.on_event("startup")
async def startup_event():
    """Initialize database on application startup."""
    init_db()


@app.exception_handler(HTTPException)
async def validation_exception_handler(request, exc):
    """
    Preserve the default FastAPI HTTPException handling shape so callers
    get the usual FastAPI response body. Kept here so you can customize it later.
    """
    return await app.default_exception_handler(request, exc)


app.include_router(router)

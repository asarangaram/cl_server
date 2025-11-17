from typing import Dict, Optional

from pydantic import BaseModel, Field


class Error(BaseModel):
    code: Optional[int] = Field(None, description="Error code")
    status: Optional[str] = Field(None, description="Error name")
    message: Optional[str] = Field(None, description="Error message")
    errors: Optional[Dict] = Field(None, description="Errors")


class PaginationMetadata(BaseModel):
    total: Optional[int] = None
    total_pages: Optional[int] = None
    first_page: Optional[int] = None
    last_page: Optional[int] = None
    page: Optional[int] = None
    previous_page: Optional[int] = None
    next_page: Optional[int] = None


class LandingPageResult(BaseModel):
    name: str
    info: str
    id: int
    status: Optional[str] = Field(None, readOnly=True)


class Item(BaseModel):
    id: Optional[int] = Field(None, readOnly=True)
    is_collection: Optional[bool] = None
    label: Optional[str] = None
    description: Optional[str] = None
    parent_id: Optional[int] = None
    added_date: Optional[str] = Field(None, readOnly=True)
    updated_date: Optional[str] = Field(None, readOnly=True)
    is_deleted: Optional[bool] = None
    create_date: Optional[str] = Field(None, readOnly=True)
    file_size: Optional[int] = Field(None, readOnly=True)
    height: Optional[int] = Field(None, readOnly=True)
    width: Optional[int] = Field(None, readOnly=True)
    duration: Optional[float] = Field(None, readOnly=True)
    mime_type: Optional[str] = Field(None, readOnly=True)
    type: Optional[str] = Field(None, readOnly=True)
    extension: Optional[str] = Field(None, readOnly=True)
    md5: Optional[str] = Field(None, readOnly=True)


class UploadResponse(BaseModel):
    file_identifier: Optional[str] = Field(None, readOnly=True)
    status: Optional[str] = Field(None, readOnly=True)
    mimeType: Optional[str] = Field(None, readOnly=True)
    createDate: Optional[str] = Field(None, readOnly=True)
    fileSize: Optional[int] = Field(None, readOnly=True)
    height: Optional[int] = Field(None, readOnly=True)
    width: Optional[int] = Field(None, readOnly=True)
    duration: Optional[float] = Field(None, readOnly=True)
    type: Optional[str] = Field(None, readOnly=True)
    extension: Optional[str] = Field(None, readOnly=True)
    md5: Optional[str] = Field(None, readOnly=True)


class BGTask(BaseModel):
    media_id: Optional[str] = None
    task_name: Optional[str] = None
    task_id: Optional[str] = None
    task_status: Optional[str] = None

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


class BodyCreateEntity(BaseModel):
    label: Optional[str] = Field(None, title="Label")
    description: Optional[str] = Field(None, title="Description")
    parent_id: Optional[int] = Field(None, title="Parent Id")
    is_collection: bool = Field(..., title="Is Collection")
    # image is part of the multipart body – handled separately


class BodyUpdateEntity(BaseModel):
    label: Optional[str] = Field(None, title="Label")
    description: Optional[str] = Field(None, title="Description")
    parent_id: Optional[int] = Field(None, title="Parent Id")
    is_collection: bool = Field(..., title="Is Collection")
    # image is part of the multipart body – handled separately


class BodyPatchEntity(BaseModel):
    label: Optional[str] = Field(None, title="Label")
    description: Optional[str] = Field(None, title="Description")
    parent_id: Optional[int] = Field(None, title="Parent Id")
    is_deleted: Optional[bool] = Field(None, title="Is Deleted")


class Item(BaseModel):
    id: Optional[int] = Field(None, title="Id", read_only=True)
    is_collection: Optional[bool] = Field(None, title="Is Collection")
    label: Optional[str] = Field(None, title="Label")
    description: Optional[str] = Field(None, title="Description")
    parent_id: Optional[int] = Field(None, title="Parent Id")
    added_date: Optional[str] = Field(None, title="Added Date", read_only=True)
    updated_date: Optional[str] = Field(None, title="Updated Date", read_only=True)
    is_deleted: Optional[bool] = Field(None, title="Is Deleted")
    create_date: Optional[str] = Field(None, title="Create Date", read_only=True)
    file_size: Optional[int] = Field(None, title="File Size", read_only=True)
    height: Optional[int] = Field(None, title="Height", read_only=True)
    width: Optional[int] = Field(None, title="Width", read_only=True)
    duration: Optional[float] = Field(None, title="Duration", read_only=True)
    mime_type: Optional[str] = Field(None, title="Mime Type", read_only=True)
    type: Optional[str] = Field(None, title="Type", read_only=True)
    extension: Optional[str] = Field(None, title="Extension", read_only=True)
    md5: Optional[str] = Field(None, title="Md5", read_only=True)

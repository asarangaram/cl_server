from __future__ import annotations

from typing import List, Optional

from fastapi import (
    APIRouter,
    Body,
    Depends,
    File,
    Form,
    HTTPException,
    Path,
    Query,
    UploadFile,
    status,
)
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from schemas import BodyCreateEntity, BodyPatchEntity, BodyUpdateEntity, Item

from .database import get_db
from .services.entity_service import DuplicateFileError
from .services import EntityService

router = APIRouter()


@router.get(
    "/entity/",
    tags=["entity"],
    summary="Get Entities",
    description="Retrieves a paginated list of media entities.",
    operation_id="get_entities_entity__get",
    responses={200: {"model": List[Item], "description": "Successful Response"}},
)
async def get_entities(
    filter_param: Optional[str] = Query(
        None, title="Filter Param", description="Optional filter string"
    ),
    search_query: Optional[str] = Query(
        None, title="Search Query", description="Optional search query"
    ),
    db: Session = Depends(get_db),
) -> List[Item]:
    service = EntityService(db)
    return service.get_entities(filter_param, search_query)


@router.post(
    "/entity/",
    tags=["entity"],
    summary="Create Entity",
    description="Creates a new entity.",
    operation_id="create_entity_entity__post",
    status_code=status.HTTP_201_CREATED,
    responses={201: {"model": Item, "description": "Successful Response"}},
)
async def create_entity(
    is_collection: bool = Form(..., title="Is Collection"),
    label: Optional[str] = Form(None, title="Label"),
    description: Optional[str] = Form(None, title="Description"),
    parent_id: Optional[int] = Form(None, title="Parent Id"),
    image: Optional[UploadFile] = File(None, title="Image"),
    db: Session = Depends(get_db),
) -> Item:
    service = EntityService(db)
    
    # Create body object from form fields
    body = BodyCreateEntity(
        is_collection=is_collection,
        label=label,
        description=description,
        parent_id=parent_id
    )
    
    # Read file bytes and filename if provided
    file_bytes = None
    filename = "file"
    if image:
        file_bytes = await image.read()
        filename = image.filename or "file"
    
    try:
        return service.create_entity(body, file_bytes, filename)
    except DuplicateFileError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))


@router.delete(
    "/entity/",
    tags=["entity"],
    summary="Delete Collection",
    description="Deletes the entire collection.",
    operation_id="delete_collection_entity__delete",
    responses={200: {"model": None, "description": "Successful Response"}},
)
async def delete_collection(db: Session = Depends(get_db)) -> JSONResponse:
    service = EntityService(db)
    service.delete_all_entities()
    return JSONResponse(content=None, status_code=status.HTTP_200_OK)


@router.get(
    "/entity/{entity_id}",
    tags=["entity"],
    summary="Get Entity",
    description="Retrieves a specific media entity by its ID.",
    operation_id="get_entity_entity__entity_id__get",
    responses={200: {"model": Item, "description": "Successful Response"}},
)
async def get_entity(
    entity_id: int = Path(..., title="Entity Id"),
    content: Optional[str] = Query(
        None, title="Content", description="Optional content query"
    ),
    db: Session = Depends(get_db),
) -> Item:
    service = EntityService(db)
    item = service.get_entity_by_id(entity_id)
    if not item:
        raise HTTPException(status_code=404, detail="Entity not found")
    return item


@router.put(
    "/entity/{entity_id}",
    tags=["entity"],
    summary="Put Entity",
    description="Update an existing entity.",
    operation_id="put_entity_entity__entity_id__put",
    responses={200: {"model": Item, "description": "Successful Response"}},
)
async def put_entity(
    entity_id: int = Path(..., title="Entity Id"),
    is_collection: bool = Form(..., title="Is Collection"),
    label: Optional[str] = Form(None, title="Label"),
    description: Optional[str] = Form(None, title="Description"),
    parent_id: Optional[int] = Form(None, title="Parent Id"),
    image: UploadFile = File(..., title="Image"),
    db: Session = Depends(get_db),
) -> Item:
    service = EntityService(db)
    
    # Create body object from form fields
    body = BodyUpdateEntity(
        is_collection=is_collection,
        label=label,
        description=description,
        parent_id=parent_id
    )
    
    # Read file bytes and filename (mandatory for PUT)
    file_bytes = await image.read()
    filename = image.filename or "file"
    
    try:
        item = service.update_entity(entity_id, body, file_bytes, filename)
        if not item:
            raise HTTPException(status_code=404, detail="Entity not found")
        return item
    except DuplicateFileError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))


@router.patch(
    "/entity/{entity_id}",
    tags=["entity"],
    summary="Patch Entity",
    description="Patch an existing entity.",
    operation_id="patch_entity_entity__entity_id__patch",
    responses={200: {"model": Item, "description": "Successful Response"}},
)
async def patch_entity(
    entity_id: int = Path(..., title="Entity Id"),
    body: BodyPatchEntity = Body(..., embed=True),
    db: Session = Depends(get_db),
) -> Item:
    service = EntityService(db)
    item = service.patch_entity(entity_id, body)
    if not item:
        raise HTTPException(status_code=404, detail="Entity not found")
    return item


@router.delete(
    "/entity/{entity_id}",
    tags=["entity"],
    summary="Delete Entity",
    description="Deletes a specific entity by ID.",
    operation_id="delete_entity_entity__entity_id__delete",
    responses={200: {"model": None, "description": "Successful Response"}},
)
async def delete_entity(
    entity_id: int = Path(..., title="Entity Id"),
    db: Session = Depends(get_db),
) -> JSONResponse:
    service = EntityService(db)
    item = service.delete_entity(entity_id)
    if not item:
        raise HTTPException(status_code=404, detail="Entity not found")
    return JSONResponse(content=None, status_code=status.HTTP_200_OK)


@router.get(
    "/",
    tags=[],
    summary="Root",
    description="Returns a simple welcome string",
    operation_id="root_get",
    responses={200: {"description": "Welcome to CoLAN"}},
)
async def root() -> JSONResponse:
    return JSONResponse(content={"message": "Welcome to CoLAN!"})

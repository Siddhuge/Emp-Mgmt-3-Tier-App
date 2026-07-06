"""Department business logic."""
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.department import Department
from app.repository import department_repository
from app.schemas.department import DepartmentCreate


def list_departments(db: Session) -> list[Department]:
    return department_repository.list_all(db)


def create_department(db: Session, data: DepartmentCreate) -> Department:
    if department_repository.get_by_name(db, data.name):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Department '{data.name}' already exists",
        )
    return department_repository.create(db, data)

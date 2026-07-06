"""Employee routes."""
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user, require_roles
from app.database import get_db
from app.models.user import UserRole
from app.schemas.employee import EmployeeCreate, EmployeeOut, EmployeeUpdate
from app.services import employee_service

router = APIRouter(prefix="/api/employees", tags=["employees"])

# Admins and Managers may modify employees; everyone authenticated can read.
_manage = require_roles(UserRole.ADMIN, UserRole.MANAGER)


@router.get("", response_model=list[EmployeeOut])
def list_employees(
    search: str | None = Query(default=None, description="Search by name/email/designation"),
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
) -> list:
    return employee_service.list_employees(db, search)


@router.post("", response_model=EmployeeOut, status_code=status.HTTP_201_CREATED)
def create_employee(
    payload: EmployeeCreate,
    db: Session = Depends(get_db),
    _=Depends(_manage),
):
    return employee_service.create_employee(db, payload)


@router.put("/{employee_id}", response_model=EmployeeOut)
def update_employee(
    employee_id: int,
    payload: EmployeeUpdate,
    db: Session = Depends(get_db),
    _=Depends(_manage),
):
    return employee_service.update_employee(db, employee_id, payload)


@router.delete("/{employee_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_employee(
    employee_id: int,
    db: Session = Depends(get_db),
    _=Depends(require_roles(UserRole.ADMIN)),
) -> None:
    employee_service.delete_employee(db, employee_id)

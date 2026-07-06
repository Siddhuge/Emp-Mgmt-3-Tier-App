"""Employee business logic."""
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.employee import Employee
from app.repository import department_repository, employee_repository
from app.schemas.employee import EmployeeCreate, EmployeeUpdate


def _validate_department(db: Session, department_id: int | None) -> None:
    if department_id is not None and not department_repository.get_by_id(db, department_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Department {department_id} does not exist",
        )


def list_employees(db: Session, search: str | None = None) -> list[Employee]:
    return employee_repository.list_all(db, search)


def get_employee(db: Session, employee_id: int) -> Employee:
    employee = employee_repository.get_by_id(db, employee_id)
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Employee {employee_id} not found",
        )
    return employee


def create_employee(db: Session, data: EmployeeCreate) -> Employee:
    if employee_repository.get_by_email(db, data.email):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"An employee with email '{data.email}' already exists",
        )
    _validate_department(db, data.department_id)
    employee = Employee(**data.model_dump())
    return employee_repository.create(db, employee)


def update_employee(db: Session, employee_id: int, data: EmployeeUpdate) -> Employee:
    employee = get_employee(db, employee_id)
    updates = data.model_dump(exclude_unset=True)

    new_email = updates.get("email")
    if new_email and new_email != employee.email:
        existing = employee_repository.get_by_email(db, new_email)
        if existing and existing.id != employee_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"An employee with email '{new_email}' already exists",
            )

    if "department_id" in updates:
        _validate_department(db, updates["department_id"])

    for field, value in updates.items():
        setattr(employee, field, value)
    return employee_repository.save(db, employee)


def delete_employee(db: Session, employee_id: int) -> None:
    employee = get_employee(db, employee_id)
    employee_repository.delete(db, employee)

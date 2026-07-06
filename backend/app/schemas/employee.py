"""Employee schemas."""
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.schemas.department import DepartmentOut


class EmployeeBase(BaseModel):
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    email: EmailStr
    designation: str | None = Field(default=None, max_length=150)
    salary: float | None = Field(default=None, ge=0)
    is_active: bool = True
    department_id: int | None = None


class EmployeeCreate(EmployeeBase):
    pass


class EmployeeUpdate(BaseModel):
    first_name: str | None = Field(default=None, min_length=1, max_length=100)
    last_name: str | None = Field(default=None, min_length=1, max_length=100)
    email: EmailStr | None = None
    designation: str | None = Field(default=None, max_length=150)
    salary: float | None = Field(default=None, ge=0)
    is_active: bool | None = None
    department_id: int | None = None


class EmployeeOut(EmployeeBase):
    id: int
    created_at: datetime
    department: DepartmentOut | None = None

    model_config = {"from_attributes": True}

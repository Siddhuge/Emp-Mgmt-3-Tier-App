"""Department schemas."""
from pydantic import BaseModel, Field


class DepartmentBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)
    manager: str | None = Field(default=None, max_length=150)


class DepartmentCreate(DepartmentBase):
    pass


class DepartmentOut(DepartmentBase):
    id: int

    model_config = {"from_attributes": True}

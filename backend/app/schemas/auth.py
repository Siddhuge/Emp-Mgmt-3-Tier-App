"""Authentication-related schemas."""
from pydantic import BaseModel

from app.models.user import UserRole


class LoginRequest(BaseModel):
    username: str
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: int
    username: str
    role: UserRole

    model_config = {"from_attributes": True}


class MessageResponse(BaseModel):
    message: str

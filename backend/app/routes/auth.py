"""Authentication routes."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.auth import LoginRequest, MessageResponse, Token, UserOut
from app.services import auth_service

router = APIRouter(prefix="/api", tags=["auth"])


@router.post("/login", response_model=Token)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> Token:
    token = auth_service.login(db, payload.username, payload.password)
    return Token(access_token=token)


@router.post("/logout", response_model=MessageResponse)
def logout(_: User = Depends(get_current_user)) -> MessageResponse:
    # JWT is stateless; logout is handled client-side by discarding the token.
    return MessageResponse(message="Successfully logged out")


@router.get("/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user)) -> User:
    return current_user

"""Authentication business logic."""
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.auth.security import create_access_token, verify_password
from app.models.user import User
from app.repository import user_repository


def authenticate(db: Session, username: str, password: str) -> User:
    user = user_repository.get_by_username(db, username)
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )
    return user


def login(db: Session, username: str, password: str) -> str:
    user = authenticate(db, username, password)
    return create_access_token(subject=user.username, role=user.role.value)

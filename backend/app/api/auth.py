from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.security import CurrentUser, get_current_user
from app.core.supabase import get_public_supabase


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)


class LoginRequest(BaseModel):
    email: str
    password: str


@router.post("/login")
def login(data: LoginRequest):
    supabase = get_public_supabase()

    try:
        response = supabase.auth.sign_in_with_password(
            {
                "email": data.email,
                "password": data.password,
            }
        )

        if response.session is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Login failed",
            )

        return {
            "access_token": response.session.access_token,
            "refresh_token": response.session.refresh_token,
            "token_type": "bearer",
            "user": {
                "id": str(response.user.id),
                "email": response.user.email,
            },
        }

    except HTTPException:
        raise

    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )


@router.get("/me")
def get_me(
    user: CurrentUser = Depends(get_current_user),
):
    return {
        "authenticated": True,
        "user": user.model_dump(),
    }
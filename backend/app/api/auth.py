import httpx

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.config import get_settings
from app.core.security import CurrentUser, get_access_token, get_current_user
from app.core.supabase import get_public_supabase

settings = get_settings()


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)


class LoginRequest(BaseModel):
    email: str
    password: str

class ProfileUpdate(BaseModel):
    full_name: str | None = None
    phone: str | None = None


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

@router.patch("/me")
def update_me(
    data: ProfileUpdate,
    user: CurrentUser = Depends(get_current_user),
    token: str = Depends(get_access_token),
):
    updates = {}

    if data.full_name is not None:
        full_name = data.full_name.strip()

        if not full_name:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Full name cannot be empty",
            )

        updates["full_name"] = full_name

    if data.phone is not None:
        phone = data.phone.strip()
        updates["phone"] = phone if phone else None

    if not updates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No profile fields were provided",
        )

    response = httpx.patch(
        f"{settings.supabase_url}/rest/v1/profiles",
        headers={
            "apikey": settings.supabase_publishable_key,
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Prefer": "return=representation",
        },
        params={
            "id": f"eq.{user.id}",
        },
        json=updates,
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=response.status_code,
            detail="Could not update profile",
        )

    updated_profiles = response.json()

    if not updated_profiles:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )

    updated_profile = updated_profiles[0]

    return {
        "message": "Profile updated successfully",
        "user": {
            "id": str(user.id),
            "email": user.email,
            "full_name": updated_profile.get("full_name"),
            "phone": updated_profile.get("phone"),
            "role": updated_profile.get("role"),
        },
    }
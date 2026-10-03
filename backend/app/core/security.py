from typing import Optional

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

from app.core.config import get_settings
from app.core.supabase import get_public_supabase


bearer_scheme = HTTPBearer(auto_error=False)
settings = get_settings()


class CurrentUser(BaseModel):
    id: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    phone: Optional[str] = None
    role: str


def get_access_token(
    credentials: HTTPAuthorizationCredentials = Depends(
        bearer_scheme
    ),
) -> str:

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return credentials.credentials


def get_current_user(
    token: str = Depends(get_access_token),
) -> CurrentUser:

    try:
        supabase = get_public_supabase()

        auth_response = supabase.auth.get_user(token)

        if auth_response.user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token",
            )

        auth_user = auth_response.user

    except HTTPException:
        raise

    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        response = httpx.get(
            f"{settings.supabase_url}/rest/v1/profiles",
            headers={
                "apikey": settings.supabase_publishable_key,
                "Authorization": f"Bearer {token}",
            },
            params={
                "id": f"eq.{auth_user.id}",
                "select": "id,full_name,phone,role",
            },
            timeout=10.0,
        )

        response.raise_for_status()
        profiles = response.json()

    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to load user profile",
        )

    if not profiles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User profile not found",
        )

    profile = profiles[0]

    return CurrentUser(
        id=str(auth_user.id),
        email=auth_user.email,
        full_name=profile.get("full_name"),
        phone=profile.get("phone"),
        role=profile["role"],
    )


def require_roles(*allowed_roles: str):

    def role_checker(
        user: CurrentUser = Depends(get_current_user),
    ) -> CurrentUser:

        if user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to access this resource",
            )

        return user

    return role_checker
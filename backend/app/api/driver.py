from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
import httpx
from app.core.config import get_settings
from app.core.security import CurrentUser, get_access_token, require_roles

router = APIRouter(prefix="/driver", tags=["Driver"])
settings = get_settings()

def user_headers(token: str):
    return {
        "apikey": settings.supabase_publishable_key,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }

class AvailabilityUpdate(BaseModel):
    is_accepting_requests: bool

@router.get("/me")
def get_driver_me(
    current_user: CurrentUser = Depends(require_roles("driver")),
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/driver_profiles?user_id=eq.{current_user.id}",
        headers=user_headers(token),
        timeout=10.0
    )

    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch driver profile")

    data = response.json()
    if not data:
        raise HTTPException(status_code=404, detail="Driver profile not found")

    return data[0]

@router.get("/vehicles")
def get_driver_vehicles(
    current_user: CurrentUser = Depends(require_roles("driver")),
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/vehicles?driver_id=eq.{current_user.id}",
        headers=user_headers(token),
        timeout=10.0
    )

    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch vehicles")

    return response.json()

@router.get("/availability")
def get_driver_availability(
    current_user: CurrentUser = Depends(require_roles("driver")),
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/driver_profiles?select=is_accepting_requests&user_id=eq.{current_user.id}",
        headers=user_headers(token),
        timeout=10.0
    )

    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch availability")

    data = response.json()
    return {"is_accepting_requests": data[0].get("is_accepting_requests")} if data else {}

@router.patch("/availability")
def update_driver_availability(
    payload: AvailabilityUpdate,
    current_user: CurrentUser = Depends(require_roles("driver")),
    token: str = Depends(get_access_token)
):
    response = httpx.patch(
        f"{settings.supabase_url}/rest/v1/driver_profiles?user_id=eq.{current_user.id}",
        headers=user_headers(token),
        json={"is_accepting_requests": payload.is_accepting_requests},
        timeout=10.0
    )

    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Could not update availability")

    return {"status": "success", "is_accepting_requests": payload.is_accepting_requests}

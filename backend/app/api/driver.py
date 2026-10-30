from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
import httpx
from app.core.config import get_settings
from app.core.security import CurrentUser, get_access_token, require_roles

router = APIRouter(prefix="/driver", tags=["Driver"])
settings = get_settings()

# JWT Token à¶‘à¶š à·ƒà·„ API key à¶‘à¶š Supabase à¶‘à¶šà¶§ à¶ºà·€à¶±à·Šà¶± à·„à¶¯à·à¶œà¶­à·Šà¶­à·” header function à¶‘à¶š
# (à¶¸à·šà¶š traveler.py à¶‘à¶šà·š à¶­à·’à¶ºà·™à¶± à·€à·’à¶¯à·’à·„à¶§à¶¸ à¶œà·à¶½à¶´à·™à¶± à¶¶à·€ à¶­à·„à·€à·”à¶»à·” à¶šà¶»à¶œà¶±à·Šà¶±)[cite: 4]
def user_headers(token: str):
    return {
        "apikey": settings.supabase_publishable_key,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }

# Availability à¶ºà·à·€à¶­à·Šà¶šà·à¶½à·“à¶± à¶šà·’à¶»à·“à¶¸à¶§ Pydantic Model à¶‘à¶šà¶šà·Š
class AvailabilityUpdate(BaseModel):
    is_accepting_requests: bool

# 1. GET /driver/me - Driver à¶œà·š profile à¶‘à¶š à¶œà·à¶±à·“à¶¸[cite: 4, 5]
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

# 2. GET /driver/vehicles - Driver à¶§ à¶…à¶¯à·à·… à·€à·à·„à¶± à¶œà·à¶±à·“à¶¸[cite: 4, 5]
@router.get("/vehicles")
def get_driver_vehicles(
    current_user: CurrentUser = Depends(require_roles("driver")),
    token: str = Depends(get_access_token)
):
    # 'vehicles' table à¶‘à¶šà¶šà·Š à¶´à·€à¶­à·’à¶± à¶¶à·€ à¶‹à¶´à¶šà¶½à·Šà¶´à¶±à¶º à¶šà¶» à¶‡à¶­
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/vehicles?driver_id=eq.{current_user.id}",
        headers=user_headers(token),
        timeout=10.0
    )

    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch vehicles")

    return response.json()

# 3. GET /driver/availability - Driver à¶œà·š availability status à¶‘à¶š à¶¶à·à¶½à·“à¶¸[cite: 4]
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

# 4. PATCH /driver/availability - Driver à¶œà·š availability status à¶‘à¶š à·€à·™à¶±à·ƒà·Š à¶šà·’à¶»à·“à¶¸[cite: 4, 5]
@router.patch("/availability")
def update_driver_availability(
    payload: AvailabilityUpdate,
    current_user: CurrentUser = Depends(require_roles("driver")),
    token: str = Depends(get_access_token)
):
    # RPC à¶‘à¶šà¶šà·Š à·€à·™à¶±à·”à·€à¶§ Supabase REST à·„à¶»à·„à· à¶šà·™à¶½à·’à¶±à·Šà¶¸ driver_profiles update à¶šà·’à¶»à·“à¶¸
    response = httpx.patch(
        f"{settings.supabase_url}/rest/v1/driver_profiles?user_id=eq.{current_user.id}",
        headers=user_headers(token),
        json={"is_accepting_requests": payload.is_accepting_requests},
        timeout=10.0
    )

    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Could not update availability")

    return {"status": "success", "is_accepting_requests": payload.is_accepting_requests}

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
import httpx
from app.core.config import get_settings
from app.core.security import CurrentUser, get_access_token, require_roles

router = APIRouter(tags=["Driver"])
settings = get_settings()

# JWT Token එක සහ API key එක Supabase එකට යවන්න හදාගත්තු header function එක
# (මේක traveler.py එකේ තියෙන විදිහටම ගැලපෙන බව තහවුරු කරගන්න)[cite: 4]
def user_headers(token: str):
    return {
        "apikey": settings.supabase_publishable_key,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }

# Availability යාවත්කාලීන කිරීමට Pydantic Model එකක්
class AvailabilityUpdate(BaseModel):
    is_accepting_requests: bool

# 1. GET /driver/me - Driver ගේ profile එක ගැනීම[cite: 4, 5]
@router.get("/me")
def get_driver_me(
    current_user: dict = Depends(require_roles(["driver"])), 
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/driver_profiles?user_id=eq.{current_user['id']}",
        headers=user_headers(token),
        timeout=10.0
    )
    
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch driver profile")
        
    data = response.json()
    if not data:
        raise HTTPException(status_code=404, detail="Driver profile not found")
        
    return data[0]

# 2. GET /driver/vehicles - Driver ට අදාළ වාහන ගැනීම[cite: 4, 5]
@router.get("/vehicles")
def get_driver_vehicles(
    current_user: dict = Depends(require_roles(["driver"])), 
    token: str = Depends(get_access_token)
):
    # 'vehicles' table එකක් පවතින බව උපකල්පනය කර ඇත
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/vehicles?driver_id=eq.{current_user['id']}",
        headers=user_headers(token),
        timeout=10.0
    )
    
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch vehicles")
        
    return response.json()

# 3. GET /driver/availability - Driver ගේ availability status එක බැලීම[cite: 4]
@router.get("/availability")
def get_driver_availability(
    current_user: dict = Depends(require_roles(["driver"])), 
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/driver_profiles?select=is_accepting_requests&user_id=eq.{current_user['id']}",
        headers=user_headers(token),
        timeout=10.0
    )
    
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch availability")
        
    data = response.json()
    return {"is_accepting_requests": data[0].get("is_accepting_requests")} if data else {}

# 4. PATCH /driver/availability - Driver ගේ availability status එක වෙනස් කිරීම[cite: 4, 5]
@router.patch("/availability")
def update_driver_availability(
    payload: AvailabilityUpdate,
    current_user: dict = Depends(require_roles(["driver"])), 
    token: str = Depends(get_access_token)
):
    # RPC එකක් වෙනුවට Supabase REST හරහා කෙලින්ම driver_profiles update කිරීම
    response = httpx.patch(
        f"{settings.supabase_url}/rest/v1/driver_profiles?user_id=eq.{current_user['id']}",
        headers=user_headers(token),
        json={"is_accepting_requests": payload.is_accepting_requests},
        timeout=10.0
    )
    
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Could not update availability")
        
    return {"status": "success", "is_accepting_requests": payload.is_accepting_requests}
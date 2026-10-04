from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

from app.core.security import CurrentUser, get_access_token, require_roles
from app.core.supabase import get_service_supabase

router = APIRouter(
    prefix="/provider",
    tags=["Provider"]
)

# ==========================================
# Pydantic Schemas (Request/Response Models)
# ==========================================

class AccommodationUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    amenities: Optional[List[str]] = None

class RoomCreate(BaseModel):
    room_type: str
    capacity: int
    price_per_night: float
    description: Optional[str] = None

class RoomAvailabilityCreate(BaseModel):
    date: str
    is_available: bool = True
    price_override: Optional[float] = None


# ==========================================
# 1. Accommodation Owner APIs
# ==========================================

# 1. GET /provider/accommodations - Owner ට අදාළ Accommodations ලැයිස්තුව ලබා ගැනීම
@router.get("/accommodations")
async def get_provider_accommodations(
    current_user: CurrentUser = Depends(require_roles(["accommodation_owner", "admin"]))
):
    supabase = get_service_supabase()
    response = supabase.table("accommodations").select("*").eq("owner_id", current_user.id).execute()
    return response.data


# 2. PATCH /provider/accommodations/{id} - Accommodation විස්තර Update කිරීම
@router.patch("/accommodations/{accommodation_id}")
async def update_accommodation(
    accommodation_id: str,
    payload: AccommodationUpdate,
    current_user: CurrentUser = Depends(require_roles(["accommodation_owner", "admin"]))
):
    supabase = get_service_supabase()
    
    # Check ownership
    acc = supabase.table("accommodations").select("owner_id").eq("id", accommodation_id).single().execute()
    if not acc.data or (acc.data["owner_id"] != current_user.id and current_user.role != "admin"):
        raise HTTPException(status_code=403, detail="Not authorized to update this accommodation")
    
    update_data = {k: v for k, v in payload.dict().items() if v is not None}
    response = supabase.table("accommodations").update(update_data).eq("id", accommodation_id).execute()
    return response.data


# 3. GET /provider/accommodations/{id}/rooms - කාමර (Rooms) ලැයිස්තුව ලබා ගැනීම
@router.get("/accommodations/{accommodation_id}/rooms")
async def get_accommodation_rooms(
    accommodation_id: str,
    current_user: CurrentUser = Depends(require_roles(["accommodation_owner", "admin"]))
):
    supabase = get_service_supabase()
    response = supabase.table("rooms").select("*").eq("accommodation_id", accommodation_id).execute()
    return response.data


# 4. POST /provider/accommodations/{id}/rooms - අලුත් කාමරයක් එකතු කිරීම
@router.post("/accommodations/{accommodation_id}/rooms", status_code=status.HTTP_201_CREATED)
async def create_room(
    accommodation_id: str,
    payload: RoomCreate,
    current_user: CurrentUser = Depends(require_roles(["accommodation_owner", "admin"]))
):
    supabase = get_service_supabase()
    
    room_data = payload.dict()
    room_data["accommodation_id"] = accommodation_id
    
    response = supabase.table("rooms").insert(room_data).execute()
    return response.data


# 5. GET /provider/rooms/{room_id}/availability - Room availability පරීක්ෂා කිරීම
@router.get("/rooms/{room_id}/availability")
async def get_room_availability(
    room_id: str,
    current_user: CurrentUser = Depends(require_roles(["accommodation_owner", "admin"]))
):
    supabase = get_service_supabase()
    response = supabase.table("room_availability").select("*").eq("room_id", room_id).execute()
    return response.data


# 6. POST/PUT /provider/rooms/{room_id}/availability - Room availability සහ pricing සැකසීම
@router.post("/rooms/{room_id}/availability")
async def set_room_availability(
    room_id: str,
    payload: RoomAvailabilityCreate,
    current_user: CurrentUser = Depends(require_roles(["accommodation_owner", "admin"]))
):
    supabase = get_service_supabase()
    
    avail_data = payload.dict()
    avail_data["room_id"] = room_id
    
    response = supabase.table("room_availability").upsert(avail_data).execute()
    return response.data
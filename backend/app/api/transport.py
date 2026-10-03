from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from datetime import date, time, datetime
import httpx
from app.core.config import get_settings
from app.core.security import CurrentUser, get_access_token, require_roles

router = APIRouter(tags=["Transport"])
settings = get_settings()

def user_headers(token: str):
    return {
        "apikey": settings.supabase_publishable_key,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }

# Data Models
class TransportRequestCreate(BaseModel):
    pickup_location_snapshot: str
    trip_start_date: date
    trip_end_date: date
    passenger_count: int
    luggage_count: int
    currency: str

class BidCreate(BaseModel):
    vehicle_id: int
    bid_amount: float
    currency: str
    message: str = None

# Tracking module validation[cite: 6]
class LocationUpdate(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracy_meters: float = 0.0
    speed_kmh: float = 0.0
    heading_degrees: float = 0.0

# 1. POST /traveler/trips/{trip_id}/transport-requests[cite: 5]
@router.post("/traveler/trips/{trip_id}/transport-requests")
def create_transport_request(
    trip_id: int, 
    payload: TransportRequestCreate,
    current_user: dict = Depends(require_roles(["traveler"])), 
    token: str = Depends(get_access_token)
):
    data = payload.dict()
    data.update({
        "trip_id": trip_id,
        "traveler_id": current_user['id'],
        "status": "OPEN"
    })
    response = httpx.post(
        f"{settings.supabase_url}/rest/v1/transport_requests",
        headers=user_headers(token),
        json=data,
        timeout=10.0
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to create request")
    return response.json()[0]

# 2. GET /traveler/transport-requests[cite: 5]
@router.get("/traveler/transport-requests")
def get_traveler_requests(
    current_user: dict = Depends(require_roles(["traveler"])), 
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/transport_requests?traveler_id=eq.{current_user['id']}",
        headers=user_headers(token),
        timeout=10.0
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch requests")
    return response.json()

# 3. GET /driver/transport-requests/open[cite: 5]
@router.get("/driver/transport-requests/open")
def get_open_requests(
    current_user: dict = Depends(require_roles(["driver"])), 
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/transport_requests?status=eq.OPEN",
        headers=user_headers(token),
        timeout=10.0
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch open requests")
    return response.json()

# 4. POST /driver/transport-requests/{request_id}/bids[cite: 5]
@router.post("/driver/transport-requests/{request_id}/bids")
def submit_bid(
    request_id: int,
    payload: BidCreate,
    current_user: dict = Depends(require_roles(["driver"])), 
    token: str = Depends(get_access_token)
):
    data = payload.dict()
    data.update({
        "transport_request_id": request_id,
        "driver_id": current_user['id'],
        "status": "SUBMITTED"
    })
    response = httpx.post(
        f"{settings.supabase_url}/rest/v1/driver_bids",
        headers=user_headers(token),
        json=data,
        timeout=10.0
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to submit bid")
    return response.json()[0]

# 5. POST /driver/bids/{bid_id}/withdraw[cite: 5]
@router.post("/driver/bids/{bid_id}/withdraw")
def withdraw_bid(
    bid_id: int,
    current_user: dict = Depends(require_roles(["driver"])), 
    token: str = Depends(get_access_token)
):
    # RPC pattern[cite: 5, 6]
    rpc_response = httpx.post(
        f"{settings.supabase_url}/rest/v1/rpc/withdraw_driver_bid",
        headers=user_headers(token),
        json={"p_bid_id": bid_id},
        timeout=10.0
    )
    if rpc_response.status_code >= 400:
        raise HTTPException(status_code=rpc_response.status_code, detail="Could not withdraw bid")
    return {"status": "success", "message": "Bid withdrawn"}

# 6. GET /traveler/transport-requests/{request_id}/bids[cite: 5]
@router.get("/traveler/transport-requests/{request_id}/bids")
def get_bids_for_request(
    request_id: int,
    current_user: dict = Depends(require_roles(["traveler"])), 
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/driver_bids?transport_request_id=eq.{request_id}",
        headers=user_headers(token),
        timeout=10.0
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch bids")
    return response.json()

# 7. POST /traveler/transport-requests/{request_id}/accept-bid/{bid_id}[cite: 5]
@router.post("/traveler/transport-requests/{request_id}/accept-bid/{bid_id}")
def accept_bid(
    request_id: int,
    bid_id: int,
    current_user: dict = Depends(require_roles(["traveler"])), 
    token: str = Depends(get_access_token)
):
    # RPC pattern[cite: 5, 6]
    rpc_response = httpx.post(
        f"{settings.supabase_url}/rest/v1/rpc/accept_driver_bid",
        headers=user_headers(token),
        json={
            "p_request_id": request_id,
            "p_bid_id": bid_id
        },
        timeout=10.0
    )
    if rpc_response.status_code >= 400:
        raise HTTPException(status_code=rpc_response.status_code, detail="Could not accept bid")
    return {"status": "success", "message": "Bid accepted"}

# 8. GET /transport-requests/{request_id}[cite: 5]
@router.get("/transport-requests/{request_id}")
def get_request_details(
    request_id: int,
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/transport_requests?id=eq.{request_id}",
        headers=user_headers(token),
        timeout=10.0
    )
    if response.status_code >= 400 or not response.json():
        raise HTTPException(status_code=404, detail="Request not found")
    return response.json()[0]

# 9. POST /driver/transport-requests/{request_id}/location[cite: 5]
@router.post("/driver/transport-requests/{request_id}/location")
def submit_location(
    request_id: int,
    payload: LocationUpdate,
    current_user: dict = Depends(require_roles(["driver"])), 
    token: str = Depends(get_access_token)
):
    # RPC pattern[cite: 5, 6]
    rpc_response = httpx.post(
        f"{settings.supabase_url}/rest/v1/rpc/submit_transport_location",
        headers=user_headers(token),
        json={
            "p_transport_request_id": request_id,
            "p_latitude": payload.latitude,
            "p_longitude": payload.longitude,
            "p_accuracy_meters": payload.accuracy_meters,
            "p_speed_kmh": payload.speed_kmh,
            "p_heading_degrees": payload.heading_degrees,
            "p_recorded_at": datetime.utcnow().isoformat()
        },
        timeout=10.0
    )
    if rpc_response.status_code >= 400:
        raise HTTPException(status_code=rpc_response.status_code, detail="Could not submit location")
    return {"status": "success", "message": "Location updated"}

# 10. GET /traveler/transport-requests/{request_id}/location[cite: 5]
@router.get("/traveler/transport-requests/{request_id}/location")
def get_transport_location(
    request_id: int,
    current_user: dict = Depends(require_roles(["traveler"])), 
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/current_transport_locations?transport_request_id=eq.{request_id}",
        headers=user_headers(token),
        timeout=10.0
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch location")
    return response.json()
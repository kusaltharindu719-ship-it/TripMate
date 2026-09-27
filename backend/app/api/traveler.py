from datetime import date
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field, model_validator
from typing import Any
from typing import Any, Optional

from app.core.config import get_settings
from app.core.security import (
    CurrentUser,
    get_access_token,
    require_roles,
)


router = APIRouter(
    prefix="/traveler",
    tags=["Traveler"],
)

settings = get_settings()


# =========================================================
# REQUEST MODELS
# =========================================================

class TripCreate(BaseModel):
    trip_name: str
    start_location: str

    start_lat: Optional[float] = Field(
        default=None,
        ge=-90,
        le=90,
    )

    start_lng: Optional[float] = Field(
        default=None,
        ge=-180,
        le=180,
    )

    start_date: date
    end_date: date

    adult_count: int = Field(default=1, ge=0)
    child_count: int = Field(default=0, ge=0)

    budget: Optional[float] = Field(
        default=None,
        ge=0,
    )

    currency: str = "LKR"

    special_requirements: Optional[str] = None

    @model_validator(mode="after")
    def validate_trip(self):

        if self.end_date < self.start_date:
            raise ValueError(
                "End date cannot be before start date"
            )

        if self.adult_count + self.child_count < 1:
            raise ValueError(
                "At least one traveler is required"
            )

        return self


# =========================================================
# HELPER
# =========================================================

def user_headers(token: str) -> dict:
    return {
        "apikey": settings.supabase_publishable_key,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


# =========================================================
# 1. GET ACTIVE DESTINATIONS
# =========================================================

@router.get("/destinations")
def get_destinations(
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):

    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/destinations",
        headers=user_headers(token),
        params={
            "select": (
                "id,name,district,province,description,"
                "latitude,longitude,image_url"
            ),
            "is_active": "eq.true",
            "order": "name.asc",
        },
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load destinations",
        )

    return response.json()


# =========================================================
# 2. CREATE TRIP
# =========================================================

@router.post(
    "/trips",
    status_code=status.HTTP_201_CREATED,
)
def create_trip(
    data: TripCreate,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):

    payload = {
        "traveler_id": user.id,

        "trip_name": data.trip_name.strip(),
        "start_location": data.start_location.strip(),

        "start_lat": data.start_lat,
        "start_lng": data.start_lng,

        "start_date": data.start_date.isoformat(),
        "end_date": data.end_date.isoformat(),

        "adult_count": data.adult_count,
        "child_count": data.child_count,

        "budget": data.budget,

        "currency": data.currency.upper(),

        "special_requirements": (
            data.special_requirements.strip()
            if data.special_requirements
            else None
        ),
    }

    response = httpx.post(
        f"{settings.supabase_url}/rest/v1/trips",
        headers={
            **user_headers(token),
            "Prefer": "return=representation",
        },
        json=payload,
        timeout=10.0,
    )

    if response.status_code >= 400:
        try:
            error = response.json().get(
                "message",
                "Unable to create trip",
            )
        except Exception:
            error = "Unable to create trip"

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error,
        )

    trips = response.json()

    if not trips:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Trip was created but could not be returned",
        )

    return trips[0]
class TripPreferencesUpdate(BaseModel):
    interests: Any = None
    food_preferences: Any = None
    dietary_preferences: Any = None
    accommodation_preferences: Any = None
    transport_preferences: Any = None
    notes: Optional[str] = None


class TripDestinationCreate(BaseModel):
    destination_id: int
    visit_order: int = Field(ge=1)

    planned_arrival_date: Optional[date] = None
    planned_departure_date: Optional[date] = None

    notes: Optional[str] = None

    @model_validator(mode="after")
    def validate_dates(self):

        if (
            self.planned_arrival_date
            and self.planned_departure_date
            and self.planned_departure_date
            < self.planned_arrival_date
        ):
            raise ValueError(
                "Departure date cannot be before arrival date"
            )

        return self
class TripDestinationUpdate(BaseModel):
    visit_order: Optional[int] = Field(
        default=None,
        ge=1,
    )

    planned_arrival_date: Optional[date] = None
    planned_departure_date: Optional[date] = None
    notes: Optional[str] = None

    @model_validator(mode="after")
    def validate_dates(self):
        if (
            self.planned_arrival_date
            and self.planned_departure_date
            and self.planned_departure_date
            < self.planned_arrival_date
        ):
            raise ValueError(
                "Departure date cannot be before arrival date"
            )

        return self


# =========================================================
# 3. GET MY TRIPS
# =========================================================

@router.get("/trips")
def get_my_trips(
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):

    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/trips",
        headers=user_headers(token),
        params={
            "traveler_id": f"eq.{user.id}",
            "select": (
                "id,trip_name,start_location,"
                "start_lat,start_lng,"
                "start_date,end_date,"
                "adult_count,child_count,"
                "number_of_travelers,"
                "budget,currency,"
                "special_requirements,status,"
                "created_at,updated_at"
            ),
            "order": "created_at.desc",
        },
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load trips",
        )

    return response.json()
@router.get("/trips/{trip_id}")
def get_trip_details(
    trip_id: int,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/trips",
        headers=user_headers(token),
        params={
            "id": f"eq.{trip_id}",
            "traveler_id": f"eq.{user.id}",
            "select": (
                "id,trip_name,start_location,"
                "start_lat,start_lng,"
                "start_date,end_date,"
                "adult_count,child_count,"
                "number_of_travelers,"
                "budget,currency,"
                "special_requirements,status,"
                "created_at,updated_at"
            ),
        },
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load trip",
        )

    trips = response.json()

    if not trips:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found",
        )

    return trips[0]
# =========================================================
# 4. UPDATE TRIP PREFERENCES
# =========================================================

@router.put("/trips/{trip_id}/preferences")
def update_trip_preferences(
    trip_id: int,
    data: TripPreferencesUpdate,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):

    # Check that this trip belongs to the logged-in traveler
    trip_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/trips",
        headers=user_headers(token),
        params={
            "id": f"eq.{trip_id}",
            "traveler_id": f"eq.{user.id}",
            "select": "id",
        },
        timeout=10.0,
    )

    if (
        trip_response.status_code >= 400
        or not trip_response.json()
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found",
        )

    # Check whether preferences already exist
    existing_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/trip_preferences",
        headers=user_headers(token),
        params={
            "trip_id": f"eq.{trip_id}",
            "select": "id",
        },
        timeout=10.0,
    )

    if existing_response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to check trip preferences",
        )

    payload = {
        "trip_id": trip_id,
        "interests": data.interests,
        "food_preferences": data.food_preferences,
        "dietary_preferences": data.dietary_preferences,
        "accommodation_preferences":
            data.accommodation_preferences,
        "transport_preferences":
            data.transport_preferences,
        "notes": (
            data.notes.strip()
            if data.notes
            else None
        ),
    }

    existing = existing_response.json()

    if existing:

        response = httpx.patch(
            f"{settings.supabase_url}/rest/v1/trip_preferences",
            headers={
                **user_headers(token),
                "Prefer": "return=representation",
            },
            params={
                "trip_id": f"eq.{trip_id}",
            },
            json=payload,
            timeout=10.0,
        )

    else:

        response = httpx.post(
            f"{settings.supabase_url}/rest/v1/trip_preferences",
            headers={
                **user_headers(token),
                "Prefer": "return=representation",
            },
            json=payload,
            timeout=10.0,
        )

    if response.status_code >= 400:

        try:
            error = response.json().get(
                "message",
                "Unable to save trip preferences",
            )
        except Exception:
            error = "Unable to save trip preferences"

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error,
        )

    result = response.json()

    return result[0] if result else {
        "message": "Preferences saved"
    }


# =========================================================
# 5. GET TRIP PREFERENCES
# =========================================================

@router.get("/trips/{trip_id}/preferences")
def get_trip_preferences(
    trip_id: int,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):

    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/trip_preferences",
        headers=user_headers(token),
        params={
            "trip_id": f"eq.{trip_id}",
            "select": "*",
        },
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load trip preferences",
        )

    result = response.json()

    if not result:
        return None

    return result[0]


# =========================================================
# 6. ADD DESTINATION TO TRIP
# =========================================================

@router.post(
    "/trips/{trip_id}/destinations",
    status_code=status.HTTP_201_CREATED,
)
def add_trip_destination(
    trip_id: int,
    data: TripDestinationCreate,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):

    payload = {
        "trip_id": trip_id,
        "destination_id": data.destination_id,
        "visit_order": data.visit_order,

        "planned_arrival_date": (
            data.planned_arrival_date.isoformat()
            if data.planned_arrival_date
            else None
        ),

        "planned_departure_date": (
            data.planned_departure_date.isoformat()
            if data.planned_departure_date
            else None
        ),

        "notes": (
            data.notes.strip()
            if data.notes
            else None
        ),
    }

    response = httpx.post(
        f"{settings.supabase_url}/rest/v1/trip_destinations",
        headers={
            **user_headers(token),
            "Prefer": "return=representation",
        },
        json=payload,
        timeout=10.0,
    )

    if response.status_code >= 400:

        try:
            error = response.json().get(
                "message",
                "Unable to add destination",
            )
        except Exception:
            error = "Unable to add destination"

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error,
        )

    result = response.json()

    return result[0]


# =========================================================
# 7. GET TRIP DESTINATIONS
# =========================================================

@router.get("/trips/{trip_id}/destinations")
def get_trip_destinations(
    trip_id: int,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):

    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/trip_destinations",
        headers=user_headers(token),
        params={
            "trip_id": f"eq.{trip_id}",
            "select": (
                "id,trip_id,destination_id,"
                "visit_order,"
                "planned_arrival_date,"
                "planned_departure_date,"
                "notes,created_at,"
                "destinations("
                "id,name,district,province,"
                "latitude,longitude,image_url"
                ")"
            ),
            "order": "visit_order.asc",
        },
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load trip destinations",
        )

    return response.json()
# =========================================================
# UPDATE TRIP DESTINATION
# =========================================================

@router.patch(
    "/trips/{trip_id}/destinations/{trip_destination_id}"
)
def update_trip_destination(
    trip_id: int,
    trip_destination_id: int,
    data: TripDestinationUpdate,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):

    payload = data.model_dump(
        exclude_unset=True
    )

    if "planned_arrival_date" in payload:
        payload["planned_arrival_date"] = (
            payload["planned_arrival_date"].isoformat()
            if payload["planned_arrival_date"]
            else None
        )

    if "planned_departure_date" in payload:
        payload["planned_departure_date"] = (
            payload["planned_departure_date"].isoformat()
            if payload["planned_departure_date"]
            else None
        )

    if "notes" in payload and payload["notes"]:
        payload["notes"] = payload["notes"].strip()

    if not payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No changes were provided",
        )

    response = httpx.patch(
        f"{settings.supabase_url}/rest/v1/trip_destinations",
        headers={
            **user_headers(token),
            "Prefer": "return=representation",
        },
        params={
            "id": f"eq.{trip_destination_id}",
            "trip_id": f"eq.{trip_id}",
        },
        json=payload,
        timeout=10.0,
    )

    if response.status_code >= 400:
        try:
            error = response.json().get(
                "message",
                "Unable to update destination",
            )
        except Exception:
            error = "Unable to update destination"

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error,
        )

    result = response.json()

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip destination not found",
        )

    return result[0]
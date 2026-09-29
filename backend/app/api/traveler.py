from datetime import date, timedelta
from app.core.supabase import get_service_supabase
from typing import Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, status
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
class RoomCartCreate(BaseModel):
    room_type_id: int
    check_in_date: date
    check_out_date: date
    rooms_requested: int = 1
    adult_count: int
    child_count: int = 0
    accommodation_meal_plan_id: int | None = None
    notes: str | None = None


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
# =========================================================
# ACCOMMODATION DISCOVERY
# =========================================================


# =========================================================
# 10. LIST ACCOMMODATIONS
# =========================================================

@router.get("/accommodations")
def get_accommodations(
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/accommodations",
        headers=user_headers(token),
        params={
            "is_active": "eq.true",
            "select": (
                "id,accommodation_type_id,name,description,"
                "address,latitude,longitude,"
                "phone,email,website_url,"
                "check_in_time,check_out_time,"
                "star_rating"
            ),
            "order": "name.asc",
        },
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load accommodations",
        )

    accommodations = response.json()

    # Add images for each accommodation
    for accommodation in accommodations:
        image_response = httpx.get(
            f"{settings.supabase_url}/rest/v1/accommodation_images",
            headers=user_headers(token),
            params={
                "accommodation_id": f"eq.{accommodation['id']}",
                "select": (
                    "id,image_url,image_type,display_order"
                ),
                "order": "display_order.asc",
            },
            timeout=10.0,
        )

        accommodation["images"] = (
            image_response.json()
            if image_response.status_code < 400
            else []
        )

    return accommodations


# =========================================================
# 11. ACCOMMODATION DETAILS
# =========================================================

@router.get("/accommodations/{accommodation_id}")
def get_accommodation_details(
    accommodation_id: int,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/accommodations",
        headers=user_headers(token),
        params={
            "id": f"eq.{accommodation_id}",
            "is_active": "eq.true",
            "select": (
                "id,accommodation_type_id,name,description,"
                "address,latitude,longitude,"
                "phone,email,website_url,"
                "check_in_time,check_out_time,"
                "star_rating,created_at,updated_at"
            ),
        },
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load accommodation",
        )

    result = response.json()

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Accommodation not found",
        )

    accommodation = result[0]

    image_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/accommodation_images",
        headers=user_headers(token),
        params={
            "accommodation_id": f"eq.{accommodation_id}",
            "select": (
                "id,image_url,image_type,display_order"
            ),
            "order": "display_order.asc",
        },
        timeout=10.0,
    )

    accommodation["images"] = (
        image_response.json()
        if image_response.status_code < 400
        else []
    )

    return accommodation


# =========================================================
# 12. LIST ROOMS FOR ACCOMMODATION
# =========================================================

@router.get("/accommodations/{accommodation_id}/rooms")
def get_accommodation_rooms(
    accommodation_id: int,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/room_types",
        headers=user_headers(token),
        params={
            "accommodation_id": f"eq.{accommodation_id}",
            "is_active": "eq.true",
            "select": (
                "id,accommodation_id,name,description,"
                "max_adults,max_children,max_guests,"
                "room_size_square_meters,"
                "base_price_per_night,currency,"
                "total_rooms"
            ),
            "order": "base_price_per_night.asc",
        },
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load rooms",
        )

    rooms = response.json()

    for room in rooms:
        image_response = httpx.get(
            f"{settings.supabase_url}/rest/v1/room_images",
            headers=user_headers(token),
            params={
                "room_type_id": f"eq.{room['id']}",
                "select": (
                    "id,image_url,display_order"
                ),
                "order": "display_order.asc",
            },
            timeout=10.0,
        )

        room["images"] = (
            image_response.json()
            if image_response.status_code < 400
            else []
        )

    return rooms

# =========================================================
# ROOM AVAILABILITY
# =========================================================

@router.get("/rooms/{room_id}/availability")
def get_room_availability(
    room_id: int,

    check_in: date = Query(...),
    check_out: date = Query(...),

    rooms_requested: int = Query(
        default=1,
        ge=1,
    ),

    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):
    # -----------------------------------------------------
    # 1. Validate dates
    # -----------------------------------------------------

    if check_out <= check_in:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Check-out date must be after check-in date",
        )

    nights = (check_out - check_in).days


    # -----------------------------------------------------
    # 2. Load room
    # -----------------------------------------------------

    room_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/room_types",
        headers=user_headers(token),
        params={
            "id": f"eq.{room_id}",
            "is_active": "eq.true",
            "select": (
                "id,accommodation_id,name,"
                "base_price_per_night,currency,"
                "total_rooms,max_adults,"
                "max_children,max_guests"
            ),
        },
        timeout=10.0,
    )

    if room_response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load room",
        )

    rooms = room_response.json()

    if not rooms:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found",
        )

    room = rooms[0]


    # -----------------------------------------------------
    # 3. Load configured availability
    # -----------------------------------------------------

    availability_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/room_availability",
        headers=user_headers(token),
        params=[
            ("room_type_id", f"eq.{room_id}"),
            ("date", f"gte.{check_in.isoformat()}"),
            ("date", f"lt.{check_out.isoformat()}"),
            (
                "select",
                (
                    "id,date,available_rooms,"
                    "price_override,"
                    "minimum_stay_nights,is_closed"
                ),
            ),
            ("order", "date.asc"),
        ],
        timeout=10.0,
    )

    if availability_response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load room availability",
        )

    availability = availability_response.json()


    # -----------------------------------------------------
    # 4. Load ACTIVE reservations
    #
    # We use trusted backend access ONLY to aggregate
    # reserved inventory. Raw reservation data is not
    # returned to the traveler.
    # -----------------------------------------------------

    service_db = get_service_supabase()

    reservation_response = (
        service_db
        .table("room_inventory_reservations")
        .select("stay_date,rooms_reserved")
        .eq("room_type_id", room_id)
        .eq("status", "reserved")
        .gte("stay_date", check_in.isoformat())
        .lt("stay_date", check_out.isoformat())
        .execute()
    )

    reserved_by_date = {}

    for reservation in reservation_response.data:
        stay_date = reservation["stay_date"]

        reserved_by_date[stay_date] = (
            reserved_by_date.get(stay_date, 0)
            + reservation["rooms_reserved"]
        )


    # -----------------------------------------------------
    # 5. Detect missing availability dates
    # -----------------------------------------------------

    expected_dates = {
        (check_in + timedelta(days=i)).isoformat()
        for i in range(nights)
    }

    configured_dates = {
        day["date"]
        for day in availability
    }

    missing_dates = sorted(
        expected_dates - configured_dates
    )


    # -----------------------------------------------------
    # 6. Calculate real availability + price
    # -----------------------------------------------------

    detailed_availability = []

    estimated_total = 0

    all_dates_available = (
        len(missing_dates) == 0
    )

    minimum_rooms_remaining = None

    required_minimum_stay = 1


    for day in availability:

        configured_rooms = day["available_rooms"]

        reserved_rooms = reserved_by_date.get(
            day["date"],
            0,
        )

        remaining_rooms = max(
            configured_rooms - reserved_rooms,
            0,
        )

        effective_price = (
            day["price_override"]
            if day["price_override"] is not None
            else room["base_price_per_night"]
        )

        minimum_stay = (
            day["minimum_stay_nights"]
            or 1
        )

        required_minimum_stay = max(
            required_minimum_stay,
            minimum_stay,
        )

        date_available = (
            not day["is_closed"]
            and remaining_rooms >= rooms_requested
        )

        if not date_available:
            all_dates_available = False

        if minimum_rooms_remaining is None:
            minimum_rooms_remaining = remaining_rooms
        else:
            minimum_rooms_remaining = min(
                minimum_rooms_remaining,
                remaining_rooms,
            )

        estimated_total += (
            effective_price
            * rooms_requested
        )

        detailed_availability.append(
            {
                "date": day["date"],

                "configured_rooms":
                    configured_rooms,

                "reserved_rooms":
                    reserved_rooms,

                "remaining_rooms":
                    remaining_rooms,

                "rooms_requested":
                    rooms_requested,

                "is_closed":
                    day["is_closed"],

                "minimum_stay_nights":
                    minimum_stay,

                "effective_price":
                    effective_price,

                "available":
                    date_available,
            }
        )


    # -----------------------------------------------------
    # 7. Minimum-stay validation
    # -----------------------------------------------------

    minimum_stay_valid = (
        nights >= required_minimum_stay
    )

    if not minimum_stay_valid:
        all_dates_available = False


    # -----------------------------------------------------
    # 8. Final response
    # -----------------------------------------------------

    return {
        "room": room,

        "check_in": check_in,
        "check_out": check_out,

        "nights": nights,
        "rooms_requested": rooms_requested,

        "available": all_dates_available,

        "missing_dates": missing_dates,

        "minimum_stay_required":
            required_minimum_stay,

        "minimum_stay_valid":
            minimum_stay_valid,

        "minimum_rooms_remaining":
            minimum_rooms_remaining,

        "estimated_total":
            estimated_total,

        "currency":
            room["currency"],

        "availability":
            detailed_availability,
    }
# =========================================================
# ADD ROOM TO TRIP CART
# =========================================================

@router.post("/trips/{trip_id}/cart/rooms")
def add_room_to_trip_cart(
    trip_id: int,
    payload: RoomCartCreate,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(
        require_roles("traveler")
    ),
):
    # -----------------------------------------------------
    # 1. Basic validation
    # -----------------------------------------------------

    if payload.rooms_requested <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one room must be requested",
        )

    if payload.adult_count < 0 or payload.child_count < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Guest counts cannot be negative",
        )

    if payload.adult_count + payload.child_count <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one guest is required",
        )

    if payload.check_out_date <= payload.check_in_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Check-out date must be after check-in date",
        )


    # -----------------------------------------------------
    # 2. Load traveler's trip
    # RLS ensures another traveler's trip is not accessible
    # -----------------------------------------------------

    trip_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/trips",
        headers=user_headers(token),
        params={
            "id": f"eq.{trip_id}",
            "select": (
                "id,start_date,end_date,"
                "adult_count,child_count,status"
            ),
        },
        timeout=10.0,
    )

    if trip_response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load trip",
        )

    trips = trip_response.json()

    if not trips:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found",
        )

    trip = trips[0]


    # -----------------------------------------------------
    # 3. Trip-date validation
    # -----------------------------------------------------

    trip_start = date.fromisoformat(
        trip["start_date"]
    )

    trip_end = date.fromisoformat(
        trip["end_date"]
    )

    if (
        payload.check_in_date < trip_start
        or payload.check_out_date > trip_end
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Room dates must be within trip dates",
        )


    # -----------------------------------------------------
    # 4. Load room
    # -----------------------------------------------------

    room_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/room_types",
        headers=user_headers(token),
        params={
            "id": f"eq.{payload.room_type_id}",
            "is_active": "eq.true",
            "select": (
                "id,accommodation_id,name,"
                "max_adults,max_children,max_guests,"
                "base_price_per_night,currency,total_rooms"
            ),
        },
        timeout=10.0,
    )

    if room_response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load room",
        )

    rooms = room_response.json()

    if not rooms:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found or unavailable",
        )

    room = rooms[0]


    # -----------------------------------------------------
    # 5. Capacity validation
    # -----------------------------------------------------

    max_adults = (
        room["max_adults"]
        * payload.rooms_requested
    )

    max_children = (
        room["max_children"]
        * payload.rooms_requested
    )

    max_guests = (
        room["max_guests"]
        * payload.rooms_requested
    )

    if payload.adult_count > max_adults:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Adult count exceeds room capacity",
        )

    if payload.child_count > max_children:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Child count exceeds room capacity",
        )

    if (
        payload.adult_count
        + payload.child_count
        > max_guests
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Total guest count exceeds room capacity",
        )


    # -----------------------------------------------------
    # 6. Load availability rows
    # -----------------------------------------------------

    nights = (
        payload.check_out_date
        - payload.check_in_date
    ).days

    availability_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/room_availability",
        headers=user_headers(token),
        params=[
            (
                "room_type_id",
                f"eq.{payload.room_type_id}",
            ),
            (
                "date",
                f"gte.{payload.check_in_date.isoformat()}",
            ),
            (
                "date",
                f"lt.{payload.check_out_date.isoformat()}",
            ),
            (
                "select",
                (
                    "date,available_rooms,"
                    "minimum_stay_nights,is_closed"
                ),
            ),
            ("order", "date.asc"),
        ],
        timeout=10.0,
    )

    if availability_response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to check room availability",
        )

    availability = availability_response.json()


    # -----------------------------------------------------
    # 7. Every night must have availability configuration
    # -----------------------------------------------------

    expected_dates = {
        (
            payload.check_in_date
            + timedelta(days=i)
        ).isoformat()
        for i in range(nights)
    }

    configured_dates = {
        row["date"]
        for row in availability
    }

    missing_dates = sorted(
        expected_dates - configured_dates
    )

    if missing_dates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "message": "Room availability is not configured for all requested nights",
                "missing_dates": missing_dates,
            },
        )


    # -----------------------------------------------------
    # 8. Find already RESERVED inventory
    # -----------------------------------------------------

    service_db = get_service_supabase()

    reservation_response = (
        service_db
        .table("room_inventory_reservations")
        .select("stay_date,rooms_reserved")
        .eq(
            "room_type_id",
            payload.room_type_id,
        )
        .eq("status", "reserved")
        .gte(
            "stay_date",
            payload.check_in_date.isoformat(),
        )
        .lt(
            "stay_date",
            payload.check_out_date.isoformat(),
        )
        .execute()
    )

    reserved_by_date = {}

    for reservation in reservation_response.data:

        stay_date = reservation["stay_date"]

        reserved_by_date[stay_date] = (
            reserved_by_date.get(stay_date, 0)
            + reservation["rooms_reserved"]
        )


    # -----------------------------------------------------
    # 9. Validate actual remaining rooms + minimum stay
    # -----------------------------------------------------

    minimum_stay_required = 1

    for day in availability:

        if day["is_closed"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Room is closed on {day['date']}"
                ),
            )

        reserved_rooms = reserved_by_date.get(
            day["date"],
            0,
        )

        remaining_rooms = max(
            day["available_rooms"]
            - reserved_rooms,
            0,
        )

        if remaining_rooms < payload.rooms_requested:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Not enough rooms available on "
                    f"{day['date']}"
                ),
            )

        minimum_stay_required = max(
            minimum_stay_required,
            day["minimum_stay_nights"] or 1,
        )


    if nights < minimum_stay_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Minimum stay is "
                f"{minimum_stay_required} nights"
            ),
        )


    # -----------------------------------------------------
    # 10. Optional meal-plan validation
    # -----------------------------------------------------

    if payload.accommodation_meal_plan_id is not None:

        meal_response = httpx.get(
            f"{settings.supabase_url}/rest/v1/accommodation_meal_plans",
            headers=user_headers(token),
            params={
                "id": (
                    f"eq."
                    f"{payload.accommodation_meal_plan_id}"
                ),
                "is_available": "eq.true",
                "select": (
                    "id,accommodation_id,"
                    "price_per_adult,"
                    "price_per_child,currency"
                ),
            },
            timeout=10.0,
        )

        if meal_response.status_code >= 400:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unable to load meal plan",
            )

        meal_plans = meal_response.json()

        if not meal_plans:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Meal plan not found or unavailable",
            )

        meal_plan = meal_plans[0]

        if (
            meal_plan["accommodation_id"]
            != room["accommodation_id"]
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Meal plan must belong to "
                    "the same accommodation"
                ),
            )


    # -----------------------------------------------------
    # 11. Insert cart item
    #
    # IMPORTANT:
    # Do NOT send browser-controlled price/name.
    # Database trigger creates authoritative snapshots.
    # -----------------------------------------------------

    cart_data = {
        "trip_id": trip_id,

        "item_type": "room",

        "room_type_id":
            payload.room_type_id,

        "quantity":
            payload.rooms_requested,

        "check_in_date":
            payload.check_in_date.isoformat(),

        "check_out_date":
            payload.check_out_date.isoformat(),

        "accommodation_meal_plan_id":
            payload.accommodation_meal_plan_id,

        "selection_details": {
            "adult_count":
                payload.adult_count,

            "child_count":
                payload.child_count,
        },

        "notes":
            payload.notes,
    }


    insert_headers = {
        **user_headers(token),
        "Prefer": "return=representation",
    }

    insert_response = httpx.post(
        f"{settings.supabase_url}/rest/v1/trip_cart_items",
        headers=insert_headers,
        json=cart_data,
        timeout=10.0,
    )


    if insert_response.status_code >= 400:

        try:
            error_data = insert_response.json()

            error_message = (
                error_data.get("message")
                or error_data.get("details")
                or "Unable to add room to cart"
            )

        except Exception:
            error_message = (
                "Unable to add room to cart"
            )

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_message,
        )


    created_items = insert_response.json()

    if not created_items:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Cart item was not returned",
        )


    return {
        "message": "Room added to trip cart successfully",
        "cart_item": created_items[0],
    }
# =========================================================
# ADD ROOM TO TRIP CART
# =========================================================

@router.post("/trips/{trip_id}/cart/rooms")
def add_room_to_trip_cart(
    trip_id: int,
    payload: RoomCartCreate,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(require_roles("traveler")),
):
    # 1. Basic validation
    if payload.rooms_requested <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one room must be requested",
        )

    if payload.adult_count < 0 or payload.child_count < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Guest counts cannot be negative",
        )

    if payload.adult_count + payload.child_count <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one guest is required",
        )

    if payload.check_out_date <= payload.check_in_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Check-out date must be after check-in date",
        )

    # 2. Load the traveler's trip
    trip_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/trips",
        headers=user_headers(token),
        params={
            "id": f"eq.{trip_id}",
            "select": "id,start_date,end_date,adult_count,child_count,status",
        },
        timeout=10.0,
    )

    if trip_response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load trip",
        )

    trips = trip_response.json()

    if not trips:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found",
        )

    trip = trips[0]

    trip_start = date.fromisoformat(trip["start_date"])
    trip_end = date.fromisoformat(trip["end_date"])

    if (
        payload.check_in_date < trip_start
        or payload.check_out_date > trip_end
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Room dates must be within trip dates",
        )

    # 3. Load room
    room_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/room_types",
        headers=user_headers(token),
        params={
            "id": f"eq.{payload.room_type_id}",
            "is_active": "eq.true",
            "select": (
                "id,accommodation_id,name,"
                "max_adults,max_children,max_guests,"
                "base_price_per_night,currency,total_rooms"
            ),
        },
        timeout=10.0,
    )

    if room_response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load room",
        )

    rooms = room_response.json()

    if not rooms:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Room not found or unavailable",
        )

    room = rooms[0]

    # 4. Capacity validation
    max_adults = (room["max_adults"] or 0) * payload.rooms_requested
    max_children = (room["max_children"] or 0) * payload.rooms_requested
    max_guests = (room["max_guests"] or 0) * payload.rooms_requested

    if payload.adult_count > max_adults:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Adult count exceeds room capacity",
        )

    if payload.child_count > max_children:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Child count exceeds room capacity",
        )

    if payload.adult_count + payload.child_count > max_guests:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Total guest count exceeds room capacity",
        )

    # 5. Load configured room availability
    nights = (payload.check_out_date - payload.check_in_date).days

    availability_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/room_availability",
        headers=user_headers(token),
        params=[
            ("room_type_id", f"eq.{payload.room_type_id}"),
            ("date", f"gte.{payload.check_in_date.isoformat()}"),
            ("date", f"lt.{payload.check_out_date.isoformat()}"),
            (
                "select",
                "date,available_rooms,minimum_stay_nights,is_closed",
            ),
            ("order", "date.asc"),
        ],
        timeout=10.0,
    )

    if availability_response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to check room availability",
        )

    availability = availability_response.json()

    expected_dates = {
        (payload.check_in_date + timedelta(days=i)).isoformat()
        for i in range(nights)
    }

    configured_dates = {
        row["date"]
        for row in availability
    }

    missing_dates = sorted(expected_dates - configured_dates)

    if missing_dates:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "message": "Room availability is not configured for all requested nights",
                "missing_dates": missing_dates,
            },
        )

    # 6. Check already reserved inventory
    service_db = get_service_supabase()

    reservation_response = (
        service_db
        .table("room_inventory_reservations")
        .select("stay_date,rooms_reserved")
        .eq("room_type_id", payload.room_type_id)
        .eq("status", "reserved")
        .gte("stay_date", payload.check_in_date.isoformat())
        .lt("stay_date", payload.check_out_date.isoformat())
        .execute()
    )

    reserved_by_date = {}

    for reservation in reservation_response.data:
        stay_date = reservation["stay_date"]

        reserved_by_date[stay_date] = (
            reserved_by_date.get(stay_date, 0)
            + reservation["rooms_reserved"]
        )

    # 7. Validate real remaining rooms
    minimum_stay_required = 1

    for day in availability:
        if day["is_closed"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Room is closed on {day['date']}",
            )

        reserved_rooms = reserved_by_date.get(day["date"], 0)

        remaining_rooms = max(
            day["available_rooms"] - reserved_rooms,
            0,
        )

        if remaining_rooms < payload.rooms_requested:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Not enough rooms available on {day['date']}",
            )

        minimum_stay_required = max(
            minimum_stay_required,
            day["minimum_stay_nights"] or 1,
        )

    if nights < minimum_stay_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Minimum stay is {minimum_stay_required} nights",
        )

    # 8. Validate optional meal plan
    if payload.accommodation_meal_plan_id is not None:
        meal_response = httpx.get(
            f"{settings.supabase_url}/rest/v1/accommodation_meal_plans",
            headers=user_headers(token),
            params={
                "id": f"eq.{payload.accommodation_meal_plan_id}",
                "is_available": "eq.true",
                "select": (
                    "id,accommodation_id,"
                    "price_per_adult,price_per_child,currency"
                ),
            },
            timeout=10.0,
        )

        if meal_response.status_code >= 400:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unable to load meal plan",
            )

        meal_plans = meal_response.json()

        if not meal_plans:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Meal plan not found or unavailable",
            )

        if meal_plans[0]["accommodation_id"] != room["accommodation_id"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Meal plan must belong to the same accommodation",
            )

    # 9. Add room to cart
    cart_data = {
        "trip_id": trip_id,
        "item_type": "room",
        "room_type_id": payload.room_type_id,
        "quantity": payload.rooms_requested,
        "check_in_date": payload.check_in_date.isoformat(),
        "check_out_date": payload.check_out_date.isoformat(),
        "accommodation_meal_plan_id": payload.accommodation_meal_plan_id,
        "selection_details": {
            "adult_count": payload.adult_count,
            "child_count": payload.child_count,
        },
        "notes": payload.notes,
    }

    insert_headers = {
        **user_headers(token),
        "Prefer": "return=representation",
    }

    insert_response = httpx.post(
        f"{settings.supabase_url}/rest/v1/trip_cart_items",
        headers=insert_headers,
        json=cart_data,
        timeout=10.0,
    )

    if insert_response.status_code >= 400:
        try:
            error_data = insert_response.json()
            error_message = (
                error_data.get("message")
                or error_data.get("details")
                or "Unable to add room to cart"
            )
        except Exception:
            error_message = "Unable to add room to cart"

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=error_message,
        )

    created_items = insert_response.json()

    if not created_items:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Cart item was not returned",
        )

    return {
        "message": "Room added to trip cart successfully",
        "cart_item": created_items[0],
    }
# =========================================================
# VIEW TRIP CART
# =========================================================

@router.get("/trips/{trip_id}/cart")
def get_trip_cart(
    trip_id: int,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(require_roles("traveler")),
):
    # 1. Make sure this trip belongs to the logged-in traveler
    trip_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/trips",
        headers=user_headers(token),
        params={
            "id": f"eq.{trip_id}",
            "select": "id,trip_name,start_date,end_date,status",
        },
        timeout=10.0,
    )

    if trip_response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load trip",
        )

    trips = trip_response.json()

    if not trips:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found",
        )

    # 2. Load cart items
    cart_response = httpx.get(
        f"{settings.supabase_url}/rest/v1/trip_cart_items",
        headers=user_headers(token),
        params={
            "trip_id": f"eq.{trip_id}",
            "select": "*",
            "order": "created_at.asc",
        },
        timeout=10.0,
    )

    if cart_response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Unable to load trip cart",
        )

    items = cart_response.json()

    return {
        "trip": trips[0],
        "item_count": len(items),
        "items": items,
    }
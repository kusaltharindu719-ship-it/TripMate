"""Accommodation owner API: models, helpers and five endpoints."""

from datetime import date as Date, time
import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.config import get_settings
from app.core.security import CurrentUser, get_access_token, require_roles

router = APIRouter(prefix="/provider/accommodations", tags=["Accommodation Owner"])
settings = get_settings()
logger = logging.getLogger(__name__)


# 1. REQUEST MODELS


class AccommodationCreate(BaseModel):
    model_config = ConfigDict(
        extra="forbid", str_strip_whitespace=True, allow_inf_nan=False
    )

    accommodation_type_id: int | None = Field(default=None, gt=0)
    name: str = Field(min_length=1)
    description: str | None = None
    address: str = Field(min_length=1)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    phone: str | None = None
    email: str | None = None
    check_in_time: time | None = None
    check_out_time: time | None = None
    star_rating: float | None = Field(default=None, ge=0, le=5)
    is_active: bool = True


class RoomTypeCreate(BaseModel):
    model_config = ConfigDict(
        extra="forbid", str_strip_whitespace=True, allow_inf_nan=False
    )

    name: str = Field(min_length=1)
    description: str | None = None
    max_adults: int = Field(default=1, gt=0)
    max_children: int = Field(default=0, ge=0)
    max_guests: int = Field(gt=0)
    base_price_per_night: float = Field(ge=0)
    currency: str = Field(default="LKR", pattern=r"^[A-Z]{3}$")
    total_rooms: int = Field(gt=0)
    is_active: bool = True

    @model_validator(mode="after")
    def validate_capacity(
        self,
    ):
        # Match the repository's room_types constraint.
        if self.max_guests < self.max_adults:
            raise ValueError("max_guests must be at least max_adults")
        return self


class RoomAvailabilityItem(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)

    room_type_id: int = Field(gt=0)
    date: Date
    available_rooms: int = Field(ge=0)
    price_override: float | None = Field(default=None, ge=0)
    minimum_stay_nights: int = Field(default=1, gt=0)
    is_closed: bool = False


# 2. HELPERS


def user_headers(token: str) -> dict:
    return {
        "apikey": settings.supabase_publishable_key,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


def check_response(response):
    if response.status_code >= 400:
        # Preserve the exact Supabase error for schema/privilege troubleshooting.
        # Never log request headers, JWTs or credentials.
        logger.error("Supabase returned %s: %s", response.status_code, response.text)
        try:
            error = response.json()
        except ValueError:
            error = {}
        code = error.get("code") if isinstance(error, dict) else None
        message = error.get("message", "") if isinstance(error, dict) else ""
        if code == "23505":
            raise HTTPException(409, "A matching record already exists")
        if code in {"23503", "23514"} or (
            code == "P0001"
            and message == "Available rooms cannot exceed total room count"
        ):
            raise HTTPException(400, message or "Invalid accommodation data")
        if response.status_code == 401:
            raise HTTPException(401, "Invalid or expired authentication token")
        if code == "42501" and "row-level security" in message.lower():
            raise HTTPException(403, "You cannot modify this accommodation data")
        raise HTTPException(
            502, "Accommodation database request failed; see server logs"
        )
    try:
        rows = response.json()
    except ValueError as exc:
        raise HTTPException(502, "Invalid accommodation database response") from exc
    if not isinstance(rows, list):
        raise HTTPException(502, "Invalid accommodation database response")
    return rows


def require_owned_accommodation(
    accommodation_id: int,
    user: CurrentUser,
    token: str,
):
    if accommodation_id <= 0:
        raise HTTPException(422, "Accommodation ID must be positive")
    try:
        response = httpx.get(
            f"{settings.supabase_url}/rest/v1/accommodations",
            headers=user_headers(token),
            params={
                "id": f"eq.{accommodation_id}",
                "owner_id": f"eq.{user.id}",
                "select": "id",
            },
            timeout=10.0,
        )
    except httpx.RequestError as exc:
        raise HTTPException(502, "Unable to connect to accommodation database") from exc
    rows = check_response(response)
    if not rows:
        raise HTTPException(404, "Accommodation not found")


# 3. LIST MY ACCOMMODATIONS


@router.get("/")
def list_accommodations(
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(require_roles("accommodation_owner")),
):
    try:
        response = httpx.get(
            f"{settings.supabase_url}/rest/v1/accommodations",
            headers=user_headers(token),
            params={
                "owner_id": f"eq.{user.id}",
                "select": "*",
                "order": "created_at.desc",
            },
            timeout=10.0,
        )
    except httpx.RequestError as exc:
        raise HTTPException(502, "Unable to connect to accommodation database") from exc
    rows = check_response(response)
    return {"accommodation_count": len(rows), "accommodations": rows}


# 4. CREATE AN ACCOMMODATION


@router.post("/", status_code=201)
def create_accommodation(
    payload: AccommodationCreate,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(require_roles("accommodation_owner")),
):
    data = payload.model_dump(mode="json")
    # The logged-in owner supplies this ID, not the browser.
    data["owner_id"] = user.id
    try:
        response = httpx.post(
            f"{settings.supabase_url}/rest/v1/accommodations",
            headers={**user_headers(token), "Prefer": "return=representation"},
            json=data,
            timeout=10.0,
        )
    except httpx.RequestError as exc:
        raise HTTPException(502, "Unable to connect to accommodation database") from exc
    rows = check_response(response)
    if not rows:
        raise HTTPException(502, "Created accommodation was not returned")
    return {"message": "Accommodation created successfully", "accommodation": rows[0]}


# 5. LIST ROOM TYPES


@router.get("/{accommodation_id}/room-types")
def list_room_types(
    accommodation_id: int,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(require_roles("accommodation_owner")),
):
    require_owned_accommodation(accommodation_id, user, token)
    try:
        response = httpx.get(
            f"{settings.supabase_url}/rest/v1/room_types",
            headers=user_headers(token),
            params={
                "accommodation_id": f"eq.{accommodation_id}",
                "select": "*",
                "order": "id.asc",
            },
            timeout=10.0,
        )
    except httpx.RequestError as exc:
        raise HTTPException(502, "Unable to connect to accommodation database") from exc
    rows = check_response(response)
    return {"room_type_count": len(rows), "room_types": rows}


# 6. CREATE A ROOM TYPE


@router.post("/{accommodation_id}/room-types", status_code=201)
def create_room_type(
    accommodation_id: int,
    payload: RoomTypeCreate,
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(require_roles("accommodation_owner")),
):
    require_owned_accommodation(accommodation_id, user, token)
    data = payload.model_dump(mode="json")
    data["accommodation_id"] = accommodation_id
    try:
        response = httpx.post(
            f"{settings.supabase_url}/rest/v1/room_types",
            headers={**user_headers(token), "Prefer": "return=representation"},
            json=data,
            timeout=10.0,
        )
    except httpx.RequestError as exc:
        raise HTTPException(502, "Unable to connect to accommodation database") from exc
    rows = check_response(response)
    if not rows:
        raise HTTPException(502, "Created room type was not returned")
    return {"message": "Room type created successfully", "room_type": rows[0]}


# 7. UPDATE ROOM AVAILABILITY


@router.put("/{accommodation_id}/room-availability")
def update_room_availability(
    accommodation_id: int,
    payload: list[RoomAvailabilityItem],
    token: str = Depends(get_access_token),
    user: CurrentUser = Depends(require_roles("accommodation_owner")),
):
    require_owned_accommodation(accommodation_id, user, token)
    if not payload:
        raise HTTPException(400, "At least one availability row is required")
    seen = set()
    rooms = {}
    # Validate the whole batch before issuing a single atomic upsert.
    for item in payload:
        key = (item.room_type_id, item.date)
        if key in seen:
            raise HTTPException(
                400, "Duplicate room type and date in availability request"
            )
        seen.add(key)
        if item.room_type_id not in rooms:
            try:
                response = httpx.get(
                    f"{settings.supabase_url}/rest/v1/room_types",
                    headers=user_headers(token),
                    params={
                        "id": f"eq.{item.room_type_id}",
                        "accommodation_id": f"eq.{accommodation_id}",
                        "select": "id,total_rooms",
                    },
                    timeout=10.0,
                )
            except httpx.RequestError as exc:
                raise HTTPException(
                    502, "Unable to connect to accommodation database"
                ) from exc
            rows = check_response(response)
            if not rows:
                raise HTTPException(404, "Room type not found in this accommodation")
            rooms[item.room_type_id] = rows[0]["total_rooms"]
        if item.available_rooms > rooms[item.room_type_id]:
            raise HTTPException(400, "Available rooms cannot exceed total room count")
    try:
        response = httpx.post(
            f"{settings.supabase_url}/rest/v1/room_availability",
            headers={
                **user_headers(token),
                "Prefer": "return=representation,resolution=merge-duplicates",
            },
            params={"on_conflict": "room_type_id,date"},
            json=[item.model_dump(mode="json") for item in payload],
            timeout=10.0,
        )
    except httpx.RequestError as exc:
        raise HTTPException(502, "Unable to connect to accommodation database") from exc
    rows = check_response(response)
    if not rows:
        raise HTTPException(502, "Updated availability was not returned")
    return {"message": "Room availability updated successfully", "availability": rows}

from datetime import time
from typing import List, Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.core.config import get_settings
from app.core.security import CurrentUser, get_access_token, require_roles


router = APIRouter(
    prefix="/provider/restaurants",
    tags=["Restaurant Owner"],
)

settings = get_settings()


def user_headers(token: str):
    return {
        "apikey": settings.supabase_publishable_key,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }


def verify_restaurant_ownership(
    restaurant_id: int,
    current_user: CurrentUser,
    token: str,
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/restaurants",
        headers=user_headers(token),
        params={
            "id": f"eq.{restaurant_id}",
            "owner_id": f"eq.{current_user.id}",
            "select": "id",
        },
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to verify restaurant ownership",
        )

    if not response.json():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Restaurant not found or does not belong to this owner",
        )


class RestaurantCreate(BaseModel):
    name: str = Field(..., min_length=1)
    description: Optional[str] = None
    address: str = Field(..., min_length=1)
    is_active: bool = True


class FoodItemCreate(BaseModel):
    name: str = Field(..., min_length=1)
    price: float = Field(..., ge=0)
    currency: str = "LKR"
    is_available: bool = True


class BuffetCreate(BaseModel):
    name: str = Field(..., min_length=1)
    description: Optional[str] = None
    price_per_person: float = Field(..., ge=0)
    currency: str = "LKR"
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    minimum_guests: Optional[int] = Field(default=None, gt=0)
    maximum_guests: Optional[int] = Field(default=None, gt=0)
    is_available: bool = True


class OpeningHourItem(BaseModel):
    day_of_week: int = Field(..., ge=0, le=6)
    opening_time: Optional[time] = None
    closing_time: Optional[time] = None
    is_closed: bool = False


class OpeningHoursUpdate(BaseModel):
    hours: List[OpeningHourItem]


@router.get("/")
def get_my_restaurants(
    current_user: CurrentUser = Depends(
        require_roles("restaurant_owner")
    ),
    token: str = Depends(get_access_token),
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/restaurants",
        headers=user_headers(token),
        params={
            "owner_id": f"eq.{current_user.id}",
            "select": "*",
        },
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to fetch restaurants",
        )

    return response.json()


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
)
def create_restaurant(
    payload: RestaurantCreate,
    current_user: CurrentUser = Depends(
        require_roles("restaurant_owner")
    ),
    token: str = Depends(get_access_token),
):
    data = payload.model_dump()
    data["owner_id"] = current_user.id

    response = httpx.post(
        f"{settings.supabase_url}/rest/v1/restaurants",
        headers=user_headers(token),
        json=data,
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to create restaurant",
        )

    result = response.json()

    if not result:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Restaurant created but no data was returned",
        )

    return result[0]


@router.post(
    "/{restaurant_id}/menu-items",
    status_code=status.HTTP_201_CREATED,
)
def add_menu_item(
    restaurant_id: int,
    payload: FoodItemCreate,
    current_user: CurrentUser = Depends(
        require_roles("restaurant_owner")
    ),
    token: str = Depends(get_access_token),
):
    verify_restaurant_ownership(
        restaurant_id,
        current_user,
        token,
    )

    data = payload.model_dump()
    data["restaurant_id"] = restaurant_id

    response = httpx.post(
        f"{settings.supabase_url}/rest/v1/food_items",
        headers=user_headers(token),
        json=data,
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to add menu item",
        )

    result = response.json()

    if not result:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Menu item created but no data was returned",
        )

    return result[0]


@router.post(
    "/{restaurant_id}/buffets",
    status_code=status.HTTP_201_CREATED,
)
def add_buffet(
    restaurant_id: int,
    payload: BuffetCreate,
    current_user: CurrentUser = Depends(
        require_roles("restaurant_owner")
    ),
    token: str = Depends(get_access_token),
):
    verify_restaurant_ownership(
        restaurant_id,
        current_user,
        token,
    )

    if (
        payload.minimum_guests is not None
        and payload.maximum_guests is not None
        and payload.maximum_guests < payload.minimum_guests
    ):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Maximum guests cannot be less than minimum guests",
        )

    data = payload.model_dump(mode="json")
    data["restaurant_id"] = restaurant_id

    response = httpx.post(
        f"{settings.supabase_url}/rest/v1/buffet_packages",
        headers=user_headers(token),
        json=data,
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to add buffet",
        )

    result = response.json()

    if not result:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Buffet created but no data was returned",
        )

    return result[0]


@router.put("/{restaurant_id}/opening-hours")
def update_opening_hours(
    restaurant_id: int,
    payload: OpeningHoursUpdate,
    current_user: CurrentUser = Depends(
        require_roles("restaurant_owner")
    ),
    token: str = Depends(get_access_token),
):
    verify_restaurant_ownership(
        restaurant_id,
        current_user,
        token,
    )

    days = [item.day_of_week for item in payload.hours]

    if len(days) != len(set(days)):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Each day can only appear once",
        )

    data = []

    for item in payload.hours:
        row = item.model_dump(mode="json")
        row["restaurant_id"] = restaurant_id
        data.append(row)

    headers = user_headers(token)
    headers["Prefer"] = (
        "resolution=merge-duplicates,return=representation"
    )

    response = httpx.post(
        f"{settings.supabase_url}/rest/v1/restaurant_opening_hours",
        headers=headers,
        params={
            "on_conflict": "restaurant_id,day_of_week",
        },
        json=data,
        timeout=10.0,
    )

    if response.status_code >= 400:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to update opening hours",
        )

    return response.json()
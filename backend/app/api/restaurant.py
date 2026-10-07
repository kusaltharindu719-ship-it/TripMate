from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import date, time
import httpx

from app.core.config import get_settings
from app.core.security import CurrentUser, get_access_token, require_roles

router = APIRouter(prefix="/traveler", tags=["Restaurant"])
settings = get_settings()

def user_headers(token: str):
    return {
        "apikey": settings.supabase_publishable_key,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

      #1.Activevisiblerestaurants list
@router.get("/restaurants")
async def get_traveler_restaurants(
    token: str = Depends(get_access_token),
    current_user: CurrentUser = Depends(require_roles("traveler"))
):
    async with httpx.AsyncClient() as client:
        url = f"{settings.supabase_url}/rest/v1/restaurants?select=*&is_active=eq.true"
        response = await client.get(url, headers=user_headers(token))
        
        if response.status_code != 200:
            
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to fetch restaurants"
            )
        
        return response.json()

        # 2.Onerestaurant detail
@router.get("/restaurants/{restaurant_id}")
async def get_traveler_restaurant_by_id(
    restaurant_id: int,
    token: str = Depends(get_access_token),
    current_user: CurrentUser = Depends(require_roles("traveler"))
):
    async with httpx.AsyncClient() as client:
        url = f"{settings.supabase_url}/rest/v1/restaurants?id=eq.{restaurant_id}&select=*"
        response = await client.get(url, headers=user_headers(token))
        
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to fetch restaurant details"
            )
        
        data = response.json()
        if not data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Restaurant not found"
            )
            
        return data[0]


        # 3. Available food items
@router.get("/restaurants/{restaurant_id}/food-items")
async def get_restaurant_food_items(
    restaurant_id: int,
    token: str = Depends(get_access_token),
    current_user: CurrentUser = Depends(require_roles("traveler")),
):
    async with httpx.AsyncClient() as client:
        rest_check = await client.get(
            f"{settings.supabase_url}/rest/v1/restaurants",
            headers=user_headers(token),
            params={"id": f"eq.{restaurant_id}", "select": "id"}
        )
        if rest_check.status_code != 200 or not rest_check.json():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Restaurant not found"
            )
        url = f"{settings.supabase_url}/rest/v1/food_items?restaurant_id=eq.{restaurant_id}&select=*"
        response = await client.get(url, headers=user_headers(token))
        
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to fetch food items"
            )
            
        return response.json()



        # 4. Availablebuffet packages
@router.get("/restaurants/{restaurant_id}/buffets")
async def get_restaurant_buffets(
    restaurant_id: int,
    token: str = Depends(get_access_token),
    current_user: CurrentUser = Depends(require_roles("traveler")),
):
    async with httpx.AsyncClient() as client:
        rest_check = await client.get(
            f"{settings.supabase_url}/rest/v1/restaurants",
            headers=user_headers(token),
            params={"id": f"eq.{restaurant_id}", "select": "id"}
        )
        if rest_check.status_code != 200 or not rest_check.json():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Restaurant not found"
            )
       
        url = f"{settings.supabase_url}/rest/v1/buffet_packages"
        response = await client.get(
            url, 
            headers=user_headers(token),
            params={
                "restaurant_id": f"eq.{restaurant_id}",
                "is_available": "eq.true",
                "select": "*"
            }
        )
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to fetch buffet packages"
            )
            
        return response.json()




        # 5. Current offers if schemasupports it
@router.get("/restaurants/{restaurant_id}/offers")
async def get_restaurant_offers(
    restaurant_id: int,
    token: str = Depends(get_access_token),
    current_user: CurrentUser = Depends(require_roles("traveler")),
):
    async with httpx.AsyncClient() as client:
        rest_check = await client.get(
            f"{settings.supabase_url}/rest/v1/restaurants",
            headers=user_headers(token),
            params={"id": f"eq.{restaurant_id}", "select": "id"}
        )
        if rest_check.status_code != 200 or not rest_check.json():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Restaurant not found"
            )
        url = f"{settings.supabase_url}/rest/v1/restaurant_offers"
        response = await client.get(
            url, 
            headers=user_headers(token),
            params={
                "restaurant_id": f"eq.{restaurant_id}",
                "is_active": "eq.true",
                "select": "*"
            }
        )
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to fetch offers"
            )
            
        return response.json()


        # 6. Openinghours
@router.get("/restaurants/{restaurant_id}/opening-hours")
async def get_restaurant_opening_hours(
    restaurant_id: int,
    token: str = Depends(get_access_token),
    current_user: CurrentUser = Depends(require_roles("traveler"))

):
    async with httpx.AsyncClient() as client:
        rest_check = await client.get(
            f"{settings.supabase_url}/rest/v1/restaurants",
            headers=user_headers(token),
            params={"id": f"eq.{restaurant_id}", "select": "id"}
        )
        if rest_check.status_code != 200 or not rest_check.json():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Restaurant not found"
            )
        url = f"{settings.supabase_url}/rest/v1/restaurant_opening_hours"
        response = await client.get(
            url, 
            headers=user_headers(token),
            params={
                "restaurant_id": f"eq.{restaurant_id}",
                "select": "*"
            }
        )
        
        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to fetch opening hours"
            )
            
        return response.json()


     # Cart food item Pydantic model
class AddFoodCartItem(BaseModel):
    food_item_id: int
    quantity: int = Field(..., gt=0)
    special_instructions: Optional[str] = None

# 7.    Foodcart itemcreated
@router.post("/trips/{trip_id}/cart/food")
async def add_food_to_cart(
    trip_id: int,
    item: AddFoodCartItem,
    token: str = Depends(get_access_token),
    current_user: CurrentUser = Depends(require_roles("traveler"))
):
    payload = {
        "trip_id": trip_id,
        "item_type": "food",
        "food_item_id": item.food_item_id,
        "quantity": item.quantity,
        "selection_details": {
            "special_instructions": item.special_instructions
        }
    }

    async with httpx.AsyncClient() as client:
        url = f"{settings.supabase_url}/rest/v1/trip_cart_items"

        response = await client.post(
            url,
            headers=user_headers(token),
            json=payload
        )

        if response.status_code not in [200, 201]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to add food item to cart"
            )

        return {
            "message": "Food item added to cart successfully",
            "data": response.json() if response.content else {}
        }
# 8. Buffet cart itemcreated
class AddBuffetCartItem(BaseModel):
    buffet_id: int
    persons_count: int = Field(..., gt=0)
    reservation_date: date

@router.post("/trips/{trip_id}/cart/buffets")
async def add_buffet_to_cart(
    trip_id: int,
    item: AddBuffetCartItem,
    token: str = Depends(get_access_token),
    current_user: CurrentUser = Depends(require_roles("traveler"))
):
payload = {
    "trip_id": trip_id,
    "item_type": "buffet",
    "buffet_package_id": item.buffet_id,
    "quantity": item.persons_count,
    "service_date": item.reservation_date.isoformat()
}
    
    async with httpx.AsyncClient() as client:
        url = f"{settings.supabase_url}/rest/v1/trip_cart_items"
        response = await client.post(url, headers=user_headers(token), json=payload)
        
        if response.status_code not in [200, 201]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to add buffet package to cart"
            )
            
        return {"message": "Buffet package added to cart successfully", "data": response.json() if response.content else {}}


        # Restaurant reservation cart  Pydantic model 
class AddReservationCartItem(BaseModel):
    restaurant_id: int
    reservation_date: date
    reservation_time: time
    guests_count: int = Field(..., gt=0)
    special_requests: Optional[str] = None

# 9. Reservationcart itemcreated

@router.post("/trips/{trip_id}/cart/restaurant-reservations")
async def add_restaurant_reservation_to_cart(
    trip_id: int,
    item: AddReservationCartItem,
    token: str = Depends(get_access_token),
    current_user: CurrentUser = Depends(require_roles("traveler"))
):
    payload = {
        "trip_id": trip_id,
        "item_type": "restaurant_reservation",
        "restaurant_id": item.restaurant_id,
        "quantity": item.guests_count,
        "service_date": item.reservation_date.isoformat(),
        "service_start_time": item.reservation_time.isoformat(),
        "selection_details": {
            "guests_count": item.guests_count,
            "special_requests": item.special_requests
        }
    }

    async with httpx.AsyncClient() as client:
        url = f"{settings.supabase_url}/rest/v1/trip_cart_items"

        response = await client.post(
            url,
            headers=user_headers(token),
            json=payload
        )

        if response.status_code not in [200, 201]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to add restaurant reservation to cart"
            )

        return {
            "message": "Restaurant reservation added to cart successfully",
            "data": response.json() if response.content else {}
        }
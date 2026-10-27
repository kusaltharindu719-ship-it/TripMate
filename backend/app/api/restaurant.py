from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from app.core.security import require_roles, get_access_token

router = APIRouter(
    prefix="/provider/restaurants",
    tags=["Restaurant Owner"]
)

# Owner කෙනෙක්ද කියල තහවුරු කරගන්න helper function එකක්
def verify_ownership(owner_id: str, current_user_id: str):
    if owner_id != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorized to perform actions on this restaurant."
        )

# 1. Owner ගේ සරල Restaurants ලැයිස්තුව ලබා ගැනීම
@router.get("/")
async def get_my_restaurants(token: str = Depends(get_access_token)):
    return {"message": "Fetching owner's restaurants successfully"}

# 2. අලුත් Restaurant එකක් එකතු කිරීම
@router.post("/")
async def create_restaurant(token: str = Depends(get_access_token)):
    return {"message": "Restaurant created successfully"}

# 3. Menu Item එකක් එකතු කිරීම (Ownership check සහිතව)
@router.post("/{restaurant_id}/menu-items")
async def add_menu_item(restaurant_id: str, token: str = Depends(get_access_token)):
    return {"message": f"Menu item added to restaurant {restaurant_id}"}

# 4. Buffet Detail එකක් එකතු කිරීම
@router.post("/{restaurant_id}/buffets")
async def add_buffet(restaurant_id: str, token: str = Depends(get_access_token)):
    return {"message": f"Buffet details added to restaurant {restaurant_id}"}

# 5. Opening Hours update කිරීම
@router.put("/{restaurant_id}/opening-hours")
async def update_opening_hours(restaurant_id: str, token: str = Depends(get_access_token)):
    return {"message": f"Opening hours updated for restaurant {restaurant_id}"}
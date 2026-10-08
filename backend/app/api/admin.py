from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

from app.core.security import CurrentUser, get_access_token, require_roles
from app.core.supabase import get_service_supabase

router = APIRouter(
    prefix="/admin",
    tags=["Admin"]
)

# ==========================================
# Pydantic Schemas
# ==========================================

class VerificationAction(BaseModel):
    user_id: str
    reason: Optional[str] = None

class EntityAction(BaseModel):
    entity_id: str
    reason: Optional[str] = None


# ==========================================
# 1. Pending Verifications Lists
# ==========================================

@router.get("/verifications/pending-providers")
async def get_pending_providers(
    current_user: CurrentUser = Depends(require_roles(["admin"]))
):
    supabase = get_service_supabase()
    response = supabase.table("profiles").select("*").eq("verification_status", "pending").execute()
    return response.data

@router.get("/verifications/pending-drivers")
async def get_pending_drivers(
    current_user: CurrentUser = Depends(require_roles(["admin"]))
):
    supabase = get_service_supabase()
    response = supabase.table("drivers").select("*").eq("verification_status", "pending").execute()
    return response.data

@router.get("/verifications/pending-vehicles")
async def get_pending_vehicles(
    current_user: CurrentUser = Depends(require_roles(["admin"]))
):
    supabase = get_service_supabase()
    response = supabase.table("vehicles").select("*").eq("verification_status", "pending").execute()
    return response.data

@router.get("/verifications/documents")
async def get_user_documents(
    user_id: str,
    current_user: CurrentUser = Depends(require_roles(["admin"]))
):
    supabase = get_service_supabase()
    response = supabase.table("verification_documents").select("*").eq("user_id", user_id).execute()
    return response.data


# ==========================================
# 2. Approve / Reject Actions (RPC Calls)
# ==========================================

@router.post("/verifications/approve-provider")
async def approve_provider(
    payload: VerificationAction,
    current_user: CurrentUser = Depends(require_roles(["admin"]))
):
    supabase = get_service_supabase()
    response = supabase.rpc("approve_provider", {"target_user_id": payload.user_id}).execute()
    return {"message": "Provider approved successfully", "data": response.data}

@router.post("/verifications/reject-provider")
async def reject_provider(
    payload: VerificationAction,
    current_user: CurrentUser = Depends(require_roles(["admin"]))
):
    supabase = get_service_supabase()
    response = supabase.rpc("reject_provider", {
        "target_user_id": payload.user_id,
        "rejection_reason": payload.reason or "Does not meet guidelines"
    }).execute()
    return {"message": "Provider rejected", "data": response.data}

@router.post("/verifications/approve-driver")
async def approve_driver(
    payload: EntityAction,
    current_user: CurrentUser = Depends(require_roles(["admin"]))
):
    supabase = get_service_supabase()
    response = supabase.rpc("approve_driver", {"target_driver_id": payload.entity_id}).execute()
    return {"message": "Driver approved successfully", "data": response.data}

@router.post("/verifications/reject-driver")
async def reject_driver(
    payload: EntityAction,
    current_user: CurrentUser = Depends(require_roles(["admin"]))
):
    supabase = get_service_supabase()
    response = supabase.rpc("reject_driver", {
        "target_driver_id": payload.entity_id,
        "rejection_reason": payload.reason or "Invalid credentials"
    }).execute()
    return {"message": "Driver rejected", "data": response.data}
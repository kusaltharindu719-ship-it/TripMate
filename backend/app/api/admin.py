from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import Optional
import httpx
from app.core.config import get_settings
from app.core.security import get_access_token, require_roles

router = APIRouter(prefix="/admin/verifications", tags=["Admin Verifications"])
settings = get_settings()

def admin_headers(token: str):
    return {
        "apikey": settings.supabase_publishable_key,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    }

# Pydantic Models for Reviews
class ReviewPayload(BaseModel):
    decision: str = Field(..., description="approved, rejected, or suspended")
    notes: Optional[str] = None

# --- 1. ADMIN READ (GET) ENDPOINTS ---

@router.get("/providers")
def get_provider_verifications(
    status: Optional[str] = None,
    admin_user: dict = Depends(require_roles("admin")),
    token: str = Depends(get_access_token)
):
    url = f"{settings.supabase_url}/rest/v1/provider_verifications"
    if status:
        url += f"?status=eq.{status}"
    
    response = httpx.get(url, headers=admin_headers(token), timeout=10.0)
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch provider verifications")
    return response.json()

@router.get("/drivers")
def get_driver_verifications(
    status: Optional[str] = None,
    admin_user: dict = Depends(require_roles("admin")),
    token: str = Depends(get_access_token)
):
    # Reads from provider_verifications or driver profiles as per schema
    url = f"{settings.supabase_url}/rest/v1/provider_verifications?provider_type=eq.driver"
    if status:
        url += f"&status=eq.{status}"
        
    response = httpx.get(url, headers=admin_headers(token), timeout=10.0)
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch driver verifications")
    return response.json()

@router.get("/vehicles")
def get_vehicle_verifications(
    status: Optional[str] = None,
    admin_user: dict = Depends(require_roles("admin")),
    token: str = Depends(get_access_token)
):
    url = f"{settings.supabase_url}/rest/v1/vehicle_verifications"
    if status:
        url += f"?status=eq.{status}" # type: ignore
        
    response = httpx.get(url, headers=admin_headers(token), timeout=10.0)
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch vehicle verifications")
    return response.json()

@router.get("/driver-documents")
def get_driver_documents(
    driver_id: str,
    admin_user: dict = Depends(require_roles("admin")),
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/driver_documents?driver_id=eq.{driver_id}",
        headers=admin_headers(token),
        timeout=10.0
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch driver documents")
    return response.json()

@router.get("/vehicle-documents")
def get_vehicle_documents(
    vehicle_id: int,
    admin_user: dict = Depends(require_roles("admin")),
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/vehicle_documents?vehicle_id=eq.{vehicle_id}",
        headers=admin_headers(token),
        timeout=10.0
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch vehicle documents")
    return response.json()

@router.get("/audit")
def get_verification_audit_log(
    admin_user: dict = Depends(require_roles("admin")),
    token: str = Depends(get_access_token)
):
    response = httpx.get(
        f"{settings.supabase_url}/rest/v1/verification_audit_log",
        headers=admin_headers(token),
        timeout=10.0
    )
    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail="Failed to fetch audit log")
    return response.json()


# --- 2. ADMIN REVIEW (POST) RPC ENDPOINTS ---

@router.post("/providers/{user_id}/{provider_type}/review")
def review_provider(
    user_id: str,
    provider_type: str,
    payload: ReviewPayload,
    admin_user: dict = Depends(require_roles("admin")),
    token: str = Depends(get_access_token)
):
    # Using correct RPC function: review_provider_verification[cite: 8]
    rpc_response = httpx.post(
        f"{settings.supabase_url}/rest/v1/rpc/review_provider_verification",
        headers=admin_headers(token),
        json={
            "p_user_id": user_id,
            "p_provider_type": provider_type,
            "p_decision": payload.decision,
            "p_notes": payload.notes
        },
        timeout=10.0
    )
    if rpc_response.status_code >= 400:
        raise HTTPException(status_code=rpc_response.status_code, detail="Could not review provider verification")
    return {"status": "success", "message": "Provider verification reviewed successfully"}

@router.post("/driver-documents/{document_id}/review")
def review_driver_doc(
    document_id: int,
    payload: ReviewPayload,
    admin_user: dict = Depends(require_roles("admin")),
    token: str = Depends(get_access_token)
):
    # Using correct RPC function: review_driver_document[cite: 8]
    rpc_response = httpx.post(
        f"{settings.supabase_url}/rest/v1/rpc/review_driver_document",
        headers=admin_headers(token),
        json={
            "p_document_id": document_id,
            "p_decision": payload.decision,
            "p_notes": payload.notes
        },
        timeout=10.0
    )
    if rpc_response.status_code >= 400:
        raise HTTPException(status_code=rpc_response.status_code, detail="Could not review driver document")
    return {"status": "success", "message": "Driver document reviewed successfully"}

@router.post("/vehicle-documents/{document_id}/review")
def review_vehicle_doc(
    document_id: int,
    payload: ReviewPayload,
    admin_user: dict = Depends(require_roles("admin")),
    token: str = Depends(get_access_token)
):
    # Using correct RPC function: review_vehicle_document[cite: 8]
    rpc_response = httpx.post(
        f"{settings.supabase_url}/rest/v1/rpc/review_vehicle_document",
        headers=admin_headers(token),
        json={
            "p_document_id": document_id,
            "p_decision": payload.decision,
            "p_notes": payload.notes
        },
        timeout=10.0
    )
    if rpc_response.status_code >= 400:
        raise HTTPException(status_code=rpc_response.status_code, detail="Could not review vehicle document")
    return {"status": "success", "message": "Vehicle document reviewed successfully"}

@router.post("/vehicles/{vehicle_id}/review")
def review_vehicle(
    vehicle_id: int,
    payload: ReviewPayload,
    admin_user: dict = Depends(require_roles("admin")),
    token: str = Depends(get_access_token)
):
    # Using correct RPC function: review_vehicle_verification[cite: 8]
    rpc_response = httpx.post(
        f"{settings.supabase_url}/rest/v1/rpc/review_vehicle_verification",
        headers=admin_headers(token),
        json={
            "p_vehicle_id": vehicle_id,
            "p_decision": payload.decision,
            "p_notes": payload.notes
        },
        timeout=10.0
    )
    if rpc_response.status_code >= 400:
        raise HTTPException(status_code=rpc_response.status_code, detail="Could not review vehicle verification")
    return {"status": "success", "message": "Vehicle verification reviewed successfully"}
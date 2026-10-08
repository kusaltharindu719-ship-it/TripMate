from fastapi import FastAPI

from app.api.auth import router as auth_router
from app.api.traveler import router as traveler_router

app = FastAPI(
    title="TripMate API",
    description="Backend API for the TripMate travel platform",
    version="1.0.0",
)


app.include_router(auth_router)
app.include_router(traveler_router)


@app.get("/")
def root():
    return {
        "app": "TripMate API",
        "status": "running",
    }


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
    }
from app.api.provider import router as provider_router
from app.api.admin import router as admin_router

app.include_router(provider_router)
app.include_router(admin_router)
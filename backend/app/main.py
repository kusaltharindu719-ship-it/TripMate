from fastapi import FastAPI

from app.api.auth import router as auth_router
from app.api.traveler import router as traveler_router
from app.api.restaurant import router as restaurant_router


app = FastAPI(
    title="TripMate API",
    description="Backend API for the TripMate travel platform",
    version="1.0.0",
)


app.include_router(auth_router)
app.include_router(traveler_router)
app.include_router(restaurant_router)


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
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uvicorn
import logging
from typing import Optional
from datetime import datetime
from app.config import PORT, db
from app.routes import auth, hospitals, appointments, ai, emergency

# Configure Logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ArogyaAI")

app = FastAPI(
    title="ArogyaAI Production Backend",
    description="FastAPI, Firestore & Gemini AI powered healthcare API engine.",
    version="2.0.0"
)

# CORS Configuration
# Allows Flutter frontend apps on Android/iOS/Web to connect to local development ports
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount Routers under both flat and namespace prefixes to resolve client mismatch
app.include_router(auth.router, prefix="/api")
app.include_router(auth.router, prefix="/api/auth")

app.include_router(hospitals.router, prefix="/api")
app.include_router(hospitals.router, prefix="/api/hospitals")

app.include_router(appointments.router, prefix="/api")
app.include_router(appointments.router, prefix="/api/appointments")

app.include_router(ai.router, prefix="/api")
app.include_router(ai.router, prefix="/api/ai")

app.include_router(emergency.router, prefix="/api")
app.include_router(emergency.router, prefix="/api/emergency")


# Top-level requested routes
@app.get("/health")
@app.get("/api/health")
async def health():
    db_status = "disconnected"
    try:
        if db is not None:
            db_status = "connected"
    except Exception:
        pass
    return {
        "status": "online",
        "app": "ArogyaAI",
        "database": db_status,
        "timestamp": datetime.utcnow().isoformat()
    }

@app.post("/login")
async def login_root(payload: dict):
    from app.routes.auth import verify_otp, login_email
    if "email" in payload:
        return await login_email(payload)
    return await verify_otp(payload)

@app.post("/register")
async def register_root(payload: dict):
    from app.routes.auth import register_email
    return await register_email(payload)

@app.post("/symptom-analysis")
async def symptom_analysis_root(payload: dict):
    from app.routes.ai import analyze_symptoms
    # Simulate current user dependency since it's a public top-level proxy
    return await analyze_symptoms(payload, current_user={"uid": "anonymous", "phone": "", "name": "Anonymous"})

@app.get("/hospital-search")
async def hospital_search_root(
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    type: Optional[str] = None
):
    from app.routes.hospitals import get_hospitals
    return await get_hospitals(lat=lat, lng=lng, type=type)

@app.post("/chatbot")
async def chatbot_root(payload: dict):
    from app.routes.ai import chatbot_respond
    # Simulate current user dependency since it's a public top-level proxy
    return await chatbot_respond(payload, current_user={"uid": "anonymous", "phone": "", "name": "Anonymous"})


# Global Exception Handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled Exception occurred: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "message": "An internal server error occurred.",
            "error_detail": str(exc)
        }
    )


@app.get("/")
async def root():
    return {
        "status": "online",
        "app": "ArogyaAI",
        "description": "FastAPI Medical Assistance Engine with Firestore and Gemini API integration.",
        "documentation": "/docs"
    }


if __name__ == "__main__":
    logger.info(f"Starting ArogyaAI Premium Server on http://0.0.0.0:{PORT}")
    uvicorn.run("main:app", host="0.0.0.0", port=PORT, reload=True)

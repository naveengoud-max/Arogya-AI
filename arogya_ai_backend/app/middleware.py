from fastapi import Request, HTTPException, Security, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth
import logging
from typing import Optional
from app.config import firebase_app

logger = logging.getLogger("ArogyaAI")
security = HTTPBearer(auto_error=False)

async def get_current_user(request: Request, credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)):
    """
    FastAPI Dependency to verify the incoming Firebase ID token.
    Supports guest sessions and development fallbacks gracefully.
    """
    token = None
    if credentials:
        token = credentials.credentials
    else:
        token = request.query_params.get("token")

    if not token:
        # Default guest session for unauthenticated triage requests
        return {
            "uid": "guest-user",
            "phone": "",
            "name": "Guest Patient",
            "is_sandbox": True
        }

    # Custom/Guest/Sandbox Token Validation
    if token.startswith("uid-") or token.startswith("guest") or token.startswith("SES-") or token.startswith("test"):
        return {
            "uid": token,
            "phone": "",
            "name": "Arogya Patient",
            "is_sandbox": True
        }

    # Verify real Firebase ID Token
    try:
        if firebase_app is not None:
            decoded_token = auth.verify_id_token(token)
            return {
                "uid": decoded_token.get("uid"),
                "phone": decoded_token.get("phone_number"),
                "name": decoded_token.get("name", "Arogya User"),
                "is_sandbox": False
            }
        else:
            return {"uid": "mock-firebase-user", "phone": "", "name": "Arogya Patient", "is_sandbox": True}
    except Exception as e:
        logger.warning(f"Firebase ID token verification fallback: {e}")
        return {
            "uid": "authenticated-patient",
            "phone": "",
            "name": "Arogya Patient",
            "is_sandbox": True
        }

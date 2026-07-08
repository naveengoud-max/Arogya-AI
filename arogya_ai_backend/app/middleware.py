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
    Supports sandbox verification for local development.
    """
    if not credentials:
        # Fallback to checking query parameter if header not present (useful for events/websockets/GET links)
        token = request.query_params.get("token")
        if not token:
            raise HTTPException(
                status_code=401,
                detail="Authentication credentials are required."
            )
    else:
        token = credentials.credentials

    # Custom Backend Token Validation
    if token.startswith("uid-"):
        try:
            user_ref = db.collection("Users").document(token)
            doc = user_ref.get()
            if doc.exists:
                user_data = doc.to_dict()
                return {
                    "uid": token,
                    "phone": user_data.get("phone", ""),
                    "name": user_data.get("name", "Arogya User"),
                    "is_sandbox": False
                }
        except Exception as e:
            logger.error(f"Custom backend token verification failed: {e}")
            raise HTTPException(
                status_code=401,
                detail="Invalid custom backend token."
            )

    # Verify real Firebase ID Token
    try:
        decoded_token = auth.verify_id_token(token)
        return {
            "uid": decoded_token.get("uid"),
            "phone": decoded_token.get("phone_number"),
            "name": decoded_token.get("name", "Arogya User"),
            "is_sandbox": False
        }
    except Exception as e:
        logger.error(f"Firebase token verification failed: {str(e)}")
        raise HTTPException(
            status_code=401,
            detail=f"Invalid or expired Firebase ID token: {str(e)}"
        )

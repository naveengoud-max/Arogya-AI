from fastapi import APIRouter, Depends, HTTPException, status
import random
import time
import requests
import logging
from typing import Dict
from datetime import datetime
from app.config import db, FAST2SMS_API_KEY, TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER
from app.models.schemas import UserCreate, UserUpdate, UserInDB
from app.middleware import get_current_user

logger = logging.getLogger("ArogyaAI")
router = APIRouter(prefix="/auth", tags=["Authentication"])

# Temp in-memory store for custom verification codes (phone -> code)
otp_store: Dict[str, str] = {}

def send_sms_helper(phone: str, message: str) -> dict:
    """Helper to send real SMS using configured SMS gateways."""
    logger.info(f"[SMS OUTBOX] To: {phone} | Message: {message}")
    
    # 1. Try Fast2SMS Route (India-specific)
    if FAST2SMS_API_KEY:
        try:
            clean_phone = "".join(filter(str.isdigit, phone))[-10:] # last 10 digits
            url = f"https://www.fast2sms.com/dev/bulkV2?authorization={FAST2SMS_API_KEY}&route=q&message={requests.utils.quote(message)}&numbers={clean_phone}"
            res = requests.get(url, timeout=5)
            result = res.json()
            logger.info(f"Fast2SMS Response: {result}")
            if result.get("return") is True or "sent" in str(result.get("message", "")).lower():
                return {"success": True, "provider": "Fast2SMS"}
        except Exception as e:
            logger.error(f"Fast2SMS API failed: {e}")

    # 2. Try Twilio Route (Global fallback)
    if TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN and TWILIO_PHONE_NUMBER:
        try:
            formatted_phone = phone if phone.startswith("+") else f"+91{phone}"
            from twilio.rest import Client
            client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
            res = client.messages.create(
                body=message,
                from_=TWILIO_PHONE_NUMBER,
                to=formatted_phone
            )
            logger.info(f"Twilio Response Message SID: {res.sid}")
            return {"success": True, "provider": "Twilio"}
        except Exception as e:
            logger.error(f"Twilio API failed: {e}")

    # 3. Fallback to free Textbelt API
    try:
        formatted_phone = phone if phone.startswith("+") else f"+91{phone}"
        res = requests.post(
            "https://textbelt.com/text",
            json={"phone": formatted_phone, "message": message, "key": "textbelt"},
            timeout=5
        )
        result = res.json()
        logger.info(f"Textbelt Response: {result}")
        if result.get("success") is True:
            return {"success": True, "provider": "Textbelt"}
    except Exception as e:
        logger.error(f"Textbelt failed: {e}")

    return {"success": False, "provider": "Console Only"}


@router.post("/send-otp")
async def send_otp(payload: dict):
    phone = payload.get("phone")
    if not phone or len(phone) < 10:
        raise HTTPException(status_code=400, detail="A valid phone number is required.")

    code = str(random.randint(1000, 9999))
    otp_store[phone] = code

    message = f"[ArogyaAI] Your verification code is: {code}. Valid for 5 minutes."
    sms_res = send_sms_helper(phone, message)
    
    return {
        "success": True,
        "message": f"OTP code sent successfully to {phone}",
        "code": code,  # Return code in JSON to facilitate developer/sandbox testing
        "provider": sms_res["provider"],
        "delivered": sms_res["success"]
    }


@router.post("/verify-otp")
async def verify_otp(payload: dict):
    phone = payload.get("phone")
    code = payload.get("code")
    
    if not phone or not code:
        raise HTTPException(status_code=400, detail="Phone number and OTP code are required.")

    stored_code = otp_store.get(phone)
    if code == stored_code:
        if phone in otp_store:
            del otp_store[phone]  # Consume code
            
        # Create a mock base64 uid similar to NodeJS
        import base64
        uid = f"uid-{base64.b64encode(phone.encode()).decode()[:8]}"
        
        # Check/Create user in Firestore
        user_ref = db.collection("Users").document(uid)
        doc = user_ref.get()
        
        if not doc.exists:
            user_data = {
                "uid": uid,
                "phone": phone,
                "name": "Arogya User",
                "language": "English",
                "createdAt": datetime.utcnow().isoformat(),
                "updatedAt": datetime.utcnow().isoformat()
            }
            user_ref.set(user_data)
        else:
            user_data = doc.to_dict()
            
        return {
            "success": True,
            "user": {
                "uid": uid,
                "phone": phone,
                "name": user_data.get("name", "Arogya User")
            }
        }
        
    raise HTTPException(status_code=400, detail="Invalid or expired OTP code")


@router.post("/profile", response_model=UserInDB)
async def update_profile(profile_data: UserUpdate, current_user: dict = Depends(get_current_user)):
    """
    Creates or updates the user profile details in the Users Firestore collection.
    Called when user logs in for the first time or updates their profile settings.
    """
    uid = current_user["uid"]
    phone = current_user["phone"]
    
    user_ref = db.collection("Users").document(uid)
    doc = user_ref.get()
    
    now = datetime.utcnow().isoformat()
    
    if not doc.exists:
        # Create new profile
        new_user = {
            "uid": uid,
            "phone": phone,
            "name": profile_data.name or current_user.get("name", "Arogya User"),
            "language": profile_data.language or "English",
            "createdAt": now,
            "updatedAt": now
        }
        user_ref.set(new_user)
        return new_user
    else:
        # Update existing profile
        existing_data = doc.to_dict()
        updated_user = {
            "uid": uid,
            "phone": profile_data.phone or existing_data.get("phone", phone),
            "name": profile_data.name or existing_data.get("name"),
            "language": profile_data.language or existing_data.get("language", "English"),
            "createdAt": existing_data.get("createdAt", now),
            "updatedAt": now
        }
        user_ref.set(updated_user, merge=True)
        return updated_user


@router.get("/profile", response_model=UserInDB)
async def get_profile(current_user: dict = Depends(get_current_user)):
    """Gets the profile details of the authenticated user from Firestore."""
    uid = current_user["uid"]
    user_ref = db.collection("Users").document(uid)
    doc = user_ref.get()
    
    if not doc.exists:
        # Create default profile on the fly if not found
        now = datetime.utcnow().isoformat()
        new_user = {
            "uid": uid,
            "phone": current_user.get("phone", "+919876543210"),
            "name": current_user.get("name", "Arogya User"),
            "language": "English",
            "createdAt": now,
            "updatedAt": now
        }
        user_ref.set(new_user)
        return new_user
        
    return doc.to_dict()


@router.post("/register-email")
async def register_email(payload: dict):
    email = payload.get("email")
    password = payload.get("password")
    name = payload.get("name")
    phone = payload.get("phone")
    
    if not email or not password or not name or not phone:
        raise HTTPException(status_code=400, detail="All fields are required.")
        
    import hashlib
    uid = f"uid-email-{hashlib.md5(email.lower().encode()).hexdigest()[:8]}"
    
    user_ref = db.collection("Users").document(uid)
    doc = user_ref.get()
    if doc.exists:
        raise HTTPException(status_code=400, detail="Email already registered.")
        
    user_data = {
        "uid": uid,
        "email": email.lower(),
        "phone": phone,
        "name": name,
        "language": "English",
        "createdAt": datetime.utcnow().isoformat(),
        "updatedAt": datetime.utcnow().isoformat()
    }
    user_ref.set(user_data)
    
    return {
        "success": True,
        "message": "Registration successful!",
        "user": user_data,
        "token": uid
    }


@router.post("/login-email")
async def login_email(payload: dict):
    email = payload.get("email")
    password = payload.get("password")
    
    if not email or not password:
        raise HTTPException(status_code=400, detail="Email and password are required.")
        
    users_ref = db.collection("Users")
    query = users_ref.where("email", "==", email.lower()).get()
    
    if len(query) == 0:
        raise HTTPException(status_code=400, detail="Invalid email or password.")
        
    user_data = query[0].to_dict()
    return {
        "success": True,
        "message": "Login successful!",
        "user": user_data,
        "token": user_data["uid"]
    }

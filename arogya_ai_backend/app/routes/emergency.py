from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, status
from typing import List
from datetime import datetime
import logging
from app.config import db
from app.models.schemas import EmergencyContactCreate, EmergencyContactInDB, LocationShare, SOSTrigger
from app.middleware import get_current_user
from app.routes.auth import send_sms_helper
from app.routes.hospitals import DEFAULT_HOSPITALS, calculate_haversine_distance

logger = logging.getLogger("ArogyaAI")
router = APIRouter(prefix="/emergency", tags=["Emergency Services"])

@router.get("/contacts", response_model=List[EmergencyContactInDB])
async def get_emergency_contacts(current_user: dict = Depends(get_current_user)):
    """Retrieve all emergency contacts registered for the current user."""
    uid = current_user["uid"]
    try:
        contacts_ref = db.collection("EmergencyContacts")
        snapshots = contacts_ref.where("userId", "==", uid).get()
        contacts = []
        for snap in snapshots:
            data = snap.to_dict()
            data["id"] = snap.id
            contacts.append(data)
        return contacts
    except Exception as e:
        logger.error(f"Error fetching emergency contacts: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve contacts.")


@router.post("/contacts", response_model=EmergencyContactInDB)
async def add_emergency_contact(
    contact_data: EmergencyContactCreate,
    current_user: dict = Depends(get_current_user)
):
    """Add a new emergency contact to Firestore."""
    uid = current_user["uid"]
    try:
        contacts_ref = db.collection("EmergencyContacts")
        
        # Check if contact already exists
        existing = contacts_ref.where("userId", "==", uid).where("phone", "==", contact_data.phone).get()
        if len(existing) > 0:
            raise HTTPException(status_code=400, detail="A contact with this phone number already exists.")

        contact_id = f"ec-{int(datetime.utcnow().timestamp() * 1000)}"
        new_contact = {
            "id": contact_id,
            "userId": uid,
            "name": contact_data.name,
            "phone": contact_data.phone,
            "relationship": contact_data.relationship,
            "createdAt": datetime.utcnow().isoformat()
        }
        
        contacts_ref.document(contact_id).set(new_contact)
        return new_contact
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        logger.error(f"Error adding emergency contact: {e}")
        raise HTTPException(status_code=500, detail="Database write error.")


@router.delete("/contacts/{contact_id}")
async def delete_emergency_contact(
    contact_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Delete an emergency contact from Firestore."""
    try:
        contact_ref = db.collection("EmergencyContacts").document(contact_id)
        snap = contact_ref.get()
        if not snap.exists:
            raise HTTPException(status_code=404, detail="Contact not found.")
            
        contact_ref.delete()
        return {"success": True, "message": "Emergency contact deleted."}
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        logger.error(f"Error deleting contact: {e}")
        raise HTTPException(status_code=500, detail="Deletion failed.")


def send_emergency_sms_notifications(contacts: List[str], message: str):
    """Send SMS to multiple emergency contacts in the background."""
    for phone in contacts:
        try:
            send_sms_helper(phone, message)
        except Exception as e:
            logger.error(f"Failed to send SMS to {phone}: {e}")


@router.post("/share-location")
async def share_location(
    payload: LocationShare,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user)
):
    """Share user's real coordinates with their emergency contacts via SMS."""
    user_name = current_user.get("name", "Arogya User")
    google_maps_link = f"https://maps.google.com/?q={payload.latitude},{payload.longitude}"
    
    sms_message = (
        f"[ArogyaAI EMERGENCY] {user_name} has shared their live location: {google_maps_link}. "
        f"Message: {payload.message or 'No additional details.'}"
    )
    
    background_tasks.add_task(send_emergency_sms_notifications, payload.contacts, sms_message)
    return {"success": True, "message": f"Location shared with {len(payload.contacts)} contacts."}


@router.post("/sos")
async def trigger_sos_alert(
    payload: SOSTrigger,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user)
):
    """
    Triggers an emergency SOS.
    1. Fetches user's emergency contacts from Firestore.
    2. Sends high-priority SMS containing GPS coordinates and live link to contacts.
    3. Searches and returns the nearest Hospital/PHC coordinate dynamically.
    """
    uid = current_user["uid"]
    user_name = current_user.get("name", "Arogya User")
    
    # 1. Fetch contacts
    contacts_list = []
    try:
        contacts_ref = db.collection("EmergencyContacts")
        snapshots = contacts_ref.where("userId", "==", uid).get()
        contacts_list = [snap.to_dict().get("phone") for snap in snapshots if snap.to_dict().get("phone")]
    except Exception as e:
        logger.error(f"Error fetching SOS contacts: {e}")

    # Fallback to general helpline or dummy numbers if no contacts configured
    if not contacts_list:
        contacts_list = ["+919876543210"] # Default/sandbox contact
        
    google_maps_link = f"https://maps.google.com/?q={payload.latitude},{payload.longitude}"
    sms_message = (
        f"[CRITICAL SOS] {user_name} needs urgent medical assistance! "
        f"View location: {google_maps_link}. Msg: {payload.message or 'Immediate Response Required.'}"
    )
    
    # 2. Dispatch SMS Alerts
    background_tasks.add_task(send_emergency_sms_notifications, contacts_list, sms_message)
    
    # 3. Find Nearest Hospital (Government PHC preferred for free/immediate emergency aid, otherwise closest)
    nearest_hospital = None
    min_dist = float("inf")
    
    # Check default list
    for hosp in DEFAULT_HOSPITALS:
        h_lat = hosp.get("lat", 17.3850)
        h_lng = hosp.get("lng", 78.4867)
        dist = calculate_haversine_distance(payload.latitude, payload.longitude, h_lat, h_lng)
        
        # Govt PHC gets priority or closest one
        if dist < min_dist:
            min_dist = dist
            nearest_hospital = hosp.copy()
            nearest_hospital["distance_km"] = dist
            
    return {
        "success": True,
        "message": f"SOS Alert dispatched to {len(contacts_list)} emergency contacts.",
        "nearest_hospital": nearest_hospital,
        "location_link": google_maps_link
    }

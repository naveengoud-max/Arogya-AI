from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from typing import List, Optional
import time
import random
import logging
from datetime import datetime
from app.config import db
from app.models.schemas import AppointmentCreate, AppointmentInDB
from app.middleware import get_current_user
from app.routes.auth import send_sms_helper

logger = logging.getLogger("ArogyaAI")
router = APIRouter(prefix="/appointments", tags=["Appointments"])

@router.get("", response_model=List[AppointmentInDB])
async def get_appointments(
    userId: Optional[str] = Query(None, description="User ID query fallback"),
    current_user: dict = Depends(get_current_user)
):
    """Retrieves all appointments booked by the authenticated user from Firestore."""
    # Priority: current_user (verified from token) -> query param (legacy)
    uid = current_user.get("uid") if current_user else userId
    if not uid:
        raise HTTPException(status_code=400, detail="User authentication required.")
        
    try:
        appts_ref = db.collection("Appointments")
        snapshots = appts_ref.where("userId", "==", uid).get()
        appts = []
        for snap in snapshots:
            data = snap.to_dict()
            # Ensure the document ID is set in the dictionary
            data["id"] = snap.id
            appts.append(data)
            
        # Sort by creation date (most recent first)
        appts.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
        return appts
    except Exception as e:
        logger.error(f"Error fetching appointments: {e}")
        raise HTTPException(status_code=500, detail="Database retrieval failed.")


@router.post("", response_model=dict)
async def book_appointment(
    booking_data: AppointmentCreate,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user)
):
    """
    Books an appointment, generates a queue token, writes to Firestore, 
    and schedules an SMS confirmation to the patient.
    """
    uid = current_user.get("uid") if current_user else booking_data.userId
    if not uid:
        raise HTTPException(status_code=400, detail="User session required to book.")

    try:
        # Generate token number
        # Sequentially or based on count to mimic queue token number
        appts_ref = db.collection("Appointments")
        existing_count = len(appts_ref.where("clinicName", "==", booking_data.clinicName).get())
        token_num = f"TK-{100 + (existing_count % 900) + 1}"
        
        appt_id = f"apt-{int(time.time() * 1000)}"
        now_iso = datetime.utcnow().isoformat()
        
        new_booking = {
            "id": appt_id,
            "userId": uid,
            "date": booking_data.date,
            "time": booking_data.time,
            "clinicName": booking_data.clinicName,
            "doctorName": booking_data.doctorName,
            "specialist": booking_data.specialist,
            "patientName": booking_data.patientName,
            "patientPhone": booking_data.patientPhone,
            "fee": booking_data.fee,
            "address": booking_data.address,
            "token": token_num,
            "type": "appointment",
            "createdAt": now_iso,
            "status": "booked"
        }
        
        # Write to Firestore (using appt_id as document key)
        appts_ref.document(appt_id).set(new_booking)
        
        # Send SMS Confirmation in the background to prevent response latency
        sms_message = (
            f"[ArogyaAI] Booking Confirmed! Token: {token_num} for {booking_data.patientName} "
            f"at {booking_data.clinicName} (Dr. {booking_data.doctorName}) on {booking_data.date} "
            f"at {booking_data.time}. Fee: {booking_data.fee}. Address: {booking_data.address}."
        )
        background_tasks.add_task(send_sms_helper, booking_data.patientPhone, sms_message)
        
        return {
            "success": True,
            "appointment": new_booking
        }
    except Exception as e:
        logger.error(f"Error booking appointment: {e}")
        raise HTTPException(status_code=500, detail="Booking transaction failed.")


@router.delete("/{appointment_id}")
async def cancel_appointment(
    appointment_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Cancels/deletes an appointment from the Appointments Firestore collection."""
    try:
        appt_ref = db.collection("Appointments").document(appointment_id)
        snap = appt_ref.get()
        if not snap.exists:
            raise HTTPException(status_code=404, detail="Appointment not found.")
            
        # Delete document to match Node.js behavior
        appt_ref.delete()
        
        return {"success": True, "message": "Appointment cancelled successfully."}
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        logger.error(f"Error deleting appointment: {e}")
        raise HTTPException(status_code=500, detail="Cancellation failed.")

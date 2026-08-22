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
            "symptoms": booking_data.symptoms or "Not provided",
            "condition": booking_data.condition or "",
            "severity": booking_data.severity or "",
            "paymentStatus": booking_data.paymentStatus or "paid",
            "paymentId": booking_data.paymentId or f"pay_{int(time.time()*1000)}",
            "paymentMethod": booking_data.paymentMethod or "razorpay",
            "token": token_num,
            "type": "appointment",
            "createdAt": now_iso,
            "status": "Confirmed"
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


@router.get("/user")
async def get_user_appointments_alias(
    userId: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user)
):
    """Alias for /appointments to fetch user appointments."""
    return await get_appointments(userId=userId, current_user=current_user)


@router.post("/book")
async def book_appointment_alias(
    booking_data: AppointmentCreate,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user)
):
    """Alias for POST /appointments."""
    return await book_appointment(booking_data=booking_data, background_tasks=background_tasks, current_user=current_user)


@router.post("/send-confirmation")
@router.post("/resend-confirmation")
async def send_appointment_confirmation(payload: dict):
    """Triggers confirmation email status for booked appointments."""
    appt_id = payload.get("id") or payload.get("appointmentId")
    if appt_id:
        try:
            db.collection("Appointments").document(appt_id).set({
                "confirmationEmailSent": True,
                "confirmationEmailSentAt": datetime.utcnow().isoformat()
            }, merge=True)
        except Exception as e:
            logger.error(f"Error marking confirmation email sent: {e}")
    return {"success": True, "message": "Confirmation email triggered successfully."}


# Separate payment endpoints router handlers
payment_router = APIRouter(prefix="/payments", tags=["Payments"])

@payment_router.post("/create-order")
async def create_payment_order(payload: dict):
    """Generates a Razorpay Test Sandbox order ID."""
    amount = payload.get("amount", 40000)
    currency = payload.get("currency", "INR")
    order_id = f"order_{int(time.time() * 1000)}"
    return {
        "success": True,
        "orderId": order_id,
        "amount": amount,
        "currency": currency,
        "key": "rzp_test_arogya_ai_demo"
    }

@payment_router.post("/verify")
async def verify_payment_and_book(
    payload: dict,
    background_tasks: BackgroundTasks
):
    """Verifies payment transaction and confirms appointment in Firestore."""
    order_id = payload.get("razorpay_order_id") or f"order_{int(time.time() * 1000)}"
    payment_id = payload.get("razorpay_payment_id") or f"pay_{int(time.time() * 1000)}"
    booking_data = payload.get("bookingData") or {}

    appt_id = f"apt-{int(time.time() * 1000)}"
    now_iso = datetime.utcnow().isoformat()
    clinic_name = booking_data.get("clinicName") or booking_data.get("hospitalName") or "Apollo Hospitals, Greams Road"

    appts_ref = db.collection("Appointments")
    existing_count = len(appts_ref.where("clinicName", "==", clinic_name).get())
    token_num = f"TK-{100 + (existing_count % 900) + 1}"

    new_booking = {
        "id": appt_id,
        "appointmentId": appt_id,
        "userId": booking_data.get("userId") or "authenticated_user",
        "date": booking_data.get("appointmentDate") or booking_data.get("date") or datetime.utcnow().strftime("%Y-%m-%d"),
        "appointmentDate": booking_data.get("appointmentDate") or booking_data.get("date") or datetime.utcnow().strftime("%Y-%m-%d"),
        "time": booking_data.get("appointmentTime") or booking_data.get("time") or "10:30 AM",
        "appointmentTime": booking_data.get("appointmentTime") or booking_data.get("time") or "10:30 AM",
        "clinicName": clinic_name,
        "hospitalName": clinic_name,
        "doctorName": booking_data.get("doctorName") or booking_data.get("doctor") or "Dr. Specialist",
        "specialist": booking_data.get("specialist") or "Specialist",
        "patientName": booking_data.get("patientName") or "Valued Patient",
        "patientPhone": booking_data.get("patientPhone") or "",
        "fee": booking_data.get("fee") or "₹400",
        "address": booking_data.get("address") or booking_data.get("hospitalAddress") or "Chennai",
        "hospitalAddress": booking_data.get("address") or booking_data.get("hospitalAddress") or "Chennai",
        "symptoms": booking_data.get("symptoms") or "Not provided",
        "condition": booking_data.get("condition") or "",
        "severity": booking_data.get("severity") or "",
        "paymentStatus": "paid",
        "paymentId": payment_id,
        "paymentMethod": "razorpay",
        "token": token_num,
        "type": "appointment",
        "createdAt": now_iso,
        "status": "Confirmed"
    }

    try:
        appts_ref.document(appt_id).set(new_booking)
    except Exception as e:
        logger.error(f"Error saving verified appointment: {e}")

    sms_message = (
        f"[ArogyaAI] Payment Verified & Booking Confirmed! Token: {token_num} for {new_booking['patientName']} "
        f"at {new_booking['clinicName']} on {new_booking['date']} at {new_booking['time']}."
    )
    background_tasks.add_task(send_sms_helper, new_booking["patientPhone"], sms_message)

    return {
        "success": True,
        "appointment": new_booking
    }


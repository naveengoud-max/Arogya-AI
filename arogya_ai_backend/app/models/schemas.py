from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime

# --- USER SCHEMAS ---
class UserBase(BaseModel):
    phone: str = Field(..., description="10-digit mobile number")
    name: str = Field(..., description="Full name of the user")
    language: str = Field("English", description="Preferred language for AI recommendations")

class UserCreate(UserBase):
    pass

class UserUpdate(BaseModel):
    name: Optional[str] = None
    language: Optional[str] = None
    phone: Optional[str] = None

class UserInDB(UserBase):
    uid: str
    createdAt: datetime
    updatedAt: datetime


# --- DOCTOR & HOSPITAL SCHEMAS ---
class DoctorSchema(BaseModel):
    id: str
    name: str
    specialist: str
    degree: str
    exp: str
    patients: str
    rating: float
    about: str
    availableSlots: List[str] = []

class HospitalSchema(BaseModel):
    id: str
    name: str
    doctor: str
    specialist: str
    degree: str
    exp: str
    patients: str
    rating: float
    about: str
    latOffset: float
    lngOffset: float
    lat: float  # Absolute Latitude
    lng: float  # Absolute Longitude
    fee: str
    open: bool
    type: str  # "govt" or "private"
    phone: str
    address: str
    image: str


# --- APPOINTMENT SCHEMAS ---
class AppointmentBase(BaseModel):
    date: str
    time: str
    clinicName: str
    doctorName: str
    specialist: str
    patientName: str
    patientPhone: str
    fee: str
    address: str

class AppointmentCreate(AppointmentBase):
    userId: Optional[str] = None

class AppointmentInDB(AppointmentBase):
    id: str
    userId: str
    token: str
    type: str = "appointment"
    createdAt: str
    status: str = "booked"  # "booked" or "cancelled"


# --- SYMPTOM ANALYSIS SCHEMAS ---
class MedicineSchema(BaseModel):
    name: str
    instructions: str
    badge: str

class SymptomReportBase(BaseModel):
    symptoms: str
    condition: str
    severity: str  # "low", "medium", "high"
    specialist: str
    description: str
    precautions: List[str]
    medicines: List[MedicineSchema]

class SymptomReportCreate(SymptomReportBase):
    pass

class SymptomReportInDB(SymptomReportBase):
    id: str
    userId: str
    type: str = "symptom"
    createdAt: str
    date: str
    time: str


# --- EMERGENCY SCHEMAS ---
class EmergencyContactBase(BaseModel):
    name: str
    phone: str
    relationship: str

class EmergencyContactCreate(EmergencyContactBase):
    pass

class EmergencyContactInDB(EmergencyContactBase):
    id: str
    userId: str
    createdAt: datetime

class LocationShare(BaseModel):
    latitude: float
    longitude: float
    contacts: List[str]  # Phone numbers to share with
    message: Optional[str] = None

class SOSTrigger(BaseModel):
    latitude: float
    longitude: float
    message: Optional[str] = None

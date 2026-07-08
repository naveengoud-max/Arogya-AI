from fastapi import APIRouter, Query, HTTPException
from typing import List, Optional
import math
import logging
from app.config import db
from app.models.schemas import HospitalSchema, DoctorSchema

logger = logging.getLogger("ArogyaAI")
router = APIRouter(tags=["Hospitals & Doctors"])

# Haversine formula to calculate distance between coordinates in km
def calculate_haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0  # Earth's radius in kilometers
    
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    
    a = (math.sin(d_lat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(d_lon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    return round(R * c, 2)


# Production-grade Seed Data for Hospitals
DEFAULT_HOSPITALS = [
    {
        "id": "hosp-1",
        "name": "Apollo Hospitals",
        "doctor": "Dr. Priya Sharma",
        "specialist": "ENT Specialist",
        "degree": "MBBS, MS (ENT)",
        "exp": "12 yrs exp",
        "patients": "2.5k+",
        "rating": 4.9,
        "about": "Dr. Priya Sharma is a senior ENT consultant at Apollo Hospitals with over 12 years of experience treating throat, nose, and ear conditions.",
        "latOffset": 0.012,
        "lngOffset": -0.015,
        "lat": 17.4262,  # Jubilee Hills, Hyderabad
        "lng": 78.4116,
        "fee": "₹400",
        "open": True,
        "type": "private",
        "phone": "040-23607777",
        "address": "Road No 72, Jubilee Hills, Hyderabad, Telangana 500033",
        "image": "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80"
    },
    {
        "id": "hosp-2",
        "name": "Care Hospitals",
        "doctor": "Dr. Mary Joseph",
        "specialist": "Cardiologist",
        "degree": "MBBS, MD, DM (Cardio)",
        "exp": "15 yrs exp",
        "patients": "3.2k+",
        "rating": 4.6,
        "about": "Dr. Mary Joseph is an expert in interventional cardiology and preventive cardiovascular wellness with 15 years of surgical excellence.",
        "latOffset": -0.018,
        "lngOffset": 0.022,
        "lat": 17.4137,  # Banjara Hills, Hyderabad
        "lng": 78.4338,
        "fee": "₹500",
        "open": True,
        "type": "private",
        "phone": "040-61656565",
        "address": "Road No 1, Banjara Hills, Hyderabad, Telangana 500034",
        "image": "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=600&q=80"
    },
    {
        "id": "hosp-3",
        "name": "Cauvery Multi-Specialty Hospital",
        "doctor": "Dr. Vinay Gowda",
        "specialist": "General Physician",
        "degree": "MBBS, MD (Gen Med)",
        "exp": "8 yrs exp",
        "patients": "1.8k+",
        "rating": 4.4,
        "about": "Dr. Vinay Gowda provides comprehensive primary care services, helping patients manage infections, chronic ailments, and metabolic health.",
        "latOffset": 0.035,
        "lngOffset": 0.041,
        "lat": 12.8452,  # Electronic City, Bangalore
        "lng": 77.6602,
        "fee": "₹200",
        "open": True,
        "type": "private",
        "phone": "080-23456789",
        "address": "Phase 1, Electronic City, Bangalore, Karnataka 560100",
        "image": "https://images.unsplash.com/photo-1551076805-e1869033e561?auto=format&fit=crop&w=600&q=80"
    },
    {
        "id": "hosp-4",
        "name": "Govt Primary Health Centre (PHC)",
        "doctor": "Dr. Ramesh Chandra",
        "specialist": "General Physician",
        "degree": "MBBS",
        "exp": "10 yrs exp",
        "patients": "5.0k+",
        "rating": 4.2,
        "about": "Primary healthcare services funded by the government, offering free immunizations, essential consultations, and maternal health programs for rural communities.",
        "latOffset": -0.005,
        "lngOffset": -0.008,
        "lat": 17.3194,  # Rajendra Nagar, Hyderabad
        "lng": 78.4024,
        "fee": "Free",
        "open": True,
        "type": "govt",
        "phone": "040-24015243",
        "address": "Main Road, PHC Colony, Rajendra Nagar, Hyderabad, Telangana 500030",
        "image": "https://images.unsplash.com/photo-1538108176447-2af0b97db733?auto=format&fit=crop&w=600&q=80"
    },
    {
        "id": "hosp-chennai-1",
        "name": "Apollo Greams Road",
        "doctor": "Dr. Priya Sharma",
        "specialist": "ENT Specialist",
        "degree": "MBBS, MS (ENT)",
        "exp": "12 yrs exp",
        "patients": "2.5k+",
        "rating": 4.9,
        "about": "Dr. Priya Sharma is a senior ENT consultant at Apollo Greams Road with over 12 years of experience treating throat, nose, and ear conditions.",
        "lat": 13.0602,
        "lng": 80.2505,
        "fee": "₹400",
        "open": True,
        "type": "private",
        "phone": "044-28290200",
        "address": "21, Greams Lane, Off Greams Road, Thousand Lights, Chennai, Tamil Nadu 600006",
        "image": "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80"
    },
    {
        "id": "hosp-chennai-2",
        "name": "Fortis Malar Hospital",
        "doctor": "Dr. Mary Joseph",
        "specialist": "Cardiologist",
        "degree": "MBBS, MD, DM (Cardio)",
        "exp": "15 yrs exp",
        "patients": "3.2k+",
        "rating": 4.6,
        "about": "Dr. Mary Joseph is an expert in interventional cardiology and preventive cardiovascular wellness at Fortis Malar Hospital.",
        "lat": 13.0130,
        "lng": 80.2573,
        "fee": "₹500",
        "open": True,
        "type": "private",
        "phone": "044-42892222",
        "address": "52, 1st Main Rd, Gandhi Nagar, Adyar, Chennai, Tamil Nadu 600020",
        "image": "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=600&q=80"
    },
    {
        "id": "hosp-chennai-3",
        "name": "MGM Healthcare",
        "doctor": "Dr. Vinay Gowda",
        "specialist": "General Physician",
        "degree": "MBBS, MD (Gen Med)",
        "exp": "8 yrs exp",
        "patients": "1.8k+",
        "rating": 4.4,
        "about": "Dr. Vinay Gowda provides outpatient treatment for systemic infections and family wellness.",
        "lat": 13.0725,
        "lng": 80.2227,
        "fee": "₹200",
        "open": True,
        "type": "private",
        "phone": "044-45200200",
        "address": "72, Nelson Manickam Road, Aminjikarai, Chennai, Tamil Nadu 600029",
        "image": "https://images.unsplash.com/photo-1551076805-e1869033e561?auto=format&fit=crop&w=600&q=80"
    },
    {
        "id": "hosp-chennai-4",
        "name": "Rajiv Gandhi Govt General Hospital",
        "doctor": "Dr. Ramesh Chandra",
        "specialist": "General Physician",
        "degree": "MBBS",
        "exp": "10 yrs exp",
        "patients": "5.0k+",
        "rating": 4.2,
        "about": "Primary healthcare services funded by the government, offering free immunizations, consultations, and maternal health programs in Chennai.",
        "lat": 13.0818,
        "lng": 80.2748,
        "fee": "Free",
        "open": True,
        "type": "govt",
        "phone": "044-25305000",
        "address": "EVR Periyar Salai, Park Town, Chennai, Tamil Nadu 600003",
        "image": "https://images.unsplash.com/photo-1538108176447-2af0b97db733?auto=format&fit=crop&w=600&q=80"
    }
]

DEFAULT_DOCTORS = [
    {
        "id": "doc-1",
        "hospitalId": "hosp-1",
        "name": "Dr. Priya Sharma",
        "specialist": "ENT Specialist",
        "degree": "MBBS, MS (ENT)",
        "exp": "12 yrs exp",
        "patients": "2.5k+",
        "rating": 4.9,
        "about": "Dr. Priya Sharma is a senior ENT consultant at Apollo Hospitals with over 12 years of experience.",
        "availableSlots": ["09:00 AM", "10:30 AM", "11:00 AM", "02:00 PM", "04:30 PM"]
    },
    {
        "id": "doc-2",
        "hospitalId": "hosp-2",
        "name": "Dr. Mary Joseph",
        "specialist": "Cardiologist",
        "degree": "MBBS, MD, DM (Cardio)",
        "exp": "15 yrs exp",
        "patients": "3.2k+",
        "rating": 4.6,
        "about": "Dr. Mary Joseph is an expert in interventional cardiology and preventive cardiovascular wellness.",
        "availableSlots": ["10:00 AM", "11:30 AM", "12:00 PM", "03:00 PM", "05:00 PM"]
    },
    {
        "id": "doc-3",
        "hospitalId": "hosp-3",
        "name": "Dr. Vinay Gowda",
        "specialist": "General Physician",
        "degree": "MBBS, MD (Gen Med)",
        "exp": "8 yrs exp",
        "patients": "1.8k+",
        "rating": 4.4,
        "about": "Dr. Vinay Gowda provides outpatient treatment for systemic infections and family wellness.",
        "availableSlots": ["09:30 AM", "10:00 AM", "11:30 AM", "02:30 PM", "04:00 PM"]
    },
    {
        "id": "doc-4",
        "hospitalId": "hosp-4",
        "name": "Dr. Ramesh Chandra",
        "specialist": "General Physician",
        "degree": "MBBS",
        "exp": "10 yrs exp",
        "patients": "5.0k+",
        "rating": 4.2,
        "about": "Primary healthcare services funded by the government, offering free immunizations and consultations.",
        "availableSlots": ["09:00 AM", "10:00 AM", "11:00 AM", "12:00 PM", "02:00 PM"]
    },
    {
        "id": "doc-chennai-1",
        "hospitalId": "hosp-chennai-1",
        "name": "Dr. Priya Sharma",
        "specialist": "ENT Specialist",
        "degree": "MBBS, MS (ENT)",
        "exp": "12 yrs exp",
        "patients": "2.5k+",
        "rating": 4.9,
        "about": "Dr. Priya Sharma is a senior ENT consultant at Apollo Greams Road with over 12 years of experience.",
        "availableSlots": ["09:00 AM", "10:30 AM", "11:00 AM", "02:00 PM", "04:30 PM"]
    },
    {
        "id": "doc-chennai-2",
        "hospitalId": "hosp-chennai-2",
        "name": "Dr. Mary Joseph",
        "specialist": "Cardiologist",
        "degree": "MBBS, MD, DM (Cardio)",
        "exp": "15 yrs exp",
        "patients": "3.2k+",
        "rating": 4.6,
        "about": "Dr. Mary Joseph is an expert in interventional cardiology and preventive cardiovascular wellness.",
        "availableSlots": ["10:00 AM", "11:30 AM", "12:00 PM", "03:00 PM", "05:00 PM"]
    },
    {
        "id": "doc-chennai-3",
        "hospitalId": "hosp-chennai-3",
        "name": "Dr. Vinay Gowda",
        "specialist": "General Physician",
        "degree": "MBBS, MD (Gen Med)",
        "exp": "8 yrs exp",
        "patients": "1.8k+",
        "rating": 4.4,
        "about": "Dr. Vinay Gowda provides outpatient treatment for systemic infections and family wellness.",
        "availableSlots": ["09:30 AM", "10:00 AM", "11:30 AM", "02:30 PM", "04:00 PM"]
    },
    {
        "id": "doc-chennai-4",
        "hospitalId": "hosp-chennai-4",
        "name": "Dr. Ramesh Chandra",
        "specialist": "General Physician",
        "degree": "MBBS",
        "exp": "10 yrs exp",
        "patients": "5.0k+",
        "rating": 4.2,
        "about": "Primary healthcare services funded by the government, offering free immunizations and consultations.",
        "availableSlots": ["09:00 AM", "10:00 AM", "11:00 AM", "12:00 PM", "02:00 PM"]
    }
]


def seed_hospitals_and_doctors():
    """Seed base hospitals and doctors in Firestore collections if they are empty."""
    try:
        hospitals_ref = db.collection("Hospitals")
        docs = hospitals_ref.get()
        if len(docs) == 0:
            logger.info("Seeding Hospitals collection in Firestore...")
            for hosp in DEFAULT_HOSPITALS:
                hospitals_ref.document(hosp["id"]).set(hosp)
            logger.info("Hospitals successfully seeded.")
            
        doctors_ref = db.collection("Doctors")
        docs_d = doctors_ref.get()
        if len(docs_d) == 0:
            logger.info("Seeding Doctors collection in Firestore...")
            for doc in DEFAULT_DOCTORS:
                doctors_ref.document(doc["id"]).set(doc)
            logger.info("Doctors successfully seeded.")
    except Exception as e:
        logger.error(f"Error seeding Firestore database: {e}")


# Initialize seeding on router import/startup
seed_hospitals_and_doctors()


@router.get("/hospitals")
async def get_hospitals(
    lat: Optional[float] = Query(None, description="User current latitude for distance sorting"),
    lng: Optional[float] = Query(None, description="User current longitude for distance sorting"),
    type: Optional[str] = Query(None, description="Filter by type ('govt' or 'private')")
):
    """
    Get all clinics and government PHCs. 
    If lat and lng are provided, returns sorted list with calculated distances.
    """
    try:
        hospitals_ref = db.collection("Hospitals")
        snapshots = hospitals_ref.get()
        hospitals = [snap.to_dict() for snap in snapshots]
        
        # Fallback to local variables if firestore fetch fails or returns empty during init
        if not hospitals:
            hospitals = DEFAULT_HOSPITALS.copy()
            
        # Apply type filtering
        if type:
            hospitals = [h for h in hospitals if h.get("type") == type.lower()]

        # Calculate distances if coordinates are provided
        for hosp in hospitals:
            h_lat = hosp.get("lat")
            h_lng = hosp.get("lng")
            
            # If absolute lat/lng not set in legacy models, derive from Hyderabad base + offset
            if h_lat is None or h_lng is None:
                # Fallback center is Hyderabad (17.3850, 78.4867)
                h_lat = 17.3850 + hosp.get("latOffset", 0)
                h_lng = 78.4867 + hosp.get("lngOffset", 0)
                hosp["lat"] = h_lat
                hosp["lng"] = h_lng
                
            if lat is not None and lng is not None:
                dist = calculate_haversine_distance(lat, lng, h_lat, h_lng)
                hosp["distance_km"] = dist
            else:
                hosp["distance_km"] = None

        # Sort by distance if calculated
        if lat is not None and lng is not None:
            hospitals.sort(key=lambda x: x.get("distance_km", 999999))

        return hospitals
    except Exception as e:
        logger.error(f"Error retrieving hospitals: {e}")
        # Fallback dump to ensure client continues functioning
        return DEFAULT_HOSPITALS


@router.get("/hospitals/{hospital_id}")
async def get_hospital_details(hospital_id: str):
    """Get complete details of a specific hospital."""
    try:
        hosp_ref = db.collection("Hospitals").document(hospital_id)
        snap = hosp_ref.get()
        if not snap.exists:
            # Check default array
            hosp = next((h for h in DEFAULT_HOSPITALS if h["id"] == hospital_id), None)
            if hosp:
                return hosp
            raise HTTPException(status_code=404, detail="Hospital not found")
        return snap.to_dict()
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        logger.error(f"Error fetching hospital detail: {e}")
        raise HTTPException(status_code=500, detail="Database error occurred.")


@router.get("/hospitals/{hospital_id}/doctors", response_model=List[DoctorSchema])
async def get_hospital_doctors(hospital_id: str):
    """Get the list of doctors operating in a specific hospital."""
    try:
        doctors_ref = db.collection("Doctors")
        snapshots = doctors_ref.where("hospitalId", "==", hospital_id).get()
        doctors = [snap.to_dict() for snap in snapshots]
        
        # Fallback to local default array
        if not doctors:
            doctors = [d for d in DEFAULT_DOCTORS if d["hospitalId"] == hospital_id]
            
        return doctors
    except Exception as e:
        logger.error(f"Error fetching hospital doctors: {e}")
        # Fallback
        return [d for d in DEFAULT_DOCTORS if d["hospitalId"] == hospital_id]

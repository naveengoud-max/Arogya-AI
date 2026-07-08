# ArogyaAI Production Backend API

A production-ready REST API backend built with **FastAPI**, **Firebase Firestore**, and **Google Gemini 1.5 Flash**, designed to serve the ArogyaAI mobile application with secure, localized healthcare assistance.

## 🚀 Key Features

*   **FastAPI REST Architecture**: High-performance, clean RESTful endpoints for users, clinic bookings, reports, and emergency SOS services.
*   **Security Middleware**: Validates native Firebase Phone Authentication ID Tokens (`Authorization: Bearer <token>`) at the server level.
*   **Fallback Sandbox Mode**: Auto-detects sandbox environments/development settings, facilitating out-of-the-box developer testing even without Firebase credentials configured.
*   **Firestore Database**: Integrates directly with Google Firestore using six mapped production collections: `Users`, `Appointments`, `SymptomReports`, `Hospitals`, `Doctors`, and `EmergencyContacts`.
*   **Gemini AI Diagnostics**: Implements AI symptom checks with clinical guidelines and explainable medical advice, featuring native translation and transliteration for English, Hindi, Telugu, and Tamil.
*   **Heuristic Fallback Engine**: Fully integrated multilingual rule-based analysis as a fail-safe if network or Gemini API keys are missing.
*   **Emergency SOS Services**: GPS-driven emergency hospital finder (Haversine sorting) combined with contact list CRUD and location sharing via Twilio/Fast2SMS SMS gateways.

---

## 📂 Repository Structure

```text
arogya_ai_backend/
├── app/
│   ├── __init__.py
│   ├── main.py            # Entry point & CORS/Global error handlers
│   ├── config.py          # Firebase initialization & local Mock DB fallback
│   ├── middleware.py      # Authorization token validation
│   ├── models/
│   │   ├── __init__.py
│   │   └── schemas.py     # Pydantic schemas for request/response validation
│   └── routes/
│       ├── __init__.py
│       ├── auth.py        # Authentication & Profile management
│       ├── hospitals.py   # Clinics listing & distance sorting
│       ├── appointments.py# Booking & sequential token queues
│       ├── ai.py          # Gemini AI multilingual symptom checker
│       └── emergency.py   # SOS alerts & Location sharing
├── requirements.txt       # Dependencies
└── .env                   # Configuration settings
```

---

## 🛠️ Step-by-Step Installation

### 1. Prerequisite Checks
Ensure Python 3.10+ is installed on your local machine:
```bash
python --version
```

### 2. Create a Virtual Environment & Install Dependencies
Navigate to the backend directory and execute:
```bash
# Create environment
python -m venv venv

# Activate on Windows
venv\Scripts\activate

# Activate on macOS/Linux
source venv/bin/activate

# Install requirements
pip install -r requirements.txt
```

### 3. Environment Configuration
Create a `.env` file in the root of the `arogya_ai_backend/` folder:
```env
PORT=5000

# Google Gemini API key (Obtain from Google AI Studio)
GEMINI_API_KEY=YOUR_GEMINI_API_KEY

# Google Firebase Admin SDK Credentials
# Download from: Firebase Console -> Project Settings -> Service Accounts -> Generate Private Key
FIREBASE_CREDENTIALS=firebase_credentials.json

# (Optional) SMS Gateway Keys - Leave blank to use console logger
FAST2SMS_API_KEY=YOUR_FAST2SMS_KEY
TWILIO_ACCOUNT_SID=YOUR_TWILIO_SID
TWILIO_AUTH_TOKEN=YOUR_TWILIO_TOKEN
TWILIO_PHONE_NUMBER=YOUR_TWILIO_PHONE
```

*Place your downloaded Firebase credentials JSON file inside the `arogya_ai_backend/` directory and name it `firebase_credentials.json`.*

### 4. Running the Server Locally
To run the server with hot-reload enabled:
```bash
python app/main.py
```
The server will start on `http://0.0.0.0:5000`. You can access the interactive API docs at `http://127.0.0.1:5000/docs`.

---

## 📱 Mobile App Synchronization

For the Flutter mobile app to talk to your local backend server, you should:
1. Ensure both your PC and test device are on the **same Wi-Fi network**.
2. Identify your PC's IP address (`ipconfig` on Windows or `ifconfig` on macOS/Linux).
3. Inside the mobile app, double-tap the **Logo** on the Login screen to activate **Developer Mode**, or tap the **Settings gear icon** in the top right to update the Server URL to:
   `http://<YOUR_PC_IP>:5000/api`
   *(Example: `http://192.168.31.194:5000/api`)*

---

## 📚 REST API Reference

| Endpoint | Method | Auth Required | Description |
| :--- | :--- | :---: | :--- |
| `/api/auth/send-otp` | `POST` | No | Sends an OTP code to user phone (Sandbox code returned in JSON) |
| `/api/auth/verify-otp` | `POST` | No | Verifies OTP code and registers/syncs profile session |
| `/api/auth/profile` | `POST` | Yes | Saves/Updates user name and language settings in Firestore |
| `/api/auth/profile` | `GET` | Yes | Fetches current user profile from Firestore |
| `/api/hospitals` | `GET` | No | Lists clinics, government PHCs, and maps coordinates |
| `/api/hospitals/{id}`| `GET` | No | Retrieves detailed clinic coordinates and doctor schedules |
| `/api/appointments` | `POST` | Yes | Creates an appointment pass and generates token `TK-XXX` |
| `/api/appointments` | `GET` | Yes | Retrieves user appointment history logs |
| `/api/ai/diagnose` | `POST` | Yes | Triggers Gemini AI multilingual analysis and logs report |
| `/api/emergency/contacts` | `GET/POST`| Yes | Lists or registers emergency contacts |
| `/api/emergency/sos` | `POST` | Yes | Triggers SOS message and returns nearest emergency hospital |

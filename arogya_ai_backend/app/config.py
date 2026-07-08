import os
import json
import logging
from typing import Any
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore
import google.generativeai as genai

# Setup Logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("ArogyaAI")

# Load environment variables
load_dotenv()

PORT = int(os.getenv("PORT", 5000))
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
FAST2SMS_API_KEY = os.getenv("FAST2SMS_API_KEY", "")
TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN", "")
TWILIO_PHONE_NUMBER = os.getenv("TWILIO_PHONE_NUMBER", "")
FIREBASE_CREDENTIALS = os.getenv("FIREBASE_CREDENTIALS", "")

# Initialize Gemini API
if GEMINI_API_KEY:
    try:
        genai.configure(api_key=GEMINI_API_KEY)
        logger.info("Gemini API successfully configured.")
    except Exception as e:
        logger.error(f"Failed to configure Gemini API: {e}")
else:
    logger.warning("GEMINI_API_KEY not found in environment. AI features will fallback to offline rule-based diagnosis.")

# Initialize Firebase Admin SDK
db = None
firebase_app = None

# A Local JSON-based fallback database for Firestore collections to guarantee the app runs out-of-the-box
class JSONCollection:
    def __init__(self, name: str):
        self.name = name
        self.file_path = f"db_{name.lower()}.json"
        if not os.path.exists(self.file_path):
            with open(self.file_path, "w") as f:
                json.dump({}, f)
                
    def _read(self):
        try:
            with open(self.file_path, "r") as f:
                return json.load(f)
        except Exception:
            return {}
            
    def _write(self, data):
        try:
            with open(self.file_path, "w") as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            logger.error(f"Error writing to {self.file_path}: {e}")

    def document(self, doc_id: str):
        class DocumentRef:
            def __init__(self, col, d_id):
                self.col = col
                self.id = d_id
            
            def get(self):
                class DocumentSnapshot:
                    def __init__(self, exists, data, d_id):
                        self.exists = exists
                        self._data = data
                        self.id = d_id
                    def to_dict(self):
                        return self._data
                data = self.col._read()
                doc_data = data.get(self.id)
                return DocumentSnapshot(doc_data is not None, doc_data, self.id)
                
            def set(self, data: dict, merge=False):
                current_data = self.col._read()
                if merge and self.id in current_data:
                    current_data[self.id].update(data)
                else:
                    current_data[self.id] = data
                self.col._write(current_data)
                
            def delete(self):
                current_data = self.col._read()
                if self.id in current_data:
                    del current_data[self.id]
                    self.col._write(current_data)
                    return True
                return False
                
        return DocumentRef(self, doc_id)

    def add(self, data: dict):
        import time, random
        doc_id = f"auto_{int(time.time() * 1000)}_{random.randint(100,999)}"
        self.document(doc_id).set(data)
        class DocRef:
            def __init__(self, d_id):
                self.id = d_id
        return DocRef(doc_id)

    def get(self):
        # Returns list of mock snapshots
        class DocSnapshot:
            def __init__(self, d_id, data):
                self.id = d_id
                self._data = data
            def to_dict(self):
                return self._data
        current_data = self._read()
        return [DocSnapshot(k, v) for k, v in current_data.items()]

    def where(self, field: str, op: str, value: Any):
        # Basic mockup of Firestore's where query
        class QueryRef:
            def __init__(self, col, f, o, v):
                self.col = col
                self.field = f
                self.op = o
                self.value = v
            def get(self):
                class DocSnapshot:
                    def __init__(self, d_id, data):
                        self.id = d_id
                        self._data = data
                    def to_dict(self):
                        return self._data
                current_data = self.col._read()
                results = []
                for k, v in current_data.items():
                    item_val = v.get(self.field)
                    match = False
                    if self.op == "==":
                        match = (item_val == self.value)
                    elif self.op == "in":
                        match = (item_val in self.value) if isinstance(self.value, list) else False
                    if match:
                        results.append(DocSnapshot(k, v))
                return results
        return QueryRef(self, field, op, value)

class MockFirestoreClient:
    def collection(self, name: str):
        return JSONCollection(name)

try:
    if FIREBASE_CREDENTIALS and os.path.exists(FIREBASE_CREDENTIALS):
        cred = credentials.Certificate(FIREBASE_CREDENTIALS)
        firebase_app = firebase_admin.initialize_app(cred)
        db = firestore.client()
        logger.info("Firebase Admin SDK successfully initialized using Service Account file.")
    elif os.path.exists("firebase_credentials.json"):
        cred = credentials.Certificate("firebase_credentials.json")
        firebase_app = firebase_admin.initialize_app(cred)
        db = firestore.client()
        logger.info("Firebase Admin SDK successfully initialized using local firebase_credentials.json.")
    else:
        # Try initializing with default credentials (will fail if not in GCP, but handles gracefully)
        firebase_app = firebase_admin.initialize_app()
        db = firestore.client()
        logger.info("Firebase Admin SDK initialized with Application Default Credentials.")
except Exception as e:
    logger.warning(f"Firebase Admin SDK failed to initialize: {e}. Falling back to Mock Firestore JSON database.")
    db = MockFirestoreClient()

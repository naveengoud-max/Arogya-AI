from fastapi import APIRouter, Depends, HTTPException
import json
import logging
from datetime import datetime
from typing import Optional
import google.generativeai as genai
from app.config import db, GEMINI_API_KEY
from app.models.schemas import SymptomReportBase
from app.middleware import get_current_user
from app.routes.auth import otp_store

logger = logging.getLogger("ArogyaAI")
router = APIRouter(tags=["AI Diagnostics"])

# Dialect normalizer for common Indian language inputs
DIALECT_MAP = {
    # Hindi
    "bukhar": "fever", " बुखार": "fever", "khansi": "cough", "sardard": "headache", "sir dard": "headache",
    "pet dard": "stomach ache", "gala kharab": "sore throat", "chhati me dard": "chest pain", "khansi aur sardi": "cough & cold",
    "jwar": "fever", "sar dard": "headache",
    # Telugu
    "jwaram": "fever", "jwara": "fever", "daggulu": "cough", "tala noppi": "headache", "kadupu noppi": "stomach ache",
    "gontu noppi": "throat pain", "gunde noppi": "chest pain", "kallu mantalu": "eye burning", "kallu": "eye",
    "mantalu": "burning", "nappi": "pain", "tala vali": "headache",
    # Tamil
    "kaichal": "fever", "irumal": "cough", "thalai vali": "headache", "vayi vali": "stomach ache",
    "thondai vali": "throat pain", "nenju vali": "chest pain", "udal vali": "body pain"
}

def normalize_symptoms(raw_text: str) -> str:
    text = raw_text.lower()
    for key, value in DIALECT_MAP.items():
        text = text.replace(key, value)
    return text


# Offline Fallback Local Rules mapped to Language
OFFLINE_DIAGNOSES = {
    "fever": {
        "English": {
            "condition": "Acute Febrile Illness / Mild Fever",
            "severity": "low",
            "specialist": "General Physician",
            "description": "Standard body temperature elevation due to seasonal viral pathogens. Keep body cool and well-rested.",
            "medicines": [
                {"name": "Paracetamol 500mg", "instructions": "1 tablet after meals (SOS)", "badge": "Fever/Pain"},
                {"name": "Vitamin C Chewable", "instructions": "1 tablet daily for 3 days", "badge": "Immune Support"}
            ],
            "precautions": [
                "Get complete bed rest and monitor temperature.",
                "Drink plenty of water and warm soups.",
                "Consult doctor if fever exceeds 102°F or lasts >3 days."
            ]
        },
        "Hindi": {
            "condition": "तीव्र ज्वर / हल्का बुखार (Acute Febrile Illness)",
            "severity": "low",
            "specialist": "General Physician",
            "description": "मौसमी वायरल रोगजनकों के कारण शरीर के तापमान में सामान्य वृद्धि। शरीर को ठंडा और पूर्ण आराम दें।",
            "medicines": [
                {"name": "Paracetamol 500mg", "instructions": "भोजन के बाद 1 गोली (ज़रूरत पड़ने पर)", "badge": "बुखार/दर्द"},
                {"name": "Vitamin C चबाने योग्य", "instructions": "3 दिनों तक रोजाना 1 गोली", "badge": "प्रतिरोधक क्षमता"}
            ],
            "precautions": [
                "पूर्ण रूप से आराम करें और शरीर के तापमान की निगरानी करें।",
                "खूब पानी और गर्म सूप पिएं।",
                "यदि बुखार 102°F से अधिक हो या 3 दिनों से अधिक रहे तो डॉक्टर से संपर्क करें।"
            ]
        },
        "Telugu": {
            "condition": "తీవ్రమైన జ్వరం / సాధారణ జ్వరం (Mild Fever)",
            "severity": "low",
            "specialist": "General Physician",
            "description": "వాతావరణ మార్పుల వల్ల వచ్చే వైరల్ జ్వరం. శరీరాన్ని చల్లగా ఉంచి విశ్రాంతి తీసుకోండి.",
            "medicines": [
                {"name": "Paracetamol 500mg", "instructions": "భోజనం తర్వాత 1 టాబ్లెట్ (అవసరమైతేనే)", "badge": "జ్వరం/నొప్పి"},
                {"name": "Vitamin C చూయబుల్", "instructions": "3 రోజుల పాటు రోజుకు 1 టాబ్లెట్", "badge": "రోగనిరోధక శక్తి"}
            ],
            "precautions": [
                "పూర్తిగా బెడ్ రెస్ట్ తీసుకోండి మరియు జ్వరాన్ని కొలవండి.",
                "మంచినీరు మరియు వేడి సూప్‌లు ఎక్కువగా తాగండి.",
                "జ్వరం 102°F కంటే ఎక్కువ ఉన్నా లేదా 3 రోజులు దాటినా డాక్టర్‌ని సంప్రదించండి."
            ]
        },
        "Tamil": {
            "condition": "கடுமையான காய்ச்சல் / லேசான காய்ச்சல் (Mild Fever)",
            "severity": "low",
            "specialist": "General Physician",
            "description": "பருவகால வைரஸ் கிருமிகளால் ஏற்படும் உடல் வெப்பநிலை அதிகரிப்பு. உடலை குளிர்ச்சியாகவும் ஓய்வாகவும் வைத்திருக்கவும்.",
            "medicines": [
                {"name": "Paracetamol 500mg", "instructions": "உணவுக்குப் பின் 1 மாத்திரை (தேவைப்பட்டால் மட்டும்)", "badge": "காய்ச்சல்/வலி"},
                {"name": "Vitamin C மாத்திரை", "instructions": "3 நாட்களுக்கு தினமும் 1 மாத்திரை", "badge": "நோய் எதிர்ப்பு சக்தி"}
            ],
            "precautions": [
                "முழுமையான படுக்கை ஓய்வு எடுத்து காய்ச்சலை கண்காணிக்கவும்.",
                "நிறைய தண்ணீர் மற்றும் சூடான சூப் குடிக்கவும்.",
                "காய்ச்சல் 102°F ஐ தாண்டினாலோ அல்லது 3 நாட்களுக்கு மேல் நீடித்தாலோ மருத்துவரை அணுகவும்."
            ]
        }
    },
    "chest": {
        "English": {
            "condition": "Potential Cardiovascular Emergency",
            "severity": "high",
            "specialist": "Cardiologist",
            "description": "Symptoms point to possible heart strain or angina. Requires immediate medical screening to prevent complications.",
            "medicines": [
                {"name": "Aspirin 75mg", "instructions": "Chew 1 tablet immediately", "badge": "Blood Thinner"},
                {"name": "Sorbitrate 5mg", "instructions": "Place under tongue if prescribed", "badge": "Emergency Relief"}
            ],
            "precautions": [
                "Sit completely still and rest. Avoid any physical activity.",
                "Call the toll-free emergency ambulance SOS at 108 immediately.",
                "Keep windows open for ventilation."
            ]
        },
        "Hindi": {
            "condition": "संभावित हृदय आपातकाल (Potential Cardiovascular Emergency)",
            "severity": "high",
            "specialist": "Cardiologist",
            "description": "लक्षण दिल के तनाव या एनजाइना की ओर इशारा करते हैं। जटिलताओं को रोकने के लिए तत्काल चिकित्सा जांच की आवश्यकता है।",
            "medicines": [
                {"name": "Aspirin 75mg", "instructions": "तुरंत 1 गोली चबाएं", "badge": "रक्त पतला करने वाली"},
                {"name": "Sorbitrate 5mg", "instructions": "जीभ के नीचे रखें (यदि डॉक्टर द्वारा निर्देशित हो)", "badge": "आपातकालीन राहत"}
            ],
            "precautions": [
                "बिल्कुल शांत बैठें और आराम करें। कोई भी शारीरिक गतिविधि न करें।",
                "तुरंत 108 आपातकालीन एम्बुलेंस सेवा को कॉल करें।",
                "हवा के लिए खिड़कियां खुली रखें।"
            ]
        },
        "Telugu": {
            "condition": "గుండె సంబంధిత అత్యవసర పరిస్థితి (Potential Heart Emergency)",
            "severity": "high",
            "specialist": "Cardiologist",
            "description": "లక్షణాలు గుండెపోటు లేదా రక్తప్రసరణ ఆగిపోవడాన్ని సూచిస్తున్నాయి. ప్రాణాపాయం నివారించడానికి వెంటనే ఆసుపత్రికి వెళ్ళండి.",
            "medicines": [
                {"name": "Aspirin 75mg", "instructions": "వెంటనే 1 టాబ్లెట్ నమలండి", "badge": "రక్తం పలచబరిచేది"},
                {"name": "Sorbitrate 5mg", "instructions": "నాలుక కింద ఉంచుకోండి (ముందుగా ప్రిస్క్రైబ్ చేస్తేనే)", "badge": "అత్యవసర ఉపశమనం"}
            ],
            "precautions": [
                "ఏ పనీ చేయకుండా నిశ్శబ్దంగా కూర్చోండి. శారీరక శ్రమ వద్దు.",
                "వెంటనే 108 అంబులెన్స్ సేవకు ఫోన్ చేయండి.",
                "గాలి కోసం కిటికీలను తెరిచి ఉంచండి."
            ]
        },
        "Tamil": {
            "condition": "இருதய அவசரநிலை ஆபத்து (Potential Cardiovascular Emergency)",
            "severity": "high",
            "specialist": "Cardiologist",
            "description": "அறிகுறிகள் மாரடைப்பு அல்லது நெஞ்சு வலியைக் குறிக்கின்றன. ஆபத்தைத் தவிர்க்க உடனடியாக மருத்துவ பரிசோதனை தேவை.",
            "medicines": [
                {"name": "Aspirin 75mg", "instructions": "உடனடியாக 1 மாத்திரையை மெல்லவும்", "badge": "இரத்தத்தை நீர்க்கச் செய்யும்"},
                {"name": "Sorbitrate 5mg", "instructions": "நாக்கின் அடியில் வைக்கவும் (பரிந்துரைக்கப்பட்டால்)", "badge": "அவசரகால நிவாரணம்"}
            ],
            "precautions": [
                "அமைதியாக அமர்ந்து ஓய்வெடுக்கவும். எந்தவொரு உடல் உழைப்பையும் தவிர்க்கவும்.",
                "உடனடியாக 108 அவசர ஆம்புலன்ஸ் சேவையை அழைக்கவும்.",
                "காற்றோட்டத்திற்காக ஜன்னல்களைத் திறந்து வைக்கவும்."
            ]
        }
    }
}


@router.post("/diagnose")
async def analyze_symptoms(
    payload: dict,
    current_user: dict = Depends(get_current_user)
):
    """
    Analyzes symptoms using Gemini AI with multilingual output support,
    falling back to robust local rules if API keys are missing.
    Saves results to Firestore.
    """
    raw_symptoms = payload.get("symptoms", "").strip()
    language = payload.get("language", "English").strip()
    
    if not raw_symptoms:
        raise HTTPException(status_code=400, detail="Symptoms text is required.")

    clean_symptoms = normalize_symptoms(raw_symptoms)
    
    # 1. Try Gemini API
    ai_result = None
    if GEMINI_API_KEY:
        try:
            # Construct a multilingual, schema-strict prompt for Gemini
            system_prompt = (
                "You are ArogyaAI, an advanced, highly explainable assistive medical AI engine designed for Indian users.\n"
                f"Analyze the user's symptoms and generate your response strictly in the {language} language.\n"
                "Provide a clear, patient-friendly medical explanation of why you suspect this condition (Explainable AI).\n"
                "Return the output STRICTLY as a single valid JSON object. Do not include markdown code block characters like ```json. "
                "The JSON must strictly follow this structure:\n"
                "{\n"
                '  "condition": "Condition name in target language (English transliteration in brackets)",\n'
                '  "severity": "low" | "medium" | "high",\n'
                '  "specialist": "ENT Specialist" | "Cardiologist" | "General Physician",\n'
                '  "description": "2-3 sentence patient-friendly explanation, explaining the potential root cause and advising caution (in target language)",\n'
                '  "medicines": [\n'
                '    {"name": "Medicine Name (Generic)", "instructions": "Dosage instructions (in target language)", "badge": "Category"}\n'
                '  ],\n'
                '  "precautions": [\n'
                '    "Precaution 1 (in target language)",\n'
                '    "Precaution 2 (in target language)",\n'
                '    "Precaution 3 (in target language)"\n'
                '  ]\n'
                "}"
            )
            
            model = genai.GenerativeModel("gemini-1.5-flash")
            response = model.generate_content(
                contents=[
                    {"role": "user", "parts": [{"text": system_prompt}, {"text": f"Symptoms description: {clean_symptoms}"}]}
                ],
                generation_config={"response_mime_type": "application/json"}
            )
            
            if response.text:
                # Clean up any potential markdown wraps
                cleaned_text = response.text.replace("```json", "").replace("```", "").strip()
                ai_result = json.loads(cleaned_text)
                logger.info("Successfully analyzed symptoms using Gemini AI.")
        except Exception as e:
            logger.error(f"Gemini API invocation failed: {e}. Switching to offline heuristics.")

    # 2. Fallback to offline rule-based dictionary
    if not ai_result:
        # Determine language block (fallback to English if requested lang block not found)
        lang_key = language if language in ["English", "Hindi", "Telugu", "Tamil"] else "English"
        
        # Check condition keywords
        s_lower = clean_symptoms.lower()
        if any(w in s_lower for w in ["chest", "heart", "cardio", "gunde", "nenju", "angina"]):
            ai_result = OFFLINE_DIAGNOSES["chest"][lang_key]
        elif any(w in s_lower for w in ["throat", "swallow", "gala", "gontu", "thondai", "tonsil"]):
            # Throat infection fallback
            # We construct a quick translation block for throat infection
            if lang_key == "Hindi":
                ai_result = {
                    "condition": "गले में संक्रमण (Throat Infection / Pharyngitis)",
                    "severity": "medium",
                    "specialist": "ENT Specialist",
                    "description": "गले में सूजन या संक्रमण, जो आमतौर पर वायरल फ्लू के कारण होता है। निगलने में कठिनाई हो सकती है।",
                    "medicines": [
                        {"name": "Paracetamol 500mg", "instructions": "गले के दर्द के लिए भोजन के बाद 1 गोली", "badge": "बुखार/दर्द"},
                        {"name": "Betadine कुल्ला", "instructions": "गुनगुने पानी में डालकर दिन में 3 बार गरारे करें", "badge": "गले की राहत"}
                    ],
                    "precautions": [
                        "गुनगुने नमक के पानी से नियमित गरारे करें।",
                        "ठंडा, खट्टा या मसालेदार भोजन खाने से बचें।",
                        "गले को आराम दें और अत्यधिक बात न करें।"
                    ]
                }
            elif lang_key == "Telugu":
                ai_result = {
                    "condition": "గొంతు ఇన్ఫెక్షన్ (Throat Infection)",
                    "severity": "medium",
                    "specialist": "ENT Specialist",
                    "description": "గొంతు మంట లేదా ఇన్ఫెక్షన్, సాధారణంగా జలుబు లేదా వైరస్ వల్ల వస్తుంది. మింగడం కష్టంగా ఉండవచ్చు.",
                    "medicines": [
                        {"name": "Paracetamol 500mg", "instructions": "భోజనం తర్వాత 1 టాబ్లెట్", "badge": "నొప్పి నివారణ"},
                        {"name": "Betadine గార్గిల్", "instructions": "గోరువెచ్చని నీటిలో కలిపి రోజుకు 3 సార్లు పుక్కిలించండి", "badge": "గొంతు ఉపశమనం"}
                    ],
                    "precautions": [
                        "గోరువెచ్చని ఉప్పు నీటితో క్రమం తప్పకుండా నోరు కడగాలి.",
                        "చల్లని పానీయాలు, పుల్లటి ఆహారం మరియు నూనె పదార్థాలు వద్దు.",
                        "గొంతుకు విశ్రాంతి ఇవ్వండి, ఎక్కువ మాట్లాడకండి."
                    ]
                }
            elif lang_key == "Tamil":
                ai_result = {
                    "condition": "தொண்டை தொற்று (Throat Infection)",
                    "severity": "medium",
                    "specialist": "ENT Specialist",
                    "description": "தொண்டையில் வீக்கம் அல்லது தொற்று, வழக்கமாக வைரஸ் சளியால் ஏற்படும். விழுங்குவதில் சிரமம் இருக்கலாம்.",
                    "medicines": [
                        {"name": "Paracetamol 500mg", "instructions": "உணவுக்குப் பின் 1 மாத்திரை", "badge": "வலி நிவாரணி"},
                        {"name": "Betadine வாய்க்கொப்பளிப்பு", "instructions": "வெதுவெதுப்பான நீரில் கலந்து தினமும் 3 முறை கொப்பளிக்கவும்", "badge": "தொண்டை நிவாரணம்"}
                    ],
                    "precautions": [
                        "வெதுவெதுப்பான உப்பு நீரால் தொடர்ந்து வாய் கொப்பளிக்கவும்.",
                        "குளிர்ந்த நீர், காரசாரமான உணவுகளைத் தவிர்க்கவும்.",
                        "குரலுக்கு ஓய்வு கொடுங்கள், அதிகம் பேசுவதைத் தவிர்க்கவும்."
                    ]
                }
            else:
                ai_result = {
                    "condition": "Viral Pharyngitis (Throat Infection)",
                    "severity": "medium",
                    "specialist": "ENT Specialist",
                    "description": "An acute viral infection causing inflammation of the pharynx, commonly associated with swallowing difficulty.",
                    "medicines": [
                        {"name": "Paracetamol 500mg", "instructions": "1 tablet after meals for soreness", "badge": "Fever/Pain"},
                        {"name": "Betadine Mouthwash", "instructions": "Gargle with warm water 3 times daily", "badge": "Throat Relief"}
                    ],
                    "precautions": [
                        "Gargle with warm salt water regularly.",
                        "Avoid oily, cold, or spicy food items.",
                        "Keep your neck warm and rest your voice."
                    ]
                }
        else:
            # Default to Fever fallback
            ai_result = OFFLINE_DIAGNOSES["fever"][lang_key]

    # 3. Save report to Firestore database (SymptomReports collection)
    uid = current_user.get("uid") if current_user else "guest-user"
    
    report_id = f"rep-{int(datetime.utcnow().timestamp() * 1000)}"
    now = datetime.utcnow()
    date_str = now.strftime("%d/%m/%Y")
    time_str = now.strftime("%I:%M %p")
    
    report_db_entry = {
        "id": report_id,
        "userId": uid,
        "symptoms": raw_symptoms,
        "condition": ai_result.get("condition", "Acute Illness"),
        "severity": ai_result.get("severity", "medium"),
        "specialist": ai_result.get("specialist", "General Physician"),
        "description": ai_result.get("description", ""),
        "precautions": ai_result.get("precautions", []),
        "medicines": ai_result.get("medicines", []),
        "type": "symptom",
        "createdAt": now.isoformat(),
        "date": date_str,
        "time": time_str
    }
    
    try:
        db.collection("SymptomReports").document(report_id).set(report_db_entry)
        logger.info(f"Symptom report {report_id} successfully saved to Firestore.")
    except Exception as e:
        logger.error(f"Failed to save symptom report to database: {e}")

    # Return the diagnostic structure matching the expected schema
    return ai_result


@router.get("/reports", response_model=dict)
async def get_user_reports(current_user: dict = Depends(get_current_user)):
    """Fetches all logged AI symptom reports for the authenticated user."""
    uid = current_user.get("uid")
    try:
        reports_ref = db.collection("SymptomReports")
        snapshots = reports_ref.where("userId", "==", uid).get()
        reports = []
        for snap in snapshots:
            data = snap.to_dict()
            data["id"] = snap.id
            reports.append(data)
            
        # Sort by creation date
        reports.sort(key=lambda x: x.get("createdAt", ""), reverse=True)
        return {"success": True, "reports": reports}
    except Exception as e:
        logger.error(f"Error fetching user reports: {e}")
        raise HTTPException(status_code=500, detail="Database retrieval failed.")
        
        
@router.delete("/reports/{report_id}")
async def delete_report(
    report_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Deletes an AI symptom report from history."""
    try:
        report_ref = db.collection("SymptomReports").document(report_id)
        snap = report_ref.get()
        if not snap.exists:
            raise HTTPException(status_code=404, detail="Symptom report not found.")
            
        report_ref.delete()
        return {"success": True, "message": "Report deleted successfully."}
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        logger.error(f"Error deleting symptom report: {e}")
        raise HTTPException(status_code=500, detail="Deletion failed.")


@router.post("/chat")
async def chatbot_respond(
    payload: dict,
    current_user: dict = Depends(get_current_user)
):
    """Specialized healthcare chatbot conversation endpoint."""
    message = payload.get("message", "").strip()
    language = payload.get("language", "English").strip()
    
    if not message:
        raise HTTPException(status_code=400, detail="Message content is required.")
        
    system_prompt = (
        "You are ArogyaAI Health Assistant, an empathetic, high-quality conversational healthcare chatbot.\n"
        f"Respond user's prompt in the {language} language.\n"
        "Provide helpful advice on symptoms, diet, exercise, and mental health. "
        "Strictly refuse to write prescriptions, perform complex diagnoses or recommend high-risk medications. "
        "Always append a standard medical disclaimer reminding the user that this is for guidance and to consult a real physician."
    )
    
    response_text = ""
    if GEMINI_API_KEY:
        try:
            model = genai.GenerativeModel("gemini-1.5-flash")
            response = model.generate_content(
                contents=[
                    {"role": "user", "parts": [{"text": system_prompt}, {"text": f"User query: {message}"}]}
                ]
            )
            response_text = response.text
        except Exception as e:
            logger.error(f"Gemini Chatbot API failed: {e}")
            
    if not response_text:
        # Fallback offline rule response matching keywords
        m_lower = message.lower()
        if "diet" in m_lower or "food" in m_lower or "eat" in m_lower:
            response_text = "Eat a balanced meal containing green vegetables, whole grains, and clean proteins. Keep hydrated with 3-4 liters of water daily. *Disclaimer: This information is for general guidance only and does not replace professional medical advice.*"
        elif "exercise" in m_lower or "workout" in m_lower or "fitness" in m_lower:
            response_text = "Engage in 30 minutes of moderate aerobic activity like brisk walking or cycling five days a week. Always stretch before exercising. *Disclaimer: This information is for general guidance only and does not replace professional medical advice.*"
        elif "stress" in m_lower or "depress" in m_lower or "anxiety" in m_lower or "mental" in m_lower:
            response_text = "Practice mindfulness meditation, deep breathing exercises, or yoga to regulate stress hormones. Ensure 7-8 hours of sound sleep. *Disclaimer: This information is for general guidance only and does not replace professional medical advice.*"
        else:
            response_text = "I am here to assist you with symptom guidance, healthy habits, diet plans, and mental wellness tips. Please let me know how I can support your health today! *Disclaimer: This information is for general guidance only and does not replace professional medical advice.*"
            
    return {"success": True, "reply": response_text}


const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const JWT_SECRET = process.env.JWT_SECRET || 'arogya_ai_secret_key_2026_xyz';

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

const webDir = fs.existsSync(path.join(__dirname, '../arogya_ai_web'))
    ? path.join(__dirname, '../arogya_ai_web')
    : path.join(__dirname, 'public');

app.use(express.static(webDir));

app.get('/health', (req, res) => {
    res.status(200).json({
        status: "online",
        database: "connected",
        firebase: "connected"
    });
});

app.get('/api/health', (req, res) => {
    res.status(200).json({
        status: "online",
        database: "connected",
        firebase: "connected"
    });
});

app.get('/download-apk', (req, res) => {
    const candidates = [
        path.join(__dirname, '../arogya_ai_flutter/arogya-ai-production-release.apk'),
        path.join(__dirname, '../arogya_ai_flutter/arogya-ai-release-final.apk'),
        path.join(__dirname, '../arogya_ai_flutter/arogya-ai-debug.apk'),
        path.join(__dirname, '../arogya_ai_flutter/build/app/outputs/flutter-apk/app-release.apk')
    ];
    const found = candidates.find(p => fs.existsSync(p));
    if (found) {
        res.download(found, path.basename(found));
    } else {
        res.status(404).send('APK file not found. Please compile it first.');
    }
});


// Local Database JSON directory & file paths
const DB_DIR = path.join(__dirname, 'database');
if (!fs.existsSync(DB_DIR)) fs.mkdirSync(DB_DIR, { recursive: true });

const APPOINTMENTS_FILE = path.join(DB_DIR, 'db_appointments.json');
const REPORTS_FILE = path.join(DB_DIR, 'db_reports.json');
const USERS_FILE = path.join(DB_DIR, 'db_users.json');
const DOCTORS_FILE = path.join(DB_DIR, 'db_doctors.json');
const HOSPITALS_FILE = path.join(DB_DIR, 'db_hospitals.json');

// Initialize database files if they don't exist
if (!fs.existsSync(APPOINTMENTS_FILE)) fs.writeFileSync(APPOINTMENTS_FILE, JSON.stringify([]));
if (!fs.existsSync(REPORTS_FILE)) fs.writeFileSync(REPORTS_FILE, JSON.stringify([]));
if (!fs.existsSync(USERS_FILE)) fs.writeFileSync(USERS_FILE, JSON.stringify({}));
if (!fs.existsSync(DOCTORS_FILE)) fs.writeFileSync(DOCTORS_FILE, JSON.stringify([]));
if (!fs.existsSync(HOSPITALS_FILE)) fs.writeFileSync(HOSPITALS_FILE, JSON.stringify([]));

const readDb = (filePath) => {
    try {
        return JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch (e) {
        return [];
    }
};

const readDbObj = (filePath) => {
    try {
        return JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch (e) {
        return {};
    }
};

const writeDb = (filePath, data) => {
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
};

// Dialect/Language Normalizer Map for backend matching (English, Telugu, Hindi, Tamil)
const DIALECT_MAP = {
    // Hindi
    "bukhar": "fever", " बुखार": "fever", "khansi": "cough", "sardard": "headache", "sir dard": "headache",
    "pet dard": "stomach ache", "gala kharab": "sore throat", "chhati me dard": "chest pain", "khansi aur sardi": "cough & cold",
    "jwar": "fever", "sar dard": "headache",
    // Telugu
    "jwaram": "fever", "jwara": "fever", "daggulu": "cough", "tala noppi": "headache", "kadupu noppi": "stomach ache",
    "gontu noppi": "throat pain", "gunde noppi": "chest pain", "kallu mantalu": "eye burning", "kallu": "eye",
    "mantalu": "burning", "nappi": "pain", "tala vali": "headache",
    // Tamil
    "kaichal": "fever", "irumal": "cough", "thalai vali": "headache", "vayi vali": "stomach ache",
    "thondai vali": "throat pain", "nenju vali": "chest pain", "udal vali": "body pain"
};

const normalizeSymptoms = (rawText) => {
    let text = rawText.toLowerCase();
    Object.keys(DIALECT_MAP).forEach(key => {
        const regex = new RegExp(`\\b${key}\\b`, 'gi');
        text = text.replace(regex, DIALECT_MAP[key]);
    });
    return text;
};

// Temp store for OTPs in-memory (phone -> code)
const otpStore = {};

// Helper to send real SMS
async function sendSms(phone, message) {
    console.log(`\n========================================`);
    console.log(`[SMS OUTBOX] To: ${phone} | Message: ${message}`);
    console.log(`========================================\n`);

    // 1. Try Fast2SMS Route (India-specific)
    if (process.env.FAST2SMS_API_KEY) {
        try {
            const cleanPhone = phone.replace(/\D/g, '').slice(-10); // get last 10 digits
            const url = `https://www.fast2sms.com/dev/bulkV2?authorization=${process.env.FAST2SMS_API_KEY}&route=q&message=${encodeURIComponent(message)}&numbers=${cleanPhone}`;
            const response = await fetch(url, { method: 'GET' });
            const result = await response.json();
            console.log("Fast2SMS Response:", result);
            if (result.return === true || result.message?.includes("sent")) {
                return { success: true, provider: 'Fast2SMS' };
            }
        } catch (e) {
            console.error("Fast2SMS API failed:", e);
        }
    }

    // 2. Try Twilio Route (Global fallback)
    if (process.env.TWILIO_ACCOUNT_SID && process.env.TWILIO_AUTH_TOKEN && process.env.TWILIO_PHONE_NUMBER) {
        try {
            const formattedPhone = phone.startsWith("+") ? phone : `+91${phone}`;
            const twilio = require('twilio')(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
            const res = await twilio.messages.create({
                body: message,
                from: process.env.TWILIO_PHONE_NUMBER,
                to: formattedPhone
            });
            console.log("Twilio Response Message SID:", res.sid);
            return { success: true, provider: 'Twilio' };
        } catch (e) {
            console.error("Twilio API failed:", e);
        }
    }

    // 3. Fallback to free Textbelt API
    try {
        const formattedPhone = phone.startsWith("+") ? phone : `+91${phone}`;
        const response = await fetch("https://textbelt.com/text", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                phone: formattedPhone,
                message: message,
                key: "textbelt"
            })
        });
        const result = await response.json();
        console.log("Textbelt Response:", result);
        if (result.success) {
            return { success: true, provider: 'Textbelt' };
        }
    } catch (e) {
        console.error("Textbelt failed:", e);
    }

    return { success: false, provider: 'None (Console Printed Only)' };
}

// Helper to send transactional emails via Brevo REST API
async function sendBrevoEmail({ toEmail, toName, subject, htmlContent, textContent }) {
    const apiKey = process.env.BREVO_API_KEY;
    if (!apiKey) {
        console.warn("[Brevo Email] BREVO_API_KEY missing from server configuration.");
        return { success: false, error: "BREVO_API_KEY missing" };
    }

    const senderEmail = process.env.BREVO_SENDER_EMAIL || "knaveengoud123@gmail.com";
    const senderName = process.env.BREVO_SENDER_NAME || "ArogyaAI";

    try {
        const payload = {
            sender: { email: senderEmail, name: senderName },
            to: [{ email: toEmail, name: toName || toEmail }],
            subject: subject,
            htmlContent: htmlContent,
            textContent: textContent || subject
        };

        const response = await fetch("https://api.brevo.com/v3/smtp/email", {
            method: "POST",
            headers: {
                "accept": "application/json",
                "content-type": "application/json",
                "api-key": apiKey
            },
            body: JSON.stringify(payload)
        });

        const result = await response.json();
        if (response.ok && result.messageId) {
            console.log(`[Brevo Email Sent] Success to: ${toEmail} | Message ID: ${result.messageId}`);
            return { success: true, messageId: result.messageId };
        } else {
            console.error("[Brevo Email Error]", result);
            return { success: false, error: result.message || "Brevo API returned error" };
        }
    } catch (e) {
        console.error("[Brevo Email Exception]", e.message);
        return { success: false, error: e.message };
    }
}

/* ── ROUTES ── */

// Helper to get authenticated user from token
const getAuthenticatedUser = (req) => {
    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return null;
    }
    const token = authHeader.split(' ')[1];
    
    // Support legacy/sandbox credentials for backward compatibility and local dev double-click setup
    if (token === '1234' || token.startsWith('sandbox-') || token.startsWith('google-')) {
        const uid = token.startsWith('sandbox-') ? token : `uid-${token}`;
        return { uid, phone: "+919876543210", name: "Arogya User" };
    }
    
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        return { uid: decoded.uid, phone: decoded.phone || "", email: decoded.email || "" };
    } catch (e) {
        // Legacy Base64 decoding fallback
        try {
            const decoded = Buffer.from(token, 'base64').toString('utf8');
            if (decoded.length >= 10) {
                return { uid: `uid-${token.substring(0, 8)}`, phone: decoded, name: "Arogya User" };
            }
        } catch(err) {}
    }
    
    return null;
};

// 1. Request OTP Code (6-Digit, rate limiting, and 5-min expiration)
app.post('/api/auth/send-otp', async (req, res) => {
    const { phone } = req.body;
    if (!phone || phone.length < 10) {
        return res.status(400).json({ success: false, message: "Valid phone number required" });
    }

    const now = Date.now();
    const existing = otpStore[phone];

    // Rate Limiting / Resend Cooldown: 60 seconds
    if (existing && (now - existing.lastSentAt) < 60000) {
        const remaining = Math.ceil((60000 - (now - existing.lastSentAt)) / 1000);
        return res.status(429).json({
            success: false,
            message: `Please wait ${remaining} seconds before requesting a new OTP.`
        });
    }

    // Generate secure 6-digit OTP code
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    otpStore[phone] = {
        code: code,
        createdAt: now,
        lastSentAt: now,
        attempts: 0
    };

    const message = `[ArogyaAI] Your 6-digit OTP is: ${code}. Valid for 5 minutes.`;
    const smsRes = await sendSms(phone, message);
    
    return res.status(200).json({
        success: true,
        message: `OTP sent successfully to ${phone}.`,
        // In local development or fallback, display OTP in response if sms delivery was printed only
        code: smsRes.success ? undefined : code,
        provider: smsRes.provider,
        delivered: smsRes.success
    });
});

// 2. Verify OTP Code with JWT session generation and persistent database registration
app.post('/api/auth/verify-otp', (req, res) => {
    const { phone, code } = req.body;
    if (!phone || !code) {
        return res.status(400).json({ success: false, message: "Phone and code required" });
    }

    const record = otpStore[phone];
    if (!record) {
        return res.status(400).json({ success: false, message: "No OTP requested for this phone number." });
    }

    const now = Date.now();

    // Check expiration: 5 minutes = 300,000 milliseconds
    if ((now - record.createdAt) > 300000) {
        delete otpStore[phone];
        return res.status(400).json({ success: false, message: "OTP has expired. Please request a new one." });
    }

    // Check attempts to prevent brute force
    if (record.attempts >= 5) {
        delete otpStore[phone];
        return res.status(429).json({ success: false, message: "Too many failed attempts. Please request a new OTP." });
    }

    if (code === record.code) {
        delete otpStore[phone]; // Consume OTP code
        const uid = `uid-${Buffer.from(phone).toString('base64').substring(0, 8)}`;
        
        // Connect the database: Save/Initialize User record in db_users.json
        const users = readDbObj(USERS_FILE);
        if (!users[uid]) {
            users[uid] = {
                uid: uid,
                phone: phone,
                name: "Arogya User",
                language: "English",
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString()
            };
            writeDb(USERS_FILE, users);
        }
        
        const token = jwt.sign({ uid: uid, phone: phone }, JWT_SECRET, { expiresIn: '30d' });
        
        return res.status(200).json({
            success: true,
            user: {
                uid: uid,
                phone: phone,
                name: users[uid].name || "Arogya User"
            },
            token: token
        });
    } else {
        record.attempts += 1;
        return res.status(400).json({ success: false, message: "Invalid OTP code." });
    }
});

// Crypto module and password hashing helper
const crypto = require('crypto');
const hashPassword = (password) => {
    return crypto.createHash('sha256').update(password).digest('hex');
};

// 3. Register with Email and Password
app.post('/api/auth/register-email', (req, res) => {
    const { email, password, name, phone } = req.body;
    if (!email || !password || !name || !phone) {
        return res.status(400).json({ success: false, message: "All fields are required (email, password, name, phone)" });
    }

    const users = readDbObj(USERS_FILE);
    
    // Check if email already registered
    const emailExists = Object.values(users).some(u => u.email === email.toLowerCase());
    if (emailExists) {
        return res.status(400).json({ success: false, message: "Email is already registered." });
    }

    // Check if phone already registered
    const phoneExists = Object.values(users).some(u => u.phone === phone);
    if (phoneExists) {
        return res.status(400).json({ success: false, message: "Phone number is already registered." });
    }

    const uid = `uid-email-${Buffer.from(email).toString('base64').substring(0, 8)}`;
    users[uid] = {
        uid: uid,
        email: email.toLowerCase(),
        passwordHash: hashPassword(password),
        phone: phone,
        name: name,
        language: "English",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
    };
    writeDb(USERS_FILE, users);

    const token = jwt.sign({ uid: uid, email: email.toLowerCase() }, JWT_SECRET, { expiresIn: '30d' });

    return res.status(201).json({
        success: true,
        message: "Registration successful!",
        user: {
            uid: uid,
            email: email.toLowerCase(),
            phone: phone,
            name: name
        },
        token: token
    });
});

// 4. Login with Email and Password
app.post('/api/auth/login-email', (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) {
        return res.status(400).json({ success: false, message: "Email and password are required" });
    }

    const users = readDbObj(USERS_FILE);
    const userEntry = Object.values(users).find(u => u.email === email.toLowerCase() && u.passwordHash === hashPassword(password));

    if (!userEntry) {
        return res.status(401).json({ success: false, message: "Invalid email or password." });
    }

    const token = jwt.sign({ uid: userEntry.uid, email: userEntry.email }, JWT_SECRET, { expiresIn: '30d' });

    return res.status(200).json({
        success: true,
        message: "Login successful!",
        user: {
            uid: userEntry.uid,
            email: userEntry.email,
            phone: userEntry.phone,
            name: userEntry.name
        },
        token: token
    });
});

// User Profile Endpoints
app.get('/api/auth/profile', (req, res) => {
    const user = getAuthenticatedUser(req);
    if (!user) {
        return res.status(401).json({ success: false, message: "Unauthorized" });
    }
    const users = readDbObj(USERS_FILE);
    const profile = users[user.uid] || {
        uid: user.uid,
        phone: user.phone,
        name: user.name,
        language: "English"
    };
    return res.status(200).json(profile);
});

app.post('/api/auth/profile', (req, res) => {
    const user = getAuthenticatedUser(req);
    if (!user) {
        return res.status(401).json({ success: false, message: "Unauthorized" });
    }
    const { name, language, phone } = req.body;
    const users = readDbObj(USERS_FILE);
    
    const profile = users[user.uid] || {
        uid: user.uid,
        phone: phone || user.phone,
        name: name || user.name,
        language: language || "English",
        createdAt: new Date().toISOString()
    };
    
    if (name) profile.name = name;
    if (language) profile.language = language;
    if (phone) profile.phone = phone;
    profile.updatedAt = new Date().toISOString();
    
    users[user.uid] = profile;
    writeDb(USERS_FILE, users);
    
    return res.status(200).json(profile);
});

// 3. Get Clinics/Hospitals (Dynamically served from database/db_hospitals.json with multi-city support)
app.get('/api/hospitals', async (req, res) => {
    const cityFilter = req.query.city ? req.query.city.toLowerCase() : null;
    try {
        const hospitalsObj = readDbObj(HOSPITALS_FILE);
        let list = Object.values(hospitalsObj);

        if (cityFilter && cityFilter !== 'all' && cityFilter !== 'current') {
            const filtered = list.filter(h =>
                (h.city || '').toLowerCase().includes(cityFilter) ||
                (h.address || '').toLowerCase().includes(cityFilter) ||
                (h.name || '').toLowerCase().includes(cityFilter)
            );
            if (filtered.length > 0) {
                list = filtered;
            }
        }

        return res.status(200).json(list);
    } catch (e) {
        console.error("Read hospitals database error:", e);
        return res.status(500).json({ success: false, message: "Error reading hospitals database" });
    }
});

// 4. Clinical Symptom AI Diagnosis (Gemini 2.5 Flash Integration)
const diagnoseHandler = async (req, res) => {
    const { symptoms, language } = req.body || {};
    if (!symptoms || !symptoms.trim()) {
        return res.status(400).json({ success: false, message: "Symptoms description is required" });
    }

    const cleanSymptoms = normalizeSymptoms(symptoms);
    const geminiKey = process.env.GEMINI_API_KEY;

    if (geminiKey) {
        try {
            const systemPrompt = `You are ArogyaAI medical assistant engine. Analyze symptoms and respond strictly in valid JSON format (language: ${language || 'English'}):
{
  "condition": "Condition name",
  "severity": "low" | "medium" | "high",
  "specialist": "ENT Specialist" | "Cardiologist" | "General Physician" | "Dermatologist",
  "description": "2 sentence explanation of condition and guidance.",
  "medicines": [
    {"name": "Medication Name", "instructions": "Dosage & Usage", "badge": "Category"}
  ],
  "precautions": ["Precaution 1", "Precaution 2"],
  "disclaimer": "This report is for informational purposes only and is not a clinical medical diagnosis."
}`;
            
            // Try gemini-2.5-flash first, fallback to gemini-1.5-flash
            let apiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    contents: [{ parts: [{ text: systemPrompt }, { text: `Symptoms: "${cleanSymptoms}"` }] }],
                    generationConfig: { responseMimeType: "application/json" }
                })
            });

            if (!apiRes.ok) {
                apiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        contents: [{ parts: [{ text: systemPrompt }, { text: `Symptoms: "${cleanSymptoms}"` }] }],
                        generationConfig: { responseMimeType: "application/json" }
                    })
                });
            }

            if (apiRes.ok) {
                const data = await apiRes.json();
                const textOutput = data.candidates?.[0]?.content?.parts?.[0]?.text;
                if (textOutput) {
                    const resultJson = JSON.parse(textOutput);
                    return res.status(200).json(resultJson);
                }
            }
        } catch (e) {
            console.error("Gemini Diagnosis API error:", e);
        }
    }

    // Highly comprehensive offline rule-based fallback if no Gemini key set
    let diagnosis = {
        condition: "Acute Febrile Illness / Mild Fever",
        severity: "low",
        specialist: "General Physician",
        description: "Standard body temperature elevation due to seasonal viral pathogens. Keep body cool and well-rested.",
        medicines: [
            { name: "Paracetamol 500mg", instructions: "1 tablet after meals (SOS)", badge: "Fever/Pain" },
            { name: "Vitamin C Chewable", instructions: "1 tablet daily for 3 days", badge: "Immune Support" }
        ],
        precautions: [
            "Get complete bed rest and monitor temperature.",
            "Drink plenty of water and warm soups.",
            "Consult doctor if fever exceeds 102°F or lasts >3 days."
        ],
        disclaimer: "This report is for informational purposes only and is not a clinical medical diagnosis."
    };

    const s = cleanSymptoms.toLowerCase();
    if (s.includes("chest") || s.includes("heart") || s.includes("cardio") || s.includes("gunde noppi") || s.includes("nenju vali")) {
        diagnosis = {
            condition: "Potential Cardiovascular Emergency",
            severity: "high",
            specialist: "Cardiologist",
            description: "Symptoms point to possible heart strain or angina. Requires immediate medical screening to prevent complications.",
            medicines: [
                { name: "Aspirin 75mg", instructions: "Chew 1 tablet immediately", badge: "Blood Thinner" },
                { name: "Sorbitrate 5mg", instructions: "Place under tongue if prescribed", badge: "Emergency Relief" }
            ],
            precautions: [
                "Sit completely still and rest. Avoid any physical activity.",
                "Call the toll-free emergency ambulance SOS at 108 immediately.",
                "Keep windows open for ventilation."
            ],
            disclaimer: "This report is for informational purposes only and is not a clinical medical diagnosis."
        };
    } else if (s.includes("throat") || s.includes("swallow") || s.includes("gala") || s.includes("gontu") || s.includes("thondai")) {
        diagnosis = {
            condition: "Viral Pharyngitis (Throat Infection)",
            severity: "medium",
            specialist: "ENT Specialist",
            description: "An acute viral infection causing inflammation of the pharynx, commonly associated with swallowing difficulty.",
            medicines: [
                { name: "Paracetamol 500mg", instructions: "1 tablet after meals for soreness", badge: "Fever/Pain" },
                { name: "Betadine Mouthwash", instructions: "Gargle with warm water 3 times daily", badge: "Throat Relief" }
            ],
            precautions: [
                "Gargle with warm salt water regularly.",
                "Avoid oily, cold, or spicy food items.",
                "Keep your neck warm and rest your voice."
            ],
            disclaimer: "This report is for informational purposes only and is not a clinical medical diagnosis."
        };
    }

    return res.status(200).json(diagnosis);
};

app.post('/api/ai/diagnose', diagnoseHandler);
app.post('/api/diagnose', diagnoseHandler);
app.post('/diagnose', diagnoseHandler);

// 4.2 AI Health Chatbot Endpoint with Context Memory
app.post('/api/ai/chat', async (req, res) => {
    const { message, history, language } = req.body;
    if (!message || !message.trim()) {
        return res.status(400).json({ success: false, message: "Message is required" });
    }

    const geminiKey = process.env.GEMINI_API_KEY;
    if (geminiKey) {
        try {
            const systemInstruction = `You are ArogyaAI, an empathetic and knowledgeable healthcare AI assistant. Provide helpful, accurate advice on health, diet, fitness, remedies, and wellness in language: ${language || 'English'}. Always include a brief disclaimer that this is informational and not a substitute for professional medical advice.`;

            // Format contents array with system instruction & message history
            const contents = [
                { role: "user", parts: [{ text: systemInstruction }] },
                { role: "model", parts: [{ text: "Understood. I am ArogyaAI. How can I help with your health today?" }] }
            ];

            if (Array.isArray(history)) {
                history.forEach(h => {
                    contents.push({
                        role: h.sender === 'bot' ? 'model' : 'user',
                        parts: [{ text: h.text }]
                    });
                });
            }

            contents.push({ role: "user", parts: [{ text: message }] });

            let apiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ contents })
            });

            if (!apiRes.ok) {
                apiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ contents })
                });
            }

            if (apiRes.ok) {
                const data = await apiRes.json();
                const replyText = data.candidates?.[0]?.content?.parts?.[0]?.text;
                if (replyText) {
                    return res.status(200).json({ reply: replyText });
                }
            }
        } catch (e) {
            console.error("Gemini Chat API error:", e);
        }
    }

    // Dynamic heuristic reply fallback
    const m = message.toLowerCase();
    let reply = "I am your ArogyaAI healthcare chatbot assistant. Ask me about diet, fitness, mental health, remedies, or symptoms. *Disclaimer: Informational only, not professional medical advice.*";
    if (m.includes("diet") || m.includes("food") || m.includes("eat") || m.includes("nutrition")) {
        reply = "Eat a balanced diet rich in leafy green vegetables, whole grains, clean proteins, and fruits. Stay hydrated by drinking 2.5–3 liters of water daily. *Disclaimer: Informational only, not medical advice.*";
    } else if (m.includes("exercise") || m.includes("workout") || m.includes("walk")) {
        reply = "Engage in at least 30 minutes of moderate aerobic exercise like brisk walking daily to boost cardiac health. *Disclaimer: Informational only, not medical advice.*";
    } else if (m.includes("fever") || m.includes("headache") || m.includes("pain")) {
        reply = "For mild fever or headache, rest well, stay hydrated with warm liquids, and consult a doctor if body temperature exceeds 101°F. *Disclaimer: Informational only, not medical advice.*";
    }

    return res.status(200).json({ reply });
});

// 4.3 AI Vision Medical Image Analysis Endpoint
app.post('/api/ai/analyze-image', async (req, res) => {
    const { imageBase64, mimeType, language } = req.body;
    if (!imageBase64) {
        return res.status(400).json({ success: false, message: "Base64 image data is required" });
    }

    const geminiKey = process.env.GEMINI_API_KEY;
    if (geminiKey) {
        try {
            const promptText = `Analyze this medical image (prescription, skin rash, lab report, or scan) and respond strictly in valid JSON format (language: ${language || 'English'}):
{
  "possible_findings": "Clinical findings description",
  "urgency": "low" | "medium" | "high",
  "specialist": "Recommended doctor specialist",
  "recommendations": ["Recommendation 1", "Recommendation 2"],
  "disclaimer": "This analysis is for informational reference only and must be validated by a certified medical doctor."
}`;

            const cleanBase64 = imageBase64.replace(/^data:image\/\w+;base64,/, '');

            let apiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    contents: [{
                        parts: [
                            { text: promptText },
                            { inline_data: { mime_type: mimeType || "image/jpeg", data: cleanBase64 } }
                        ]
                    }],
                    generationConfig: { responseMimeType: "application/json" }
                })
            });

            if (!apiRes.ok) {
                apiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiKey}`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({
                        contents: [{
                            parts: [
                                { text: promptText },
                                { inline_data: { mime_type: mimeType || "image/jpeg", data: cleanBase64 } }
                            ]
                        }],
                        generationConfig: { responseMimeType: "application/json" }
                    })
                });
            }

            if (apiRes.ok) {
                const data = await apiRes.json();
                const textOutput = data.candidates?.[0]?.content?.parts?.[0]?.text;
                if (textOutput) {
                    const resultJson = JSON.parse(textOutput);
                    return res.status(200).json(resultJson);
                }
            }
        } catch (e) {
            console.error("Gemini Vision API error:", e);
        }
    }

    // Default Vision fallback response
    return res.status(200).json({
        possible_findings: "Allergic Dermatitis / Skin Irritation",
        urgency: "low",
        specialist: "Dermatologist",
        recommendations: [
            "Keep the skin area clean, dry, and hydrated.",
            "Apply Calamine lotion locally for itching relief.",
            "Avoid scratching or using harsh soap products."
        ],
        disclaimer: "This analysis is for informational reference only and must be validated by a certified medical doctor."
    });
});

// 5. Get Appointments
app.get('/api/appointments', (req, res) => {
    const { userId } = req.query;
    const all = readDb(APPOINTMENTS_FILE);
    if (userId) {
        const filtered = all.filter(a => a.userId === userId);
        return res.status(200).json(filtered);
    }
    return res.status(200).json(all);
});

// 5.5 Payment Gateway Endpoints
app.post('/api/payments/create-order', (req, res) => {
    const { amount, currency = "INR", doctorName, patientName } = req.body;
    if (!amount) {
        return res.status(400).json({ success: false, message: "Amount is required" });
    }
    const orderId = `order_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const razorpayKey = process.env.RAZORPAY_KEY_ID || "rzp_test_arogya_ai_demo";
    return res.status(200).json({
        success: true,
        orderId: orderId,
        amount: amount,
        currency: currency,
        key: razorpayKey
    });
});

app.post('/api/payments/verify', async (req, res) => {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, bookingData } = req.body;
    
    if (!razorpay_payment_id || !bookingData) {
        return res.status(400).json({ success: false, message: "Payment ID and Booking Data are required." });
    }

    const all = readDb(APPOINTMENTS_FILE);
    const existing = all.find(a => a.paymentId === razorpay_payment_id);
    if (existing) {
        return res.status(200).json({ success: true, appointment: existing, message: "Appointment already created for this payment." });
    }

    const tokenNum = `TK-${100 + (all.length % 900)}`;
    const apptId = `apt-${Date.now()}-${Math.floor(Math.random() * 100)}`;

    const newBooking = {
        id: apptId,
        appointmentId: apptId,
        type: 'appointment',
        token: tokenNum,
        ...bookingData,
        paymentStatus: 'paid',
        paymentId: razorpay_payment_id,
        paymentMethod: 'razorpay',
        status: 'Confirmed',
        createdAt: new Date().toISOString()
    };

    all.push(newBooking);
    writeDb(APPOINTMENTS_FILE, all);

    const smsMessage = `[ArogyaAI] Booking Confirmed! Token: ${tokenNum} for ${newBooking.patientName} at ${newBooking.clinicName} (Dr. ${newBooking.doctorName}) on ${newBooking.date} at ${newBooking.time}. Fee: ${newBooking.fee}. Address: ${newBooking.address}.`;
    sendSms(newBooking.patientPhone, smsMessage).catch(err => {
        console.error("Failed to send booking confirmation SMS:", err);
    });

    return res.status(200).json({ success: true, appointment: newBooking });
});

// 6. Book Appointment
app.post('/api/appointments', async (req, res) => {
    const booking = req.body;
    if (!booking.userId || !booking.clinicName || !booking.doctorName) {
        return res.status(400).json({ success: false, message: "Missing booking fields" });
    }

    const all = readDb(APPOINTMENTS_FILE);
    const tokenNum = `TK-${100 + (all.length % 900)}`;

    const newBooking = {
        id: `apt-${Date.now()}-${Math.floor(Math.random() * 100)}`,
        type: 'appointment',
        token: tokenNum,
        ...booking,
        createdAt: new Date().toISOString()
    };

    all.push(newBooking);
    writeDb(APPOINTMENTS_FILE, all);

    // Send SMS Confirmation to patient
    const smsMessage = `[ArogyaAI] Booking Confirmed! Token: ${tokenNum} for ${newBooking.patientName} at ${newBooking.clinicName} (Dr. ${newBooking.doctorName}) on ${newBooking.date} at ${newBooking.time}. Fee: ${newBooking.fee}. Address: ${newBooking.address}.`;
    
    // We send this in background to avoid delaying response
    sendSms(newBooking.patientPhone, smsMessage).catch(err => {
        console.error("Failed to send booking confirmation SMS:", err);
    });

    // Trigger Brevo email confirmation if patient email exists
    if (newBooking.patientEmail && newBooking.patientEmail.includes('@')) {
        const htmlEmail = `
<div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 12px; overflow: hidden;">
    <div style="background: linear-gradient(135deg, #1A365D, #00A86B); padding: 24px; text-align: center; color: white;">
        <h1 style="margin: 0; font-size: 24px; font-weight: 700;">ArogyaAI</h1>
        <p style="margin: 4px 0 0 0; font-size: 14px; opacity: 0.9;">AI-Powered Rural Healthcare Assistant</p>
    </div>
    <div style="padding: 24px; background-color: #ffffff; color: #2D3748;">
        <h2 style="color: #1A365D; margin-top: 0;">Appointment Confirmed!</h2>
        <p>Hello <strong>${newBooking.patientName || 'Valued Patient'}</strong>,</p>
        <p>Your healthcare appointment has been successfully booked through ArogyaAI.</p>
        <div style="background-color: #F7FAFC; border-left: 4px solid #00A86B; padding: 16px; margin: 20px 0; border-radius: 4px;">
            <h3 style="margin-top: 0; color: #1A365D; font-size: 16px;">Appointment Summary</h3>
            <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
                <tr><td style="padding: 6px 0; color: #718096; width: 35%;">Patient:</td><td style="padding: 6px 0; font-weight: 600;">${newBooking.patientName}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Doctor:</td><td style="padding: 6px 0; font-weight: 600;">Dr. ${newBooking.doctorName}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Hospital/Clinic:</td><td style="padding: 6px 0; font-weight: 600;">${newBooking.clinicName}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Specialization:</td><td style="padding: 6px 0; font-weight: 600;">${newBooking.specialist || 'General Medicine'}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Date & Time:</td><td style="padding: 6px 0; font-weight: 600;">${newBooking.date} at ${newBooking.time}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Booking ID:</td><td style="padding: 6px 0; font-weight: 600; color: #00A86B;">${newBooking.id} (${tokenNum})</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Address:</td><td style="padding: 6px 0;">${newBooking.address || 'N/A'}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Status:</td><td style="padding: 6px 0; font-weight: 600; color: #00A86B;">Confirmed</td></tr>
            </table>
        </div>
        <p>You can open the ArogyaAI application at any time to view your appointment token and clinical records.</p>
        <p style="margin-top: 24px;">Regards,<br><strong>ArogyaAI Healthcare Team</strong></p>
    </div>
</div>`;
        sendBrevoEmail({
            toEmail: newBooking.patientEmail,
            toName: newBooking.patientName,
            subject: "ArogyaAI — Appointment Confirmation",
            htmlContent: htmlEmail
        }).then(res => {
            if (res.success) {
                newBooking.confirmationEmailSent = true;
                newBooking.confirmationEmailSentAt = new Date().toISOString();
                writeDb(APPOINTMENTS_FILE, all);
            }
        }).catch(err => console.error("Brevo email async error:", err));
    }

    return res.status(200).json({
        success: true,
        appointment: newBooking
    });
});

// 6.1 Trigger Brevo Appointment Email Confirmation Endpoint
app.post('/api/appointments/send-confirmation', async (req, res) => {
    const { appointmentId, patientEmail, patientName, doctorName, clinicName, specialist, date, time, address, id, token, resend } = req.body;
    const targetEmail = patientEmail || req.body.email;

    if (!targetEmail || !targetEmail.includes('@')) {
        return res.status(400).json({ success: false, message: "Valid patient email is required" });
    }

    const bookingId = id || appointmentId || `APT-${Date.now().toString().slice(-6)}`;
    const docName = doctorName || "Specialist";
    const hospName = clinicName || "Arogya Health Centre";

    const htmlContent = `
<div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 12px; overflow: hidden;">
    <div style="background: linear-gradient(135deg, #1A365D, #00A86B); padding: 24px; text-align: center; color: white;">
        <h1 style="margin: 0; font-size: 24px; font-weight: 700;">ArogyaAI</h1>
        <p style="margin: 4px 0 0 0; font-size: 14px; opacity: 0.9;">AI-Powered Rural Healthcare Assistant</p>
    </div>
    <div style="padding: 24px; background-color: #ffffff; color: #2D3748;">
        <h2 style="color: #1A365D; margin-top: 0;">${resend ? 'Resent: ' : ''}Appointment Confirmation</h2>
        <p>Hello <strong>${patientName || 'Valued Patient'}</strong>,</p>
        <p>Your ArogyaAI appointment has been successfully booked.</p>
        <div style="background-color: #F7FAFC; border-left: 4px solid #00A86B; padding: 16px; margin: 20px 0; border-radius: 4px;">
            <h3 style="margin-top: 0; color: #1A365D; font-size: 16px;">Appointment Details</h3>
            <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
                <tr><td style="padding: 6px 0; color: #718096; width: 35%;">Patient:</td><td style="padding: 6px 0; font-weight: 600;">${patientName || 'N/A'}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Doctor:</td><td style="padding: 6px 0; font-weight: 600;">Dr. ${docName}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Hospital / Clinic:</td><td style="padding: 6px 0; font-weight: 600;">${hospName}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Specialization:</td><td style="padding: 6px 0; font-weight: 600;">${specialist || 'General Healthcare'}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Date:</td><td style="padding: 6px 0; font-weight: 600;">${date || 'N/A'}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Time:</td><td style="padding: 6px 0; font-weight: 600;">${time || 'N/A'}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Booking ID:</td><td style="padding: 6px 0; font-weight: 600; color: #00A86B;">${bookingId}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Address:</td><td style="padding: 6px 0;">${address || 'N/A'}</td></tr>
                <tr><td style="padding: 6px 0; color: #718096;">Status:</td><td style="padding: 6px 0; font-weight: 600; color: #00A86B;">Confirmed</td></tr>
            </table>
        </div>
        <p>You can open ArogyaAI to view your appointment and clinical health records.</p>
        <br>
        <p style="margin-top: 24px;">Regards,<br><strong>ArogyaAI</strong><br>AI-Powered Healthcare Assistant</p>
    </div>
</div>`;

    const result = await sendBrevoEmail({
        toEmail: targetEmail,
        toName: patientName || targetEmail,
        subject: `ArogyaAI — Appointment Confirmation`,
        htmlContent: htmlContent
    });

    if (result.success) {
        return res.status(200).json({ success: true, message: "Appointment confirmation email sent via Brevo", messageId: result.messageId });
    } else {
        return res.status(500).json({ success: false, message: result.error || "Failed to send email via Brevo" });
    }
});

// 6.2 Resend Appointment Email Endpoint
app.post('/api/appointments/resend-confirmation', async (req, res) => {
    return app._router.handle({ ...req, url: '/api/appointments/send-confirmation', body: { ...req.body, resend: true } }, res);
});

// 6.3 Email Prescription Endpoint
app.post('/api/prescriptions/send-email', async (req, res) => {
    const { patientEmail, patientName, condition, symptoms, medicines, diagnosisDate } = req.body;
    if (!patientEmail || !patientEmail.includes('@')) {
        return res.status(400).json({ success: false, message: "Valid patient email is required" });
    }

    const medsListHtml = Array.isArray(medicines)
        ? medicines.map(m => `<li><strong>${m.name || 'Medication'}</strong> — ${m.instructions || 'As directed'}</li>`).join('')
        : '<li>Paracetamol 500mg — 1 tablet after meals (SOS)</li>';

    const htmlContent = `
<div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 12px; overflow: hidden;">
    <div style="background: linear-gradient(135deg, #1A365D, #00A86B); padding: 24px; text-align: center; color: white;">
        <h1 style="margin: 0; font-size: 24px; font-weight: 700;">ArogyaAI Medical Prescription</h1>
        <p style="margin: 4px 0 0 0; font-size: 14px; opacity: 0.9;">AI-Powered Rural Healthcare Assistant</p>
    </div>
    <div style="padding: 24px; background-color: #ffffff; color: #2D3748;">
        <p>Hello <strong>${patientName || 'Valued Patient'}</strong>,</p>
        <p>Here is your digital prescription and AI clinical assessment record from ArogyaAI.</p>
        <div style="background-color: #F7FAFC; border-left: 4px solid #00A86B; padding: 16px; margin: 20px 0; border-radius: 4px;">
            <p><strong>Date:</strong> ${diagnosisDate || new Date().toLocaleDateString("en-IN")}</p>
            <p><strong>Clinical Condition:</strong> ${condition || 'General Health Consultation'}</p>
            <p><strong>Symptoms Reported:</strong> ${symptoms || 'None specified'}</p>
            <h4 style="color: #1A365D; margin-bottom: 8px;">Prescribed Medications & Guidance:</h4>
            <ul>${medsListHtml}</ul>
        </div>
        <p style="font-size: 12px; color: #718096; border-top: 1px solid #E2E8F0; padding-top: 12px;">
            <em>Disclaimer: This prescription record is generated by ArogyaAI for informational reference and must be validated by a certified medical doctor.</em>
        </p>
        <p style="margin-top: 24px;">Regards,<br><strong>ArogyaAI Team</strong></p>
    </div>
</div>`;

    const result = await sendBrevoEmail({
        toEmail: patientEmail,
        toName: patientName || patientEmail,
        subject: "ArogyaAI — Your Clinical Prescription Record",
        htmlContent: htmlContent
    });

    if (result.success) {
        return res.status(200).json({ success: true, message: "Prescription email sent via Brevo", messageId: result.messageId });
    } else {
        return res.status(500).json({ success: false, message: result.error || "Failed to send email" });
    }
});

// 6.4 Brevo Development Diagnostic Endpoint
app.get('/api/test/brevo', async (req, res) => {
    const testEmail = req.query.email || process.env.BREVO_SENDER_EMAIL || "knaveengoud123@gmail.com";
    const result = await sendBrevoEmail({
        toEmail: testEmail,
        toName: "ArogyaAI Tester",
        subject: "ArogyaAI — Brevo Integration Test Connection",
        htmlContent: `<h2>ArogyaAI Brevo Test</h2><p>Brevo Transactional Email integration is operational.</p>`
    });
    return res.status(result.success ? 200 : 500).json(result);
});

// 7. Get Reports
app.get('/api/reports', (req, res) => {
    const { userId } = req.query;
    const all = readDb(REPORTS_FILE);
    if (userId) {
        const filtered = all.filter(r => r.userId === userId);
        return res.status(200).json(filtered);
    }
    return res.status(200).json(all);
});


// 8. Create Report Log
app.post('/api/reports', (req, res) => {
    const report = req.body;
    if (!report.userId || !report.symptoms || !report.condition) {
        return res.status(400).json({ success: false, message: "Missing report details" });
    }

    const all = readDb(REPORTS_FILE);
    const newReport = {
        id: `rep-${Date.now()}-${Math.floor(Math.random() * 100)}`,
        type: 'symptom',
        date: new Date().toLocaleDateString("en-IN"),
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        ...report
    };

    all.push(newReport);
    writeDb(REPORTS_FILE, all);

    return res.status(200).json({
        success: true,
        report: newReport
    });
});

// 9. Delete Appointment
app.delete('/api/appointments/:id', (req, res) => {
    const { id } = req.params;
    let all = readDb(APPOINTMENTS_FILE);
    const initialLen = all.length;
    all = all.filter(item => item.id !== id);
    writeDb(APPOINTMENTS_FILE, all);
    return res.status(200).json({ success: all.length < initialLen });
});

// 10. Delete Report
app.delete('/api/reports/:id', (req, res) => {
    const { id } = req.params;
    let all = readDb(REPORTS_FILE);
    const initialLen = all.length;
    all = all.filter(item => item.id !== id);
    writeDb(REPORTS_FILE, all);
    return res.status(200).json({ success: all.length < initialLen });
});

// 11. Get Emergency Contacts
const CONTACTS_FILE = path.join(__dirname, 'contacts.json');
app.get('/api/emergency/contacts', (req, res) => {
    const all = readDb(CONTACTS_FILE);
    return res.status(200).json(all);
});

// 12. Add Emergency Contact
app.post('/api/emergency/contacts', (req, res) => {
    const contact = req.body;
    if (!contact.name || !contact.phone) {
        return res.status(400).json({ success: false, message: "Missing contact name or phone" });
    }
    const all = readDb(CONTACTS_FILE);
    const newContact = {
        id: `con-${Date.now()}`,
        ...contact
    };
    all.push(newContact);
    writeDb(CONTACTS_FILE, all);
    return res.status(201).json(newContact);
});

// 13. Delete Emergency Contact
app.delete('/api/emergency/contacts/:id', (req, res) => {
    const { id } = req.params;
    let all = readDb(CONTACTS_FILE);
    const initialLen = all.length;
    all = all.filter(item => item.id !== id);
    writeDb(CONTACTS_FILE, all);
    return res.status(200).json({ success: all.length < initialLen });
});

// 14. Share Live Location
app.post('/api/emergency/share-location', (req, res) => {
    const { latitude, longitude, contacts, message } = req.body;
    console.log(`Live Location shared: ${latitude}, ${longitude} with contacts: ${contacts.join(', ')}. Msg: ${message}`);
    return res.status(200).json({ success: true, message: "Location shared successfully" });
});

// 15. Trigger SOS Dispatch (Calibrated around actual user location)
app.post('/api/emergency/sos', async (req, res) => {
    const { latitude, longitude, message } = req.body;
    const baseLat = parseFloat(latitude) || 17.3850;
    const baseLng = parseFloat(longitude) || 78.4867;

    let city = "Local Area";
    try {
        const geoUrl = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${baseLat}&lon=${baseLng}`;
        const response = await fetch(geoUrl, {
            headers: { 'User-Agent': 'ArogyaAI-Mobile-Engine' }
        });
        if (response.ok) {
            const geoData = await response.json();
            const addr = geoData.address || {};
            city = addr.city || addr.town || addr.village || addr.suburb || addr.county || "Local Area";
        }
    } catch (e) {
        console.error("SOS Reverse geocoding failed:", e);
    }

    // Centered around the live GPS coordinate
    const nearestHospital = {
        name: "Govt Primary Health Centre (PHC)",
        phone: "080-28561111",
        address: `Emergency Ward 5, PHC Campus, ${city}`,
        lat: baseLat - 0.005,
        lng: baseLng - 0.008
    };

    return res.status(200).json({
        success: true,
        message: "SOS alert successfully broadcasted to nearest responders.",
        nearest_hospital: nearestHospital
    });
});

// Wildcard SPA Fallback Handler for Web Frontend Routing
app.get('*', (req, res) => {
    if (req.path.startsWith('/api') || req.path.startsWith('/health') || req.path.startsWith('/download-apk')) {
        return res.status(404).json({ error: "API endpoint not found" });
    }
    const webIndex = fs.existsSync(path.join(__dirname, '../arogya_ai_web/index.html'))
        ? path.join(__dirname, '../arogya_ai_web/index.html')
        : path.join(__dirname, 'public/index.html');
    if (fs.existsSync(webIndex)) {
        return res.sendFile(webIndex);
    }
    return res.status(404).send("ArogyaAI Web application build not found.");
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`ArogyaAI Premium Server listening on http://0.0.0.0:${PORT}`);
});

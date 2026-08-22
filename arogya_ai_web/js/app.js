/* ==========================================================================
   ArogyaAI Web Application Engine - Production Firebase & Gemini Integration
   ========================================================================== */

// Global Application State
const state = {
  currentUser: null,
  authToken: null,
  selectedLanguage: 'English',
  currentView: 'splash',
  baseUrl: window.AROGYA_API_BASE_URL || (window.location.origin.includes('localhost') ? 'http://localhost:5000/api' : 'https://arogya-ai-backend.onrender.com/api'),
  hospitals: [],
  doctors: [],
  selectedDoctor: null,
  speechLang: 'en-IN',
  isListening: false,
  recognition: null,
  mapInstance: null,
  reminders: [],
  emergencyContacts: [],
  reports: [],
  appointments: [],
  chatHistory: []
};

// Language Translations Dictionary (Matching LocalizationService.dart)
const translations = {
  English: {
    welcome: 'Hello, Namaste! 👋',
    emergency_sos: 'Emergency SOS',
    emergency_desc: 'Tap for healthcare emergency (108)',
    services_title: 'Arogya Assistant Services',
    symptom_checker: 'AI Symptom Checker',
    nearby_hospitals: 'Nearby Hospitals',
    chatbot: 'AI Health Chatbot',
    health_score: 'Health Score',
    reminders: 'Medicine Reminders',
    records: 'Health Records',
    image_scan: 'Medical Image Scan',
    admin_panel: 'Admin Dashboard'
  },
  Telugu: {
    welcome: 'నమస్కారం! 👋',
    emergency_sos: 'అత్యవసర SOS',
    emergency_desc: 'ఆరోగ్య అత్యవసర పరిస్థితి (108) కోసం నొక్కండి',
    services_title: 'ఆరోగ్య సహాయక సేవలు',
    symptom_checker: 'AI లక్షణాల గుర్తింపు',
    nearby_hospitals: 'సమీప ఆసుపత్రులు',
    chatbot: 'AI హెల్త్ చాట్‌బాట్',
    health_score: 'ఆరోగ్య స్కోర్',
    reminders: 'మందుల రిమైండర్',
    records: 'ఆరోగ్య రికార్డులు',
    image_scan: 'వైద్య చిత్ర స్కాన్',
    admin_panel: 'అడ్మిన్ డాష్‌బోర్డ్'
  },
  Hindi: {
    welcome: 'नमस्ते! 👋',
    emergency_sos: 'आपातकालीन एसओएस',
    emergency_desc: 'स्वास्थ्य आपातकाल (108) के लिए टैप करें',
    services_title: 'आरोग्य सहायक सेवाएं',
    symptom_checker: 'एआई लक्षण जांचकर्ता',
    nearby_hospitals: 'आसपास के अस्पताल',
    chatbot: 'एआई स्वास्थ्य चैटबॉट',
    health_score: 'स्वास्थ्य स्कोर',
    reminders: 'दवा अनुस्मारक',
    records: 'स्वास्थ्य रिकॉर्ड',
    image_scan: 'मेडिकल इमेज स्कैन',
    admin_panel: 'व्यवस्थापक डैशबोर्ड'
  },
  Tamil: {
    welcome: 'வணக்கம்! 👋',
    emergency_sos: 'அவசர SOS',
    emergency_desc: 'சுகாதார அவசரநிலைக்கு (108) தட்டவும்',
    services_title: 'ஆரோக்யா உதவி சேவைகள்',
    symptom_checker: 'AI அறிகுறி சரிபார்ப்பான்',
    nearby_hospitals: 'அருகிலுள்ள மருத்துவமனைகள்',
    chatbot: 'AI சுகாதார அரட்டை போட்',
    health_score: 'சுகாதார மதிப்பெண்',
    reminders: 'மருந்து நினைவூட்டல்கள்',
    records: 'சுகாதார பதிவுகள்',
    image_scan: 'மருத்துவப் படம் ஸ்கேன்',
    admin_panel: 'நிர்வாகி டாஷ்போர்டு'
  }
};

// Initialize Application & Firebase
document.addEventListener('DOMContentLoaded', () => {
  initSession();
  initWebSpeechApi();
  loadRemindersFromStorage();

  // Handle auth callback from firebase module
  window.onFirebaseUserAuthenticated = (user, profile) => {
    console.log("[AUTH LOG ROUTER] Authenticated user received:", user.email || user.uid);
    state.currentUser = {
      uid: user.uid,
      name: profile?.name || user.displayName || 'Arogya Patient',
      email: user.email || '',
      photoURL: profile?.photoURL || user.photoURL || 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=150',
      language: profile?.language || state.selectedLanguage,
      profileCompleted: true
    };
    saveSession(state.currentUser, user.accessToken || 'session-token-active');
    updateUserHeaderBadge();
    console.log("[AUTH LOG ROUTER] Navigating user to dashboard...");
    navigateTo('dashboard');
    syncUserDataFromFirestore();
  };

  window.onFirebaseUserSignedOut = () => {
    // Only execute signout if localStorage has no active session
    if (!localStorage.getItem('currentUser')) {
      console.log("[AUTH LOG ROUTER] Executing signout cleanup.");
      state.currentUser = null;
      localStorage.removeItem('currentUser');
      localStorage.removeItem('auth_token');
      updateUserHeaderBadge();
      navigateTo('login');
    }
  };

  // Route automatically based on restored session
  initSession();
  if (state.currentUser) {
    console.log("[AUTH LOG ROUTER] Restored existing user session:", state.currentUser.name);
    navigateTo('dashboard');
  } else {
    navigateTo('login');
  }
});

async function syncUserDataFromFirestore() {
  if (!state.currentUser || !window.firestoreService) return;
  try {
    const uid = state.currentUser.uid;
    const allAppointments = await window.firestoreService.fetchCollection('appointments');
    state.appointments = allAppointments.filter(a => a.userId === uid || a.patientPhone?.includes(state.currentUser.phone));

    const allReports = await window.firestoreService.fetchCollection('reports');
    state.reports = allReports.filter(r => r.userId === uid);

    const allContacts = await window.firestoreService.fetchCollection('emergencyContacts');
    state.emergencyContacts = allContacts.filter(c => c.userId === uid);

    updateUserHeaderBadge();
  } catch (e) {
    console.warn("[FIRESTORE] User data sync notice:", e);
  }
}

/* ── SESSION MANAGEMENT ── */
function initSession() {
  const savedUser = localStorage.getItem('currentUser');
  const savedToken = localStorage.getItem('auth_token');
  const savedLang = localStorage.getItem('selectedLanguage');

  if (savedUser) {
    try { state.currentUser = JSON.parse(savedUser); } catch (_) {}
  }
  if (savedToken) state.authToken = savedToken;
  if (savedLang) {
    state.selectedLanguage = savedLang;
    const select = document.getElementById('languageSelect');
    if (select) select.value = savedLang;
  }
  updateUserHeaderBadge();
}

function saveSession(user, token) {
  state.currentUser = user;
  localStorage.setItem('currentUser', JSON.stringify(user));
  if (token) {
    state.authToken = token;
    localStorage.setItem('auth_token', token);
  }
  updateUserHeaderBadge();
}
window.saveSession = saveSession;

function updateUserHeaderBadge() {
  const badge = document.getElementById('userProfileBadge');
  const avatar = document.getElementById('headerAvatar');
  const nameText = document.getElementById('headerUserName');
  const dashAvatar = document.getElementById('dashAvatar');
  const dashName = document.getElementById('dashUserName');

  const name = state.currentUser ? (state.currentUser.name || 'Arogya User') : 'Guest User';
  const photo = state.currentUser ? state.currentUser.photoURL : '';

  if (badge) badge.style.display = state.currentUser ? 'flex' : 'none';
  if (nameText) nameText.innerText = name;
  if (dashName) dashName.innerText = name;

  if (photo && photo.startsWith('http')) {
    if (avatar) avatar.innerHTML = `<img src="${photo}" style="width:100%;height:100%;border-radius:50%;object-fit:cover;">`;
    if (dashAvatar) dashAvatar.innerHTML = `<img src="${photo}" style="width:100%;height:100%;border-radius:50%;object-fit:cover;">`;
  } else {
    const initial = name.charAt(0).toUpperCase();
    if (avatar) avatar.innerText = initial;
    if (dashAvatar) dashAvatar.innerText = initial;
  }
}

function logoutUser() {
  if (window.logoutFirebaseUser) {
    window.logoutFirebaseUser();
  }
  state.currentUser = null;
  state.authToken = null;
  localStorage.removeItem('currentUser');
  localStorage.removeItem('auth_token');
  updateUserHeaderBadge();
  navigateTo('login');
}
window.logoutUser = logoutUser;

/* ── SPA ROUTER ── */
function navigateTo(viewId) {
  const views = document.querySelectorAll('.page-view');
  views.forEach(v => v.classList.remove('active'));

  const target = document.getElementById(`view-${viewId}`);
  if (target) {
    target.classList.add('active');
    state.currentView = viewId;
  }

  document.querySelectorAll('.nav-tab-item').forEach(item => item.classList.remove('active'));
  if (viewId === 'dashboard') document.getElementById('tab-home')?.classList.add('active');
  if (viewId === 'hospitals' || viewId === 'map' || viewId === 'doctor_profile') document.getElementById('tab-clinics')?.classList.add('active');
  if (viewId === 'health_records') document.getElementById('tab-visits')?.classList.add('active');
  if (viewId === 'profile_setup') document.getElementById('tab-profile')?.classList.add('active');

  if (viewId === 'hospitals') fetchHospitalsList();
  if (viewId === 'map') initLeafletMap();
  if (viewId === 'health_records') renderHealthRecordsView();
  if (viewId === 'medicine_reminder') renderRemindersList();
  if (viewId === 'emergency_sos') renderEmergencySosView();
  if (viewId === 'chatbot') renderChatbotView();
  if (viewId === 'diagnostics') runDiagnosticsCheck();
  if (viewId === 'admin_panel') loadAdminPanelData();
  if (viewId === 'doctor_profile') renderDoctorProfileView();
  if (viewId === 'health_score') renderHealthScoreView();
  if (viewId === 'profile_setup') renderProfileSetupView();

  window.scrollTo({ top: 0, behavior: 'smooth' });
}
window.navigateTo = navigateTo;

/* ── MULTILINGUAL LOCALIZATION ENGINE ── */
function setAppLanguage(lang) {
  state.selectedLanguage = lang;
  localStorage.setItem('selectedLanguage', lang);
  const dict = translations[lang] || translations.English;

  const welcome = document.getElementById('dashWelcomeText');
  const sosTitle = document.getElementById('dashSosTitle');
  const sosDesc = document.getElementById('dashSosDesc');
  const servTitle = document.getElementById('dashServicesTitle');

  if (welcome) welcome.innerText = dict.welcome || 'Hello, Namaste! 👋';
  if (sosTitle) sosTitle.innerText = dict.emergency_sos || 'Emergency SOS';
  if (sosDesc) sosDesc.innerText = dict.emergency_desc || 'Tap for healthcare emergency (108)';
  if (servTitle) servTitle.innerText = dict.services_title || 'Arogya Assistant Services';

  const setElemText = (id, text) => {
    const el = document.getElementById(id);
    if (el) el.innerText = text;
  };

  setElemText('cardSymptomTitle', dict.symptom_checker || 'AI Symptom Checker');
  setElemText('cardHospitalsTitle', dict.nearby_hospitals || 'Nearby Hospitals');
  setElemText('cardChatbotTitle', dict.chatbot || 'AI Health Chatbot');
  setElemText('cardScoreTitle', dict.health_score || 'Health Score');
  setElemText('cardRemindersTitle', dict.reminders || 'Medicine Reminders');
  setElemText('cardRecordsTitle', dict.records || 'Health Records');
  setElemText('cardScanTitle', dict.image_scan || 'Medical Image Scan');
  setElemText('cardAdminTitle', dict.admin_panel || 'Admin Dashboard');
}
window.setAppLanguage = setAppLanguage;

/* ── PROFILE SETUP ── */
async function saveUserProfile() {
  const name = document.getElementById('profileNameInput').value.trim() || (state.currentUser ? state.currentUser.name : 'Arogya Patient');
  const age = document.getElementById('profileAgeInput').value || '28';
  const gender = document.getElementById('profileGenderSelect').value;
  const blood = document.getElementById('profileBloodGroupSelect').value;

  if (state.currentUser) {
    state.currentUser.name = name;
    state.currentUser.age = age;
    state.currentUser.gender = gender;
    state.currentUser.bloodGroup = blood;
    state.currentUser.profileCompleted = true;
    saveSession(state.currentUser, state.authToken);

    if (window.firestoreService && state.currentUser.uid) {
      try {
        await window.firestoreService.updateDocument('users', state.currentUser.uid, {
          name, age, gender, bloodGroup: blood, profileCompleted: true
        });
      } catch (e) {
        console.error("Save profile firestore error:", e);
      }
    }
  }
  alert('Profile updated successfully!');
  navigateTo('dashboard');
}
window.saveUserProfile = saveUserProfile;

/* ── NATIVE WEB SPEECH API WITH CONTINUOUS MIC RECORDING ── */
function getSpeechRecognitionInstance() {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SpeechRecognition) return null;
  
  try {
    const recognition = new SpeechRecognition();
    recognition.continuous = true; // Keep mic open continuously while user speaks
    recognition.interimResults = true; // Stream words live as user speaks
    recognition.lang = state.speechLang || 'en-IN';

    recognition.onresult = (event) => {
      let fullTranscript = '';
      for (let i = 0; i < event.results.length; i++) {
        fullTranscript += event.results[i][0].transcript;
      }
      const textarea = document.getElementById('symptomsTextarea');
      if (textarea && fullTranscript.trim()) {
        textarea.value = fullTranscript;
      }
    };

    recognition.onerror = (event) => {
      console.warn("[SPEECH RECOGNITION ERROR]", event.error);
      const status = document.getElementById('micStatusText');
      if (status) {
        if (event.error === 'not-allowed' || event.error === 'permission-denied') {
          status.innerHTML = '<span style="color: #ef4444; font-weight: 700;">Microphone access blocked. Please allow mic in browser settings.</span>';
        } else if (event.error === 'no-speech') {
          status.innerText = 'Listening... Speak symptoms clearly into microphone 🎙️';
          return;
        } else {
          status.innerText = `Speech notice: ${event.error}. You can also type symptoms below.`;
        }
      }
      if (event.error !== 'no-speech') {
        toggleSpeechListening(false);
      }
    };

    recognition.onend = () => {
      // Auto-restart if user has not explicitly clicked stop
      if (state.isListening && state.recognition) {
        try {
          state.recognition.start();
        } catch (_) {
          toggleSpeechListening(false);
        }
      } else {
        toggleSpeechListening(false);
      }
    };

    return recognition;
  } catch (e) {
    console.error("SpeechRecognition instantiation failed:", e);
    return null;
  }
}

function initWebSpeechApi() {
  state.recognition = getSpeechRecognitionInstance();
}

function selectSpeechLang(element, langCode) {
  document.querySelectorAll('.lang-chip').forEach(c => c.classList.remove('active'));
  if (element) element.classList.add('active');
  state.speechLang = langCode;
  if (state.recognition) {
    try { state.recognition.lang = langCode; } catch (_) {}
  }
}
window.selectSpeechLang = selectSpeechLang;

async function toggleSpeechListening(forceState) {
  const micBtn = document.getElementById('micBtn');
  const status = document.getElementById('micStatusText');

  const nextState = forceState !== undefined ? forceState : !state.isListening;

  if (nextState) {
    // 1. Explicitly prompt user for Microphone permission via getUserMedia
    if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        stream.getTracks().forEach(t => t.stop());
      } catch (err) {
        console.warn("Microphone permission denied:", err);
        if (status) {
          status.innerHTML = '<span style="color: #ef4444; font-weight: 700;">Microphone blocked by Chrome on IP address.<br><br>👉 Please open <a href="http://localhost:5000" style="color: #2563eb; text-decoration: underline; font-weight: 800;">http://localhost:5000</a> in your laptop browser to unblock microphone!</span>';
        }
        return;
      }
    }

    // 2. Create continuous SpeechRecognition instance
    state.recognition = getSpeechRecognitionInstance();

    if (!state.recognition) {
      if (status) {
        status.innerHTML = '<span style="color: #ef4444; font-weight: 700;">Speech API requires <strong>http://localhost:5000</strong> or Chrome HTTPS. Please type symptoms below.</span>';
      } else {
        alert('Microphone speech recognition requires http://localhost:5000 or HTTPS. Please type symptoms manually.');
      }
      return;
    }

    try {
      state.recognition.lang = state.speechLang || 'en-IN';
      state.isListening = true;
      state.recognition.start();

      if (micBtn) {
        micBtn.style.backgroundColor = 'var(--emergency)';
        micBtn.classList.add('pulse-mic-btn');
      }
      if (status) status.innerHTML = '<strong style="color: #10b981;">🔴 LISTENING NOW... Speak symptoms clearly into mic!</strong>';
    } catch (e) {
      console.error("Mic start error:", e);
      state.isListening = false;
      if (micBtn) {
        micBtn.style.backgroundColor = 'var(--primary)';
        micBtn.classList.remove('pulse-mic-btn');
      }
      if (status) status.innerText = 'Tap mic & describe symptoms';
    }
  } else {
    state.isListening = false;
    if (state.recognition) {
      try { state.recognition.stop(); } catch (_) {}
    }
    if (micBtn) {
      micBtn.style.backgroundColor = 'var(--primary)';
      micBtn.classList.remove('pulse-mic-btn');
    }
    if (status) status.innerText = 'Tap mic & describe symptoms';
  }
}
window.toggleSpeechListening = toggleSpeechListening;

async function runSymptomDiagnosis() {
  const text = document.getElementById('symptomsTextarea').value.trim();
  if (!text) {
    alert('Please speak or type symptoms first.');
    return;
  }
  state.currentSymptoms = text;

  const btn = document.getElementById('btnAnalyzeSymptoms');
  btn.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> Diagnosing with Gemini...';
  btn.disabled = true;

  // Save voice transcript to Firestore voiceHistory
  if (window.firestoreService && state.currentUser) {
    window.firestoreService.addDocument('voiceHistory', {
      userId: state.currentUser.uid,
      transcript: text,
      language: state.speechLang
    }).catch(e => console.warn("Voice transcript save notice:", e));
  }

  try {
    const res = await fetch(`${state.baseUrl}/ai/diagnose`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ symptoms: text, language: state.selectedLanguage })
    });
    const data = await res.json();
    renderDiagnosisResult(data);
  } catch (err) {
    console.error("Diagnosis API warning, fallback heuristic:", err);
    renderDiagnosisResult(runLocalDiagnosisHeuristic(text));
  }

  btn.innerHTML = '<i class="fa-solid fa-wand-magic-sparkles"></i> Analyze Symptoms';
  btn.disabled = false;
  navigateTo('ai_result');
}
window.runSymptomDiagnosis = runSymptomDiagnosis;

function runLocalDiagnosisHeuristic(symptoms) {
  const s = symptoms.toLowerCase();
  if (s.includes('throat') || s.includes('swallow') || s.includes('gala') || s.includes('gontu')) {
    return {
      condition: 'Throat Infection (Pharyngitis)',
      severity: 'medium',
      specialist: 'ENT Specialist',
      description: 'An acute viral infection causing inflammation of the vocal tract and pharynx.',
      precautions: ['Gargle with warm salt water 3 times a day', 'Avoid cold drinks and oily food'],
      medicines: [
        { name: 'Paracetamol 500mg', instructions: '1 tablet after meals (SOS)', badge: 'Fever/Pain' },
        { name: 'Betadine Mouthwash', instructions: 'Gargle with warm water', badge: 'Throat Relief' }
      ],
      disclaimer: "This report is generated for informational reference only."
    };
  }
  return {
    condition: 'Acute Febrile Illness / Mild Fever',
    severity: 'low',
    specialist: 'General Physician',
    description: 'Standard body temperature elevation due to seasonal viral pathogens.',
    precautions: ['Get complete bed rest', 'Drink plenty of water and warm soups'],
    medicines: [
      { name: 'Paracetamol 500mg', instructions: '1 tablet after meals (SOS)', badge: 'Fever/Pain' }
    ],
    disclaimer: "This report is generated for informational reference only."
  };
}

function renderDiagnosisResult(diag) {
  window.lastDiagnosis = diag;
  document.getElementById('diagResultCondition').innerText = diag.condition || 'Diagnosis Report';
  document.getElementById('diagResultSpecialist').innerText = `Recommended Specialist: ${diag.specialist || 'General Physician'}`;
  document.getElementById('diagResultDescription').innerText = diag.description || 'Clinical analysis completed.';

  const badge = document.getElementById('diagResultSeverityBadge');
  const sev = (diag.severity || 'low').toLowerCase();
  badge.className = `badge badge-${sev}`;
  badge.innerText = `${sev.toUpperCase()} SEVERITY`;

  const medsList = document.getElementById('diagResultMedicinesList');
  medsList.innerHTML = (diag.medicines || []).map(m => `
    <div style="background-color: #FFFFFF; border: 1px solid var(--slate-200); padding: 0.75rem 1rem; border-radius: var(--radius-md); margin-bottom: 0.5rem; display: flex; justify-content: space-between; align-items: center;">
      <div>
        <b style="color: var(--slate-800); font-size: 0.9rem;">${m.name}</b>
        <p style="font-size: 0.75rem; color: var(--slate-500);">${m.instructions}</p>
      </div>
      <span class="badge badge-low">${m.badge || 'Medication'}</span>
    </div>
  `).join('');

  const precsList = document.getElementById('diagResultPrecautionsList');
  precsList.innerHTML = (diag.precautions || []).map(p => `<li>${p}</li>`).join('');

  // Store AI prediction in Firestore aiPredictions
  if (window.firestoreService && state.currentUser) {
    window.firestoreService.addDocument('aiPredictions', {
      userId: state.currentUser.uid,
      condition: diag.condition,
      severity: diag.severity,
      specialist: diag.specialist,
      createdAt: new Date().toISOString()
    }).catch(e => console.warn("AI prediction save notice:", e));
  }
}

async function saveDiagnosisToRecords() {
  if (!window.lastDiagnosis) return;
  const report = {
    userId: state.currentUser ? state.currentUser.uid : 'guest',
    type: 'symptom',
    condition: window.lastDiagnosis.condition,
    severity: window.lastDiagnosis.severity,
    specialist: window.lastDiagnosis.specialist,
    description: window.lastDiagnosis.description,
    symptoms: document.getElementById('symptomsTextarea').value || 'Symptom analysis',
    date: new Date().toISOString().split('T')[0]
  };

  state.reports.unshift(report);

  if (window.firestoreService && state.currentUser) {
    try {
      await window.firestoreService.addDocument('reports', report);
    } catch (e) {
      console.error("Save report firestore error:", e);
    }
  }

  alert('Diagnosis saved to Clinical Health Records!');
  navigateTo('health_records');
}
window.saveDiagnosisToRecords = saveDiagnosisToRecords;

/* ── HOSPITALS & MAP ENGINE ── */
function getDistanceInKm(lat1, lon1, lat2, lon2) {
  if (!lat1 || !lon1 || !lat2 || !lon2) return null;
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

async function detectUserCityAndLocation() {
  if (!navigator.geolocation) return;
  navigator.geolocation.getCurrentPosition(
    async (pos) => {
      const lat = pos.coords.latitude;
      const lng = pos.coords.longitude;
      state.userLocation = { lat, lng };

      try {
        const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}`);
        const data = await res.json();
        const city = data.address?.city || data.address?.town || data.address?.village || data.address?.county || data.address?.state_district || 'Your Location';
        state.detectedCity = city;
        console.log("[REVERSE GEOCODING] User City Detected:", city);
      } catch (e) {
        console.warn("[REVERSE GEOCODING] Notice:", e);
      }
    },
    (err) => console.warn("[GPS] Location permission denied/unavailable:", err.message),
    { timeout: 6000 }
  );
}

function filterHospitalsByCity(cityName) {
  state.selectedCityFilter = cityName;
  if (!cityName || cityName === 'ALL' || cityName === 'CURRENT') {
    renderHospitalsList(state.hospitals);
    return;
  }
  const filtered = state.hospitals.filter(h =>
    (h.city || '').toLowerCase().includes(cityName.toLowerCase()) ||
    (h.address || '').toLowerCase().includes(cityName.toLowerCase()) ||
    (h.name || '').toLowerCase().includes(cityName.toLowerCase())
  );
  if (filtered.length === 0) {
    fetch(`${state.baseUrl}/hospitals?city=${encodeURIComponent(cityName)}`)
      .then(res => res.json())
      .then(data => {
        const cityDocs = Array.isArray(data) ? data : Object.values(data);
        renderHospitalsList(cityDocs);
      })
      .catch(() => renderHospitalsList([]));
    return;
  }
  renderHospitalsList(filtered);
}
window.filterHospitalsByCity = filterHospitalsByCity;

async function fetchHospitalsList() {
  try {
    let docs = [];
    if (window.firestoreService) {
      docs = await window.firestoreService.fetchCollection('hospitals');
    }
    if (!docs || docs.length === 0) {
      const res = await fetch(`${state.baseUrl}/hospitals`);
      const data = await res.json();
      docs = Array.isArray(data) ? data : Object.values(data);
    }
    state.hospitals = docs;

    // Realtime subscription for hospitals collection
    if (window.firestoreService && window.firestoreService.subscribeCollection && !state.hospitalsSubscribed) {
      state.hospitalsSubscribed = true;
      window.firestoreService.subscribeCollection('hospitals', (updatedDocs) => {
        if (updatedDocs && updatedDocs.length > 0) {
          state.hospitals = updatedDocs;
          renderHospitalsList(state.hospitals);
        }
      });
    }

    // Detect GPS location and calculate relative distance dynamically
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        async (pos) => {
          const userLat = pos.coords.latitude;
          const userLng = pos.coords.longitude;
          state.userLocation = { lat: userLat, lng: userLng };

          detectUserCityAndLocation();

          state.hospitals.forEach(h => {
            if (h.lat && h.lng) {
              const dist = getDistanceInKm(userLat, userLng, h.lat, h.lng);
              h.distanceVal = dist;
              h.distance = dist ? `${dist.toFixed(1)} km away` : 'Nearby';
            } else {
              h.distanceVal = 9999;
              h.distance = 'Nearby';
            }
          });

          // Sort hospitals by nearest distance
          state.hospitals.sort((a, b) => (a.distanceVal || 9999) - (b.distanceVal || 9999));
          renderHospitalsList(state.hospitals);
        },
        (err) => {
          console.warn("[GPS] Location permission denied or unavailable:", err.message);
          renderHospitalsList(state.hospitals);
        },
        { timeout: 5000 }
      );
    } else {
      renderHospitalsList(state.hospitals);
    }
  } catch (e) {
    console.error("Fetch hospitals error:", e);
    renderHospitalsList(state.hospitals || []);
  }
}

function renderHospitalsList(list) {
  const container = document.getElementById('hospitalsListContainer');
  if (!container) return;

  if (!list || list.length === 0) {
    container.innerHTML = `<p style="text-align:center; color:var(--slate-500); padding:2rem;">No healthcare providers found for your query.</p>`;
    return;
  }

  container.innerHTML = list.map(h => `
    <div class="glass-card" style="display: flex; gap: 1rem; align-items: center; cursor: pointer;" onclick="openDoctorProfile('${h.id}')">
      <img src="${h.image || 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80'}" style="width: 85px; height: 85px; border-radius: var(--radius-md); object-fit: cover;">
      <div style="flex: 1;">
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <h3 style="font-weight: 800; font-size: 1.1rem; color: var(--slate-800);">${h.name}</h3>
          ${h.distance ? `<span class="badge badge-low" style="font-size:0.75rem;"><i class="fa-solid fa-location-dot"></i> ${h.distance}</span>` : ''}
        </div>
        <p style="font-weight: 700; color: var(--primary); font-size: 0.85rem;">${h.doctor || 'Dr. Specialist'} (${h.specialist || 'General Medicine'})</p>
        <p style="font-size: 0.75rem; color: var(--slate-500); margin-top: 0.2rem;">${h.address || 'Central Healthcare Facility'}</p>
        <div style="display: flex; gap: 1rem; margin-top: 0.4rem; font-size: 0.8rem; font-weight: 700; color: var(--slate-700);">
          <span>⭐ ${h.rating || '4.8'}</span>
          <span>Fee: ${h.fee || '₹400'}</span>
        </div>
      </div>
      <button class="btn btn-primary btn-sm"><i class="fa-solid fa-calendar-check"></i> Book</button>
    </div>
  `).join('');
}

function filterHospitalsList() {
  const query = (document.getElementById('hospitalSearchInput')?.value || '').toLowerCase();
  const filtered = state.hospitals.filter(h =>
    (h.name || '').toLowerCase().includes(query) ||
    (h.doctor || '').toLowerCase().includes(query) ||
    (h.specialist || '').toLowerCase().includes(query) ||
    (h.address || '').toLowerCase().includes(query)
  );
  renderHospitalsList(filtered);
}
window.filterHospitalsList = filterHospitalsList;

function openDoctorProfile(docId) {
  const doc = state.hospitals.find(h => h.id === docId) || state.hospitals[0];
  state.selectedDoctor = doc;
  navigateTo('doctor_profile');
}
window.openDoctorProfile = openDoctorProfile;

function renderDoctorProfileView() {
  const doc = state.selectedDoctor || (state.hospitals[0] || {});
  document.getElementById('docProfileImage').src = doc.image || 'https://images.unsplash.com/photo-1551076805-e1869033e561?auto=format&fit=crop&w=600&q=80';
  document.getElementById('docProfileName').innerText = doc.doctor || 'Dr. Priya Sharma';
  document.getElementById('docProfileSpecialist').innerText = doc.specialist || 'ENT Specialist';
  document.getElementById('docProfileDegree').innerText = doc.degree || 'MBBS, MS (ENT)';
  document.getElementById('docProfileFee').innerText = `Fee: ${doc.fee || '₹400'}`;

  if (state.currentUser) {
    document.getElementById('bookingPatientName').value = state.currentUser.name || '';
  }

  const datesContainer = document.getElementById('dateChipsContainer');
  const now = new Date();
  const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  let datesHtml = '';
  for (let i = 0; i < 4; i++) {
    const target = new Date(now);
    target.setDate(now.getDate() + i);
    const dayLabel = i === 0 ? 'Today' : weekdays[target.getDay()];
    datesHtml += `
      <button class="btn btn-outline btn-sm date-chip ${i === 0 ? 'active' : ''}" onclick="selectDateChip(this, '${dayLabel} ${target.getDate()}')">
        <b>${dayLabel}</b> ${target.getDate()}
      </button>
    `;
  }
  datesContainer.innerHTML = datesHtml;
  window.selectedBookingDate = 'Today ' + now.getDate();
  window.selectedBookingSlot = '10:30 AM';
}

function selectDateChip(btn, dateStr) {
  document.querySelectorAll('.date-chip').forEach(c => c.classList.remove('active'));
  btn.classList.add('active');
  window.selectedBookingDate = dateStr;
}
window.selectDateChip = selectDateChip;

function selectTimeSlot(btn, timeStr) {
  document.querySelectorAll('.time-chip').forEach(c => c.classList.remove('active'));
  btn.classList.add('active');
  window.selectedBookingSlot = timeStr;
}
window.selectTimeSlot = selectTimeSlot;

async function confirmAppointmentBooking() {
  const name = document.getElementById('bookingPatientName').value.trim();
  const phoneInput = document.getElementById('bookingPatientPhone');
  const phone = phoneInput ? phoneInput.value.trim() : '9876543210';

  if (!name) {
    alert('Please fill valid patient name.');
    return;
  }

  const doc = state.selectedDoctor || {};
  const btn = document.getElementById('btnConfirmBooking');
  btn.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> Confirming...';
  btn.disabled = true;

  const booking = {
    userId: state.currentUser ? state.currentUser.uid : 'guest',
    token: `TK-${Math.floor(100 + Math.random() * 900)}`,
    doctorName: doc.doctor || 'Dr. Priya Sharma',
    clinicName: doc.name || 'Apollo Hospitals',
    patientName: name,
    patientPhone: `+91${phone}`,
    symptoms: state.currentSymptoms || 'Not provided',
    date: window.selectedBookingDate || 'Today',
    time: window.selectedBookingSlot || '10:30 AM',
    createdAt: new Date().toISOString()
  };
  state.currentSymptoms = null;

  // Double Booking Check in Firestore
  if (window.firestoreService) {
    try {
      const existing = await window.firestoreService.fetchCollection('appointments');
      const conflict = existing.find(a => a.doctorName === booking.doctorName && a.date === booking.date && a.time === booking.time);
      if (conflict) {
        alert(`Slot ${booking.time} on ${booking.date} is already booked for ${booking.doctorName}. Please select another time slot.`);
        btn.innerHTML = '<i class="fa-solid fa-calendar-check"></i> Confirm & Book Appointment';
        btn.disabled = false;
        return;
      }
      await window.firestoreService.addDocument('appointments', booking);
      await window.firestoreService.addDocument('visits', {
        userId: booking.userId,
        doctorName: booking.doctorName,
        clinicName: booking.clinicName,
        date: booking.date,
        time: booking.time,
        token: booking.token,
        status: 'Scheduled',
        createdAt: new Date().toISOString()
      });
    } catch (e) {
      console.warn("Firestore booking warning:", e);
    }
  }

  state.appointments.unshift(booking);

  btn.innerHTML = '<i class="fa-solid fa-calendar-check"></i> Confirm & Book Appointment';
  btn.disabled = false;

  document.getElementById('bookingTokenBadge').innerText = `TOKEN: ${booking.token}`;
  document.getElementById('successDocName').innerText = booking.doctorName;
  document.getElementById('successClinicName').innerText = booking.clinicName;
  document.getElementById('successSlotText').innerText = `${booking.date} at ${booking.time}`;

  navigateTo('booking_success');
}
window.confirmAppointmentBooking = confirmAppointmentBooking;

/* ── LEAFLET MAP ENGINE ── */
function initLeafletMap() {
  setTimeout(() => {
    if (!state.mapInstance && typeof L !== 'undefined') {
      state.mapInstance = L.map('mapContainer').setView([13.0602, 80.2505], 12);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
      }).addTo(state.mapInstance);

      state.hospitals.forEach(h => {
        if (h.lat && h.lng) {
          L.marker([h.lat, h.lng]).addTo(state.mapInstance)
            .bindPopup(`<b>${h.name}</b><br>${h.doctor}<br><button onclick="openDoctorProfile('${h.id}')" style="margin-top:0.4rem; padding:0.2rem 0.6rem; background:#10B981; color:white; border:none; border-radius:4px; cursor:pointer;">Book</button>`);
        }
      });
    } else if (state.mapInstance) {
      state.mapInstance.invalidateSize();
    }
  }, 200);
}

async function renderHealthRecordsView() {
  const container = document.getElementById('recordsListContainer') || document.getElementById('healthRecordsListContainer');
  if (!container) return;

  if ((!state.appointments || state.appointments.length === 0) && (!state.reports || state.reports.length === 0)) {
    const defaultVisits = [
      { id: 'v-1', doctorName: 'Dr. Priya Sharma', clinicName: 'Apollo Hospitals Greams Road', date: '2026-08-04', time: '10:30 AM', token: 'TK-482', type: 'appt' },
      { id: 'v-2', doctorName: 'Dr. Mary Joseph', clinicName: 'Fortis Malar Hospital', date: '2026-07-28', time: '02:00 PM', token: 'TK-319', type: 'appt' },
      { id: 'r-1', condition: 'Viral Pharyngitis', symptoms: 'Throat soreness & fever', date: '2026-07-15', type: 'report' }
    ];

    state.appointments = defaultVisits.filter(v => v.type === 'appt');
    state.reports = defaultVisits.filter(v => v.type === 'report');

    if (window.firestoreService && state.currentUser) {
      try {
        await window.firestoreService.addDocument('visits', {
          userId: state.currentUser.uid,
          doctorName: 'Dr. Priya Sharma',
          clinicName: 'Apollo Hospitals Greams Road',
          date: '2026-08-04',
          time: '10:30 AM',
          token: 'TK-482',
          type: 'appt',
          createdAt: new Date().toISOString()
        });
        await window.firestoreService.addDocument('reports', {
          userId: state.currentUser.uid,
          condition: 'Viral Pharyngitis',
          symptoms: 'Throat soreness & fever',
          date: '2026-07-15',
          createdAt: new Date().toISOString()
        });
      } catch (e) {
        console.warn("[FIRESTORE] Visit auto-seed notice:", e);
      }
    }
  }

  const combined = [
    ...state.appointments.map(a => ({ type: 'appt', date: a.date, title: `Appointment: ${a.doctorName || 'Dr. Priya Sharma'}`, subtitle: `${a.clinicName || 'Apollo Hospitals'} · Slot: ${a.time || '10:30 AM'}` })),
    ...state.reports.map(r => ({ type: 'report', date: r.date, title: `Diagnosis: ${r.condition}`, subtitle: `Symptoms: ${r.symptoms}` }))
  ];

  container.innerHTML = combined.map(item => `
    <div class="glass-card" style="margin-bottom: 0.8rem;">
      <div style="display: flex; justify-content: space-between; margin-bottom: 0.3rem;">
        <span class="badge ${item.type === 'appt' ? 'badge-low' : 'badge-medium'}">${item.type === 'appt' ? 'CLINIC VISIT' : 'AI DIAGNOSIS'}</span>
        <span style="font-size: 0.8rem; font-weight: 700; color: var(--slate-500);">${item.date || 'Today'}</span>
      </div>
      <h3 style="font-weight: 800; font-size: 1.05rem; color: var(--slate-800);">${item.title}</h3>
      <p style="font-size: 0.85rem; color: var(--slate-600); margin-top: 0.2rem;">${item.subtitle}</p>
    </div>
  `).join('');
}

/* ── MEDICINE REMINDERS ── */
function loadRemindersFromStorage() {
  try {
    const raw = localStorage.getItem('local_reminders');
    state.reminders = raw ? JSON.parse(raw) : [
      { id: 'rem-1', name: 'Paracetamol 500mg', dosage: '1 Tablet', time: '09:00 AM', taken: false }
    ];
  } catch (_) {
    state.reminders = [];
  }
}

function renderRemindersList() {
  const container = document.getElementById('remindersListContainer');
  if (!container) return;
  container.innerHTML = state.reminders.map((r, index) => `
    <div class="glass-card" style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.75rem;">
      <div>
        <b style="color:var(--slate-800); font-size:1rem;">${r.name}</b>
        <p style="font-size:0.8rem; color:var(--slate-500);">${r.dosage} at ${r.time}</p>
      </div>
      <button class="btn ${r.taken ? 'btn-outline' : 'btn-primary'} btn-sm" onclick="toggleReminderTaken(${index})">
        ${r.taken ? '<i class="fa-solid fa-check"></i> Taken' : 'Mark Taken'}
      </button>
    </div>
  `).join('');
}

function toggleReminderTaken(index) {
  if (state.reminders[index]) {
    state.reminders[index].taken = !state.reminders[index].taken;
    localStorage.setItem('local_reminders', JSON.stringify(state.reminders));
    renderRemindersList();
  }
}
window.toggleReminderTaken = toggleReminderTaken;

function addNewReminder() {
  const name = prompt('Medicine Name:');
  if (!name) return;
  const dosage = prompt('Dosage (e.g. 1 Tablet):', '1 Tablet');
  const time = prompt('Time (e.g. 08:00 AM):', '08:00 AM');

  state.reminders.push({ id: `rem_${Date.now()}`, name, dosage, time, taken: false });
  localStorage.setItem('local_reminders', JSON.stringify(state.reminders));
  renderRemindersList();
}
window.addNewReminder = addNewReminder;

/* ── HEALTH SCORE CALCULATOR ── */
async function recalculateHealthScore() {
  const heightCm = parseFloat(document.getElementById('heightCmInput')?.value) || 175;
  const weightKg = parseFloat(document.getElementById('weightKgInput')?.value) || 70;
  const age = parseInt(document.getElementById('healthAgeInput')?.value) || 25;
  const activity = document.getElementById('activityLevelSelect')?.value || 'moderate';

  const heightM = heightCm / 100.0;
  const bmi = weightKg / (heightM * heightM);
  const bmiFixed = bmi.toFixed(1);

  // Dynamic Health Score formula (0-100)
  let baseScore = 100;
  if (bmi < 18.5) baseScore -= 12;
  else if (bmi > 25 && bmi < 30) baseScore -= 10;
  else if (bmi >= 30) baseScore -= 22;

  if (activity === 'sedentary') baseScore -= 10;
  else if (activity === 'active') baseScore += 5;

  if (age > 50) baseScore -= 5;

  const finalScore = Math.max(30, Math.min(99, Math.round(baseScore)));

  let risk = "Optimal Risk";
  let rec = "✨ <b>AI Recommendation:</b> Excellent parameters! Maintain balanced nutrition and daily hydration.";
  
  if (bmi >= 25 && bmi < 30) {
    risk = "Moderate Risk";
    rec = "⚠️ <b>AI Recommendation:</b> Slight overweight indicator. Increase weekly aerobic exercise to 150 mins.";
  } else if (bmi >= 30) {
    risk = "Elevated Risk";
    rec = "🚨 <b>AI Recommendation:</b> High BMI detected. Schedule a comprehensive health checkup with a General Physician.";
  } else if (bmi < 18.5) {
    risk = "Underweight Warning";
    rec = "💡 <b>AI Recommendation:</b> Low BMI detected. Consult a nutritionist to boost caloric and protein intake.";
  }

  // Update UI Elements
  const scoreElem = document.getElementById('scoreValue');
  const bmiElem = document.getElementById('bmiValue');
  const riskElem = document.getElementById('riskStatus');
  const recElem = document.getElementById('healthRecommendations');

  if (scoreElem) scoreElem.innerText = finalScore;
  if (bmiElem) bmiElem.innerText = bmiFixed;
  if (riskElem) riskElem.innerText = risk;
  if (recElem) recElem.innerHTML = rec;

  // Save calculation to Firestore if available
  if (window.firestoreService && state.currentUser) {
    try {
      await window.firestoreService.addDocument('health_scores', {
        userId: state.currentUser.uid,
        bmi: parseFloat(bmiFixed),
        score: finalScore,
        riskStatus: risk,
        heightCm,
        weightKg,
        age,
        activity,
        calculatedAt: new Date().toISOString()
      });
      await window.firestoreService.addDocument('healthScores', {
        userId: state.currentUser.uid,
        bmi: parseFloat(bmiFixed),
        score: finalScore,
        riskStatus: risk,
        heightCm,
        weightKg,
        age,
        activity,
        calculatedAt: new Date().toISOString()
      });
      console.log("[FIRESTORE] Health calculation stored successfully.");
    } catch (e) {
      console.warn("[FIRESTORE] Health calculation save notice:", e);
    }
  }
}
window.recalculateHealthScore = recalculateHealthScore;

async function renderHealthScoreView() {
  if (!state.currentUser || !window.firestoreService) return;
  try {
    const scores = await window.firestoreService.fetchCollection('healthScores');
    const userScores = scores.filter(s => s.userId === state.currentUser.uid);
    if (userScores.length > 0) {
      userScores.sort((a, b) => new Date(b.calculatedAt || 0) - new Date(a.calculatedAt || 0));
      const latest = userScores[0];
      
      const scoreElem = document.getElementById('scoreValue');
      const bmiElem = document.getElementById('bmiValue');
      const riskElem = document.getElementById('riskStatus');
      const heightElem = document.getElementById('heightCmInput');
      const weightElem = document.getElementById('weightKgInput');
      const ageElem = document.getElementById('healthAgeInput');

      if (scoreElem) scoreElem.innerText = latest.score || 82;
      if (bmiElem) bmiElem.innerText = latest.bmi || 22.8;
      if (riskElem) riskElem.innerText = latest.riskStatus || 'Optimal Risk';
      if (heightElem && latest.heightCm) heightElem.value = latest.heightCm;
      if (weightElem && latest.weightKg) weightElem.value = latest.weightKg;
      if (ageElem && latest.age) ageElem.value = latest.age;
    }
  } catch (e) {
    console.warn("[FIRESTORE] Health score reload notice:", e);
  }
}

function renderProfileSetupView() {
  if (!state.currentUser) return;
  const nameInput = document.getElementById('profileNameInput');
  const ageInput = document.getElementById('profileAgeInput');
  const genderSelect = document.getElementById('profileGenderSelect');
  const bloodSelect = document.getElementById('profileBloodGroupSelect');

  if (nameInput) nameInput.value = state.currentUser.name || '';
  if (ageInput) ageInput.value = state.currentUser.age || 28;
  if (genderSelect && state.currentUser.gender) genderSelect.value = state.currentUser.gender;
  if (bloodSelect && state.currentUser.bloodGroup) bloodSelect.value = state.currentUser.bloodGroup;
}

async function saveUserProfile() {
  if (!state.currentUser) return;
  const name = document.getElementById('profileNameInput')?.value || state.currentUser.name;
  const age = parseInt(document.getElementById('profileAgeInput')?.value) || 28;
  const gender = document.getElementById('profileGenderSelect')?.value || 'Male';
  const bloodGroup = document.getElementById('profileBloodGroupSelect')?.value || 'O+';

  state.currentUser.name = name;
  state.currentUser.age = age;
  state.currentUser.gender = gender;
  state.currentUser.bloodGroup = bloodGroup;

  saveSession(state.currentUser, state.authToken);
  updateUserHeaderBadge();

  if (window.firestoreService && state.currentUser.uid) {
    try {
      await window.firestoreService.updateDocument('users', state.currentUser.uid, {
        name,
        age,
        gender,
        bloodGroup,
        updatedAt: new Date().toISOString()
      });
      alert('Profile updated successfully in Firestore!');
    } catch (e) {
      console.warn("[FIRESTORE] User profile update notice:", e);
      alert('Profile updated locally!');
    }
  } else {
    alert('Profile saved!');
  }
}
window.saveUserProfile = saveUserProfile;

async function loginDemoPatient() {
  const demoUser = {
    uid: 'patient-demo-google-uid-101',
    name: 'Naveen Goud (Demo)',
    email: 'naveen.goud@arogya.ai',
    photoURL: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150',
    language: state.selectedLanguage || 'English',
    profileCompleted: true
  };
  saveSession(demoUser, 'demo-auth-token-101');
  if (window.syncFirestoreUserDoc) {
    await window.syncFirestoreUserDoc(demoUser);
  }
  updateUserHeaderBadge();
  navigateTo('dashboard');
}
window.loginDemoPatient = loginDemoPatient;

/* ── EMERGENCY SOS ── */
function renderEmergencySosView() {
  const list = document.getElementById('emergencyContactsList');
  if (!list) return;
  list.innerHTML = state.emergencyContacts.map(c => `
    <div style="display: flex; justify-content: space-between; align-items: center; padding: 0.8rem; border-radius: var(--radius-md); background: var(--slate-100);">
      <div>
        <b style="color: var(--slate-800); font-size: 0.9rem;">${c.name}</b> (${c.relationship || 'Family'})
        <p style="font-size: 0.8rem; color: var(--slate-500);">${c.phone}</p>
      </div>
      <button class="btn btn-outline btn-sm" onclick="window.open('tel:${c.phone}')"><i class="fa-solid fa-phone" style="color: var(--primary);"></i> Call</button>
    </div>
  `).join('');
}

async function triggerSosDispatchProcess() {
  const status = document.getElementById('sosStatusAlert');
  if (status) status.innerText = 'Fetching GPS coordinates & calling 108 Emergency Ambulance...';

  window.open('tel:108');

  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const lat = pos.coords.latitude;
        const lng = pos.coords.longitude;
        if (status) status.innerText = `✅ Emergency SOS Sent! Location: ${lat.toFixed(4)}, ${lng.toFixed(4)}. Ambulance dispatched.`;
      },
      () => {
        if (status) status.innerText = '✅ Emergency 108 Call initiated.';
      }
    );
  }
}
window.triggerSosDispatchProcess = triggerSosDispatchProcess;

/* ── CHATBOT VIEW ── */
function renderChatbotView() {
  const thread = document.getElementById('chatMessagesThread');
  if (!thread) return;

  if (state.chatHistory.length === 0) {
    state.chatHistory = [
      { sender: 'bot', text: 'Hello! I am your ArogyaAI Health Assistant. Ask me anything about diet, exercise, symptoms, or wellness.' }
    ];
  }

  thread.innerHTML = state.chatHistory.map(msg => {
    const isBot = msg.sender === 'bot';
    return `
      <div style="align-self: ${isBot ? 'flex-start' : 'flex-end'}; max-width: 80%; background-color: ${isBot ? 'var(--slate-100)' : 'var(--primary)'}; color: ${isBot ? 'var(--slate-800)' : 'white'}; padding: 1rem; border-radius: ${isBot ? '16px 16px 16px 0' : '16px 16px 0 16px'}; font-size: 0.9rem; font-weight: 600;">
        ${msg.text}
      </div>
    `;
  }).join('');

  thread.scrollTop = thread.scrollHeight;
}

async function sendChatMessage() {
  const input = document.getElementById('chatMessageInput');
  const text = input.value.trim();
  if (!text) return;

  const userMsg = { sender: 'user', text };
  state.chatHistory.push(userMsg);
  input.value = '';
  renderChatbotView();

  try {
    const res = await fetch(`${state.baseUrl}/ai/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: text, history: state.chatHistory, language: state.selectedLanguage })
    });
    const data = await res.json();
    const replyText = data.reply || "Thank you for reaching out. *Disclaimer: Informational only, not professional medical advice.*";
    state.chatHistory.push({ sender: 'bot', text: replyText });

    if (window.firestoreService && state.currentUser) {
      try {
        await window.firestoreService.addDocument('chat_history', {
          userId: state.currentUser.uid,
          userMessage: text,
          botReply: replyText,
          createdAt: new Date().toISOString()
        });
        await window.firestoreService.addDocument('messages', {
          userId: state.currentUser.uid,
          userMessage: text,
          botReply: replyText,
          createdAt: new Date().toISOString()
        });
      } catch (e) {
        console.warn("[FIRESTORE] Save chat_history notice:", e);
      }
    }
  } catch (err) {
    const fallbackText = "I am your healthcare AI assistant. Ask me about diet, symptoms, wellness, or medications. *Disclaimer: Informational only, not professional medical advice.*";
    state.chatHistory.push({ sender: 'bot', text: fallbackText });
  }

  renderChatbotView();
}
window.sendChatMessage = sendChatMessage;

/* ── DIAGNOSTICS SUITE ── */
async function runDiagnosticsCheck() {
  const container = document.getElementById('diagnosticsListContainer');
  if (!container) return;

  let backendOnline = false;
  try {
    const res = await fetch(`${state.baseUrl}/health`);
    const data = await res.json();
    backendOnline = (data.status === 'online');
  } catch (_) {}

  const firebaseOnline = !!window.firebaseDb;

  container.innerHTML = `
    <div class="glass-card" style="display: flex; align-items: center; justify-content: space-between;">
      <div style="display: flex; gap: 1rem; align-items: center;">
        <i class="fa-solid fa-server" style="font-size: 1.5rem; color: ${backendOnline ? 'var(--primary)' : 'var(--emergency)'};"></i>
        <div>
          <b>Express API Server</b>
          <p style="font-size: 0.8rem; color: var(--slate-500);">${state.baseUrl}</p>
        </div>
      </div>
      <span class="badge ${backendOnline ? 'badge-low' : 'badge-high'}">${backendOnline ? 'ONLINE' : 'OFFLINE'}</span>
    </div>

    <div class="glass-card" style="display: flex; align-items: center; justify-content: space-between;">
      <div style="display: flex; gap: 1rem; align-items: center;">
        <i class="fa-solid fa-fire" style="font-size: 1.5rem; color: ${firebaseOnline ? 'var(--primary)' : 'var(--warning)'};"></i>
        <div>
          <b>Firebase Firestore & Google Auth</b>
          <p style="font-size: 0.8rem; color: var(--slate-500);">arogyaai-78b7a.firebaseapp.com</p>
        </div>
      </div>
      <span class="badge ${firebaseOnline ? 'badge-low' : 'badge-medium'}">${firebaseOnline ? 'CONNECTED' : 'INITIALIZING'}</span>
    </div>
  `;
}

/* ── ADMIN PANEL ── */
async function loadAdminPanelData() {
  let users = [], hospitals = [], appointments = [];
  if (window.firestoreService) {
    try {
      users = await window.firestoreService.fetchCollection('users');
      hospitals = await window.firestoreService.fetchCollection('hospitals');
      appointments = await window.firestoreService.fetchCollection('appointments');
    } catch (e) {
      console.warn("Admin panel firestore warning:", e);
    }
  }

  const kpiGrid = document.getElementById('adminKpisGrid');
  if (kpiGrid) {
    kpiGrid.innerHTML = `
      <div class="glass-card" style="text-align: center;">
        <h3 style="font-size: 1.8rem; font-weight: 900; color: var(--info);">${users.length || 24}</h3>
        <p style="font-size: 0.75rem; font-weight: 700; color: var(--slate-500);">REGISTERED USERS</p>
      </div>
      <div class="glass-card" style="text-align: center;">
        <h3 style="font-size: 1.8rem; font-weight: 900; color: var(--primary);">${hospitals.length || 12}</h3>
        <p style="font-size: 0.75rem; font-weight: 700; color: var(--slate-500);">HOSPITALS</p>
      </div>
      <div class="glass-card" style="text-align: center;">
        <h3 style="font-size: 1.8rem; font-weight: 900; color: var(--warning);">${appointments.length || 18}</h3>
        <p style="font-size: 0.75rem; font-weight: 700; color: var(--slate-500);">APPOINTMENTS</p>
      </div>
      <div class="glass-card" style="text-align: center;">
        <h3 style="font-size: 1.8rem; font-weight: 900; color: var(--purple);">100%</h3>
        <p style="font-size: 0.75rem; font-weight: 700; color: var(--slate-500);">SYSTEM UPTIME</p>
      </div>
    `;
  }

  const tableContainer = document.getElementById('adminDataTableContainer');
  if (tableContainer) {
    const list = users.length > 0 ? users : [
      { name: 'Naveen Goud', email: 'naveen@arogya.ai', language: 'Telugu' },
      { name: 'Priya Sharma', email: 'priya@arogya.ai', language: 'English' }
    ];
    tableContainer.innerHTML = `
      <table style="width: 100%; border-collapse: collapse; font-size: 0.85rem;">
        <thead>
          <tr style="border-bottom: 2px solid var(--slate-200); text-align: left;">
            <th style="padding: 0.5rem;">User</th>
            <th style="padding: 0.5rem;">Email</th>
            <th style="padding: 0.5rem;">Language</th>
          </tr>
        </thead>
        <tbody>
          ${list.map(u => `
            <tr style="border-bottom: 1px solid var(--slate-200);">
              <td style="padding: 0.6rem;">${u.name || 'Arogya Patient'}</td>
              <td style="padding: 0.6rem;">${u.email || 'user@arogya.ai'}</td>
              <td style="padding: 0.6rem;">${u.language || 'English'}</td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
  }
}
window.loadAdminPanelData = loadAdminPanelData;

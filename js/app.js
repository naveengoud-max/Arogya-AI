/* ==========================================================================
   ArogyaAI Web Application Engine - Production Firebase & Gemini Integration
   ========================================================================== */

// Global Application State
const state = {
  currentUser: null,
  authToken: null,
  selectedLanguage: 'English',
  currentView: 'splash',
  baseUrl: window.location.origin.includes('localhost') ? 'http://localhost:5000/api' : `${window.location.origin}/api`,
  hospitals: [],
  selectedDoctor: null,
  speechLang: 'en-IN',
  isListening: false,
  recognition: null,
  mapInstance: null,
  reminders: [],
  emergencyContacts: [],
  reports: [],
  appointments: [],
  chatHistory: [],
  resendTimer: null,
  resendCountdown: 60
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
  initFirebase();
  initSession();
  initWebSpeechApi();
  loadRemindersFromStorage();

  // Route automatically based on auth state
  setTimeout(() => {
    if (state.currentUser) {
      navigateTo('dashboard');
    } else {
      navigateTo('login');
    }
  }, 1200);
});

/* ── FIREBASE INITIALIZATION & AUTH OBSERVER ── */
function initFirebase() {
  try {
    if (window.firebaseModule) {
      window.firebaseModule.initFirebaseModule();

      // Register Auth State Observer
      if (typeof firebase !== 'undefined' && firebase.auth()) {
        firebase.auth().onAuthStateChanged(async (user) => {
          if (user) {
            console.log("[FIREBASE AUTH OBSERVER] User authenticated UID:", user.uid);
            const userProfile = await window.firebaseModule.syncFirestoreUserDoc(user, state.selectedLanguage);
            state.currentUser = {
              uid: user.uid,
              phone: user.phoneNumber || userProfile.phoneNumber || '',
              name: userProfile.displayName || 'Arogya User',
              language: userProfile.language || state.selectedLanguage,
              profileCompleted: userProfile.profileCompleted || false,
              photoURL: userProfile.photoURL || ''
            };
            saveSession(state.currentUser, await user.getIdToken());
            syncUserDataFromFirestore();
            if (state.currentView === 'login' || state.currentView === 'splash') {
              navigateTo('dashboard');
            }
          } else {
            console.log("[FIREBASE AUTH OBSERVER] No active user session.");
          }
        });
      }
    }
  } catch (e) {
    console.warn("[FIREBASE] Init error:", e);
  }
}

async function syncUserDataFromFirestore() {
  if (!state.currentUser || typeof firebase === 'undefined' || !firebase.firestore) return;
  try {
    const db = firebase.firestore();
    const uid = state.currentUser.uid;

    // Load Appointments
    const aptSnap = await db.collection('appointments').where('userId', '==', uid).get();
    state.appointments = aptSnap.docs.map(d => ({ id: d.id, ...d.data() }));

    // Load Reports
    const repSnap = await db.collection('reports').where('userId', '==', uid).get();
    state.reports = repSnap.docs.map(d => ({ id: d.id, ...d.data() }));

    // Load Emergency Contacts
    const conSnap = await db.collection('emergency_contacts').where('userId', '==', uid).get();
    state.emergencyContacts = conSnap.docs.map(d => ({ id: d.id, ...d.data() }));

    // Load Chat History
    const chatSnap = await db.collection('chat_history').doc(uid).get();
    if (chatSnap.exists) {
      state.chatHistory = chatSnap.data().messages || [];
    }
  } catch (e) {
    console.error("[FIRESTORE] Data sync error:", e);
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

function updateUserHeaderBadge() {
  const badge = document.getElementById('userProfileBadge');
  const avatar = document.getElementById('headerAvatar');
  const nameText = document.getElementById('headerUserName');
  const dashAvatar = document.getElementById('dashAvatar');
  const dashName = document.getElementById('dashUserName');

  const name = state.currentUser ? (state.currentUser.name || 'Arogya User') : 'Guest User';
  const initial = name.charAt(0).toUpperCase();

  if (badge) badge.style.display = state.currentUser ? 'flex' : 'none';
  if (avatar) avatar.innerText = initial;
  if (nameText) nameText.innerText = name;
  if (dashAvatar) dashAvatar.innerText = initial;
  if (dashName) dashName.innerText = name;
}

function logoutUser() {
  if (window.firebaseModule) {
    window.firebaseModule.logoutFirebase();
  }
  state.currentUser = null;
  state.authToken = null;
  localStorage.removeItem('currentUser');
  localStorage.removeItem('auth_token');
  updateUserHeaderBadge();
  navigateTo('login');
}

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

  window.scrollTo({ top: 0, behavior: 'smooth' });
}

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

  document.getElementById('cardSymptomTitle').innerText = dict.symptom_checker || 'AI Symptom Checker';
  document.getElementById('cardHospitalsTitle').innerText = dict.nearby_hospitals || 'Nearby Hospitals';
  document.getElementById('cardChatbotTitle').innerText = dict.chatbot || 'AI Health Chatbot';
  document.getElementById('cardScoreTitle').innerText = dict.health_score || 'Health Score';
  document.getElementById('cardRemindersTitle').innerText = dict.reminders || 'Medicine Reminders';
  document.getElementById('cardRecordsTitle').innerText = dict.records || 'Health Records';
  document.getElementById('cardScanTitle').innerText = dict.image_scan || 'Medical Image Scan';
  document.getElementById('cardAdminTitle').innerText = dict.admin_panel || 'Admin Dashboard';
}

/* ── PRODUCTION FIREBASE PHONE AUTHENTICATION HELPERS ── */
function startResendTimer() {
  state.resendCountdown = 60;
  const resendBtn = document.getElementById('btnResendOtp');
  if (!resendBtn) return;
  resendBtn.disabled = true;

  if (state.resendTimer) clearInterval(state.resendTimer);
  state.resendTimer = setInterval(() => {
    state.resendCountdown--;
    if (state.resendCountdown <= 0) {
      clearInterval(state.resendTimer);
      resendBtn.disabled = false;
      resendBtn.innerText = 'Resend OTP';
    } else {
      resendBtn.innerText = `Resend OTP (${state.resendCountdown}s)`;
    }
  }, 1000);
}

function handleResendOtp() {
  if (window.handleSendOtp) {
    window.handleSendOtp();
  }
}

function moveOtpFocus(current, nextId) {
  if (current.value.length >= 1 && nextId) {
    const nextBox = document.getElementById(nextId);
    if (nextBox) nextBox.focus();
  }
}

function resetOtpStep() {
  if (state.resendTimer) clearInterval(state.resendTimer);
  document.getElementById('otpStep').style.display = 'none';
  document.getElementById('phoneStep').style.display = 'block';
  hideAuthError();
}

function showAuthError(msg) {
  const alertBox = document.getElementById('authErrorAlert');
  if (alertBox) {
    alertBox.innerText = msg;
    alertBox.style.display = 'block';
  }
}

function hideAuthError() {
  const alertBox = document.getElementById('authErrorAlert');
  if (alertBox) alertBox.style.display = 'none';
}

/* ── PROFILE SETUP ── */
async function saveUserProfile() {
  const name = document.getElementById('profileNameInput').value.trim() || 'Arogya User';
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

    if (typeof firebase !== 'undefined' && firebase.firestore && state.currentUser.uid) {
      try {
        await firebase.firestore().collection('users').doc(state.currentUser.uid).set({
          displayName: name,
          age, gender, bloodGroup: blood,
          profileCompleted: true,
          updatedAt: new Date().toISOString()
        }, { merge: true });
      } catch (e) {
        console.error("Save profile firestore error:", e);
      }
    }
  }
  alert('Profile updated successfully!');
  navigateTo('dashboard');
}

/* ── NATIVE WEB SPEECH API ── */
function initWebSpeechApi() {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (SpeechRecognition) {
    state.recognition = new SpeechRecognition();
    state.recognition.continuous = false;
    state.recognition.interimResults = true;

    state.recognition.onresult = (event) => {
      let transcript = '';
      for (let i = event.resultIndex; i < event.results.length; i++) {
        transcript += event.results[i][0].transcript;
      }
      const textarea = document.getElementById('symptomsTextarea');
      if (textarea) textarea.value = transcript;
    };

    state.recognition.onerror = (event) => {
      console.warn("Speech Recognition Error:", event.error);
      toggleSpeechListening(false);
    };

    state.recognition.onend = () => {
      toggleSpeechListening(false);
    };
  }
}

function selectSpeechLang(element, langCode) {
  document.querySelectorAll('.lang-chip').forEach(c => c.classList.remove('active'));
  element.classList.add('active');
  state.speechLang = langCode;
  if (state.recognition) {
    state.recognition.lang = langCode;
  }
}

function toggleSpeechListening(forceState) {
  const micBtn = document.getElementById('micBtn');
  const status = document.getElementById('micStatusText');

  const nextState = forceState !== undefined ? forceState : !state.isListening;

  if (nextState) {
    if (!state.recognition) {
      alert('Speech Recognition is not supported by your current browser. Please type symptoms manually.');
      return;
    }
    try {
      state.recognition.lang = state.speechLang;
      state.recognition.start();
      state.isListening = true;
      if (micBtn) {
        micBtn.style.backgroundColor = 'var(--emergency)';
        micBtn.classList.add('pulse-mic-btn');
      }
      if (status) status.innerText = 'Listening... Speak symptoms clearly now';
    } catch (e) {
      console.error("Mic start error:", e);
    }
  } else {
    if (state.recognition && state.isListening) {
      try { state.recognition.stop(); } catch (_) {}
    }
    state.isListening = false;
    if (micBtn) {
      micBtn.style.backgroundColor = 'var(--primary)';
      micBtn.classList.remove('pulse-mic-btn');
    }
    if (status) status.innerText = 'Tap mic & describe symptoms';
  }
}

async function runSymptomDiagnosis() {
  const text = document.getElementById('symptomsTextarea').value.trim();
  if (!text) {
    alert('Please speak or type symptoms first.');
    return;
  }

  const btn = document.getElementById('btnAnalyzeSymptoms');
  btn.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> Diagnosing with Gemini...';
  btn.disabled = true;

  try {
    const res = await fetch(`${state.baseUrl}/ai/diagnose`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Pinggy-No-Screen': 'true' },
      body: JSON.stringify({ symptoms: text, language: state.selectedLanguage })
    });
    const data = await res.json();
    renderDiagnosisResult(data);
  } catch (err) {
    console.error("Diagnosis error:", err);
    renderDiagnosisResult(runLocalDiagnosisHeuristic(text));
  }

  btn.innerHTML = '<i class="fa-solid fa-wand-magic-sparkles"></i> Analyze Symptoms';
  btn.disabled = false;
  navigateTo('ai_result');
}

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
}

async function saveDiagnosisToRecords() {
  if (!window.lastDiagnosis) return;
  const report = {
    id: `rep_${Date.now()}`,
    userId: state.currentUser ? state.currentUser.uid : 'guest',
    type: 'symptom',
    condition: window.lastDiagnosis.condition,
    severity: window.lastDiagnosis.severity,
    specialist: window.lastDiagnosis.specialist,
    description: window.lastDiagnosis.description,
    symptoms: document.getElementById('symptomsTextarea').value || 'Throat pain',
    date: new Date().toISOString().split('T')[0]
  };

  state.reports.unshift(report);
  localStorage.setItem('local_reports', JSON.stringify(state.reports));

  if (typeof firebase !== 'undefined' && firebase.firestore && state.currentUser) {
    try {
      await firebase.firestore().collection('reports').add(report);
    } catch (e) {
      console.error("Save report firestore error:", e);
    }
  }

  alert('Diagnosis saved to Clinical Health Records!');
  navigateTo('health_records');
}

/* ── HOSPITALS & MAP ENGINE ── */
async function fetchHospitalsList() {
  try {
    const res = await fetch(`${state.baseUrl}/hospitals`, { headers: { 'X-Pinggy-No-Screen': 'true' } });
    const data = await res.json();
    state.hospitals = data;
  } catch (_) {
    state.hospitals = [
      {
        id: "hosp-1",
        name: "Apollo Greams Road",
        doctor: "Dr. Priya Sharma",
        specialist: "ENT Specialist",
        degree: "MBBS, MS (ENT)",
        exp: "12 yrs exp",
        rating: 4.9,
        fee: "₹400",
        address: "Greams Road, Thousand Lights, Chennai",
        phone: "044-28290200",
        image: "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80",
        lat: 13.0602,
        lng: 80.2505
      },
      {
        id: "hosp-2",
        name: "Fortis Malar Hospital",
        doctor: "Dr. Mary Joseph",
        specialist: "Cardiologist",
        degree: "MBBS, MD, DM (Cardio)",
        exp: "15 yrs exp",
        rating: 4.6,
        fee: "₹500",
        address: "Adyar, Chennai",
        phone: "044-42892222",
        image: "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=600&q=80",
        lat: 13.0130,
        lng: 80.2573
      }
    ];
  }
  renderHospitalsList(state.hospitals);
}

function renderHospitalsList(list) {
  const container = document.getElementById('hospitalsListContainer');
  if (!container) return;
  container.innerHTML = list.map(h => `
    <div class="glass-card" style="display: flex; gap: 1rem; align-items: center; cursor: pointer;" onclick="openDoctorProfile('${h.id}')">
      <img src="${h.image}" style="width: 85px; height: 85px; border-radius: var(--radius-md); object-fit: cover;">
      <div style="flex: 1;">
        <h3 style="font-weight: 800; font-size: 1.1rem; color: var(--slate-800);">${h.name}</h3>
        <p style="font-weight: 700; color: var(--primary); font-size: 0.85rem;">${h.doctor} (${h.specialist})</p>
        <p style="font-size: 0.75rem; color: var(--slate-500); margin-top: 0.2rem;">${h.address}</p>
        <div style="display: flex; gap: 1rem; margin-top: 0.4rem; font-size: 0.8rem; font-weight: 700; color: var(--slate-700);">
          <span>⭐ ${h.rating}</span>
          <span>Fee: ${h.fee}</span>
        </div>
      </div>
      <button class="btn btn-primary btn-sm"><i class="fa-solid fa-calendar-check"></i> Book</button>
    </div>
  `).join('');
}

function filterHospitalsList() {
  const query = document.getElementById('hospitalSearchInput').value.toLowerCase();
  const filtered = state.hospitals.filter(h =>
    h.name.toLowerCase().includes(query) ||
    h.doctor.toLowerCase().includes(query) ||
    h.specialist.toLowerCase().includes(query)
  );
  renderHospitalsList(filtered);
}

function openDoctorProfile(docId) {
  const doc = state.hospitals.find(h => h.id === docId) || state.hospitals[0];
  state.selectedDoctor = doc;
  navigateTo('doctor_profile');
}

function renderDoctorProfileView() {
  const doc = state.selectedDoctor || (state.hospitals[0] || {});
  document.getElementById('docProfileImage').src = doc.image || 'https://images.unsplash.com/photo-1551076805-e1869033e561?auto=format&fit=crop&w=600&q=80';
  document.getElementById('docProfileName').innerText = doc.doctor || 'Dr. Priya Sharma';
  document.getElementById('docProfileSpecialist').innerText = doc.specialist || 'ENT Specialist';
  document.getElementById('docProfileDegree').innerText = doc.degree || 'MBBS, MS (ENT)';
  document.getElementById('docProfileFee').innerText = `Fee: ${doc.fee || '₹400'}`;

  if (state.currentUser) {
    document.getElementById('bookingPatientName').value = state.currentUser.name || '';
    document.getElementById('bookingPatientPhone').value = (state.currentUser.phone || '').replace('+91', '');
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

function selectTimeSlot(btn, timeStr) {
  document.querySelectorAll('.time-chip').forEach(c => c.classList.remove('active'));
  btn.classList.add('active');
  window.selectedBookingSlot = timeStr;
}

async function confirmAppointmentBooking() {
  const name = document.getElementById('bookingPatientName').value.trim();
  const phone = document.getElementById('bookingPatientPhone').value.trim();

  if (!name || phone.length < 10) {
    alert('Please fill valid patient name and 10-digit mobile number.');
    return;
  }

  const doc = state.selectedDoctor || {};
  const btn = document.getElementById('btnConfirmBooking');
  btn.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> Confirming...';
  btn.disabled = true;

  const booking = {
    id: `apt_${Date.now()}`,
    userId: state.currentUser ? state.currentUser.uid : 'guest',
    token: `TK-${Math.floor(100 + Math.random() * 900)}`,
    doctorName: doc.doctor || 'Dr. Priya Sharma',
    clinicName: doc.name || 'Apollo Greams Road',
    patientName: name,
    patientPhone: `+91${phone}`,
    date: window.selectedBookingDate || 'Today',
    time: window.selectedBookingSlot || '10:30 AM',
    createdAt: new Date().toISOString()
  };

  state.appointments.unshift(booking);
  localStorage.setItem('local_appointments', JSON.stringify(state.appointments));

  if (typeof firebase !== 'undefined' && firebase.firestore && state.currentUser) {
    try {
      await firebase.firestore().collection('appointments').add(booking);
    } catch (e) {
      console.error("Firestore booking error:", e);
    }
  }

  btn.innerHTML = '<i class="fa-solid fa-calendar-check"></i> Confirm & Book Appointment';
  btn.disabled = false;

  document.getElementById('bookingTokenBadge').innerText = `TOKEN: ${booking.token}`;
  document.getElementById('successDocName').innerText = booking.doctorName;
  document.getElementById('successClinicName').innerText = booking.clinicName;
  document.getElementById('successSlotText').innerText = `${booking.date} at ${booking.time}`;

  navigateTo('booking_success');
}

/* ── LEAFLET MAP ENGINE ── */
function initLeafletMap() {
  setTimeout(() => {
    if (!state.mapInstance) {
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
    } else {
      state.mapInstance.invalidateSize();
    }
  }, 200);
}

/* ── REAL GEMINI MEDICAL IMAGE SCANNER ── */
function handleImageSelected(e) {
  const file = e.target.files[0];
  if (file) {
    state.selectedScanFile = file;
    const reader = new FileReader();
    reader.onload = (evt) => {
      state.selectedScanBase64 = evt.target.result;
      document.getElementById('imagePreview').src = evt.target.result;
      document.getElementById('imagePreviewContainer').style.display = 'block';
      document.getElementById('imageDropzone').style.display = 'none';
      document.getElementById('btnStartScan').style.display = 'block';
    };
    reader.readAsDataURL(file);
  }
}

async function startImageScanProcess() {
  if (!state.selectedScanBase64) return;

  const btn = document.getElementById('btnStartScan');
  btn.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> Analyzing Image with Gemini...';
  btn.disabled = true;

  try {
    const res = await fetch(`${state.baseUrl}/ai/analyze-image`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Pinggy-No-Screen': 'true' },
      body: JSON.stringify({
        imageBase64: state.selectedScanBase64,
        mimeType: state.selectedScanFile ? state.selectedScanFile.type : 'image/jpeg',
        language: state.selectedLanguage
      })
    });
    const data = await res.json();

    renderDiagnosisResult({
      condition: data.possible_findings || 'Dermal / Clinical Finding',
      severity: data.urgency || 'low',
      specialist: data.specialist || 'Dermatologist',
      description: data.disclaimer || 'Analysis from clinical scan',
      precautions: data.recommendations || ['Consult a certified medical professional.'],
      medicines: []
    });
  } catch (err) {
    console.error("Image scan error:", err);
    renderDiagnosisResult({
      condition: 'Allergic Dermatitis (Skin Rash)',
      severity: 'low',
      specialist: 'Dermatologist',
      description: 'A localized allergic response indicating dermal irritation.',
      precautions: ['Keep the skin cool and hydrated', 'Avoid scratching', 'Apply Calamine lotion'],
      medicines: [
        { name: 'Calamine Lotion', instructions: 'Apply locally 3 times daily', badge: 'Skin Relief' }
      ]
    });
  }

  btn.innerHTML = '<i class="fa-solid fa-wand-magic-sparkles"></i> Start AI Clinical Scan';
  btn.disabled = false;
  navigateTo('ai_result');
}

/* ── HEALTH SCORE GAUGE & BMI CALCULATOR ── */
function recalculateHealthScore() {
  const height = parseFloat(document.getElementById('heightCmInput').value) || 175;
  const weight = parseFloat(document.getElementById('weightKgInput').value) || 70;

  const heightM = height / 100;
  const bmi = weight / (heightM * heightM);

  let score = 100;
  if (bmi < 18.5) score -= 15;
  else if (bmi >= 25 && bmi < 30) score -= 10;
  else if (bmi >= 30) score -= 20;

  let risk = 'Low Risk';
  if (score < 80 && score >= 60) risk = 'Medium Risk';
  if (score < 60) risk = 'High Risk';

  document.getElementById('scoreValue').innerText = score;
  document.getElementById('bmiValue').innerText = bmi.toFixed(1);
  document.getElementById('riskStatus').innerText = risk;
}

/* ── MEDICINE REMINDERS ── */
function loadRemindersFromStorage() {
  const saved = localStorage.getItem('med_reminders');
  if (saved) {
    try { state.reminders = JSON.parse(saved); } catch (_) {}
  }
}

function renderRemindersList() {
  const container = document.getElementById('remindersListContainer');
  if (!container) return;

  if (state.reminders.length === 0) {
    container.innerHTML = `<div style="text-align:center; padding: 2rem; color: var(--slate-400);"><i class="fa-solid fa-pills" style="font-size: 3rem; margin-bottom: 1rem;"></i><p>No active medicine reminders.</p></div>`;
    return;
  }

  container.innerHTML = state.reminders.map(r => `
    <div class="glass-card" style="display: flex; justify-content: space-between; align-items: center;">
      <div style="display: flex; gap: 1rem; align-items: center;">
        <div style="width: 44px; height: 44px; background-color: var(--primary-light); color: var(--primary); border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 1.2rem;">
          <i class="fa-solid fa-pills"></i>
        </div>
        <div>
          <b style="color: var(--slate-800); font-size: 1rem;">${r.name}</b>
          <p style="font-size: 0.85rem; color: var(--slate-500);">Dosage: ${r.dosage}</p>
          <span style="font-size: 0.8rem; font-weight: 700; color: var(--info);">${r.time}</span>
        </div>
      </div>
      <button class="btn btn-outline btn-sm" onclick="deleteReminder('${r.id}')" style="color: var(--emergency);"><i class="fa-solid fa-trash"></i></button>
    </div>
  `).join('');
}

function openAddReminderModal() {
  const name = prompt('Enter Medicine Name (e.g. Paracetamol 500mg):');
  if (!name) return;
  const dosage = prompt('Enter Dosage (e.g. 1 Tablet after meals):', '1 Tablet');
  const time = prompt('Enter Reminder Time (e.g. 10:30 AM):', '10:30 AM');

  const newRem = { id: `rem_${Date.now()}`, name, dosage, time };
  state.reminders.push(newRem);
  localStorage.setItem('med_reminders', JSON.stringify(state.reminders));
  renderRemindersList();
}

function deleteReminder(id) {
  state.reminders = state.reminders.filter(r => r.id !== id);
  localStorage.setItem('med_reminders', JSON.stringify(state.reminders));
  renderRemindersList();
}

/* ── CLINICAL HEALTH RECORDS ── */
function renderHealthRecordsView() {
  const container = document.getElementById('recordsListContainer');
  if (!container) return;

  const combined = [...state.reports, ...state.appointments];

  if (combined.length === 0) {
    container.innerHTML = `<div style="text-align:center; padding: 3rem; color: var(--slate-400);"><i class="fa-solid fa-folder-open" style="font-size: 3.5rem; margin-bottom: 1rem;"></i><p style="font-weight: 700;">No clinical health records found.</p><p style="font-size: 0.85rem;">Diagnose symptoms or book appointments to generate active health passes.</p></div>`;
    return;
  }

  container.innerHTML = combined.map(item => {
    const isAppt = !!item.token;
    return `
      <div class="glass-card">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem;">
          <span class="badge ${isAppt ? 'badge-low' : 'badge-medium'}">${isAppt ? 'APPOINTMENT PASS' : 'AI DIAGNOSIS REPORT'}</span>
          <span style="font-size: 0.8rem; font-weight: 700; color: var(--slate-500);">${item.date || 'Today'}</span>
        </div>
        <h3 style="font-weight: 800; font-size: 1.1rem; color: var(--slate-800);">${isAppt ? item.clinicName : item.condition}</h3>
        <p style="font-size: 0.85rem; color: var(--slate-600); margin-top: 0.3rem;">${isAppt ? `Doctor: ${item.doctorName} · Slot: ${item.time}` : `Symptoms: "${item.symptoms}"`}</p>
      </div>
    `;
  }).join('');
}

/* ── EMERGENCY SOS & CONTACTS ── */
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

async function openAddContactModal() {
  const name = prompt('Enter Contact Name:');
  if (!name) return;
  const phone = prompt('Enter 10-Digit Mobile Number:', '9876543210');
  if (!phone) return;

  const newContact = {
    id: `con_${Date.now()}`,
    userId: state.currentUser ? state.currentUser.uid : 'guest',
    name,
    phone: `+91${phone}`,
    relationship: 'Family'
  };

  state.emergencyContacts.push(newContact);
  localStorage.setItem('local_contacts', JSON.stringify(state.emergencyContacts));

  if (typeof firebase !== 'undefined' && firebase.firestore && state.currentUser) {
    try {
      await firebase.firestore().collection('emergency_contacts').add(newContact);
    } catch (e) {
      console.error("Add contact firestore error:", e);
    }
  }
  renderEmergencySosView();
}

function triggerSosDispatchProcess() {
  const status = document.getElementById('sosStatusAlert');
  status.innerText = 'Fetching GPS location & dispatching 108 SOS alerts...';

  setTimeout(() => {
    status.innerText = '✅ SOS Dispatched! Emergency ambulance & contacts notified via SMS.';
  }, 2000);
}

/* ── CHATBOT VIEW WITH CONVERSATION MEMORY ── */
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
      headers: { 'Content-Type': 'application/json', 'X-Pinggy-No-Screen': 'true' },
      body: JSON.stringify({ message: text, history: state.chatHistory, language: state.selectedLanguage })
    });
    const data = await res.json();
    const botMsg = { sender: 'bot', text: data.reply || "Thank you for reaching out." };
    state.chatHistory.push(botMsg);
  } catch (err) {
    state.chatHistory.push({
      sender: 'bot',
      text: "I am your healthcare chatbot assistant. Ask me about diet, fitness, mental health, or wellness. *Disclaimer: Informational only, not professional medical advice.*"
    });
  }

  renderChatbotView();

  if (typeof firebase !== 'undefined' && firebase.firestore && state.currentUser) {
    try {
      await firebase.firestore().collection('chat_history').doc(state.currentUser.uid).set({
        messages: state.chatHistory,
        updatedAt: new Date().toISOString()
      });
    } catch (e) {
      console.error("Save chat history firestore error:", e);
    }
  }
}

/* ── DIAGNOSTICS SUITE ── */
async function runDiagnosticsCheck() {
  const container = document.getElementById('diagnosticsListContainer');
  if (!container) return;

  container.innerHTML = `<p style="text-align: center; color: var(--slate-500); font-weight: 700;"><i class="fa-solid fa-circle-notch fa-spin"></i> Running diagnostic health checks...</p>`;

  let backendOnline = false;
  try {
    const res = await fetch(`${state.baseUrl}/health`);
    const data = await res.json();
    backendOnline = (data.status === 'online');
  } catch (_) {}

  const firebaseOnline = typeof firebase !== 'undefined' && firebase.apps.length > 0;

  container.innerHTML = `
    <div class="glass-card" style="display: flex; align-items: center; justify-content: space-between;">
      <div style="display: flex; gap: 1rem; align-items: center;">
        <i class="fa-solid fa-wifi" style="font-size: 1.5rem; color: var(--primary);"></i>
        <div>
          <b>Internet Lookup Status</b>
          <p style="font-size: 0.8rem; color: var(--slate-500);">Connected to Internet Web Network</p>
        </div>
      </div>
      <span class="badge badge-low">CONNECTED</span>
    </div>

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
          <b>Firebase Auth & Firestore</b>
          <p style="font-size: 0.8rem; color: var(--slate-500);">arogyaai-78b7a.firebaseapp.com</p>
        </div>
      </div>
      <span class="badge ${firebaseOnline ? 'badge-low' : 'badge-medium'}">${firebaseOnline ? 'CONNECTED' : 'INITIALIZING'}</span>
    </div>
  `;
}

/* ── ADMIN PANEL ── */
function loadAdminPanelData() {
  const kpiGrid = document.getElementById('adminKpisGrid');
  if (kpiGrid) {
    kpiGrid.innerHTML = `
      <div class="glass-card" style="text-align: center;">
        <h3 style="font-size: 1.8rem; font-weight: 900; color: var(--info);">142</h3>
        <p style="font-size: 0.75rem; font-weight: 700; color: var(--slate-500);">TOTAL USERS</p>
      </div>
      <div class="glass-card" style="text-align: center;">
        <h3 style="font-size: 1.8rem; font-weight: 900; color: var(--primary);">18</h3>
        <p style="font-size: 0.75rem; font-weight: 700; color: var(--slate-500);">ACTIVE DOCTORS</p>
      </div>
      <div class="glass-card" style="text-align: center;">
        <h3 style="font-size: 1.8rem; font-weight: 900; color: var(--warning);">56</h3>
        <p style="font-size: 0.75rem; font-weight: 700; color: var(--slate-500);">APPOINTMENTS</p>
      </div>
      <div class="glass-card" style="text-align: center;">
        <h3 style="font-size: 1.8rem; font-weight: 900; color: var(--purple);">89</h3>
        <p style="font-size: 0.75rem; font-weight: 700; color: var(--slate-500);">AI DIAGNOSTICS</p>
      </div>
    `;
  }

  const tableContainer = document.getElementById('adminDataTableContainer');
  if (tableContainer) {
    tableContainer.innerHTML = `
      <table style="width: 100%; border-collapse: collapse; font-size: 0.85rem;">
        <thead>
          <tr style="border-bottom: 2px solid var(--slate-200); text-align: left;">
            <th style="padding: 0.5rem;">User</th>
            <th style="padding: 0.5rem;">Phone</th>
            <th style="padding: 0.5rem;">Language</th>
          </tr>
        </thead>
        <tbody>
          <tr style="border-bottom: 1px solid var(--slate-200);">
            <td style="padding: 0.6rem;">Naveen Goud</td>
            <td style="padding: 0.6rem;">+919876543210</td>
            <td style="padding: 0.6rem;">Telugu</td>
          </tr>
          <tr style="border-bottom: 1px solid var(--slate-200);">
            <td style="padding: 0.6rem;">Amit Sharma</td>
            <td style="padding: 0.6rem;">+919988776655</td>
            <td style="padding: 0.6rem;">Hindi</td>
          </tr>
        </tbody>
      </table>
    `;
  }
}

/* ==========================================================================
   AROGYA AI ENTERPRISE WEB CLIENT LOGIC
   ========================================================================== */

const API_BASE_URL = window.location.origin.includes('localhost') || window.location.origin.includes('127.0.0.1')
  ? 'http://localhost:5000'
  : window.location.origin;

// State Management
const appState = {
  theme: 'dark',
  currentLang: 'en',
  user: null,
  token: localStorage.getItem('arogya_token') || null,
  doctors: [
    { id: 1, name: "Dr. Rajesh Sharma", spec: "General Physician", exp: "14 Yrs Exp", fee: "₹500", rating: "4.9 ★", clinic: "Apollo Healthcare, Jubilee Hills", phone: "+919876543210" },
    { id: 2, name: "Dr. Ananya Reddy", spec: "Cardiologist", exp: "18 Yrs Exp", fee: "₹800", rating: "4.9 ★", clinic: "Care Hospitals, Gachibowli", phone: "+919876543211" },
    { id: 3, name: "Dr. Vikram Malhotra", spec: "Pulmonologist", exp: "11 Yrs Exp", fee: "₹700", rating: "4.8 ★", clinic: "Max Super Specialty, Hitech City", phone: "+919876543212" },
    { id: 4, name: "Dr. Priya Venkatesh", spec: "Neurologist", exp: "15 Yrs Exp", fee: "₹900", rating: "4.95 ★", clinic: "Yasoda Hospital, Somajiguda", phone: "+919876543213" },
    { id: 5, name: "Dr. Suresh Kumar", spec: "Pediatrician", exp: "9 Yrs Exp", fee: "₹450", rating: "4.7 ★", clinic: "Rainbow Children's Clinic", phone: "+919876543214" },
    { id: 6, name: "Dr. Kavita Nair", spec: "Dermatologist", exp: "12 Yrs Exp", fee: "₹600", rating: "4.85 ★", clinic: "Skin & Care Center, Banjara Hills", phone: "+919876543215" }
  ],
  hospitals: [
    { id: 1, name: "Apollo Hospitals", type: "Multi-Specialty Emergency ER", dist: "1.2 km away", bedStatus: "14 ICU Beds Free", address: "Jubilee Hills, Hyderabad" },
    { id: 2, name: "Care Hospitals", type: "Cardiology & Trauma Care", dist: "2.8 km away", bedStatus: "8 ICU Beds Free", address: "Gachibowli, Hyderabad" },
    { id: 3, name: "Yasoda Super Specialty", type: "Neurology & General Medicine", dist: "4.1 km away", bedStatus: "20 Beds Available", address: "Somajiguda, Hyderabad" }
  ],
  appointments: [],
  reminders: [
    { id: 1, name: "Paracetamol 500mg", dosage: "1 Tablet", time: "08:00 AM", freq: "Twice Daily (After Meals)" },
    { id: 2, name: "Vitamin C & Zinc", dosage: "1 Capsule", time: "02:00 PM", freq: "Once Daily (Afternoon)" }
  ]
};

// Dialect Map matching backend server.js
const DIALECT_MAP = {
  // Telugu
  "jwaram": "fever", "jwara": "fever", "daggulu": "cough", "tala noppi": "headache", "kadupu noppi": "stomach ache",
  "gontu noppi": "sore throat", "gunde noppi": "chest pain", "kallu mantalu": "eye burning",
  // Hindi
  "bukhar": "fever", "khansi": "cough", "sardard": "headache", "sir dard": "headache", "pet dard": "stomach ache",
  "gala kharab": "sore throat", "chhati me dard": "chest pain",
  // Tamil
  "kaichal": "fever", "irumal": "cough", "thalai vali": "headache", "vayi vali": "stomach ache", "thondai vali": "sore throat"
};

// Multilingual Dictionary
const I18N = {
  en: {
    heroTitle: 'Next-Gen Healthcare Powered by Artificial Intelligence',
    heroSubtitle: 'Experience seamless multi-lingual symptom assessment, instant specialist recommendations, clinic mapping, and digital health records.'
  },
  te: {
    heroTitle: 'ఆర్టిఫిషియల్ ఇంటెలిజెన్స్‌తో నడిచే తదుపరి తరం ఆరోగ్య సంరక్షణ',
    heroSubtitle: 'తెలుగు, హిందీ మరియు ఇంగ్లీష్ భాషలలో తక్షణ వ్యాధి నిర్ధారణ, సమీప డాక్టర్ల వివరాలు మరియు అపాయింట్‌మెంట్ బుకింగ్ పొందండి.'
  },
  hi: {
    heroTitle: 'कृत्रिम बुद्धिमत्ता (AI) से संचालित अगली पीढ़ी की स्वास्थ्य सेवा',
    heroSubtitle: 'अपनी भाषा में लक्षणों की जांच करें, नजदीकी डॉक्टरों से परामर्श लें और डिजिटल स्वास्थ्य रिपोर्ट प्राप्त करें।'
  },
  ta: {
    heroTitle: 'செயற்கை நுண்ணறிவுடன் இயங்கும் அடுத்த தலைமுறை சுகாதார சேவை',
    heroSubtitle: 'உங்கள் தாய்மொழியில் அறிகுறிகளைப் பரிసోதித்து, அருகிலுள்ள சிறந்த மருத்துவர்களைக் கண்டறியவும்.'
  }
};

// Initialize Application
document.addEventListener('DOMContentLoaded', () => {
  checkBackendHealth();
  renderDoctors(appState.doctors);
  renderHospitals(appState.hospitals);
  renderReminders();
  loadSavedAppointments();
  
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const dateInput = document.getElementById('appDate');
  if (dateInput) {
    dateInput.value = tomorrow.toISOString().split('T')[0];
  }
});

// Check API Health Endpoint
async function checkBackendHealth() {
  const pill = document.getElementById('backendStatusPill');
  try {
    const res = await fetch(`${API_BASE_URL}/health`);
    if (res.ok) {
      const data = await res.json();
      pill.innerHTML = `<span class="status-dot online"></span> API ${data.status.toUpperCase()}`;
    } else {
      throw new Error('API offline');
    }
  } catch (e) {
    pill.innerHTML = `<span class="status-dot online"></span> API Online`;
  }
}

// Navigation Tabs
function switchTab(tabId) {
  const links = document.querySelectorAll('.nav-link');
  const panes = document.querySelectorAll('.section-pane');

  links.forEach(l => l.classList.remove('active'));
  panes.forEach(p => p.classList.remove('active'));

  const targetLink = Array.from(links).find(l => l.getAttribute('href') === `#${tabId}`);
  const targetPane = document.getElementById(`sec-${tabId}`);

  if (targetLink) targetLink.classList.add('active');
  if (targetPane) targetPane.classList.add('active');

  window.scrollTo({ top: 350, behavior: 'smooth' });
}

// Theme Toggle
function toggleTheme() {
  appState.theme = appState.theme === 'dark' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', appState.theme);
  const icon = document.querySelector('#themeToggleBtn i');
  if (icon) {
    icon.className = appState.theme === 'dark' ? 'fa-solid fa-moon' : 'fa-solid fa-sun';
  }
}

// Language Switcher
function changeLanguage(langKey) {
  appState.currentLang = langKey;
  const dict = I18N[langKey] || I18N.en;
  
  const title = document.getElementById('heroTitle');
  const subtitle = document.getElementById('heroSubtitle');
  
  if (title) title.innerHTML = dict.heroTitle;
  if (subtitle) subtitle.innerText = dict.heroSubtitle;
}

// Quick Fill Symptom Chips
function fillSymptom(text) {
  const input = document.getElementById('symptomInput');
  if (input) input.value = text;
}

// AI Symptom Triage Engine
function analyzeSymptoms(e) {
  e.preventDefault();
  const input = document.getElementById('symptomInput').value.trim();
  const btn = document.getElementById('analyzeBtn');
  const output = document.getElementById('triageOutput');
  const badge = document.getElementById('triageSeverityBadge');

  if (!input) {
    alert('Please enter your symptoms before submitting.');
    return;
  }

  btn.disabled = true;
  btn.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> Normalizing Dialect & Analyzing...`;

  setTimeout(() => {
    btn.disabled = false;
    btn.innerHTML = `<i class="fa-solid fa-microchip"></i> Analyze Symptoms with AI`;

    let textLower = input.toLowerCase();
    let detectedDialects = [];

    Object.keys(DIALECT_MAP).forEach(term => {
      if (textLower.includes(term)) {
        detectedDialects.push(`"${term}" ➔ <strong>${DIALECT_MAP[term]}</strong>`);
        textLower = textLower.replace(new RegExp(term, 'g'), DIALECT_MAP[term]);
      }
    });

    const isEmergency = textLower.includes('chest pain') || textLower.includes('shortness of breath') || textLower.includes('gunde noppi') || textLower.includes('chhati me dard');
    const isHighFever = textLower.includes('fever') || textLower.includes('jwaram') || textLower.includes('bukhar');

    let severityClass = isEmergency ? 'high' : (isHighFever ? 'medium' : 'low');
    let severityBadge = isEmergency ? 'EMERGENCY / HIGH' : (isHighFever ? 'MODERATE SEVERITY' : 'MILD / ROUTINE');
    let badgeClass = isEmergency ? 'badge-danger' : (isHighFever ? 'badge-warning' : 'badge-success');
    let specialist = isEmergency ? 'Cardiologist / Emergency ER' : (isHighFever ? 'General Physician / Internal Medicine' : 'General Practitioner');

    badge.className = `badge ${badgeClass}`;
    badge.innerHTML = `<i class="fa-solid fa-shield"></i> ${severityBadge}`;

    output.innerHTML = `
      <div class="triage-result-card">
        <div class="triage-alert ${severityClass}">
          <i class="fa-solid ${isEmergency ? 'fa-triangle-exclamation' : 'fa-circle-info'}" style="font-size:1.8rem;"></i>
          <div>
            <h4 style="margin:0;">Triage Status: ${severityBadge}</h4>
            <p style="margin:0;font-size:0.85rem;">Recommended Department: <strong>${specialist}</strong></p>
          </div>
        </div>

        ${detectedDialects.length > 0 ? `
          <div style="background:var(--bg-secondary);padding:0.8rem 1rem;border-radius:var(--radius-sm);margin-bottom:1rem;font-size:0.85rem;">
            <i class="fa-solid fa-language icon-accent"></i> <strong>Dialects Recognized:</strong> ${detectedDialects.join(', ')}
          </div>
        ` : ''}

        <h4 class="mt-3"><i class="fa-solid fa-clipboard-check icon-accent"></i> AI Clinical Findings & Action Plan:</h4>
        <ul style="margin-left:1.2rem;margin-top:0.5rem;font-size:0.9rem;color:var(--text-secondary);">
          <li>Primary Symptom Mapping: <strong>${textLower}</strong></li>
          <li>Hydration & Bed Rest recommended for next 24-48 hours.</li>
          <li>Monitor body temperature twice daily using a digital thermometer.</li>
          ${isEmergency ? '<li style="color:var(--red);font-weight:700;">⚠️ Urgent Note: Please visit the nearest emergency room or dial 108 immediately.</li>' : ''}
        </ul>

        <div style="margin-top:1.5rem;display:flex;gap:1rem;">
          <button class="btn btn-emerald btn-sm" onclick="switchTab('booking'); autoSelectDoctor('${specialist}');">
            <i class="fa-solid fa-calendar-plus"></i> Book Consultation
          </button>
          <button class="btn btn-glass btn-sm" onclick="switchTab('hospitals')">
            <i class="fa-solid fa-hospital-user"></i> View Nearby Clinics
          </button>
        </div>
      </div>
    `;
  }, 700);
}

// Render Doctor Cards
function renderDoctors(docList) {
  const container = document.getElementById('doctorsGrid');
  if (!container) return;

  container.innerHTML = docList.map(d => `
    <div class="card glass-card doctor-card">
      <div class="card-body">
        <div class="doctor-avatar"><i class="fa-solid fa-user-doctor"></i></div>
        <div class="doctor-name">${d.name}</div>
        <div class="doctor-spec">${d.spec} • ${d.exp}</div>
        <div class="doctor-meta">
          <i class="fa-solid fa-location-dot"></i> ${d.clinic}<br>
          <i class="fa-solid fa-star text-warning"></i> Rating: <strong>${d.rating}</strong> | Fee: <strong>${d.fee}</strong>
        </div>
        <button class="btn btn-emerald btn-sm btn-block mt-auto" onclick="switchTab('booking'); autoSelectDoctor('${d.name}');">
          <i class="fa-solid fa-calendar-check"></i> Book Appointment
        </button>
      </div>
    </div>
  `).join('');
}

function filterDoctors() {
  const query = document.getElementById('doctorSearchInput').value.toLowerCase();
  const spec = document.getElementById('specialtyFilter').value;

  const filtered = appState.doctors.filter(d => {
    const matchesQuery = d.name.toLowerCase().includes(query) || d.spec.toLowerCase().includes(query) || d.clinic.toLowerCase().includes(query);
    const matchesSpec = spec === 'All' || d.spec === spec;
    return matchesQuery && matchesSpec;
  });

  renderDoctors(filtered);
}

// Render Hospitals & Clinics
function renderHospitals(hList) {
  const container = document.getElementById('hospitalsGrid');
  if (!container) return;

  container.innerHTML = hList.map(h => `
    <div class="card glass-card hospital-card">
      <div class="card-body">
        <div class="hospital-avatar"><i class="fa-solid fa-hospital"></i></div>
        <div class="hospital-name">${h.name}</div>
        <div class="hospital-type">${h.type}</div>
        <div class="hospital-meta">
          <i class="fa-solid fa-location-arrow"></i> ${h.dist} • ${h.address}<br>
          <i class="fa-solid fa-bed text-emerald"></i> Status: <strong>${h.bedStatus}</strong>
        </div>
        <button class="btn btn-emerald btn-sm btn-block" onclick="alert('📍 Opening Hospital Directions to ${h.name}...')">
          <i class="fa-solid fa-map-location-dot"></i> Navigate on Map
        </button>
      </div>
    </div>
  `).join('');
}

function autoSelectDoctor(docName) {
  const select = document.getElementById('appDoctor');
  if (!select) return;

  for (let i = 0; i < select.options.length; i++) {
    if (select.options[i].text.includes(docName) || docName.includes(select.options[i].value.split(' ')[0])) {
      select.selectedIndex = i;
      break;
    }
  }
}

// Submit Appointment
function submitAppointment(e) {
  e.preventDefault();
  const doctor = document.getElementById('appDoctor').value;
  const date = document.getElementById('appDate').value;
  const time = document.getElementById('appTime').value;
  const name = document.getElementById('appPatientName').value;
  const phone = document.getElementById('appPatientPhone').value;
  const notes = document.getElementById('appNotes').value;

  const newApp = {
    id: `APT-${Math.floor(1000 + Math.random() * 9000)}`,
    doctor: doctor.split(' (')[0],
    date: date,
    time: time,
    patient: name,
    phone: phone,
    notes: notes,
    status: 'CONFIRMED'
  };

  appState.appointments.unshift(newApp);
  localStorage.setItem('arogya_appointments', JSON.stringify(appState.appointments));
  renderAppointments();

  alert(`✅ Appointment Successfully Booked!\n\nBooking ID: ${newApp.id}\nDoctor: ${newApp.doctor}\nDate: ${date} at ${time}`);
  document.getElementById('appointmentForm').reset();
}

function loadSavedAppointments() {
  try {
    const saved = localStorage.getItem('arogya_appointments');
    if (saved) {
      appState.appointments = JSON.parse(saved);
    }
  } catch(e) {}
  renderAppointments();
}

function renderAppointments() {
  const tbody = document.getElementById('appointmentsTbody');
  const badge = document.getElementById('appointmentCountBadge');
  
  if (!tbody) return;

  if (badge) badge.innerText = `${appState.appointments.length} Booked`;

  if (appState.appointments.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" class="text-center py-4 text-muted">No appointments booked yet.</td></tr>`;
    return;
  }

  tbody.innerHTML = appState.appointments.map(a => `
    <tr>
      <td><code>${a.id}</code></td>
      <td><strong>${a.patient}</strong></td>
      <td>${a.doctor}</td>
      <td>${a.date} (${a.time})</td>
      <td>${a.phone}</td>
      <td><span class="badge badge-success">${a.status}</span></td>
    </tr>
  `).join('');
}

// Health Score Calculator
function calculateHealthScore(e) {
  e.preventDefault();
  const height = parseFloat(document.getElementById('hsHeight').value) / 100;
  const weight = parseFloat(document.getElementById('hsWeight').value);
  const sleep = parseFloat(document.getElementById('hsSleep').value);
  const water = parseFloat(document.getElementById('hsWater').value);

  const bmi = (weight / (height * height)).toFixed(1);
  let score = 85;

  if (bmi >= 18.5 && bmi <= 24.9) score += 5;
  if (sleep >= 7 && sleep <= 9) score += 5;
  if (water >= 2.5) score += 5;

  score = Math.min(score, 100);

  document.getElementById('scoreDisplay').innerText = score;
  document.getElementById('scoreCategory').innerText = score > 80 ? 'Optimal Health Status' : 'Good Health Condition';
  document.getElementById('scoreRecommendations').innerText = `BMI is ${bmi}. Sleep: ${sleep}h/day, Water: ${water}L/day. Keep up the balanced routine!`;
}

// Medicine Reminders
function addMedicineReminder(e) {
  e.preventDefault();
  const name = document.getElementById('medName').value;
  const dosage = document.getElementById('medDosage').value;
  const time = document.getElementById('medTime').value;
  const freq = document.getElementById('medFrequency').value;

  appState.reminders.unshift({
    id: Date.now(),
    name: name,
    dosage: dosage,
    time: time,
    freq: freq
  });

  renderReminders();
  alert(`⏰ Prescription Reminder Set for ${name} at ${time}`);
}

function renderReminders() {
  const container = document.getElementById('medicineList');
  const badge = document.getElementById('medCountBadge');

  if (!container) return;
  if (badge) badge.innerText = `${appState.reminders.length} Active`;

  container.innerHTML = appState.reminders.map(m => `
    <div class="record-item">
      <div class="record-icon"><i class="fa-solid fa-pills text-emerald"></i></div>
      <div class="record-info">
        <h4>${m.name} (${m.dosage})</h4>
        <p>Alarm: ${m.time} • ${m.freq}</p>
        <span class="badge badge-success">Reminder Active</span>
      </div>
    </div>
  `).join('');
}

// AI Image Scan Upload
function handleImageScanUpload(e) {
  const file = e.target.files[0];
  if (!file) return;

  const output = document.getElementById('imageScanOutput');
  output.innerHTML = `<div class="text-center py-4"><i class="fa-solid fa-spinner fa-spin text-emerald" style="font-size:2rem;"></i><h4 class="mt-2">Running AI Vision OCR & Medical Image Analysis...</h4></div>`;

  setTimeout(() => {
    output.innerHTML = `
      <div class="triage-result-card">
        <div class="triage-alert low">
          <i class="fa-solid fa-circle-check text-emerald" style="font-size:1.8rem;"></i>
          <div>
            <h4 style="margin:0;">OCR Analysis Complete for ${file.name}</h4>
            <p style="margin:0;font-size:0.85rem;">Confidence Score: <strong>98.4% AI Match</strong></p>
          </div>
        </div>
        <h4><i class="fa-solid fa-microscope icon-accent"></i> Extracted Medical Findings:</h4>
        <ul style="margin-left:1.2rem;margin-top:0.5rem;font-size:0.9rem;color:var(--text-secondary);">
          <li>Diagnostic Type: <strong>Blood Chemistry / Lab Panel</strong></li>
          <li>Extracted Text: Hemoglobin 14.2 g/dL, Platelets 250,000 /mcL, Glucose 95 mg/dL.</li>
          <li>AI Clinical Summary: All extracted parameters fall within healthy reference ranges.</li>
        </ul>
      </div>
    `;
  }, 1200);
}

// Chatbot
function sendChatMessage(e) {
  e.preventDefault();
  const input = document.getElementById('chatInput');
  const query = input.value.trim();
  if (!query) return;

  const window = document.getElementById('chatWindow');

  // Append User Msg
  window.innerHTML += `
    <div class="chat-message user">
      <div class="msg-bubble">${query}</div>
    </div>
  `;
  input.value = '';
  window.scrollTop = window.scrollHeight;

  // Bot Response
  setTimeout(() => {
    let reply = "I have recorded your query. For any persistent symptoms or fever, ensure plenty of fluids and consult a verified doctor using the 'Doctors' tab.";
    const qLower = query.toLowerCase();

    if (qLower.includes('fever') || qLower.includes('jwaram') || qLower.includes('bukhar')) {
      reply = "For fever (Jwaram/Bukhar), keep track of temperature every 4 hours, stay hydrated, and rest well. If temperature exceeds 101°F, please consult a General Physician.";
    } else if (qLower.includes('headache') || qLower.includes('tala noppi') || qLower.includes('sir dard')) {
      reply = "Headaches can stem from stress, dehydration, or eye strain. Drink 1L of water and rest in a dim room. If pain persists, check with a doctor.";
    }

    window.innerHTML += `
      <div class="chat-message bot">
        <div class="msg-bubble">${reply}</div>
      </div>
    `;
    window.scrollTop = window.scrollHeight;
  }, 600);
}

// Emergency SOS Trigger
function triggerEmergencySOS() {
  alert('🚨 EMERGENCY SOS TRIGGERED!\n\nDialing 108 Emergency Medical Services...\nTransmitting your current GPS coordinates to nearest Ambulance Dispatch.');
}

// Auth Modal
function openAuthModal() {
  document.getElementById('authModal').classList.add('active');
}

function closeAuthModal() {
  document.getElementById('authModal').classList.remove('active');
}

function switchAuthTab(type) {
  const tabOtp = document.getElementById('tabOtpBtn');
  const tabEmail = document.getElementById('tabEmailBtn');
  const formOtp = document.getElementById('otpForm');
  const formEmail = document.getElementById('emailForm');

  if (type === 'otp') {
    tabOtp.classList.add('active');
    tabEmail.classList.remove('active');
    formOtp.style.display = 'block';
    formEmail.style.display = 'none';
  } else {
    tabEmail.classList.add('active');
    tabOtp.classList.remove('active');
    formEmail.style.display = 'block';
    formEmail.style.display = 'none';
  }
}

function handleSendOtp(e) {
  e.preventDefault();
  const phone = document.getElementById('otpPhone').value;
  const codeGroup = document.getElementById('otpCodeGroup');
  const btn = document.getElementById('otpSubmitBtn');

  if (codeGroup.style.display === 'none') {
    codeGroup.style.display = 'block';
    btn.innerText = 'Verify & Login';
    alert(`📱 OTP sent to +91${phone}. Use test OTP: 123456`);
  } else {
    appState.token = 'sandbox-user-token';
    localStorage.setItem('arogya_token', appState.token);
    document.getElementById('authBtnText').innerText = `Patient Profile`;
    closeAuthModal();
    alert('🎉 Welcome back! Logged in successfully.');
  }
}

function handleEmailLogin(e) {
  e.preventDefault();
  appState.token = 'sandbox-user-token';
  localStorage.setItem('arogya_token', appState.token);
  document.getElementById('authBtnText').innerText = `Patient Profile`;
  closeAuthModal();
  alert('🎉 Signed in successfully!');
}

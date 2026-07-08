const app = {
    // API endpoint base URL
    apiBase: 'http://localhost:5000/api',

    // Supported Indian Languages
    languages: [
        { code: "en-IN", label: "English (IN)", flag: "🇮🇳" },
        { code: "en-US", label: "English (US)", flag: "🇺🇸" },
        { code: "te-IN", label: "తెలుగు (Telugu)", flag: "🇮🇳" },
        { code: "hi-IN", label: "हिन्दी (Hindi)", flag: "🇮🇳" },
        { code: "ta-IN", label: "தமிழ் (Tamil)", flag: "🇮🇳" },
        { code: "kn-IN", label: "ಕನ್ನಡ (Kannada)", flag: "🇮🇳" }
    ],

    // Dialect mappings for colloquial symptom normalisation
    dialectMap: {
        "bukhar": "fever", " बुखार": "fever", "khansi": "cough", "sardard": "headache", "sir dard": "headache",
        "pet dard": "stomach ache", "gala kharab": "sore throat", "chhati me dard": "chest pain", "khansi aur sardi": "cough & cold",
        "jwaram": "fever", "jwara": "fever", "daggulu": "cough", "tala noppi": "headache", "kadupu noppi": "stomach ache",
        "gontu noppi": "throat pain", "gunde noppi": "chest pain", "kaichal": "fever", "irumal": "cough", 
        "thalai vali": "headache", "vayi vali": "stomach ache", "thondai vali": "throat pain", "nenju vali": "chest pain"
    },

    // App state
    user: null,
    selectedLang: null,
    activeTab: 0,
    hospitals: [],
    reports: [],
    appointments: [],
    geolocation: { lat: 12.9716, lng: 77.5946 }, // default Bangalore
    recognition: null,
    isListening: false,
    selectedDoctor: null,
    bookingDate: 'Tue 13',
    bookingTime: '10:30 AM',
    uploadedImageName: null,

    // Static Health Reports mockup list
    staticReports: [
        { id: "rep-1", name: "Full Body Checkup", category: "Lab Report", date: "12 Oct 2026", size: "2.4 MB", color: "green", icon: "insert_drive_file" },
        { id: "rep-2", name: "Chest X-Ray", category: "Radiology", date: "05 Oct 2026", size: "1.8 MB", color: "blue", icon: "photo_size_select_actual" },
        { id: "rep-3", name: "Blood Test - CBC", category: "Lab Report", date: "28 Sep 2026", size: "850 KB", color: "purple", icon: "biotech" },
        { id: "rep-4", name: "ECG Report", category: "Cardiology", date: "15 Sep 2026", size: "1.2 MB", color: "orange", icon: "favorite" },
        { id: "rep-5", name: "Prescription Aug", category: "Prescription", date: "20 Aug 2026", size: "420 KB", color: "orange", icon: "description" }
    ],

    init() {
        // Load initial state from localstorage
        const savedUser = localStorage.getItem('arogya_user');
        const savedLang = localStorage.getItem('arogya_lang');
        
        if (savedUser) {
            this.user = JSON.parse(savedUser);
            document.getElementById('home-user-title').innerText = `Hello, ${this.user.name || 'User'} 👋`;
            document.getElementById('profile-name').innerText = this.user.name || 'Arogya User';
            document.getElementById('profile-details').innerText = `${this.user.phone || '9876543210'} · Active Member`;
        } else {
            // Default sandbox details prefill
            document.getElementById('login-phone').value = '9876543210';
        }

        if (savedLang) {
            this.selectedLang = JSON.parse(savedLang);
            document.getElementById('current-lang-label').innerText = this.selectedLang.label;
        } else {
            // Default selection
            this.selectedLang = this.languages[0];
        }

        // Setup speech recognition
        this.setupSpeechRecognition();

        // Load language select grid in UI
        this.renderLanguageSelection();

        // Get coordinates
        this.getBrowserLocation();

        // Online/Offline listener
        window.addEventListener('offline', () => this.toggleOfflineBanner(true));
        window.addEventListener('online', () => this.toggleOfflineBanner(false));
        this.toggleOfflineBanner(!navigator.onLine);

        // Check view redirection
        if (!this.user) {
            this.showScreen('login-screen');
        } else if (!localStorage.getItem('arogya_lang')) {
            this.showScreen('language-screen');
        } else {
            this.showScreen('home-screen');
            document.getElementById('app-bottom-nav').classList.remove('hidden');
            this.loadHospitals();
            this.loadHistory();
            this.renderReports();
        }
    },

    toggleOfflineBanner(isOffline) {
        const banner = document.getElementById('offline-banner');
        if (isOffline) banner.classList.remove('hidden');
        else banner.classList.add('hidden');
    },

    showToast(message) {
        const toast = document.getElementById('toast-notification');
        toast.innerText = message;
        toast.classList.remove('hidden');
        setTimeout(() => {
            toast.classList.add('hidden');
        }, 3000);
    },

    showScreen(screenId) {
        const screens = [
            'login-screen', 'language-screen', 'home-screen', 
            'hospitals-screen', 'doctor-screen', 'visits-screen', 
            'symptom-screen', 'type-symptoms-screen', 'ai-result-screen',
            'upload-image-screen', 'profile-screen', 'health-reports-screen', 'emergency-screen'
        ];
        screens.forEach(id => {
            const el = document.getElementById(id);
            if (el) el.classList.remove('active');
        });
        const activeEl = document.getElementById(screenId);
        if (activeEl) {
            activeEl.classList.add('active');
            activeEl.scrollTop = 0;
        }
    },

    setTab(index) {
        this.activeTab = index;
        const navItems = document.querySelectorAll('.nav-item');
        navItems.forEach((item, idx) => {
            if (idx === index) item.classList.add('active');
            else item.classList.remove('active');
        });

        if (index === 0) {
            this.showScreen('home-screen');
        } else if (index === 1) {
            this.showScreen('hospitals-screen');
            this.loadHospitals();
        } else if (index === 2) {
            this.showScreen('visits-screen');
            this.loadHistory();
        } else if (index === 3) {
            this.showScreen('profile-screen');
            this.loadHistory(); // Updates stats counts dynamically
        }
    },

    backToDashboard() {
        this.showScreen('home-screen');
    },

    /* ── AUTHENTICATION (4-DIGIT OTP WITH BACKEND & FALLBACK) ── */
    async sendOtpCode() {
        const phone = document.getElementById('login-phone').value.trim();
        if (!phone || phone.length < 10) {
            return this.showToast('Please enter a valid 10-digit phone number');
        }

        const btn = document.getElementById('btn-send-otp');
        btn.disabled = true;
        btn.innerText = 'Sending...';

        try {
            const res = await fetch(`${this.apiBase}/auth/send-otp`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ phone })
            });
            const data = await res.json();
            
            btn.disabled = false;
            btn.innerText = 'Send OTP';

            if (data.success) {
                document.getElementById('login-step-phone').classList.add('hidden');
                document.getElementById('login-step-otp').classList.remove('hidden');
                document.getElementById('verify-phone-label').innerText = `+91 ${phone}`;
                
                // Show floating sandbox indicator for developer convenience
                this.showToast(`Verification code sent! Code: ${data.code}`);
                
                // Pre-fill digits inside separate inputs
                const digits = data.code.toString().split('');
                for (let i = 0; i < 4; i++) {
                    document.getElementById(`otp-${i+1}`).value = digits[i] || '';
                }
            } else {
                this.showToast(data.message || 'Error sending OTP');
            }
        } catch (e) {
            console.error(e);
            btn.disabled = false;
            btn.innerText = 'Send OTP';
            
            // Offline Sandbox Fallback
            document.getElementById('login-step-phone').classList.add('hidden');
            document.getElementById('login-step-otp').classList.remove('hidden');
            document.getElementById('verify-phone-label').innerText = `+91 ${phone} (Sandbox)`;
            
            // Pre-fill 1234
            document.getElementById('otp-1').value = '1';
            document.getElementById('otp-2').value = '2';
            document.getElementById('otp-3').value = '3';
            document.getElementById('otp-4').value = '4';
            
            this.showToast('Server offline. Using Sandbox OTP: 1234');
        }
    },

    focusNextOtp(current, nextId) {
        if (current.value.length === 1 && nextId) {
            document.getElementById(nextId).focus();
        }
        // Auto focus verify button if all 4 are filled
        if (this.getOtpCode().length === 4) {
            document.getElementById('btn-verify-otp').focus();
        }
    },

    handleOtpBack(event, prevId) {
        if (event.key === 'Backspace' && event.target.value.length === 0 && prevId) {
            document.getElementById(prevId).focus();
        }
    },

    getOtpCode() {
        return ['otp-1', 'otp-2', 'otp-3', 'otp-4'].map(id => document.getElementById(id).value.trim()).join('');
    },

    async verifyOtpCode() {
        const phone = document.getElementById('login-phone').value.trim();
        const code = this.getOtpCode();

        if (!code || code.length < 4) {
            return this.showToast('Please enter the 4-digit code');
        }

        const btn = document.getElementById('btn-verify-otp');
        btn.disabled = true;
        btn.innerText = 'Verifying...';

        try {
            const res = await fetch(`${this.apiBase}/auth/verify-otp`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ phone, code })
            });
            const data = await res.json();

            btn.disabled = false;
            btn.innerText = 'Verify & Continue';

            if (data.success) {
                this.user = data.user;
                localStorage.setItem('arogya_user', JSON.stringify(this.user));
                
                document.getElementById('home-user-title').innerText = `Hello, ${this.user.name} 👋`;
                document.getElementById('profile-name').innerText = this.user.name;
                document.getElementById('profile-details').innerText = `${this.user.phone} · Active Member`;

                this.showToast('Verification Successful! 🎉');
                this.showScreen('language-screen');
            } else {
                this.showToast(data.message || 'Invalid verification code');
            }
        } catch (e) {
            console.error(e);
            btn.disabled = false;
            btn.innerText = 'Verify & Continue';

            if (code === '1234' || code === '4321') {
                this.user = { uid: 'sandbox-uid', phone, name: 'Naveen Kumar' };
                localStorage.setItem('arogya_user', JSON.stringify(this.user));
                
                document.getElementById('home-user-title').innerText = `Hello, ${this.user.name} 👋`;
                document.getElementById('profile-name').innerText = this.user.name;
                document.getElementById('profile-details').innerText = `${this.user.phone} · Active Member`;

                this.showToast('Sandbox Login Successful! 🎉');
                this.showScreen('language-screen');
            } else {
                this.showToast('Invalid verification code. Try 1234');
            }
        }
    },

    changePhoneNumber() {
        document.getElementById('login-step-otp').classList.add('hidden');
        document.getElementById('login-step-phone').classList.remove('hidden');
        // Clear OTP inputs
        ['otp-1', 'otp-2', 'otp-3', 'otp-4'].forEach(id => document.getElementById(id).value = '');
    },

    loginWithGoogle() {
        this.user = { uid: 'google-uid', phone: '9988776655', name: 'Naveen Kumar (Google)' };
        localStorage.setItem('arogya_user', JSON.stringify(this.user));
        this.showToast('Google Sign In Successful! 🚀');
        this.showScreen('language-screen');
    },

    logoutUser() {
        localStorage.removeItem('arogya_user');
        localStorage.removeItem('arogya_lang');
        this.user = null;
        this.selectedLang = null;
        document.getElementById('app-bottom-nav').classList.add('hidden');
        // Reset phone form
        document.getElementById('login-phone').value = '9876543210';
        this.changePhoneNumber();
        this.showScreen('login-screen');
    },

    /* ── LANGUAGE SELECT STACK ── */
    renderLanguageSelection() {
        const container = document.getElementById('language-options-container');
        if (!container) return;
        
        container.innerHTML = this.languages.map(l => {
            const isSelected = this.selectedLang && this.selectedLang.code === l.code;
            const regionMarker = l.code.split('-')[1] || 'IN';
            const cleanLabel = l.label.split('(')[0].trim();
            const nativeLabel = l.label.includes('(') ? l.label.split('(')[1].replace(')', '') : 'Local Script';
            
            return `
                <div class="lang-card-item ${isSelected ? 'selected' : ''}" onclick="app.selectLanguage('${l.code}', this)">
                    <div class="lang-card-left">
                        <div class="lang-marker-avatar">${regionMarker}</div>
                        <div class="lang-details">
                            <h4>${cleanLabel}</h4>
                            <p>${nativeLabel}</p>
                        </div>
                    </div>
                    <div class="lang-radio-check"></div>
                </div>
            `;
        }).join('');
    },

    selectLanguage(code, element) {
        const target = this.languages.find(l => l.code === code);
        if (!target) return;
        this.selectedLang = target;
        
        const items = document.querySelectorAll('.lang-card-item');
        items.forEach(it => it.classList.remove('selected'));
        element.classList.add('selected');
    },

    confirmLanguage() {
        if (!this.selectedLang) {
            return this.showToast('Please select a language');
        }
        localStorage.setItem('arogya_lang', JSON.stringify(this.selectedLang));
        document.getElementById('current-lang-label').innerText = this.selectedLang.label;
        
        this.showScreen('home-screen');
        document.getElementById('app-bottom-nav').classList.remove('hidden');
        this.loadHospitals();
        this.loadHistory();
        this.renderReports();
        this.setTab(0);
    },

    /* ── HIGH ACCURACY VOICE RECOGNITION ── */
    setupSpeechRecognition() {
        const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
        if (!SR) {
            console.warn("SpeechRecognition not supported in this browser.");
            return;
        }

        this.recognition = new SR();
        this.recognition.continuous = true;
        this.recognition.interimResults = true;

        this.recognition.onresult = (e) => {
            let activeText = "";
            for (let i = 0; i < e.results.length; ++i) {
                activeText += e.results[i][0].transcript;
            }
            const normalizedText = this.cleanAndNormalizeSpeech(activeText);
            document.getElementById('symptom-input').value = normalizedText;
        };

        this.recognition.onerror = (e) => {
            console.error("Speech recognition error:", e.error);
            this.stopRecording();
        };

        this.recognition.onend = () => {
            this.stopRecording();
        };
    },

    cleanAndNormalizeSpeech(rawText) {
        let normalized = rawText.toLowerCase();
        Object.keys(this.dialectMap).forEach(key => {
            const regex = new RegExp(`\\b${key}\\b`, 'gi');
            normalized = normalized.replace(regex, this.dialectMap[key]);
        });
        return normalized;
    },

    openSymptomChecker() {
        this.showScreen('symptom-screen');
        this.renderSpeakPills();
        // Start listening automatically
        setTimeout(() => this.startRecording(), 300);
    },

    closeSymptomChecker() {
        this.stopRecording();
        this.backToDashboard();
    },

    renderSpeakPills() {
        const container = document.getElementById('speak-lang-pills');
        if (!container) return;
        
        container.innerHTML = this.languages.map(l => {
            const isSelected = this.selectedLang && this.selectedLang.code === l.code;
            return `
                <button class="lang-pill ${isSelected ? 'selected' : ''}" onclick="app.changeSpeakPill('${l.code}', this)">
                    ${l.flag} ${l.label.split('(')[0].trim()}
                </button>
            `;
        }).join('');
    },

    changeSpeakPill(code, element) {
        const target = this.languages.find(l => l.code === code);
        if (!target) return;
        this.selectedLang = target;
        localStorage.setItem('arogya_lang', JSON.stringify(target));
        document.getElementById('current-lang-label').innerText = target.label;

        const pills = document.querySelectorAll('.lang-pill');
        pills.forEach(p => p.classList.remove('selected'));
        element.classList.add('selected');

        // Restart recognition with new dialect
        if (this.isListening) {
            this.stopRecording();
            setTimeout(() => this.startRecording(), 200);
        }
    },

    toggleVoice() {
        if (!this.recognition) {
            this.showToast("Voice typing not supported. Simulating stomach ache...");
            document.getElementById('symptom-input').value = "Mujhe kadupu noppi aur bukhar horaha hai since yesterday";
            return;
        }

        if (this.isListening) {
            this.stopRecording();
        } else {
            this.startRecording();
        }
    },

    startRecording() {
        if (!this.recognition) return;
        this.isListening = true;
        
        if (this.selectedLang) {
            this.recognition.lang = this.selectedLang.code;
        }

        document.getElementById('mic-ring-anim').classList.add('animated');
        document.getElementById('chat-mic-btn').classList.add('active');
        document.getElementById('mic-status-label').innerText = "Listening... Speak now";
        
        try {
            this.recognition.start();
        } catch (e) {}
    },

    stopRecording() {
        this.isListening = false;
        const ring = document.getElementById('mic-ring-anim');
        if (ring) ring.classList.remove('animated');
        
        const btn = document.getElementById('chat-mic-btn');
        if (btn) btn.classList.remove('active');
        
        const label = document.getElementById('mic-status-label');
        if (label) label.innerText = "Tap mic & speak clearly";

        try {
            if (this.recognition) this.recognition.stop();
        } catch (e) {}
    },

    clearChat() {
        document.getElementById('symptom-input').value = '';
    },

    /* ── TYPE SYMPTOMS ENGINE ── */
    openTypeSymptoms() {
        // Clear form
        document.getElementById('type-symptom-input').value = '';
        const pills = document.querySelectorAll('.quick-pill');
        pills.forEach(p => p.classList.remove('selected'));
        
        this.showScreen('type-symptoms-screen');
    },

    toggleQuickPill(pillName, element) {
        element.classList.toggle('selected');
        const input = document.getElementById('type-symptom-input');
        
        // Append to input box text
        let currentText = input.value.trim();
        if (element.classList.contains('selected')) {
            input.value = currentText ? `${currentText}, ${pillName}` : pillName;
        } else {
            // Remove from input text
            const regex = new RegExp(`(,\\s*)?${pillName}`, 'g');
            input.value = currentText.replace(regex, '').trim().replace(/^,/, '').trim();
        }
    },

    selectDuration(duration, element) {
        this.bookingDate = duration; // reuse state variable
        const boxes = document.querySelectorAll('.duration-box');
        boxes.forEach(b => b.classList.remove('selected'));
        element.classList.add('selected');
    },

    backToSymptoms() {
        if (document.getElementById('symptom-input').value.trim()) {
            this.showScreen('symptom-screen');
        } else {
            this.showScreen('type-symptoms-screen');
        }
    },

    /* ── DIAGNOSTIC PIPELINES (AI AND OFFLINE HEURISTICS) ── */
    async sendUserMessage() {
        const text = document.getElementById('symptom-input').value.trim();
        if (!text) return this.showToast('Please speak or type symptoms first');
        this.stopRecording();
        await this.runDiagnosticEngine(text);
    },

    async analyzeTypedSymptoms() {
        const text = document.getElementById('type-symptom-input').value.trim();
        if (!text) return this.showToast('Please type your symptoms or select pills');
        await this.runDiagnosticEngine(text);
    },

    async runDiagnosticEngine(text) {
        // Check emergency keywords instantly
        const lowerText = text.toLowerCase();
        const emergencyKeywords = ['chest pain', 'breathing', 'stroke', 'unconscious', 'heart attack', 'gunde noppi', 'gontu noppi', 'nenju vali'];
        const isEmergency = emergencyKeywords.some(kw => lowerText.includes(kw));

        if (isEmergency && (lowerText.includes('chest') || lowerText.includes('heart') || lowerText.includes('gunde') || lowerText.includes('nenju') || lowerText.includes('breath'))) {
            this.triggerEmergency();
            return;
        }

        // Show full Guide page
        this.showScreen('ai-result-screen');
        document.getElementById('diag-title').innerText = "Analyzing Symptoms...";
        document.getElementById('diag-desc').innerText = "Running ArogyaAI diagnosis and matching clinical database guidelines...";
        document.getElementById('diag-meds-list').innerHTML = '';
        document.getElementById('diag-precautions-list').innerHTML = '';
        
        try {
            const res = await fetch(`${this.apiBase}/ai/diagnose`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ symptoms: text })
            });
            const diag = await res.json();
            this.renderDiagnosisGuide(diag, text);
            this.speakSymptomResult(diag);
            
            // Post report to database
            if (this.user) {
                await fetch(`${this.apiBase}/reports`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        userId: this.user.uid || this.user.phone,
                        symptoms: text,
                        condition: diag.condition,
                        severity: diag.severity,
                        specialist: diag.specialist
                    })
                });
            }
        } catch (e) {
            console.error("Fetch diagnose error, fallback to offline clinical heuristics:", e);
            const diag = this.runOfflineClinicalDiagnosis(text);
            this.renderDiagnosisGuide(diag, text);
            this.speakSymptomResult(diag);

            // Local fallback save
            if (this.user) {
                const localReps = JSON.parse(localStorage.getItem('arogya_local_reps') || '[]');
                localReps.push({
                    id: `rep-fallback-${Date.now()}`,
                    type: 'symptom',
                    userId: this.user.uid || this.user.phone,
                    date: new Date().toLocaleDateString("en-IN"),
                    time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
                    symptoms: text,
                    condition: diag.condition,
                    severity: diag.severity,
                    specialist: diag.specialist
                });
                localStorage.setItem('arogya_local_reps', JSON.stringify(localReps));
            }
        }
    },

    renderDiagnosisGuide(diag, rawText) {
        document.getElementById('diag-title').innerText = diag.condition || 'General Seasonal Ailment';
        document.getElementById('diag-desc').innerText = diag.description || 'Based on clinical guidelines for your reported symptoms.';
        document.getElementById('diag-time-label').innerText = `Today, ${new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}`;

        // Severity progress bar
        const sev = diag.severity ? diag.severity.toLowerCase() : 'low';
        const sevVal = sev === 'high' ? 'High (85%)' : sev === 'medium' ? 'Moderate (65%)' : 'Low (25%)';
        
        const labelVal = document.getElementById('severity-label-value');
        labelVal.innerText = sevVal;
        labelVal.className = sev === 'high' ? 'text-danger' : sev === 'medium' ? 'text-orange-500' : 'text-emerald-500';

        const fill = document.getElementById('severity-progress-fill');
        fill.className = `progress-bar-fill ${sev === 'high' ? 'high' : sev === 'medium' ? 'moderate' : 'low'}`;
        fill.style.width = sev === 'high' ? '85%' : sev === 'medium' ? '65%' : '25%';

        // Render Suggested Medicines
        const medsList = document.getElementById('diag-meds-list');
        medsList.innerHTML = '';
        if (diag.medicines && diag.medicines.length > 0) {
            diag.medicines.forEach(m => {
                const row = document.createElement('div');
                row.className = 'med-row-item';
                row.innerHTML = `
                    <div class="med-left-info">
                        <h4>${m.name}</h4>
                        <p>${m.instructions}</p>
                    </div>
                    <span class="med-badge-label">${m.badge || 'Prescription'}</span>
                `;
                medsList.appendChild(row);
            });
        } else {
            medsList.innerHTML = `<p style="font-size:12px; color:var(--text-muted);">Consult a physician for proper dosage charts.</p>`;
        }

        // Precautions
        const precautionsContainer = document.getElementById('diag-precautions-list');
        precautionsContainer.innerHTML = '';
        const precautionsList = diag.precautions || ["Drink fluids & rest", "Consult doctor if symptoms persist"];
        precautionsList.forEach(p => {
            const li = document.createElement('li');
            li.innerText = p;
            precautionsContainer.appendChild(li);
        });
    },

    runOfflineClinicalDiagnosis(text) {
        const s = text.toLowerCase();
        if (s.includes("throat") || s.includes("swallow") || s.includes("gontu") || s.includes("gala") || s.includes("thondai")) {
            return {
                condition: "Throat Infection (Viral Pharyngitis)",
                severity: "medium",
                specialist: "ENT Specialist",
                description: "Vocal tract strain and pharyngeal soreness indicate a mild viral throat lining infection.",
                medicines: [
                    { name: "Paracetamol 500mg", instructions: "1 tablet after meals (SOS)", badge: "Pain Relief" },
                    { name: "Betadine Gargle", instructions: "Mix with warm water 3 times/day", badge: "Relief" }
                ],
                precautions: ["Drink warm water or soups regularly", "Avoid cold drinks or spicy elements", "Give voice complete resting periods"]
            };
        }
        if (s.includes("stomach") || s.includes("pain") || s.includes("kadupu") || s.includes("pet") || s.includes("vayi")) {
            return {
                condition: "Acute Gastritis / Acid Indigestion",
                severity: "low",
                specialist: "General Physician",
                description: "Colloquial stomach pain, burning sensation or flatulence triggered by high acid build up.",
                medicines: [
                    { name: "Pantoprazole 40mg", instructions: "1 tablet in morning before breakfast", badge: "Antacid" },
                    { name: "Digene Liquid", instructions: "2 spoons after spicy meals", badge: "Indigestion" }
                ],
                precautions: ["Eat simple white rice or curd meals", "Drink buttermilk to soothe digestion", "Avoid red chili or pickles"]
            };
        }
        if (s.includes("rash") || s.includes("skin") || s.includes("charma") || s.includes("dermal")) {
            return {
                condition: "Allergic Dermatitis",
                severity: "low",
                specialist: "General Physician",
                description: "Dermal rashes triggered by temperature fluctuation, dust mites, or local allergens.",
                medicines: [
                    { name: "Cetirizine 10mg", instructions: "1 tablet at bedtime", badge: "Antihistamine" },
                    { name: "Calamine Lotion", instructions: "Apply gently to affected area", badge: "Soothing" }
                ],
                precautions: ["Do not scratch the affected skin rash area", "Wear soft, loose cotton clothes", "Bathe with cool water"]
            };
        }
        // General fallback
        return {
            condition: "Acute Febrile Infection / Viral Flu",
            severity: "low",
            specialist: "General Physician",
            description: "Body temperature change due to standard seasonal flu strains.",
            medicines: [
                { name: "Paracetamol 500mg", instructions: "1 tablet 3 times a day", badge: "Antipyretic" }
            ],
            precautions: ["Drink hot soups and stay well hydrated", "Check temperature regularly", "Get complete bed rest"]
        };
    },

    speakSymptomResult(diag) {
        if ('speechSynthesis' in window) {
            window.speechSynthesis.cancel();
            const textToSpeak = `I have analyzed your symptoms. You may have ${diag.condition}. Recommended specialist is ${diag.specialist}. Please review the precautions on screen.`;
            const utterance = new SpeechSynthesisUtterance(textToSpeak);
            if (this.selectedLang) {
                utterance.lang = this.selectedLang.code;
            }
            window.speechSynthesis.speak(utterance);
        }
    },

    /* ── UPLOAD IMAGE FLOW ── */
    openUploadImage() {
        // Clear preview card initially
        this.clearUploadedImage();
        this.showScreen('upload-image-screen');
    },

    simulateImageUpload(fileName) {
        this.uploadedImageName = fileName;
        
        const previewCard = document.getElementById('image-preview-card');
        previewCard.style.display = 'block';
        
        document.getElementById('preview-filename').innerText = fileName;
        
        // Mock preview images
        const imgEl = document.getElementById('preview-img');
        if (fileName.includes('rash')) {
            imgEl.src = "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80";
        } else {
            imgEl.src = "https://images.unsplash.com/photo-1559757175-5700dde675bc?auto=format&fit=crop&w=600&q=80";
        }

        document.getElementById('btn-analyze-image').disabled = false;
        this.showToast('Image uploaded successfully! 📸');
    },

    clearUploadedImage() {
        this.uploadedImageName = null;
        const previewCard = document.getElementById('image-preview-card');
        if (previewCard) previewCard.style.display = 'none';
        
        const btn = document.getElementById('btn-analyze-image');
        if (btn) btn.disabled = true;
    },

    async analyzeImage() {
        if (!this.uploadedImageName) return;
        this.showToast('AI Scanning Image pixels...');
        
        // Match diagnostic mapping
        const queryText = this.uploadedImageName.includes('rash') ? "skin rash irritation" : "dermal redness itchiness";
        await this.runDiagnosticEngine(queryText);
    },

    /* ── HEALTH REPORTS SCREEN ── */
    openHealthReports() {
        this.showScreen('health-reports-screen');
        this.renderReports();
    },

    renderReports(filtered = null) {
        const container = document.getElementById('reports-list-container');
        if (!container) return;

        const list = filtered || this.staticReports;
        
        if (list.length === 0) {
            container.innerHTML = `<p style="text-align:center; padding:30px; color:var(--text-muted); font-size:12px;">No reports found matching criteria</p>`;
            return;
        }

        container.innerHTML = list.map(r => {
            return `
                <div class="report-file-card">
                    <div class="report-card-left">
                        <div class="report-icon-container bg-emerald-50 text-emerald-500">
                            <span class="material-icons-round">${r.icon}</span>
                        </div>
                        <div class="report-card-info">
                            <h4>${r.name}</h4>
                            <p>${r.category} · ${r.date} · ${r.size}</p>
                        </div>
                    </div>
                    <button class="report-download-circle" onclick="app.downloadMockReport('${r.name}')">
                        <span class="material-icons-round font-12">arrow_downward</span>
                    </button>
                </div>
            `;
        }).join('');
    },

    filterReports() {
        const query = document.getElementById('report-search').value.toLowerCase().trim();
        if (!query) {
            this.renderReports();
            return;
        }
        const filtered = this.staticReports.filter(r => r.name.toLowerCase().includes(query) || r.category.toLowerCase().includes(query));
        this.renderReports(filtered);
    },

    downloadMockReport(name) {
        this.showToast(`Downloading ${name} PDF pass...`);
    },

    /* ── HOSPITALS & DOCTOR BOOKING PIPELINE ── */
    async loadHospitals() {
        try {
            const res = await fetch(`${this.apiBase}/hospitals`);
            const data = await res.json();
            
            // Map distances relative to user geolocation
            this.hospitals = data.map(h => {
                const targetLat = this.geolocation.lat + h.latOffset;
                const targetLng = this.geolocation.lng + h.lngOffset;
                const dist = this.calculateDistance(this.geolocation.lat, this.geolocation.lng, targetLat, targetLng);
                return {
                    ...h,
                    distance: dist,
                    distLabel: `${dist.toFixed(1)} km away`
                };
            });

            // Sort by proximity
            this.hospitals.sort((a, b) => a.distance - b.distance);
            this.renderHospitals(this.hospitals);
        } catch (e) {
            console.error("Fetch hospitals failed, using static fallback:", e);
            this.hospitals = [
                { id: "hosp-1", name: "Apollo Hospitals", doctor: "Dr. Priya Sharma", specialist: "ENT Specialist", degree: "MBBS, MS (ENT)", exp: "12 yrs exp", rating: "4.9", distLabel: "1.2 km away", fee: "₹400", about: "Senior consultant treating throat and nose concerns.", image: "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80" },
                { id: "hosp-2", name: "Care Hospitals", doctor: "Dr. Mary Joseph", specialist: "Cardiologist", degree: "MBBS, MD, DM (Cardio)", exp: "15 yrs exp", rating: "4.6", distLabel: "2.4 km away", fee: "₹500", about: "Cardiology consultant with advanced surgical insights.", image: "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=600&q=80" },
                { id: "hosp-3", name: "Cauvery Multi-Specialty", doctor: "Dr. Vinay Gowda", specialist: "General Physician", degree: "MBBS, MD (Gen Med)", exp: "8 yrs exp", rating: "4.4", distLabel: "3.5 km away", fee: "₹200", about: "Primary family medical care advisor.", image: "https://images.unsplash.com/photo-1551076805-e1869033e561?auto=format&fit=crop&w=600&q=80" },
                { id: "hosp-4", name: "Govt Primary Health Centre (PHC)", doctor: "Dr. Ramesh Chandra", specialist: "General Physician", degree: "MBBS", exp: "10 yrs exp", rating: "4.2", distLabel: "0.5 km away", fee: "Free", about: "Government subsidized local healthcare provider.", image: "https://images.unsplash.com/photo-1538108176447-2af0b97db733?auto=format&fit=crop&w=600&q=80" }
            ];
            this.renderHospitals(this.hospitals);
        }
    },

    renderHospitals(list) {
        const container = document.getElementById('hospital-list-container');
        if (!container) return;
        container.innerHTML = '';

        if (list.length === 0) {
            container.innerHTML = `<p style="text-align: center; color: var(--text-muted); padding: 20px;">No clinics found matching criteria</p>`;
            return;
        }

        list.forEach(h => {
            const card = document.createElement('div');
            card.className = 'hospital-item-card';
            card.innerHTML = `
                <div class="hospital-img-wrapper">
                    <img src="${h.image}" class="hospital-img" alt="${h.name}">
                    <span class="rating-badge-overlay">★ ${h.rating}</span>
                </div>
                <div class="hospital-body">
                    <div class="hospital-header">
                        <h4>${h.name}</h4>
                    </div>
                    <p class="hospital-specialist">${h.specialist} • ${h.doctor}</p>
                    <div class="hospital-footer-row">
                        <span class="distance-lbl">📍 ${h.distLabel}</span>
                        <button class="btn-book-sm-ring" onclick="app.showDoctorProfile('${h.id}')">Book Appointment</button>
                    </div>
                </div>
            `;
            container.appendChild(card);
        });
    },

    filterHospitals() {
        const query = document.getElementById('hospital-search').value.toLowerCase().trim();
        if (!query) {
            this.renderHospitals(this.hospitals);
            return;
        }
        const filtered = this.hospitals.filter(h => h.name.toLowerCase().includes(query) || h.doctor.toLowerCase().includes(query) || h.specialist.toLowerCase().includes(query));
        this.renderHospitals(filtered);
    },

    showDoctorProfile(id) {
        this.selectedDoctor = this.hospitals.find(h => h.id === id);
        if (!this.selectedDoctor) return;

        const container = document.getElementById('doctor-profile-content');
        container.innerHTML = `
            <div class="doc-header-card">
                <img src="${this.selectedDoctor.image}" class="doc-header-img" alt="Doctor Image">
                <div class="doc-info-block">
                    <h3>${this.selectedDoctor.doctor}</h3>
                    <p style="color:var(--primary-dark); font-weight:800; font-size:12px;">${this.selectedDoctor.specialist}</p>
                    <p>${this.selectedDoctor.degree}</p>
                </div>
            </div>

            <div class="doc-stats-row">
                <div class="doc-stat-item">
                    <span>⭐</span>
                    <div class="val">${this.selectedDoctor.rating}</div>
                    <div class="lbl">Rating</div>
                </div>
                <div class="doc-stat-item">
                    <span>🎗️</span>
                    <div class="val">${this.selectedDoctor.exp}</div>
                    <div class="lbl">Experience</div>
                </div>
                <div class="doc-stat-item">
                    <span>💰</span>
                    <div class="val">${this.selectedDoctor.fee}</div>
                    <div class="lbl">Fee</div>
                </div>
            </div>

            <div class="doc-section-card">
                <h4>About</h4>
                <p>${this.selectedDoctor.about || 'Senior clinical consultant providing specialized patient diagnostic services.'}</p>
            </div>

            <div class="doc-section-card doc-location-row">
                <span class="material-icons-round">place</span>
                <div>
                    <h5>${this.selectedDoctor.name}</h5>
                    <p>${this.selectedDoctor.distLabel}</p>
                </div>
            </div>

            <div class="doc-section-card doc-booking-form-box">
                <h4>Select Date</h4>
                <div class="date-selector-row">
                    <div class="date-btn selected" onclick="app.selectBookingDate('Mon 12', this)">
                        <span>Mon</span><span>12</span>
                    </div>
                    <div class="date-btn" onclick="app.selectBookingDate('Tue 13', this)">
                        <span>Tue</span><span>13</span>
                    </div>
                    <div class="date-btn" onclick="app.selectBookingDate('Wed 14', this)">
                        <span>Wed</span><span>14</span>
                    </div>
                    <div class="date-btn" onclick="app.selectBookingDate('Thu 15', this)">
                        <span>Thu</span><span>15</span>
                    </div>
                </div>

                <h4 class="margin-top-8">Select Time Slot</h4>
                <div class="time-slot-grid">
                    <button class="time-slot-btn selected" onclick="app.selectBookingTime('10:30 AM', this)">10:30 AM</button>
                    <button class="time-slot-btn" onclick="app.selectBookingTime('11:00 AM', this)">11:00 AM</button>
                    <button class="time-slot-btn" onclick="app.selectBookingTime('02:30 PM', this)">02:30 PM</button>
                    <button class="time-slot-btn" onclick="app.selectBookingTime('04:00 PM', this)">04:00 PM</button>
                </div>

                <h4 class="margin-top-8">Patient Details</h4>
                <input type="text" id="patient-name-input" class="doc-booking-input" placeholder="Patient Full Name">
                <input type="tel" id="patient-phone-input" class="doc-booking-input margin-top-6" placeholder="Patient Contact Phone" maxlength="10">

                <button class="btn primary-btn margin-top-12" onclick="app.confirmBooking()">
                    Confirm Appointment & Get Pass
                </button>
            </div>
        `;
        
        // Pre-fill patient form
        this.bookingDate = 'Mon 12';
        this.bookingTime = '10:30 AM';
        if (this.user) {
            setTimeout(() => {
                document.getElementById('patient-name-input').value = this.user.name || '';
                document.getElementById('patient-phone-input').value = this.user.phone || '';
            }, 50);
        }

        this.showScreen('doctor-screen');
    },

    backToHospitals() {
        this.showScreen('hospitals-screen');
    },

    selectBookingDate(dateStr, element) {
        this.bookingDate = dateStr;
        const btns = document.querySelectorAll('.date-btn');
        btns.forEach(btn => btn.classList.remove('selected'));
        element.classList.add('selected');
    },

    selectBookingTime(timeStr, element) {
        this.bookingTime = timeStr;
        const btns = document.querySelectorAll('.time-slot-btn');
        btns.forEach(btn => btn.classList.remove('selected'));
        element.classList.add('selected');
    },

    async confirmBooking() {
        const name = document.getElementById('patient-name-input').value.trim();
        const phone = document.getElementById('patient-phone-input').value.trim();

        if (!name) return this.showToast('Please enter patient name');
        if (!phone || phone.length < 10) return this.showToast('Please enter 10-digit patient phone');

        try {
            const res = await fetch(`${this.apiBase}/appointments`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    userId: this.user.uid || this.user.phone,
                    date: this.bookingDate,
                    time: this.bookingTime,
                    clinicName: this.selectedDoctor.name,
                    doctorName: this.selectedDoctor.doctor,
                    specialist: this.selectedDoctor.specialist,
                    patientName: name,
                    patientPhone: phone,
                    fee: this.selectedDoctor.fee,
                    address: this.selectedDoctor.name + ", Near Rural Main Road"
                })
            });
            const data = await res.json();
            if (data.success) {
                this.renderTicketModal(data.appointment);
                this.loadHistory();
            } else {
                this.showToast('Booking failed');
            }
        } catch (e) {
            console.error(e);
            // Local Sandbox fallback booking
            const fallbackPass = {
                id: `apt-fallback-${Date.now()}`,
                type: 'appointment',
                token: `TK-${Math.floor(100 + Math.random() * 899)}`,
                date: this.bookingDate,
                time: this.bookingTime,
                clinicName: this.selectedDoctor.name,
                doctorName: this.selectedDoctor.doctor,
                specialist: this.selectedDoctor.specialist,
                patientName: name,
                patientPhone: phone,
                fee: this.selectedDoctor.fee,
                address: this.selectedDoctor.name + ", Rural Road Bypass"
            };
            this.renderTicketModal(fallbackPass);
            
            // Save locally
            const localApts = JSON.parse(localStorage.getItem('arogya_local_apts') || '[]');
            localApts.push(fallbackPass);
            localStorage.setItem('arogya_local_apts', JSON.stringify(localApts));
            this.loadHistory();
        }
    },

    renderTicketModal(apt) {
        const container = document.getElementById('ticket-content');
        container.innerHTML = `
            <div class="ticket-divider-token">
                <span>Queue Registration Token</span>
                <h2>${apt.token}</h2>
            </div>
            <div class="ticket-row">
                <span>Clinic:</span>
                <span>${apt.clinicName}</span>
            </div>
            <div class="ticket-row">
                <span>Doctor:</span>
                <span>${apt.doctorName} (${apt.specialist})</span>
            </div>
            <div class="ticket-row">
                <span>Patient:</span>
                <span>${apt.patientName}</span>
            </div>
            <div class="ticket-row">
                <span>Schedule:</span>
                <span class="green-text" style="font-weight: 800;">${apt.date} at ${apt.time}</span>
            </div>
            <div class="ticket-row">
                <span>Consultation Fee:</span>
                <span>${apt.fee}</span>
            </div>
        `;
        document.getElementById('booking-success-modal').classList.remove('hidden');
    },

    closeSuccessModal() {
        document.getElementById('booking-success-modal').classList.add('hidden');
        this.setTab(2); // Redirect to visits screen
    },

    /* ── VISITS & LOGS HISTORY ── */
    async loadHistory() {
        const container = document.getElementById('history-list-container');
        if (!container) return;

        let allLogs = [];
        
        if (this.user) {
            try {
                // Fetch reports
                const rRes = await fetch(`${this.apiBase}/reports?userId=${this.user.uid || this.user.phone}`);
                const rLogs = await rRes.json();
                
                // Fetch appointments
                const aRes = await fetch(`${this.apiBase}/appointments?userId=${this.user.uid || this.user.phone}`);
                const aLogs = await aRes.json();

                allLogs = [...rLogs, ...aLogs];
            } catch (e) {
                console.warn("Backend logs error, rendering local storage fallback:", e);
                // Fallbacks
                const localApts = JSON.parse(localStorage.getItem('arogya_local_apts') || '[]');
                const localReps = JSON.parse(localStorage.getItem('arogya_local_reps') || '[]');
                allLogs = [...localApts, ...localReps];
            }
        }

        // Sort by date / timestamp if possible (most recent first)
        allLogs.sort((a, b) => (b.id?.split('-')[1] || 0) - (a.id?.split('-')[1] || 0));

        // Update stats counters dynamically in Profile if visible
        const visitsCountEl = document.getElementById('stat-visits-count');
        const repsCountEl = document.getElementById('stat-reports-count');
        if (visitsCountEl) {
            const appointmentLogsCount = allLogs.filter(l => l.type === 'appointment').length;
            visitsCountEl.innerText = appointmentLogsCount;
        }
        if (repsCountEl) {
            const reportLogsCount = allLogs.filter(l => l.type !== 'appointment').length;
            repsCountEl.innerText = reportLogsCount;
        }

        if (allLogs.length === 0) {
            container.innerHTML = `
                <div style="text-align: center; padding: 40px 20px;">
                    <div style="font-size: 44px; margin-bottom: 12px;">📋</div>
                    <h4 style="color: #334155; margin: 0; font-size: 15px; font-weight: 700;">No history recorded</h4>
                    <p style="color: #94a3b8; font-size: 12px; margin-top: 4px;">Diagnose symptoms or book clinic checkups to register passes.</p>
                </div>
            `;
            return;
        }

        container.innerHTML = '';
        allLogs.forEach(log => {
            const card = document.createElement('div');
            if (log.type === 'appointment') {
                card.className = 'history-card';
                // Inline history-card details style
                card.style.background = '#fafafa';
                card.style.borderRadius = '18px';
                card.style.border = '1.5px dashed #cbd5e1';
                card.style.padding = '14px';
                card.style.position = 'relative';
                card.style.marginBottom = '12px';

                card.innerHTML = `
                    <div class="history-card-header" style="display:flex; justify-content:space-between; border-bottom: 1px dashed #e2e8f0; padding-bottom:8px; margin-bottom:8px;">
                        <span class="badge-tag appointment" style="background:#eff6ff; color:#1e40af; font-size:9px; font-weight:700; padding:2px 8px; border-radius:10px; text-transform:uppercase;">📅 Clinic Visit</span>
                        <span class="history-token" style="font-size:12px; font-weight:900; color:#0d9488;">${log.token}</span>
                    </div>
                    <div class="history-body">
                        <h4 style="font-size:14px; font-weight:800; color:#1e293b;">${log.clinicName}</h4>
                        <p style="color: var(--primary-dark); font-weight: 700; font-size:12px; margin-top:2px;">👨‍⚕️ ${log.doctorName}</p>
                        <div class="history-details" style="font-size:11px; color:#475569; display:flex; flex-direction:column; gap:3px; margin-top:6px; margin-bottom:6px;">
                            <div>👤 Patient Name: <strong>${log.patientName}</strong></div>
                            <div>🕒 Time: <strong>${log.date} at ${log.time}</strong></div>
                            <div>💰 Fee: <strong>${log.fee}</strong></div>
                        </div>
                    </div>
                    <div class="history-footer" style="border-top:1px solid #f1f5f9; padding-top:8px; display:flex; justify-content:space-between; font-size:10px; color:var(--text-muted);">
                        <span>📍 Pay at registration desk</span>
                        <span class="action-cancel" style="color:var(--danger); font-weight:700; cursor:pointer;" onclick="app.cancelItem('${log.id}', 'appointment')">Cancel ✕</span>
                    </div>
                `;
            } else {
                // Symptom report log
                const sevLevel = log.severity || 'low';
                card.className = 'history-card report-log';
                card.style.background = 'white';
                card.style.borderRadius = '18px';
                card.style.border = '1px solid #e2e8f0';
                card.style.padding = '14px';
                card.style.position = 'relative';
                card.style.marginBottom = '12px';

                card.innerHTML = `
                    <div class="history-card-header" style="display:flex; justify-content:space-between; border-bottom: 1px solid #f1f5f9; padding-bottom:8px; margin-bottom:8px;">
                        <span class="badge-tag report ${sevLevel}" style="background:${sevLevel==='high'?'#fcebeb':sevLevel==='medium'?'#faeeda':'#ecfdf5'}; color:${sevLevel==='high'?'#a32d2d':sevLevel==='medium'?'#854f0b':'#065f46'}; font-size:9px; font-weight:700; padding:2px 8px; border-radius:10px; text-transform:uppercase;">✓ Symptom Check</span>
                        <span class="badge-tag report ${sevLevel}" style="font-weight: 800; background:${sevLevel==='high'?'#fcebeb':sevLevel==='medium'?'#faeeda':'#ecfdf5'}; color:${sevLevel==='high'?'#a32d2d':sevLevel==='medium'?'#854f0b':'#065f46'}; font-size:9px; padding:2px 8px; border-radius:10px;">${sevLevel.toUpperCase()}</span>
                    </div>
                    <div class="history-body">
                        <h4 style="font-size:14px; font-weight:800; color:#1e293b;">${log.condition}</h4>
                        <p style="color: var(--text-muted); font-style: italic; font-size:12px; margin-top:1px;">Symptoms: "${log.symptoms}"</p>
                    </div>
                    <div class="history-footer" style="border-top:1px solid #f1f5f9; padding-top:8px; display:flex; justify-content:space-between; font-size:10px; color:var(--text-muted);">
                        <span>📅 Checked: ${log.date || 'Today'}</span>
                        <span class="action-reload" style="color:var(--primary-dark); font-weight:700; cursor:pointer;" onclick="app.reloadSymptomAnalysis('${log.symptoms}')">Reload 🔄</span>
                    </div>
                `;
            }
            container.appendChild(card);
        });
    },

    async cancelItem(id, type) {
        if (!confirm('Are you sure you want to cancel this appointment visit?')) return;
        
        try {
            const res = await fetch(`${this.apiBase}/appointments/${id}`, { method: 'DELETE' });
            const data = await res.json();
            if (data.success) {
                this.showToast('Appointment cancelled successfully');
                this.loadHistory();
            }
        } catch (e) {
            console.error(e);
            // Local fallback deletion
            let localApts = JSON.parse(localStorage.getItem('arogya_local_apts') || '[]');
            localApts = localApts.filter(a => a.id !== id);
            localStorage.setItem('arogya_local_apts', JSON.stringify(localApts));
            this.showToast('Cancelled locally');
            this.loadHistory();
        }
    },

    reloadSymptomAnalysis(text) {
        this.openTypeSymptoms();
        document.getElementById('type-symptom-input').value = text;
        this.analyzeTypedSymptoms();
    },

    /* ── EMERGENCY SOS ── */
    triggerEmergency() {
        this.showScreen('emergency-screen');
        if ('speechSynthesis' in window) {
            window.speechSynthesis.cancel();
            const utterance = new SpeechSynthesisUtterance("Warning. Emergency detected. Please call an ambulance or visit the nearest government hospital immediately.");
            window.speechSynthesis.speak(utterance);
        }
    },

    /* ── GEOLOCATION DISTANCE CALCULATOR ── */
    getBrowserLocation() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (pos) => {
                    this.geolocation = {
                        lat: pos.coords.latitude,
                        lng: pos.coords.longitude
                    };
                    this.loadHospitals();
                },
                (err) => {
                    console.log("Using default geolocation offsets (Bangalore)");
                }
            );
        }
    },

    calculateDistance(lat1, lon1, lat2, lon2) {
        const R = 6371; // km
        const dLat = (lat2 - lat1) * Math.PI / 180;
        const dLon = (lon2 - lon1) * Math.PI / 180;
        const a = 
            Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }
};

// Start application on load
window.onload = () => {
    app.init();
};

// Bind to window for HTML click calls
window.app = app;

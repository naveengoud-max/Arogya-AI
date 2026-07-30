/* ==========================================================================
   ArogyaAI Official Firebase Modular Web SDK v10 Implementation
   ========================================================================== */

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js";
import {
  getAuth,
  RecaptchaVerifier,
  signInWithPhoneNumber,
  onAuthStateChanged,
  signOut
} from "https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js";
import {
  getFirestore,
  doc,
  getDoc,
  setDoc,
  updateDoc
} from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";

// Official Firebase Project Settings
const firebaseConfig = {
  apiKey: 'AIzaSyBp7LtL9l9U12-GWtGC8gsP7j8gjNddtJU',
  appId: '1:174786591628:web:789b8404e5628710cc74a9',
  messagingSenderId: '174786591628',
  projectId: 'arogyaai-78b7a',
  authDomain: 'arogyaai-78b7a.firebaseapp.com',
  storageBucket: 'arogyaai-78b7a.firebasestorage.app'
};

// Initialize Firebase App, Auth, and Firestore Database
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

window.firebaseApp = app;
window.firebaseAuth = auth;
window.firebaseDb = db;

console.log("[AUTH] Official Firebase Web SDK v10 Initialized for project:", firebaseConfig.projectId);

// Auth State Observer
onAuthStateChanged(auth, async (user) => {
  if (user) {
    console.log("[AUTH] Active session detected for UID:", user.uid);
    const profile = await syncFirestoreUserDoc(user);
    if (window.onFirebaseUserAuthenticated) {
      window.onFirebaseUserAuthenticated(user, profile);
    }
  } else {
    console.log("[AUTH] No active user session.");
  }
});

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

function showOtpNotice(msg) {
  let notice = document.getElementById('simulatedOtpNotice');
  if (!notice) {
    notice = document.createElement('p');
    notice.id = 'simulatedOtpNotice';
    notice.style.cssText = 'font-size: 0.85rem; color: #9A3412; font-weight: 700; margin-bottom: 1rem; background: #FFEDD5; padding: 0.6rem 0.8rem; border-radius: 8px; border: 1px solid #F97316; text-align: center;';
    const container = document.querySelector('.otp-input-container');
    if (container && container.parentNode) {
      container.parentNode.insertBefore(notice, container.nextSibling);
    }
  }
  if (notice) {
    notice.innerText = msg;
    notice.style.display = 'block';
  }
}

function hideOtpNotice() {
  const notice = document.getElementById('simulatedOtpNotice');
  if (notice) notice.style.display = 'none';
}

/**
 * Lazy Singleton RecaptchaVerifier Initializer
 */
function getRecaptchaVerifier() {
  if (window.appVerifier) {
    return window.appVerifier;
  }

  let container = document.getElementById("recaptcha-container");
  if (!container) {
    container = document.createElement("div");
    container.id = "recaptcha-container";
    document.body.appendChild(container);
  }

  const verifier = new RecaptchaVerifier(
    auth,
    "recaptcha-container",
    {
      size: "invisible",
      callback: (response) => {
        console.log("[AUTH] reCAPTCHA solved automatically");
      },
      'expired-callback': () => {
        console.warn("[AUTH] reCAPTCHA expired, resetting");
      }
    }
  );

  window.appVerifier = verifier;
  return verifier;
}

/**
 * Send OTP via Phone SMS
 */
window.handleSendOtp = async function () {
  console.log("[AUTH] handleSendOtp started");
  console.log("[AUTH] Starting OTP request");

  const phoneInput = document.getElementById('phoneInput');
  const phone = phoneInput ? phoneInput.value.trim() : '';

  if (!phone || phone.length < 10) {
    showAuthError('Please enter a valid 10-digit mobile number.');
    return;
  }

  hideAuthError();
  hideOtpNotice();
  const fullPhoneNumber = `+91${phone}`;

  console.log("[AUTH] Target Phone Number:", fullPhoneNumber);

  const btn = document.getElementById('btnSendOtp');
  if (btn) {
    btn.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> Dispatching SMS OTP...';
    btn.disabled = true;
  }

  window.lastOtpPhone = fullPhoneNumber;
  window.useBackendOtpFallback = false;

  try {
    // 1. Primary: Official Firebase Web SDK Phone Authentication
    const appVerifier = getRecaptchaVerifier();

    console.log("[AUTH] Calling signInWithPhoneNumber");
    console.log("[AUTH] Firebase request sent");

    const confirmationResult = await signInWithPhoneNumber(
      auth,
      fullPhoneNumber,
      appVerifier
    );

    window.confirmationResult = confirmationResult;

    console.log("[AUTH] confirmationResult received");
    console.log("[AUTH] Verification ID:", confirmationResult.verificationId);

    if (btn) {
      btn.innerHTML = '<i class="fa-solid fa-paper-plane"></i> Send Verification OTP';
      btn.disabled = false;
    }

    document.getElementById('phoneStep').style.display = 'none';
    document.getElementById('otpStep').style.display = 'block';

    if (window.startResendTimer) window.startResendTimer();
    setTimeout(() => document.getElementById('otp1')?.focus(), 200);

  } catch (error) {
    console.warn("[AUTH] Firebase Phone Auth response:", error.code, error.message);

    // If Firebase requires Cloud Billing (auth/billing-not-enabled), call backend SMS route
    try {
      const baseUrl = window.location.origin.includes('localhost') ? 'http://localhost:5000/api' : `${window.location.origin}/api`;
      const res = await fetch(`${baseUrl}/auth/send-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: fullPhoneNumber })
      });
      const data = await res.json();

      if (data.success) {
        window.useBackendOtpFallback = true;
        console.log("[AUTH SMS GATEWAY] OTP dispatch response:", data);

        // If physical SMS delivery was blocked by carrier (no API key in .env), show notice so user isn't stuck
        if (!data.delivered && data.code) {
          showOtpNotice(`⚠️ Mobile Carrier Blocked Free SMS. Use Code: ${data.code}`);
        }

        if (btn) {
          btn.innerHTML = '<i class="fa-solid fa-paper-plane"></i> Send Verification OTP';
          btn.disabled = false;
        }

        document.getElementById('phoneStep').style.display = 'none';
        document.getElementById('otpStep').style.display = 'block';

        if (window.startResendTimer) window.startResendTimer();
        setTimeout(() => document.getElementById('otp1')?.focus(), 200);
        return;
      }
    } catch (fallbackErr) {
      console.error("[AUTH SMS GATEWAY ERROR]:", fallbackErr);
    }

    let userMsg = error.message || 'Phone Authentication failed.';
    if (error.code === 'auth/unauthorized-domain') {
      userMsg = `Domain (${window.location.hostname}) is not authorized in Firebase Console.`;
    }

    showAuthError(`Auth Error: ${userMsg}`);

    if (btn) {
      btn.innerHTML = '<i class="fa-solid fa-paper-plane"></i> Send Verification OTP';
      btn.disabled = false;
    }
  }
};

/**
 * Handle Verify OTP
 */
window.handleVerifyOtp = async function () {
  let enteredOtp = '';
  for (let i = 1; i <= 6; i++) {
    const box = document.getElementById(`otp${i}`);
    if (box) enteredOtp += box.value;
  }

  if (enteredOtp.length < 6) {
    showAuthError('Please enter the complete 6-digit OTP code.');
    return;
  }

  hideAuthError();
  const btn = document.getElementById('btnVerifyOtp');
  if (btn) {
    btn.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> Verifying...';
    btn.disabled = true;
  }

  try {
    if (window.useBackendOtpFallback || !window.confirmationResult) {
      const baseUrl = window.location.origin.includes('localhost') ? 'http://localhost:5000/api' : `${window.location.origin}/api`;
      const res = await fetch(`${baseUrl}/auth/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: window.lastOtpPhone || '', code: enteredOtp })
      });
      const data = await res.json();
      if (!data.success) throw new Error(data.message || 'Invalid OTP code');

      const user = { uid: data.user.uid, phoneNumber: data.user.phone, displayName: data.user.name };
      const profile = await syncFirestoreUserDoc(user);

      if (btn) {
        btn.innerHTML = '<i class="fa-solid fa-circle-check"></i> Verify & Sign In';
        btn.disabled = false;
      }

      if (window.onFirebaseUserAuthenticated) {
        window.onFirebaseUserAuthenticated(user, profile);
      }

      if (window.navigateTo) {
        window.navigateTo('dashboard');
      }
      return;
    }

    console.log("[AUTH] Confirming OTP with Firebase confirmationResult.confirm(otp)...");
    const userCredential = await window.confirmationResult.confirm(enteredOtp);
    const user = userCredential.user;

    console.log("[AUTH] OTP verification success for UID:", user.uid);
    const profile = await syncFirestoreUserDoc(user);

    if (btn) {
      btn.innerHTML = '<i class="fa-solid fa-circle-check"></i> Verify & Sign In';
      btn.disabled = false;
    }

    if (window.onFirebaseUserAuthenticated) {
      window.onFirebaseUserAuthenticated(user, profile);
    }

    if (window.navigateTo) {
      window.navigateTo('dashboard');
    }

  } catch (error) {
    console.error("[AUTH] Verification Error:", error);
    showAuthError(`Verification Failed: ${error.message || 'Invalid OTP code.'}`);
    if (btn) {
      btn.innerHTML = '<i class="fa-solid fa-circle-check"></i> Verify & Sign In';
      btn.disabled = false;
    }
  }
};

/**
 * Store user document in Firestore (users collection, doc ID = UID)
 */
export async function syncFirestoreUserDoc(user, language = 'English') {
  const now = new Date().toISOString();
  const userRef = doc(db, "users", user.uid);

  try {
    const snap = await getDoc(userRef);
    let userData = {};

    if (snap.exists()) {
      const existing = snap.data();
      userData = {
        uid: user.uid,
        phoneNumber: user.phoneNumber || existing.phoneNumber || '',
        createdAt: existing.createdAt || now,
        lastLogin: now,
        displayName: existing.displayName || user.displayName || 'Arogya User',
        language: existing.language || language,
        profileCompleted: existing.profileCompleted || false,
        photoURL: user.photoURL || existing.photoURL || ''
      };

      await updateDoc(userRef, { lastLogin: now });
      console.log("[FIRESTORE] Updated lastLogin for user UID:", user.uid);

    } else {
      userData = {
        uid: user.uid,
        phoneNumber: user.phoneNumber || '',
        createdAt: now,
        lastLogin: now,
        displayName: user.displayName || 'Arogya User',
        language: language,
        profileCompleted: false,
        photoURL: user.photoURL || ''
      };

      await setDoc(userRef, userData);
      console.log("[FIRESTORE] Created new user doc for UID:", user.uid);
    }

    return userData;

  } catch (e) {
    console.error("[AUTH] Firebase error during Firestore sync:", e);
    return {
      uid: user.uid,
      phoneNumber: user.phoneNumber || '',
      createdAt: now,
      lastLogin: now,
      displayName: 'Arogya User',
      language: language,
      profileCompleted: false,
      photoURL: ''
    };
  }
}

/**
 * Logout User
 */
export async function logoutFirebaseUser() {
  try {
    await signOut(auth);
    console.log("[AUTH] Signed out successfully.");
  } catch (e) {
    console.error("[AUTH] Firebase error during signOut:", e);
  }
}

window.firebaseService = {
  sendFirebasePhoneOtp: window.handleSendOtp,
  verifyFirebasePhoneOtp: window.handleVerifyOtp,
  syncFirestoreUserDoc,
  logoutFirebaseUser
};

// Direct DOM Event Binding for Auth Buttons
if (document.readyState === 'loading') {
  document.addEventListener("DOMContentLoaded", bindAuthButtons);
} else {
  bindAuthButtons();
}

function bindAuthButtons() {
  const sendBtn = document.getElementById("btnSendOtp");
  if (sendBtn) {
    sendBtn.addEventListener("click", (e) => {
      e.preventDefault();
      console.log("[AUTH] #btnSendOtp clicked via direct event listener");
      window.handleSendOtp();
    });
  }

  const verifyBtn = document.getElementById("btnVerifyOtp");
  if (verifyBtn) {
    verifyBtn.addEventListener("click", (e) => {
      e.preventDefault();
      console.log("[AUTH] #btnVerifyOtp clicked via direct event listener");
      window.handleVerifyOtp();
    });
  }
}

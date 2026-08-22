/* ==========================================================================
   ArogyaAI Production Firebase Modular Web SDK v10 Implementation
   Google Sign-In & Complete Firestore Collection Services
   ========================================================================== */

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js";
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signInWithRedirect,
  getRedirectResult,
  onAuthStateChanged,
  signOut
} from "https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js";
import {
  getFirestore,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  collection,
  getDocs,
  addDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  onSnapshot
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

// Initialize Firebase Services
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

window.firebaseApp = app;
window.firebaseAuth = auth;
window.firebaseDb = db;

console.log("[AUTH] ArogyaAI Production Firebase Web SDK v10 Initialized:", firebaseConfig.projectId);

// Auth State Observer
onAuthStateChanged(auth, async (user) => {
  if (user) {
    console.log("[AUTH LOG STEP 1] Active Firebase Session found for Google UID:", user.uid, "Email:", user.email);
    const profile = await syncFirestoreUserDoc(user);
    if (window.onFirebaseUserAuthenticated) {
      console.log("[AUTH LOG STEP 2] Triggering onFirebaseUserAuthenticated callback...");
      window.onFirebaseUserAuthenticated(user, profile);
    }
  } else {
    console.log("[AUTH LOG STEP 1] No active Firebase session detected.");
    if (window.onFirebaseUserSignedOut) {
      window.onFirebaseUserSignedOut();
    }
  }
});

// Check redirect result on load
getRedirectResult(auth).then(async (result) => {
  if (result && result.user) {
    console.log("[AUTH LOG REDIRECT] Google Redirect Sign-In Success:", result.user.email);
    const profile = await syncFirestoreUserDoc(result.user);
    if (window.onFirebaseUserAuthenticated) {
      window.onFirebaseUserAuthenticated(result.user, profile);
    }
  }
}).catch((err) => {
  console.warn("[AUTH LOG REDIRECT] Redirect Sign-In Notice:", err.message);
});

/**
 * Handle Google Sign-In Authentication
 */
export async function signInWithGoogle() {
  const provider = new GoogleAuthProvider();
  provider.addScope('profile');
  provider.addScope('email');

  const btn = document.getElementById('btnGoogleSignIn');
  if (btn) {
    btn.disabled = true;
    btn.innerHTML = '<i class="fa-solid fa-circle-notch fa-spin"></i> Signing in with Google...';
  }

  console.log("[AUTH LOG START] Initiating signInWithPopup with GoogleAuthProvider...");

  try {
    const result = await signInWithPopup(auth, provider);
    const user = result.user;
    console.log("[AUTH LOG POPUP SUCCESS] Google Sign-In completed for:", user.displayName, user.email, "UID:", user.uid);

    const profile = await syncFirestoreUserDoc(user);
    
    if (btn) {
      btn.disabled = false;
      btn.innerHTML = '<i class="fa-brands fa-google"></i> Continue with Google';
    }

    if (window.onFirebaseUserAuthenticated) {
      console.log("[AUTH LOG REDIRECT] Dispatching authenticated user to SPA router...");
      window.onFirebaseUserAuthenticated(user, profile);
    }
    return { user, profile };
  } catch (error) {
    console.warn("[AUTH LOG POPUP NOTICE] Popup sign-in error or closed:", error.code, error.message);
    if (btn) {
      btn.disabled = false;
      btn.innerHTML = '<i class="fa-brands fa-google"></i> Continue with Google';
    }

    if (error.code === 'auth/popup-closed-by-user' || error.code === 'auth/cancelled-popup-request') {
      console.log("[AUTH LOG NOTICE] Popup closed by user.");
      return;
    }

    try {
      console.log("[AUTH LOG REDIRECT] Attempting signInWithRedirect fallback...");
      await signInWithRedirect(auth, provider);
    } catch (redirectErr) {
      console.error("[AUTH LOG ERROR] Google Sign-In Redirect Error:", redirectErr);
      showAuthError(`Google Sign-In Notice: ${redirectErr.message || 'Domain check pending'}`);
    }
  }
}

/**
 * Sync / Create User document in Firestore
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
        name: user.displayName || existing.name || 'Arogya Patient',
        email: user.email || existing.email || '',
        photoURL: user.photoURL || existing.photoURL || 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=150',
        language: existing.language || language,
        createdAt: existing.createdAt || now,
        lastLogin: now,
        device: navigator.userAgent || 'Web Browser',
        profileCompleted: existing.profileCompleted ?? true
      };

      await updateDoc(userRef, { lastLogin: now, photoURL: userData.photoURL });
      console.log("[FIRESTORE] Updated user doc for UID:", user.uid);

    } else {
      userData = {
        uid: user.uid,
        name: user.displayName || 'Arogya Patient',
        email: user.email || '',
        photoURL: user.photoURL || 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=150',
        language: language,
        createdAt: now,
        lastLogin: now,
        loginProvider: 'google.com',
        device: navigator.userAgent || 'Web Browser',
        profileCompleted: true
      };

      await setDoc(userRef, userData);
      console.log("[FIRESTORE] Created new user doc for UID:", user.uid);
    }

    // Trigger automatic Cloud Firestore seeding if empty
    autoSeedFirestore();

    return userData;

  } catch (e) {
    console.error("[AUTH] Firestore Sync Error:", e);
    return {
      uid: user.uid,
      name: user.displayName || 'Arogya Patient',
      email: user.email || '',
      photoURL: user.photoURL || '',
      language: language,
      createdAt: now,
      lastLogin: now,
      loginProvider: 'google.com',
      device: 'Web',
      profileCompleted: true
    };
  }
}

/**
 * Automatic Cloud Firestore Seeding Service for Hospitals, Doctors, Appointments, Visits, etc.
 */
export async function autoSeedFirestore() {
  try {
    const checkSnap = await getDocs(collection(db, "hospitals"));
    if (checkSnap.size >= 50) {
      console.log("[AUTO SEED] Cloud Firestore already populated with", checkSnap.size, "hospitals.");
      return;
    }

    console.log("[AUTO SEED] Seeding 60+ hospitals and 9 collections into Cloud Firestore...");

    const cities = [
      { name: "Chennai", lat: 13.0827, lng: 80.2707, phonePrefix: "044" },
      { name: "Hyderabad", lat: 17.3850, lng: 78.4867, phonePrefix: "040" },
      { name: "Bangalore", lat: 12.9716, lng: 77.5946, phonePrefix: "080" }
    ];

    const hospitalNames = [
      "Apollo Multi-Specialty Hospital", "Fortis Super Specialty Hospital", "Manipal Healthcare Centre",
      "Cauvery Specialty Hospital", "Max Super Specialty Hospital", "KIMS Super Specialty Institute",
      "Yashoda Healthcare Centre", "Care Heart & General Hospital", "Gleneagles Global Hospital",
      "MGM Healthcare Institute", "Sims Super Specialty Hospital", "Rajiv Gandhi Govt Hospital",
      "Govt Primary Health Center", "Rainbow Children's Hospital", "Continental Multi-Specialty",
      "Narayana Health City", "Aster CMI Specialty Hospital", "Columbia Asia Healthcare",
      "St. John's Medical Center", "Sunshine General Hospital"
    ];

    const specialists = [
      { doc: "Dr. Priya Sharma", spec: "ENT Specialist", deg: "MBBS, MS (ENT)" },
      { doc: "Dr. Mary Joseph", spec: "Cardiologist", deg: "MBBS, MD, DM" },
      { doc: "Dr. Vinay Gowda", spec: "General Physician", deg: "MBBS, MD" },
      { doc: "Dr. Rajesh Shah", spec: "Neurologist", deg: "MBBS, DM (Neuro)" },
      { doc: "Dr. Ananya Reddy", spec: "Pediatrician", deg: "MBBS, DCH" }
    ];

    for (let c of cities) {
      for (let i = 0; i < 20; i++) {
        const hName = `${c.name} ${hospitalNames[i]}`;
        const specObj = specialists[i % specialists.length];
        const docId = `hosp-${c.name.toLowerCase()}-${i+1}`;
        const latOffset = (Math.random() - 0.5) * 0.08;
        const lngOffset = (Math.random() - 0.5) * 0.08;

        await setDoc(doc(db, "hospitals", docId), {
          id: docId,
          name: hName,
          city: c.name,
          doctor: specObj.doc,
          specialist: specObj.spec,
          degree: specObj.deg,
          exp: `${10 + (i % 10)} yrs exp`,
          rating: parseFloat((4.2 + (i % 8) * 0.1).toFixed(1)),
          fee: i % 4 === 0 ? "Free" : `₹${300 + (i % 5) * 100}`,
          phone: `${c.phonePrefix}-${23000000 + i * 1111}`,
          address: `Block ${i + 1}, Main Road, ${c.name}, India`,
          lat: parseFloat((c.lat + latOffset).toFixed(4)),
          lng: parseFloat((c.lng + lngOffset).toFixed(4)),
          image: "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80",
          type: i % 4 === 0 ? "govt" : "private"
        });
      }
    }

    // Seed doctors collection
    for (let i = 0; i < 10; i++) {
      const specObj = specialists[i % specialists.length];
      await setDoc(doc(db, "doctors", `doc-${i+1}`), {
        id: `doc-${i+1}`,
        name: specObj.doc,
        speciality: specObj.spec,
        degree: specObj.deg,
        rating: 4.8,
        fee: "₹400",
        phone: "044-28290200"
      });
    }

    // Seed initial appointments & visits
    await setDoc(doc(db, "appointments", "appt-demo-1"), {
      id: "appt-demo-1",
      userId: "demo-user",
      doctorName: "Dr. Priya Sharma",
      clinicName: "Apollo Hospitals Greams Road",
      date: "2026-08-10",
      time: "10:30 AM",
      token: "TK-901",
      status: "Upcoming",
      createdAt: new Date().toISOString()
    });

    await setDoc(doc(db, "visits", "visit-demo-1"), {
      id: "visit-demo-1",
      userId: "demo-user",
      doctorName: "Dr. Mary Joseph",
      clinicName: "Fortis Malar Hospital",
      date: "2026-07-20",
      diagnosis: "General Cardiovascular Screening",
      status: "Completed",
      createdAt: new Date().toISOString()
    });

    // Seed health_scores
    await setDoc(doc(db, "health_scores", "score-demo-1"), {
      id: "score-demo-1",
      userId: "demo-user",
      bmi: 22.8,
      score: 82,
      riskStatus: "Optimal Risk",
      heightCm: 175,
      weightKg: 70,
      calculatedAt: new Date().toISOString()
    });

    // Seed chat_history
    await setDoc(doc(db, "chat_history", "chat-demo-1"), {
      id: "chat-demo-1",
      userId: "demo-user",
      userMessage: "What is a good diet for throat soreness?",
      botReply: "Drink warm salt water, ginger tea with honey, and soft soups. Avoid cold beverages. *Disclaimer: Informational only, not professional medical advice.*",
      createdAt: new Date().toISOString()
    });

    // Seed symptom_history
    await setDoc(doc(db, "symptom_history", "sym-demo-1"), {
      id: "sym-demo-1",
      userId: "demo-user",
      symptoms: "Mild fever and throat irritation",
      condition: "Viral Pharyngitis",
      severity: "medium",
      createdAt: new Date().toISOString()
    });

    // Seed notifications
    await setDoc(doc(db, "notifications", "notif-demo-1"), {
      id: "notif-demo-1",
      userId: "demo-user",
      title: "Welcome to ArogyaAI",
      message: "Your intelligent healthcare companion is ready. Search nearby clinics or ask AI chatbot.",
      read: false,
      createdAt: new Date().toISOString()
    });

    console.log("[AUTO SEED] ✅ Cloud Firestore automatically populated with 60+ hospitals and 9 collections!");
  } catch (e) {
    console.error("[AUTO SEED] Error seeding Firestore:", e);
  }
}

/**
 * Logout User
 */
export async function logoutFirebaseUser() {
  try {
    await signOut(auth);
    console.log("[AUTH] User signed out successfully.");
  } catch (e) {
    console.error("[AUTH] Sign Out Error:", e);
  }
}

function showAuthError(msg) {
  const alertBox = document.getElementById('authErrorAlert');
  if (alertBox) {
    if (msg.includes('auth/unauthorized-domain')) {
      const host = window.location.hostname;
      alertBox.innerHTML = `Google Sign-In Notice: Domain <strong>${host}</strong> is not authorized in Firebase Console.<br><br>👉 Tap <strong>"Instant Demo Patient Login"</strong> below to enter immediately, or add <code>${host}</code> to Authorized Domains in Firebase Console.`;
    } else {
      alertBox.innerText = msg;
    }
    alertBox.style.display = 'block';
  }
}

/* ==========================================================================
   Firestore Collection Data Services (Hospitals, Doctors, Appointments, etc)
   ========================================================================== */

export async function fetchCollection(collName) {
  try {
    const snap = await getDocs(collection(db, collName));
    const items = [];
    snap.forEach(d => items.push({ id: d.id, ...d.data() }));
    return items;
  } catch (e) {
    console.warn(`[FIRESTORE] Fetch collection ${collName} warning:`, e);
    return [];
  }
}

export async function addDocument(collName, data) {
  try {
    const docRef = await addDoc(collection(db, collName), {
      ...data,
      createdAt: new Date().toISOString()
    });
    return { id: docRef.id, ...data };
  } catch (e) {
    console.error(`[FIRESTORE] Add document to ${collName} failed:`, e);
    throw e;
  }
}

export async function updateDocument(collName, docId, data) {
  try {
    const docRef = doc(db, collName, docId);
    await updateDoc(docRef, { ...data, updatedAt: new Date().toISOString() });
    return true;
  } catch (e) {
    console.error(`[FIRESTORE] Update doc ${docId} in ${collName} failed:`, e);
    throw e;
  }
}

export async function deleteDocument(collName, docId) {
  try {
    await deleteDoc(doc(db, collName, docId));
    return true;
  } catch (e) {
    console.error(`[FIRESTORE] Delete doc ${docId} in ${collName} failed:`, e);
    throw e;
  }
}

export function subscribeCollection(collName, callback) {
  try {
    return onSnapshot(collection(db, collName), (snap) => {
      const items = [];
      snap.forEach(d => items.push({ id: d.id, ...d.data() }));
      callback(items);
    }, (err) => {
      console.warn(`[FIRESTORE] Realtime stream notice for ${collName}:`, err);
    });
  } catch (e) {
    console.error(`[FIRESTORE] Subscribe ${collName} error:`, e);
    return () => {};
  }
}

// Global Export mapping
window.signInWithGoogle = signInWithGoogle;
window.logoutFirebaseUser = logoutFirebaseUser;
window.syncFirestoreUserDoc = syncFirestoreUserDoc;
window.firestoreService = {
  fetchCollection,
  subscribeCollection,
  addDocument,
  updateDocument,
  deleteDocument
};

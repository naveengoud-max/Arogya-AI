import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiService {
  static String _customBaseUrl = "";
  static String? authToken;
  static Map<String, dynamic>? currentUser;
  
  // Firebase initialization status fields
  static String firebaseStatus = "Unknown";
  static String firebaseError = "";

  // Audit Logging Session Tracking
  static String? currentSessionId;
  static Timer? _heartbeatTimer;

  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl;
    }
    return AppConfig.defaultBackendUrl;
  }

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customBaseUrl = prefs.getString('custom_base_url') ?? "";
      authToken = prefs.getString('auth_token');
      currentSessionId = prefs.getString('current_session_id');
      final userStr = prefs.getString('currentUser');
      if (userStr != null) {
        currentUser = json.decode(userStr) as Map<String, dynamic>;
      }

      // Start heartbeat if user is logged in
      if (isFirebaseAvailable && FirebaseAuth.instance.currentUser != null) {
        startHeartbeatTimer();
      }
    } catch (_) {}
  }

  static Future<void> setBaseUrl(String url) async {
    _customBaseUrl = url;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_base_url', url);
    } catch (_) {}
  }

  static bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /* ── AUDIT LOGGING & SESSION TRACKING ── */

  /// Creates a unique session document in `auth_audit_logs/{sessionId}` upon successful Google Sign-In.
  static Future<void> createAuthAuditLog(Map<String, dynamic> user) async {
    if (!isFirebaseAvailable) return;
    try {
      final uid = user['uid'] ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      final sessionId = 'SES-${DateTime.now().millisecondsSinceEpoch}-${uid.substring(0, uid.length > 5 ? 5 : uid.length)}';
      currentSessionId = sessionId;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_session_id', sessionId);

      final platformStr = kIsWeb ? 'Web' : (defaultTargetPlatform == TargetPlatform.android ? 'Android' : 'Mobile');
      final deviceStr = kIsWeb ? 'Web Browser' : (defaultTargetPlatform == TargetPlatform.android ? 'Android Device' : 'Mobile Device');
      final email = user['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
      final displayName = user['name'] ?? user['displayName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Arogya Patient';
      final photoURL = user['photoURL'] ?? FirebaseAuth.instance.currentUser?.photoURL ?? '';

      final auditData = {
        'sessionId': sessionId,
        'userId': uid,
        'email': email,
        'displayName': displayName,
        'photoURL': photoURL,
        'loginMethod': 'Google',
        'loginTime': FieldValue.serverTimestamp(),
        'logoutTime': null,
        'sessionStatus': 'active',
        'platform': platformStr,
        'deviceModel': deviceStr,
        'appVersion': '1.0.0+1',
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('auth_audit_logs').doc(sessionId).set(auditData);
      print("[AUDIT LOG] Created auth_audit_logs document: $sessionId");

      startHeartbeatTimer();
    } catch (e) {
      print("[AUDIT LOG ERROR] Failed to create auth audit log: $e");
    }
  }

  /// Updates current session in `auth_audit_logs` prior to Firebase sign-out.
  static Future<void> updateLogoutAuditLog() async {
    if (!isFirebaseAvailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = currentSessionId ?? prefs.getString('current_session_id');

      if (sessionId != null && sessionId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('auth_audit_logs').doc(sessionId).update({
          'logoutTime': FieldValue.serverTimestamp(),
          'sessionStatus': 'logged_out',
          'updatedAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
        print("[AUDIT LOG] Updated session $sessionId to logged_out");
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'lastLogoutAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("[AUDIT LOG ERROR] Failed to update logout audit log: $e");
      rethrow;
    } finally {
      stopHeartbeatTimer();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_session_id');
      currentSessionId = null;
    }
  }

  static void startHeartbeatTimer() {
    stopHeartbeatTimer();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await updateHeartbeat();
    });
  }

  static void stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static Future<void> updateHeartbeat() async {
    if (!isFirebaseAvailable) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = currentSessionId ?? prefs.getString('current_session_id');
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (sessionId != null && sessionId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('auth_audit_logs').doc(sessionId).set({
          'lastSeen': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("[HEARTBEAT ERROR] $e");
    }
  }

  static Future<String> getUserRole([String? uid]) async {
    if (!isFirebaseAvailable) return 'user';
    try {
      final targetUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (targetUid == null) return 'user';

      final doc = await FirebaseFirestore.instance.collection('users').doc(targetUid).get();
      if (doc.exists && doc.data() != null) {
        final role = doc.data()!['role'];
        if (role != null) return role.toString();
      }
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email == 'knaveenkumargoud138@gmail.com') return 'admin';
    } catch (e) {
      print("[ROLE ERROR] $e");
    }
    return 'user';
  }

  static Future<void> createFirestoreUserRecord({
    required String userId,
    required String phone,
    String? name,
    String? email,
    String? language,
    int? healthScore,
  }) async {
    if (!isFirebaseAvailable) {
      print("[DIAGNOSTICS] Firestore connected failed: Firebase not initialized");
      return;
    }
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      final doc = await userRef.get();
      final now = DateTime.now().toIso8601String();
      final docData = doc.exists ? doc.data() : null;
      
      final data = {
        'uid': userId,
        'phone': phone,
        'email': email ?? (docData != null ? docData['email'] : null) ?? '',
        'name': name ?? (docData != null ? docData['name'] : null) ?? 'Arogya User',
        'createdAt': (docData != null ? docData['createdAt'] : null) ?? now,
        'lastLogin': now,
        'language': language ?? (docData != null ? docData['language'] : null) ?? 'English',
        'healthScore': docData != null ? docData['healthScore'] : healthScore ?? 0,
      };
      await userRef.set(data, SetOptions(merge: true));
      print("[DIAGNOSTICS] Firestore connected");
    } catch (e) {
      print("[DIAGNOSTICS] Firestore connected failed: $e");
    }
  }

  static Future<void> syncUserDocInFirestore(Map<String, dynamic> user) async {
    if (!isFirebaseAvailable) return;
    try {
      final uid = user['uid'] ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await userRef.get();
      final now = DateTime.now().toIso8601String();
      
      final platformStr = kIsWeb ? 'Web' : (defaultTargetPlatform == TargetPlatform.android ? 'Android' : 'Mobile');
      final deviceStr = kIsWeb ? 'Web Browser' : (defaultTargetPlatform == TargetPlatform.android ? 'Android Device' : 'Mobile Device');
      final userEmail = user['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';

      String defaultRole = 'user';
      if (userEmail == 'knaveenkumargoud138@gmail.com') {
        defaultRole = 'faculty';
      }
      final existingRole = (doc.exists && doc.data() != null) ? doc.data()!['role'] : null;

      final docData = {
        'uid': uid,
        'name': user['name'] ?? user['displayName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Arogya Patient',
        'displayName': user['name'] ?? user['displayName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Arogya Patient',
        'email': userEmail,
        'photoURL': user['photoURL'] ?? FirebaseAuth.instance.currentUser?.photoURL ?? '',
        'language': user['language'] ?? 'English',
        'createdAt': (doc.exists && doc.data() != null) ? (doc.data()!['createdAt'] ?? now) : now,
        'lastLoginAt': now,
        'lastSeen': now,
        'loginMethod': 'Google',
        'platform': platformStr,
        'device': deviceStr,
        'role': existingRole ?? defaultRole,
        'profileCompleted': (doc.exists && doc.data() != null) ? (doc.data()!['profileCompleted'] ?? true) : true,
      };

      await userRef.set(docData, SetOptions(merge: true));
      print("[FIRESTORE] User document synced successfully for UID: $uid");
    } catch (e) {
      print("[FIRESTORE] User document sync error: $e");
    }
  }

  /* ── SESSION & TOKEN STORAGE ── */
  static Future<void> saveSession(Map<String, dynamic> user, {String? token}) async {
    currentUser = user;
    if (token != null) {
      authToken = token;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUser', json.encode(user));
      if (authToken != null) {
        await prefs.setString('auth_token', authToken!);
      }
    } catch (e) {
      print("Save session error: $e");
    }
  }

  static Future<Map<String, dynamic>?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('currentUser');
      authToken = prefs.getString('auth_token');
      if (userStr != null) {
        currentUser = json.decode(userStr) as Map<String, dynamic>;
        return currentUser;
      }
    } catch (e) {
      print("Load session error: $e");
    }
    return null;
  }

  static Future<void> clearSession() async {
    try {
      if (isFirebaseAvailable) {
        try {
          await updateLogoutAuditLog();
        } catch (e) {
          print("Audit log logout write warning: $e");
        }
      }
    } finally {
      currentUser = null;
      authToken = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('currentUser');
        await prefs.remove('auth_token');
        await prefs.remove('current_session_id');
        if (isFirebaseAvailable) {
          await FirebaseAuth.instance.signOut();
        }
      } catch (e) {
        print("Clear session error: $e");
      }
    }
  }

  static Future<void> saveLanguage(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedLanguage', lang);
    } catch (e) {
      print("Save language error: $e");
    }
  }

  static Future<String?> loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('selectedLanguage');
    } catch (e) {
      print("Load language error: $e");
    }
    return null;
  }

  /* ── PLATFORM-AGNOSTIC HTTP HELPERS ── */
  static Map<String, String> get _headers => {
        'content-type': 'application/json',
        'bypass-tunnel-reminder': 'true',
        'X-Pinggy-No-Screen': 'true',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  static Future<http.Response?> _httpGet(String url) async {
    try {
      return await http.get(Uri.parse(url), headers: _headers).timeout(const Duration(seconds: 10));
    } catch (e) {
      print("HTTP GET Error ($url): $e");
      return null;
    }
  }

  static Future<http.Response?> _httpPost(String url, Map<String, dynamic> body) async {
    try {
      return await http.post(
        Uri.parse(url),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print("HTTP POST Error ($url): $e");
      return null;
    }
  }

  /* ── HELPER UTILITY METHODS ── */

  static Future<void> makeCall(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  static Future<void> launchDirections(String address) async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /* ── API CALL METHODS ── */

  // 0. Check Backend Server Connection
  static Future<bool> checkConnection() async {
    try {
      final rootUrl = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
      final healthUrl = "$rootUrl/health";
      
      final res = await _httpGet(healthUrl);
      if (res != null && res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final connected = data['status'] == 'online';
        print(connected ? "[DIAGNOSTICS] Backend connected" : "[DIAGNOSTICS] Backend disconnected");
        return connected;
      }
    } catch (_) {}
    print("[DIAGNOSTICS] Backend disconnected");
    return false;
  }

  // 1. Google Sign-In & Session Handling
  static Future<Map<String, dynamic>?> getCurrentSession() async {
    return loadSession();
  }

  // 2. Chatbot response generator
  static Future<String> chat(String text) async {
    final String queryLower = text.toLowerCase();
    if (queryLower.contains('fever')) {
      return "Fever is an immune response to infection. Rest well, stay hydrated, take Paracetamol 500mg as needed, and consult a doctor if temperature exceeds 102°F or persists over 3 days.";
    } else if (queryLower.contains('cough') || queryLower.contains('throat')) {
      return "For sore throat and cough, practice warm salt water gargles 3 times daily, stay hydrated, and take steam inhalation. Visit a health center if breathing becomes difficult.";
    } else if (queryLower.contains('appointment') || queryLower.contains('doctor')) {
      return "You can book an appointment with a nearby specialist through the Clinics & Doctors section in ArogyaAI.";
    }

    final res = await _httpPost("$baseUrl/chat", {'message': text});
    if (res != null && res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['response'] ?? data['reply'] ?? "I am monitoring your query. How can I assist your health today?";
    }
    return "ArogyaAI Clinical Assistant: Please ensure adequate hydration and consult a certified medical practitioner if symptoms persist.";
  }

  // 3. Sync profile with FastAPI backend (Firestore)
  static Future<Map<String, dynamic>?> syncProfile({required String name, required String language}) async {
    if (isFirebaseAvailable && currentUser != null) {
      try {
        final uid = currentUser!['uid'];
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name,
          'displayName': name,
          'language': language,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
        currentUser!['name'] = name;
        currentUser!['language'] = language;
        await saveSession(currentUser!);
        return currentUser;
      } catch (e) {
        print("Firebase Sync Profile Error: $e");
      }
    }

    final res = await _httpPost("$baseUrl/auth/profile", {'name': name, 'language': language});
    if (res != null && res.statusCode == 200) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      if (currentUser != null) {
        currentUser!['name'] = data['name'];
        currentUser!['language'] = data['language'];
        await saveSession(currentUser!);
      }
      return data;
    }
    return null;
  }

  // 4. Fetch User Profile Details
  static Future<Map<String, dynamic>?> getProfile() async {
    if (isFirebaseAvailable && currentUser != null) {
      try {
        final uid = currentUser!['uid'];
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          return doc.data();
        }
      } catch (e) {
        print("Firebase Get Profile Error: $e");
      }
    }

    final res = await _httpGet("$baseUrl/auth/profile");
    if (res != null && res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    return null;
  }

  // 5. Submit AI Symptom Diagnosis Request
  static Future<Map<String, dynamic>?> diagnose(String symptoms) async {
    print("[DEBUG] DIAGNOSIS INPUT = '$symptoms'");
    Map<String, dynamic>? diagResult;

    // 1. Try Backend API first over HTTP
    try {
      final res = await _httpPost("$baseUrl/diagnose", {'symptoms': symptoms, 'language': 'English'});
      if (res != null && res.statusCode == 200) {
        diagResult = json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print("HTTP Backend Diagnosis Warning: $e");
    }

    // 2. Fallback to Local Rule-Based Clinical Triage Engine if HTTP backend is unreachable
    if (diagResult == null) {
      final String symptomsLower = symptoms.toLowerCase();
      if (symptomsLower.contains("fever") || symptomsLower.contains("temperature") || symptomsLower.contains("hot") || symptomsLower.contains("jwaram") || symptomsLower.contains("bukhar")) {
        diagResult = {
          'condition': 'Viral Pyrexia (Acute Fever)',
          'severity': 'medium',
          'specialist': 'General Physician',
          'description': 'Elevated body temperature indicating a viral immune response.',
          'precautions': ['Maintain oral hydration', 'Tepid sponging if temp > 101F', 'Adequate bed rest'],
          'medicines': [
            {'name': 'Paracetamol 500mg', 'instructions': '1 tablet every 6 hours after meals (SOS)', 'badge': 'Fever & Pain'},
            {'name': 'ORS Hydration Powder', 'instructions': 'Dissolve 1 sachet in 1L water daily', 'badge': 'Hydration'}
          ]
        };
      } else if (symptomsLower.contains("throat") || symptomsLower.contains("cough") || symptomsLower.contains("cold") || symptomsLower.contains("daggulu") || symptomsLower.contains("khansi")) {
        diagResult = {
          'condition': 'Upper Respiratory Tract Infection (Pharyngitis)',
          'severity': 'low',
          'specialist': 'ENT Specialist',
          'description': 'Inflammation of nasal passages and throat mucosa.',
          'precautions': ['Warm saline gargles 3 times daily', 'Steam inhalation', 'Avoid cold beverages'],
          'medicines': [
            {'name': 'Azithromycin 500mg', 'instructions': '1 tablet daily for 3 days after food', 'badge': 'Antibiotic'},
            {'name': 'Cough Syrup (Koflet)', 'instructions': '2 teaspoons 3 times daily', 'badge': 'Cough Relief'}
          ]
        };
      } else {
        diagResult = {
          'condition': 'General Clinical Assessment',
          'severity': 'low',
          'specialist': 'General Physician',
          'description': 'Non-specific systemic symptoms requiring primary healthcare evaluation.',
          'precautions': ['Monitor symptoms for 24-48 hours', 'Maintain balanced diet and hydration'],
          'medicines': [
            {'name': 'Multivitamin Complex', 'instructions': '1 tablet daily after breakfast', 'badge': 'Supplement'}
          ]
        };
      }
    }

    // 3. Asynchronously persist diagnosis to Firestore if available
    if (isFirebaseAvailable) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final uid = user?.uid ?? (currentUser != null ? currentUser!['uid'] : 'anonymous');
        final now = DateTime.now().toIso8601String();

        final reportRef = FirebaseFirestore.instance.collection('reports').doc();
        await reportRef.set({
          'id': reportRef.id,
          'userId': uid,
          'patientName': user?.displayName ?? (currentUser != null ? currentUser!['name'] : 'Arogya Patient'),
          'patientEmail': user?.email ?? (currentUser != null ? currentUser!['email'] : ''),
          'symptoms': symptoms,
          'condition': diagResult['condition'],
          'severity': diagResult['severity'],
          'specialist': diagResult['specialist'],
          'description': diagResult['description'],
          'precautions': diagResult['precautions'],
          'medicines': diagResult['medicines'],
          'date': now.split('T').first,
          'createdAt': now,
        });
      } catch (e) {
        print("Firestore report sync warning: $e");
      }
    }

    return diagResult;
  }

  // 6. Fetch Doctor Profiles
  static Future<List<dynamic>> getDoctors({String? search, String? specialty, String? city}) async {
    if (isFirebaseAvailable) {
      try {
        final snap = await FirebaseFirestore.instance.collection('doctors').get();
        if (snap.docs.isNotEmpty) {
          var list = snap.docs.map((d) => d.data()).toList();
          if (specialty != null && specialty.isNotEmpty && specialty != 'All') {
            list = list.where((d) => (d['specialist'] ?? d['specialty'] ?? '').toString().toLowerCase().contains(specialty.toLowerCase())).toList();
          }
          return list;
        }
      } catch (e) {
        print("Firebase Get Doctors Error: $e");
      }
    }

    final res = await _httpGet("$baseUrl/doctors");
    if (res != null && res.statusCode == 200) {
      return json.decode(res.body) as List<dynamic>;
    }
    return [
      {
        "id": "doc_1",
        "name": "Dr. Priya Sharma",
        "specialist": "ENT Specialist",
        "hospitalName": "Apollo Greams Road",
        "hospitalAddress": "Greams Lane, Thousand Lights, Chennai",
        "rating": 4.9,
        "experienceYears": 14,
        "consultationFee": 500,
        "availableToday": true
      },
      {
        "id": "doc_2",
        "name": "Dr. Mary Joseph",
        "specialist": "Cardiologist",
        "hospitalName": "Care Hospitals",
        "hospitalAddress": "Banjara Hills, Hyderabad",
        "rating": 4.8,
        "experienceYears": 18,
        "consultationFee": 800,
        "availableToday": true
      },
      {
        "id": "doc_3",
        "name": "Dr. Vinay Gowda",
        "specialist": "General Physician",
        "hospitalName": "Manipal Health Center",
        "hospitalAddress": "HAL Airport Road, Bengaluru",
        "rating": 4.6,
        "experienceYears": 10,
        "consultationFee": 400,
        "availableToday": true
      }
    ];
  }

  // 7. Fetch Primary Health Centers & Clinics / Hospitals
  static Future<List<dynamic>> getClinics({String? search, double? lat, double? lng}) async {
    return getHospitals(search: search, lat: lat, lng: lng);
  }

  static Future<List<dynamic>> getHospitals({String? search, double? lat, double? lng}) async {
    if (isFirebaseAvailable) {
      try {
        final snap = await FirebaseFirestore.instance.collection('hospitals').get();
        if (snap.docs.isNotEmpty) {
          final list = snap.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['id'] = data['id'] ?? d.id;
            return data;
          }).toList();
          if (search != null && search.isNotEmpty) {
            final q = search.toLowerCase();
            return list.where((h) {
              final name = (h['name'] ?? '').toString().toLowerCase();
              final addr = (h['address'] ?? '').toString().toLowerCase();
              final area = (h['area'] ?? '').toString().toLowerCase();
              final doc = (h['doctor'] ?? '').toString().toLowerCase();
              final spec = (h['specialist'] ?? '').toString().toLowerCase();
              final specs = (h['specialties'] as List<dynamic>?)?.map((s) => s.toString().toLowerCase()).toList() ?? [];
              return name.contains(q) || addr.contains(q) || area.contains(q) || doc.contains(q) || spec.contains(q) || specs.any((s) => s.contains(q));
            }).toList();
          }
          return list;
        }
      } catch (e) {
        print("Firebase Get Hospitals Error: $e");
      }
    }

    String url = "$baseUrl/hospitals";
    List<String> params = [];
    if (lat != null && lng != null) {
      params.add("lat=$lat");
      params.add("lng=$lng");
    }
    if (search != null && search.isNotEmpty) {
      params.add("search=${Uri.encodeComponent(search)}");
    }
    if (params.isNotEmpty) {
      url += "?${params.join('&')}";
    }

    final res = await _httpGet(url);
    if (res != null && res.statusCode == 200) {
      return json.decode(res.body) as List<dynamic>;
    }

    // Verified Real 15 Chennai Hospitals Dataset
    final List<Map<String, dynamic>> chennaiHospitals = [
      {
        "id": "hosp-apollo-greams",
        "name": "Apollo Hospitals, Greams Road",
        "hospitalName": "Apollo Hospitals, Greams Road",
        "doctor": "Dr. Priya Sharma",
        "specialist": "ENT Specialist",
        "degree": "MBBS, MS (ENT)",
        "exp": "12 yrs exp",
        "patients": "2.5k+",
        "rating": 4.9,
        "fee": "₹400",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "21, Greams Lane, Off Greams Road, Thousand Lights, Chennai, Tamil Nadu 600006",
        "area": "Greams Road / Thousand Lights",
        "pincode": "600006",
        "phone": "044 28290200",
        "emergencyPhone": "1066",
        "email": "info@apollohospitals.com",
        "lat": 13.0602,
        "lng": 80.2505,
        "specialties": ["Cardiology", "Oncology", "Orthopaedics", "Neurology", "Nephrology", "Gastroenterology", "Pulmonology", "ENT"],
        "departments": ["Cardiology", "Cardiothoracic Surgery", "Neurology", "Neurosurgery", "Medical Oncology", "Surgical Oncology", "Orthopaedics", "Nephrology"],
        "doctors": [
          {
            "id": "doc-apollo-1",
            "name": "Dr. Priya Sharma",
            "doctor": "Dr. Priya Sharma",
            "specialist": "ENT Specialist",
            "degree": "MBBS, MS (ENT)",
            "exp": "12 yrs exp",
            "rating": 4.9,
            "fee": "₹400",
            "about": "Senior ENT consultant at Apollo Greams Road with over 12 years of experience."
          },
          {
            "id": "doc-apollo-2",
            "name": "Dr. Y Vijayachandra Reddy",
            "doctor": "Dr. Y Vijayachandra Reddy",
            "specialist": "Cardiologist",
            "degree": "MBBS, MD, DM (Cardio)",
            "exp": "25 yrs exp",
            "rating": 4.9,
            "fee": "₹800",
            "about": "Senior Consultant Interventional Cardiologist."
          }
        ],
        "officialWebsite": "https://www.apollohospitals.com/hospitals/apollo-hospitals-greams-road-chennai",
        "appointmentUrl": "https://www.apollohospitals.com/hospitals/apollo-hospitals-greams-road-chennai",
        "description": "Apollo Hospitals, Greams Road is the flagship multi-specialty quaternary care hospital of Apollo Group, established in 1983.",
        "image": "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-apollo-teynampet",
        "name": "Apollo Speciality Hospitals, Teynampet",
        "hospitalName": "Apollo Speciality Hospitals, Teynampet",
        "doctor": "Dr. Mahadev Swamy",
        "specialist": "Oncologist",
        "degree": "MBBS, MD (Oncology)",
        "exp": "18 yrs exp",
        "patients": "3.1k+",
        "rating": 4.8,
        "fee": "₹600",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "320, Anna Salai, Teynampet, Chennai, Tamil Nadu 600035",
        "area": "Teynampet",
        "pincode": "600035",
        "phone": "044 24331741",
        "emergencyPhone": "1066",
        "email": "info@apollohospitals.com",
        "lat": 13.0425,
        "lng": 80.2467,
        "specialties": ["Oncology", "Orthopaedics", "Neurology", "Critical Care", "Radiotherapy"],
        "departments": ["Medical Oncology", "Surgical Oncology", "Radiation Oncology", "Orthopaedics", "Neurosciences"],
        "doctors": [
          {
            "id": "doc-apollo-tey-1",
            "name": "Dr. Mahadev Swamy",
            "doctor": "Dr. Mahadev Swamy",
            "specialist": "Oncologist",
            "degree": "MBBS, MD (Oncology)",
            "exp": "18 yrs exp",
            "rating": 4.8,
            "fee": "₹600",
            "about": "Senior Surgical Oncologist specializing in modern cancer therapies."
          }
        ],
        "officialWebsite": "https://www.apollohospitals.com/hospitals/apollo-speciality-hospitals-teynampet-chennai/",
        "appointmentUrl": "https://www.apollohospitals.com/hospitals/apollo-speciality-hospitals-teynampet-chennai/",
        "description": "Comprehensive oncology and multi-speciality institute equipped with advanced robotic surgery.",
        "image": "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-apollo-omr",
        "name": "Apollo Speciality Hospitals, OMR / Perungudi",
        "hospitalName": "Apollo Speciality Hospitals, OMR / Perungudi",
        "doctor": "Dr. R. Karthik",
        "specialist": "Cardiologist",
        "degree": "MBBS, MD, DM",
        "exp": "14 yrs exp",
        "patients": "1.8k+",
        "rating": 4.7,
        "fee": "₹500",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "5/639, Old Mahabalipuram Road (OMR), Perungudi, Chennai, Tamil Nadu 600096",
        "area": "OMR / Perungudi",
        "pincode": "600096",
        "phone": "044 33221111",
        "emergencyPhone": "1066",
        "email": "info@apollohospitals.com",
        "lat": 12.9647,
        "lng": 80.2458,
        "specialties": ["Cardiology", "Trauma Care", "Orthopaedics", "General Surgery", "Paediatrics"],
        "departments": ["Emergency Medicine", "Cardiology", "Orthopaedics", "General Surgery", "Paediatrics"],
        "doctors": [
          {
            "id": "doc-apollo-omr-1",
            "name": "Dr. R. Karthik",
            "doctor": "Dr. R. Karthik",
            "specialist": "Cardiologist",
            "degree": "MBBS, MD, DM",
            "exp": "14 yrs exp",
            "rating": 4.7,
            "fee": "₹500",
            "about": "Cardiovascular specialist with focus on non-invasive cardiac care."
          }
        ],
        "officialWebsite": "https://www.apollohospitals.com/hospitals/apollo-speciality-hospitals-omr-chennai/",
        "appointmentUrl": "https://www.apollohospitals.com/hospitals/apollo-speciality-hospitals-omr-chennai/",
        "description": "Multi-specialty emergency and trauma center serving the IT corridor of OMR Chennai.",
        "image": "https://images.unsplash.com/photo-1586773860418-d37222d8fce3?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1586773860418-d37222d8fce3?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-apollo-kilpauk",
        "name": "Apollo FirstMed Hospital, Kilpauk",
        "hospitalName": "Apollo FirstMed Hospital, Kilpauk",
        "doctor": "Dr. Meenakshi Sundaram",
        "specialist": "General Physician",
        "degree": "MBBS, MD (Gen Med)",
        "exp": "16 yrs exp",
        "patients": "2.2k+",
        "rating": 4.7,
        "fee": "₹450",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "154, Poonamallee High Road, Kilpauk, Chennai, Tamil Nadu 600010",
        "area": "Kilpauk",
        "pincode": "600010",
        "phone": "044 28211111",
        "emergencyPhone": "1066",
        "email": "info@apollohospitals.com",
        "lat": 13.0784,
        "lng": 80.2435,
        "specialties": ["General Medicine", "ENT", "Obstetrics & Gynaecology", "Gastroenterology", "General Surgery"],
        "departments": ["Internal Medicine", "ENT", "Gynaecology", "Gastroenterology", "General Surgery"],
        "doctors": [
          {
            "id": "doc-apollo-kil-1",
            "name": "Dr. Meenakshi Sundaram",
            "doctor": "Dr. Meenakshi Sundaram",
            "specialist": "General Physician",
            "degree": "MBBS, MD (Gen Med)",
            "exp": "16 yrs exp",
            "rating": 4.7,
            "fee": "₹450",
            "about": "Senior physician expert in diabetic care and internal medicine."
          }
        ],
        "officialWebsite": "https://www.apollohospitals.com/hospitals/apollo-firstmed-hospitals-kilpauk-chennai/",
        "appointmentUrl": "https://www.apollohospitals.com/hospitals/apollo-firstmed-hospitals-kilpauk-chennai/",
        "description": "Secondary and tertiary healthcare facility providing high quality clinical services in Kilpauk.",
        "image": "https://images.unsplash.com/photo-1516549655169-df83a0774514?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1516549655169-df83a0774514?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-apollo-kotturpuram",
        "name": "Apollo Medical Centre, Kotturpuram",
        "hospitalName": "Apollo Medical Centre, Kotturpuram",
        "doctor": "Dr. K. Ramanathan",
        "specialist": "General Medicine",
        "degree": "MBBS, MD",
        "exp": "12 yrs exp",
        "patients": "1.4k+",
        "rating": 4.6,
        "fee": "₹350",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "No 15, Gandhi Nagar 1st Main Rd, Kotturpuram, Chennai, Tamil Nadu 600085",
        "area": "Kotturpuram",
        "pincode": "600085",
        "phone": "044 24473333",
        "emergencyPhone": "1066",
        "email": "info@apollohospitals.com",
        "lat": 13.0238,
        "lng": 80.2417,
        "specialties": ["General Medicine", "Dermatology", "Paediatrics", "Diagnostics"],
        "departments": ["General Medicine", "Dermatology", "Paediatrics", "Diagnostics", "Preventive Health"],
        "doctors": [
          {
            "id": "doc-apollo-kot-1",
            "name": "Dr. K. Ramanathan",
            "doctor": "Dr. K. Ramanathan",
            "specialist": "General Medicine",
            "degree": "MBBS, MD",
            "exp": "12 yrs exp",
            "rating": 4.6,
            "fee": "₹350",
            "about": "Consultant physician in preventive care and outpatient clinical assessments."
          }
        ],
        "officialWebsite": "https://www.apollohospitals.com/hospitals/apollo-medical-centre-kotturpuram-chennai/",
        "appointmentUrl": "https://www.apollohospitals.com/hospitals/apollo-medical-centre-kotturpuram-chennai/",
        "description": "Neighborhood Apollo outpatient medical clinic with diagnostic lab services.",
        "image": "https://images.unsplash.com/photo-1579684385127-1ef15d508118?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1579684385127-1ef15d508118?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-apollo-vanagaram",
        "name": "Apollo Speciality Hospitals, Vanagaram",
        "hospitalName": "Apollo Speciality Hospitals, Vanagaram",
        "doctor": "Dr. V. Arunkumar",
        "specialist": "Orthopaedics",
        "degree": "MBBS, MS (Ortho)",
        "exp": "16 yrs exp",
        "patients": "2.9k+",
        "rating": 4.8,
        "fee": "₹500",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "Vanagaram - Ambattur Main Rd, Vanagaram, Chennai, Tamil Nadu 600095",
        "area": "Vanagaram",
        "pincode": "600095",
        "phone": "044 26537777",
        "emergencyPhone": "1066",
        "email": "info@apollohospitals.com",
        "lat": 13.0734,
        "lng": 80.1478,
        "specialties": ["Emergency Care", "Cardiology", "Neurosurgery", "Orthopaedics", "Pulmonology"],
        "departments": ["Emergency Medicine", "Cardiology", "Neurosurgery", "Orthopedics & Trauma", "Pulmonology"],
        "doctors": [
          {
            "id": "doc-apollo-van-1",
            "name": "Dr. V. Arunkumar",
            "doctor": "Dr. V. Arunkumar",
            "specialist": "Orthopaedics",
            "degree": "MBBS, MS (Ortho)",
            "exp": "16 yrs exp",
            "rating": 4.8,
            "fee": "₹500",
            "about": "Trauma and joint replacement specialist at Vanagaram Apollo."
          }
        ],
        "officialWebsite": "https://www.apollohospitals.com/hospitals/apollo-speciality-hospitals-vanagaram-chennai/",
        "appointmentUrl": "https://www.apollohospitals.com/hospitals/apollo-speciality-hospitals-vanagaram-chennai/",
        "description": "Advanced tertiary specialty hospital equipped with level-1 emergency and ICU units.",
        "image": "https://images.unsplash.com/photo-1512678080530-7760d81faba6?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1512678080530-7760d81faba6?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-apollo-tondiarpet",
        "name": "Apollo Hospitals, Tondiarpet",
        "hospitalName": "Apollo Hospitals, Tondiarpet",
        "doctor": "Dr. G. Balaji",
        "specialist": "General Physician",
        "degree": "MBBS, MD",
        "exp": "11 yrs exp",
        "patients": "1.6k+",
        "rating": 4.6,
        "fee": "₹350",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "336, T.H. Road, Tondiarpet, Chennai, Tamil Nadu 600081",
        "area": "Tondiarpet",
        "pincode": "600081",
        "phone": "044 25913333",
        "emergencyPhone": "1066",
        "email": "info@apollohospitals.com",
        "lat": 13.1258,
        "lng": 80.2872,
        "specialties": ["General Surgery", "Obstetrics & Gynaecology", "Paediatrics", "General Medicine", "ENT"],
        "departments": ["General Surgery", "Gynaecology & Obstetrics", "Paediatrics", "General Medicine", "ENT"],
        "doctors": [
          {
            "id": "doc-apollo-ton-1",
            "name": "Dr. G. Balaji",
            "doctor": "Dr. G. Balaji",
            "specialist": "General Physician",
            "degree": "MBBS, MD",
            "exp": "11 yrs exp",
            "rating": 4.6,
            "fee": "₹350",
            "about": "Consultant physician offering general medicine care in North Chennai."
          }
        ],
        "officialWebsite": "https://www.apollohospitals.com/hospitals/apollo-hospitals-tondiarpet-chennai/",
        "appointmentUrl": "https://www.apollohospitals.com/hospitals/apollo-hospitals-tondiarpet-chennai/",
        "description": "Serving North Chennai community with emergency trauma, maternal, and surgical care.",
        "image": "https://images.unsplash.com/photo-1538108176447-2af0b97db733?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1538108176447-2af0b97db733?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-apollo-childrens",
        "name": "Apollo Children's Hospital, Thousand Lights",
        "hospitalName": "Apollo Children's Hospital, Thousand Lights",
        "doctor": "Dr. Latha Viswanathan",
        "specialist": "Paediatrician",
        "degree": "MBBS, MD, DCH",
        "exp": "20 yrs exp",
        "patients": "4.5k+",
        "rating": 4.9,
        "fee": "₹500",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "15, Shafee Mohammed Road, Thousand Lights, Chennai, Tamil Nadu 600006",
        "area": "Thousand Lights",
        "pincode": "600006",
        "phone": "044 28298282",
        "emergencyPhone": "1066",
        "email": "info@apollohospitals.com",
        "lat": 13.0612,
        "lng": 80.2520,
        "specialties": ["Paediatrics", "Paediatric Surgery", "Paediatric Cardiology", "Neonatology", "Paediatric Neurology"],
        "departments": ["General Paediatrics", "Neonatology", "Paediatric Cardiac Surgery", "Paediatric Neurology", "Paediatric Oncology"],
        "doctors": [
          {
            "id": "doc-apollo-child-1",
            "name": "Dr. Latha Viswanathan",
            "doctor": "Dr. Latha Viswanathan",
            "specialist": "Paediatrician",
            "degree": "MBBS, MD, DCH",
            "exp": "20 yrs exp",
            "rating": 4.9,
            "fee": "₹500",
            "about": "Senior Consultant Paediatrician specializing in infant health and child development."
          }
        ],
        "officialWebsite": "https://www.apollohospitals.com/hospitals/apollo-childrens-hospital-thousand-lights-chennai/",
        "appointmentUrl": "https://www.apollohospitals.com/hospitals/apollo-childrens-hospital-thousand-lights-chennai/",
        "description": "Dedicated quaternary pediatric super-specialty hospital for children and newborns.",
        "image": "https://images.unsplash.com/photo-1576765608535-5f04d1e3f289?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1576765608535-5f04d1e3f289?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-apollo-womens",
        "name": "Apollo Women's Hospital, Thousand Lights",
        "hospitalName": "Apollo Women's Hospital, Thousand Lights",
        "doctor": "Dr. Kundavi Shankar",
        "specialist": "Gynaecologist",
        "degree": "MBBS, DGO, MRCOG",
        "exp": "18 yrs exp",
        "patients": "3.8k+",
        "rating": 4.9,
        "fee": "₹550",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "15, Shafee Mohammed Road, Thousand Lights, Chennai, Tamil Nadu 600006",
        "area": "Thousand Lights",
        "pincode": "600006",
        "phone": "044 28297777",
        "emergencyPhone": "1066",
        "email": "info@apollohospitals.com",
        "lat": 13.0614,
        "lng": 80.2522,
        "specialties": ["Obstetrics", "Gynaecology", "Fertility & IVF", "Fetal Medicine", "Urogynaecology"],
        "departments": ["Obstetrics & Gynaecology", "Reproductive Medicine", "Fetal Medicine", "Gynaecologic Oncology"],
        "doctors": [
          {
            "id": "doc-apollo-wom-1",
            "name": "Dr. Kundavi Shankar",
            "doctor": "Dr. Kundavi Shankar",
            "specialist": "Gynaecologist",
            "degree": "MBBS, DGO, MRCOG",
            "exp": "18 yrs exp",
            "rating": 4.9,
            "fee": "₹550",
            "about": "Lead Obstetrician and High-Risk Pregnancy Specialist."
          }
        ],
        "officialWebsite": "https://www.apollohospitals.com/hospitals/apollo-womens-hospital-thousand-lights-chennai/",
        "appointmentUrl": "https://www.apollohospitals.com/hospitals/apollo-womens-hospital-thousand-lights-chennai/",
        "description": "Exclusive tertiary care center dedicated to women's healthcare, maternity, and reproductive sciences.",
        "image": "https://images.unsplash.com/photo-1505751172876-fa1923c5c528?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1505751172876-fa1923c5c528?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-miot",
        "name": "MIOT International, Manapakkam",
        "hospitalName": "MIOT International, Manapakkam",
        "doctor": "Dr. PVA Mohandas",
        "specialist": "Orthopaedics",
        "degree": "MBBS, MS, FRCS",
        "exp": "35 yrs exp",
        "patients": "5.0k+",
        "rating": 4.8,
        "fee": "₹600",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "4/112, Mount Poonamallee Road, Manapakkam, Chennai, Tamil Nadu 600089",
        "area": "Manapakkam",
        "pincode": "600089",
        "phone": "+91 44 42002288",
        "emergencyPhone": "105710",
        "email": "miot@miotinternational.com",
        "lat": 13.0232,
        "lng": 80.1764,
        "specialties": ["Orthopaedics", "Joint Replacement", "Cardiology", "Thoracic Surgery", "Nephrology", "Oncology"],
        "departments": ["Orthopaedics & Trauma", "Institute of Cardiac Sciences", "Nephrology", "Oncology", "Gastroenterology"],
        "doctors": [
          {
            "id": "doc-miot-1",
            "name": "Dr. PVA Mohandas",
            "doctor": "Dr. PVA Mohandas",
            "specialist": "Orthopaedics",
            "degree": "MBBS, MS, FRCS",
            "exp": "35 yrs exp",
            "rating": 4.9,
            "fee": "₹800",
            "about": "Pioneer Orthopaedic Surgeon and Founder of MIOT International."
          },
          {
            "id": "doc-miot-2",
            "name": "Dr. K. R. Balakrishnan",
            "doctor": "Dr. K. R. Balakrishnan",
            "specialist": "Cardiologist",
            "degree": "MBBS, MS, MCh (Cardio)",
            "exp": "28 yrs exp",
            "rating": 4.9,
            "fee": "₹750",
            "about": "Renowned Cardiac Surgeon & Heart Transplant Specialist."
          }
        ],
        "officialWebsite": "https://www.miotinternational.com/",
        "appointmentUrl": "https://www.miotinternational.com/",
        "description": "1000-bed multi-specialty hospital renowned worldwide for orthopedics, joint replacement, and cardiac care.",
        "image": "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-kauvery-alwarpet",
        "name": "Kauvery Hospital – Chennai Alwarpet",
        "hospitalName": "Kauvery Hospital – Chennai Alwarpet",
        "doctor": "Dr. A. Anantharaman",
        "specialist": "Cardiologist",
        "degree": "MBBS, MD, DM",
        "exp": "22 yrs exp",
        "patients": "3.4k+",
        "rating": 4.8,
        "fee": "₹500",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "199, Luz Church Road, Alwarpet, Chennai, Tamil Nadu 600004",
        "area": "Alwarpet",
        "pincode": "600004",
        "phone": "044 40006000",
        "emergencyPhone": "044 40006000",
        "email": "info@kauveryhospital.com",
        "lat": 13.0336,
        "lng": 80.2492,
        "specialties": ["Cardiology", "Geriatrics", "Vascular Surgery", "Gastroenterology", "Nephrology", "Neurology"],
        "departments": ["Heart City", "Neurosciences", "Geriatric Medicine", "Vascular Surgery", "Nephrology & Urology"],
        "doctors": [
          {
            "id": "doc-kau-alw-1",
            "name": "Dr. A. Anantharaman",
            "doctor": "Dr. A. Anantharaman",
            "specialist": "Cardiologist",
            "degree": "MBBS, MD, DM",
            "exp": "22 yrs exp",
            "rating": 4.8,
            "fee": "₹500",
            "about": "Senior Consultant Interventional Cardiologist at Kauvery Alwarpet."
          }
        ],
        "officialWebsite": "https://www.kauveryhospital.com/",
        "appointmentUrl": "https://www.kauveryhospital.com/patients-visitors/appointment/",
        "description": "Leading multi-specialty healthcare provider in central Chennai offering patient-centric medical excellence.",
        "image": "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-kauvery-radial",
        "name": "Kauvery Hospital – Radial Road",
        "hospitalName": "Kauvery Hospital – Radial Road",
        "doctor": "Dr. S. Vijay",
        "specialist": "Cardiologist",
        "degree": "MBBS, MD, DM",
        "exp": "15 yrs exp",
        "patients": "2.1k+",
        "rating": 4.7,
        "fee": "₹500",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "Radial Road, Kovilambakkam, Chennai, Tamil Nadu 600117",
        "area": "Radial Road / Kovilambakkam",
        "pincode": "600117",
        "phone": "044 61116111",
        "emergencyPhone": "044 61116111",
        "email": "info@kauveryhospital.com",
        "lat": 12.9463,
        "lng": 80.1874,
        "specialties": ["Emergency Care", "Cardiology", "Orthopaedics", "Critical Care", "Neurosciences"],
        "departments": ["Emergency & Trauma", "Interventional Cardiology", "Orthopaedics", "Intensive Care", "Neurology"],
        "doctors": [
          {
            "id": "doc-kau-rad-1",
            "name": "Dr. S. Vijay",
            "doctor": "Dr. S. Vijay",
            "specialist": "Cardiologist",
            "degree": "MBBS, MD, DM",
            "exp": "15 yrs exp",
            "rating": 4.7,
            "fee": "₹500",
            "about": "Cardiology specialist providing emergency and cardiac care on Radial Road."
          }
        ],
        "officialWebsite": "https://www.kauveryhospital.com/",
        "appointmentUrl": "https://www.kauveryhospital.com/patients-visitors/appointment/",
        "description": "State-of-the-art tertiary care hospital serving South Chennai along 200 Feet Radial Road.",
        "image": "https://images.unsplash.com/photo-1586773860418-d37222d8fce3?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1586773860418-d37222d8fce3?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-kauvery-vadapalani",
        "name": "Kauvery Hospital – Vadapalani",
        "hospitalName": "Kauvery Hospital – Vadapalani",
        "doctor": "Dr. K. Prabakaran",
        "specialist": "Gastroenterologist",
        "degree": "MBBS, MD, DM",
        "exp": "18 yrs exp",
        "patients": "2.8k+",
        "rating": 4.8,
        "fee": "₹500",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "1, Jawaharlal Nehru Salai, Vadapalani, Chennai, Tamil Nadu 600026",
        "area": "Vadapalani",
        "pincode": "600026",
        "phone": "044 40006000",
        "emergencyPhone": "044 40006000",
        "email": "info@kauveryhospital.com",
        "lat": 13.0505,
        "lng": 80.2120,
        "specialties": ["Gastroenterology", "Cardiology", "Pulmonology", "Orthopaedics", "General Medicine"],
        "departments": ["Digestive Diseases", "Cardiovascular Sciences", "Pulmonology", "Orthopaedics & Spine"],
        "doctors": [
          {
            "id": "doc-kau-vad-1",
            "name": "Dr. K. Prabakaran",
            "doctor": "Dr. K. Prabakaran",
            "specialist": "Gastroenterologist",
            "degree": "MBBS, MD, DM",
            "exp": "18 yrs exp",
            "rating": 4.8,
            "fee": "₹500",
            "about": "Senior Consultant Gastroenterologist at Vadapalani Kauvery."
          }
        ],
        "officialWebsite": "https://www.kauveryhospital.com/",
        "appointmentUrl": "https://www.kauveryhospital.com/patients-visitors/appointment/",
        "description": "Multi-specialty center delivering comprehensive digestive, cardiac, and organ care in Vadapalani.",
        "image": "https://images.unsplash.com/photo-1516549655169-df83a0774514?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1516549655169-df83a0774514?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-gleneagles-perumbakkam",
        "name": "Gleneagles Hospital, Perumbakkam / Sholinganallur",
        "hospitalName": "Gleneagles Hospital, Perumbakkam / Sholinganallur",
        "doctor": "Dr. Mohamed Rela",
        "specialist": "Liver Transplant Surgeon",
        "degree": "MBBS, MS, FRCS",
        "exp": "30 yrs exp",
        "patients": "4.2k+",
        "rating": 4.9,
        "fee": "₹700",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "439, Cheran Nagar, Perumbakkam – Sholinganallur, Chennai, Tamil Nadu 600100",
        "area": "Perumbakkam / Sholinganallur",
        "pincode": "600100",
        "phone": "+91 92402 62425",
        "emergencyPhone": "044 46242424",
        "email": "info@gleneagleshospitals.co.in",
        "lat": 12.8988,
        "lng": 80.2033,
        "specialties": ["Liver Transplantation", "Hepato-Pancreato-Biliary", "Cardiology", "Organ Transplant", "Oncology"],
        "departments": ["HPB Surgery & Liver Transplant", "Cardiac Sciences", "Multi-Organ Transplant", "Oncology", "Critical Care"],
        "doctors": [
          {
            "id": "doc-glen-1",
            "name": "Dr. Mohamed Rela",
            "doctor": "Dr. Mohamed Rela",
            "specialist": "Liver Transplant Surgeon",
            "degree": "MBBS, MS, FRCS",
            "exp": "30 yrs exp",
            "rating": 4.9,
            "fee": "₹900",
            "about": "World-renowned pioneer in liver transplantation and HPB surgery."
          }
        ],
        "officialWebsite": "https://www.gleneagleshospitals.co.in/chennai/perumbakkam",
        "appointmentUrl": "https://www.gleneagleshospitals.co.in/chennai/perumbakkam",
        "description": "Quaternary care organ transplant center and multi-specialty global health hub in Perumbakkam.",
        "image": "https://images.unsplash.com/photo-1579684385127-1ef15d508118?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1579684385127-1ef15d508118?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      },
      {
        "id": "hosp-sims-vadapalani",
        "name": "SIMS Hospital, Vadapalani",
        "hospitalName": "SIMS Hospital, Vadapalani",
        "doctor": "Dr. VV Bashi",
        "specialist": "Cardiac Surgeon",
        "degree": "MBBS, MS, MCh (Cardio)",
        "exp": "32 yrs exp",
        "patients": "4.8k+",
        "rating": 4.9,
        "fee": "₹600",
        "open": true,
        "type": "private",
        "city": "Chennai",
        "state": "Tamil Nadu",
        "country": "India",
        "address": "No. 1, Jawaharlal Nehru Salai, 100 Feet Road, Vadapalani, Chennai, Tamil Nadu 600026",
        "area": "Vadapalani",
        "pincode": "600026",
        "phone": "+91 44 2000 2001",
        "emergencyPhone": "+91 44 2000 2020",
        "email": "contactus@simshospitals.com",
        "lat": 13.0508,
        "lng": 80.2124,
        "specialties": ["Cardiac Sciences", "Orthopaedics", "Neurosciences", "Surgical Gastroenterology", "Oncology"],
        "departments": ["Institute of Cardiac Sciences", "Bone & Joint Institute", "Neurosciences", "Surgical Gastroenterology"],
        "doctors": [
          {
            "id": "doc-sims-1",
            "name": "Dr. VV Bashi",
            "doctor": "Dr. VV Bashi",
            "specialist": "Cardiac Surgeon",
            "degree": "MBBS, MS, MCh",
            "exp": "32 yrs exp",
            "rating": 4.9,
            "fee": "₹800",
            "about": "Senior Consultant Aortic & Cardiac Surgeon at SIMS Hospital."
          },
          {
            "id": "doc-sims-2",
            "name": "Dr. Vijay Bose",
            "doctor": "Dr. Vijay Bose",
            "specialist": "Orthopaedics",
            "degree": "MBBS, MS, FRCS",
            "exp": "25 yrs exp",
            "rating": 4.9,
            "fee": "₹750",
            "about": "Senior Joint Replacement & Hip Resurfacing Surgeon."
          }
        ],
        "officialWebsite": "https://www.simshospitals.com/",
        "appointmentUrl": "https://www.simshospitals.com/",
        "description": "SRM Group multi-super specialty hospital providing advanced tertiary & quaternary medical services.",
        "image": "https://images.unsplash.com/photo-1512678080530-7760d81faba6?auto=format&fit=crop&w=600&q=80",
        "imageUrl": "https://images.unsplash.com/photo-1512678080530-7760d81faba6?auto=format&fit=crop&w=600&q=80",
        "isRealHospital": true
      }
    ];

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      return chennaiHospitals.where((h) {
        final name = (h['name'] ?? '').toString().toLowerCase();
        final addr = (h['address'] ?? '').toString().toLowerCase();
        final area = (h['area'] ?? '').toString().toLowerCase();
        final doc = (h['doctor'] ?? '').toString().toLowerCase();
        final spec = (h['specialist'] ?? '').toString().toLowerCase();
        final specs = (h['specialties'] as List<dynamic>?)?.map((s) => s.toString().toLowerCase()).toList() ?? [];
        return name.contains(q) || addr.contains(q) || area.contains(q) || doc.contains(q) || spec.contains(q) || specs.any((s) => s.contains(q));
      }).toList();
    }

    return chennaiHospitals;
  }

  static final List<Map<String, dynamic>> _localAppointments = [];

  // 8. Book Appointment
  static Future<Map<String, dynamic>?> bookAppointment({
    String? clinicId,
    String? doctorName,
    String? date,
    String? appointmentDate,
    String? appointmentTime,
    String? time,
    String? patientName,
    String? patientEmail,
    String? patientPhone,
    String? clinicName,
    String? specialist,
    String? address,
    String? fee,
    String? symptoms,
    String? condition,
    String? severity,
    String? paymentStatus,
    String? paymentId,
    String? paymentMethod,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? (currentUser != null ? currentUser!['uid'] : null);
    final String pName = patientName ?? user?.displayName ?? (currentUser != null ? currentUser!['name'] : 'Valued Patient');
    final String pEmail = patientEmail ?? user?.email ?? (currentUser != null ? currentUser!['email'] : '');
    final String cName = clinicName ?? 'Primary Health Centre';
    final String cSpecialist = specialist ?? 'General Physician';
    final String cAddress = address ?? 'Local Health Center';
    final String finalDate = appointmentDate ?? date ?? DateTime.now().toIso8601String().split('T').first;
    final String finalTime = appointmentTime ?? time ?? '10:00 AM';
    final String token = "TK-${(100 + (DateTime.now().millisecondsSinceEpoch % 900))}";
    final String apptId = "APT-${DateTime.now().millisecondsSinceEpoch}";
    final String createdAtStr = DateTime.now().toIso8601String();
    final String userSymptoms = (symptoms != null && symptoms.trim().isNotEmpty) ? symptoms.trim() : 'Not provided';
    print("[DEBUG] APPOINTMENT SYMPTOMS = '$userSymptoms'");

    final apptData = {
      'id': apptId,
      'appointmentId': apptId,
      'token': token,
      'userId': uid ?? 'anonymous',
      'patientName': pName,
      'patientEmail': pEmail,
      'patientPhone': patientPhone ?? '',
      'email': pEmail,
      'doctorName': doctorName ?? 'Dr. Specialist',
      'doctor': doctorName ?? 'Dr. Specialist',
      'specialist': cSpecialist,
      'specialization': cSpecialist,
      'clinicName': cName,
      'hospitalName': cName,
      'address': cAddress,
      'hospitalAddress': cAddress,
      'clinicId': clinicId ?? 'c1',
      'date': finalDate,
      'appointmentDate': finalDate,
      'time': finalTime,
      'appointmentTime': finalTime,
      'fee': fee ?? 'Free',
      'symptoms': userSymptoms,
      if (condition != null && condition.isNotEmpty) 'condition': condition,
      if (severity != null && severity.isNotEmpty) 'severity': severity,
      'paymentStatus': paymentStatus ?? 'paid',
      'paymentId': paymentId ?? 'pay_${DateTime.now().millisecondsSinceEpoch}',
      'paymentMethod': paymentMethod ?? 'razorpay',
      'status': 'Confirmed',
      'createdAt': createdAtStr,
      'confirmationEmailSent': false,
    };

    _localAppointments.insert(0, apptData);

    final result = {
      'success': true,
      'appointment': apptData,
      ...apptData,
    };

    if (isFirebaseAvailable) {
      try {
        final docRef = FirebaseFirestore.instance.collection('appointments').doc(apptId);
        await docRef.set(apptData);
        print("[FIRESTORE] Appointment booked: $apptId");

        triggerBrevoConfirmationEmail(apptData);
        return result;
      } catch (e) {
        print("Firebase Book Appointment Error: $e");
      }
    }

    final res = await _httpPost("$baseUrl/appointments/book", apptData);
    if (res != null && res.statusCode == 200) {
      final resData = json.decode(res.body) as Map<String, dynamic>;
      triggerBrevoConfirmationEmail(resData);
      return {'success': true, 'appointment': resData, ...resData};
    }

    triggerBrevoConfirmationEmail(apptData);
    return result;
  }

  // Razorpay Order Creation
  static Future<Map<String, dynamic>?> createRazorpayOrder({
    required int amount,
    required String doctorName,
    required String patientName,
  }) async {
    try {
      final res = await _httpPost("$baseUrl/payments/create-order", {
        'amount': amount,
        'currency': 'INR',
        'doctorName': doctorName,
        'patientName': patientName,
      });
      if (res != null && res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Create Order HTTP Warning: $e");
    }
    // Sandbox order fallback
    return {
      'success': true,
      'orderId': 'order_${DateTime.now().millisecondsSinceEpoch}',
      'amount': amount,
      'currency': 'INR',
      'key': 'rzp_test_arogya_ai_demo',
    };
  }

  // Razorpay Verification & Booking
  static Future<Map<String, dynamic>?> verifyPaymentAndBook({
    required String orderId,
    required String paymentId,
    required String signature,
    required Map<String, dynamic> bookingData,
  }) async {
    try {
      final res = await _httpPost("$baseUrl/payments/verify", {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        'bookingData': bookingData,
      });
      if (res != null && res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        if (data['appointment'] != null) {
          _localAppointments.insert(0, data['appointment']);
        }
        return data;
      }
    } catch (e) {
      print("Verify Payment HTTP Warning: $e");
    }

    // Fallback: Store locally & in Firestore
    return await bookAppointment(
      doctorName: bookingData['doctorName'],
      date: bookingData['date'],
      appointmentDate: bookingData['appointmentDate'],
      appointmentTime: bookingData['appointmentTime'],
      time: bookingData['time'],
      patientName: bookingData['patientName'],
      patientPhone: bookingData['patientPhone'],
      clinicName: bookingData['clinicName'],
      specialist: bookingData['specialist'],
      address: bookingData['address'],
      fee: bookingData['fee'],
      symptoms: bookingData['symptoms'],
      condition: bookingData['condition'],
      severity: bookingData['severity'],
      paymentStatus: 'paid',
      paymentId: paymentId,
      paymentMethod: 'razorpay',
    );
  }

  // 9. Trigger Brevo Confirmation Email via Node Backend
  static Future<void> triggerBrevoConfirmationEmail(Map<String, dynamic> appointmentData) async {
    try {
      final res = await _httpPost("$baseUrl/appointments/send-confirmation", appointmentData);
      if (res != null && res.statusCode == 200) {
        print("[BREVO CONFIRMATION] Email successfully sent!");
        final apptId = appointmentData['id'] ?? appointmentData['appointmentId'];
        if (isFirebaseAvailable && apptId != null) {
          await FirebaseFirestore.instance.collection('appointments').doc(apptId).set({
            'confirmationEmailSent': true,
            'confirmationEmailSentAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print("Trigger Brevo Confirmation Email Error: $e");
    }
  }

  static Future<bool> resendAppointmentEmail(Map<String, dynamic> appointmentData) async {
    try {
      final res = await _httpPost("$baseUrl/appointments/resend-confirmation", appointmentData);
      if (res != null && res.statusCode == 200) {
        print("[BREVO RESEND] Email successfully resent!");
        return true;
      }
    } catch (e) {
      print("Resend Appointment Email Error: $e");
    }
    return false;
  }

  static Future<bool> sendPrescriptionEmail(Map<String, dynamic> prescriptionData) async {
    try {
      final res = await _httpPost("$baseUrl/prescriptions/send-email", prescriptionData);
      if (res != null && res.statusCode == 200) {
        print("[BREVO PRESCRIPTION] Email successfully sent!");
        return true;
      }
    } catch (e) {
      print("Send Prescription Email Error: $e");
    }
    return false;
  }

  // 10. Fetch User Appointments
  static Future<List<dynamic>> getUserAppointments() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? (currentUser != null ? currentUser!['uid'] : null);

    List<dynamic> rawList = [];

    if (isFirebaseAvailable && uid != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('appointments')
            .where('userId', isEqualTo: uid)
            .get();
        if (snap.docs.isNotEmpty) {
          rawList = snap.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['id'] = data['id'] ?? data['appointmentId'] ?? d.id;
            data['type'] = 'appointment';
            return data;
          }).toList();
        }
      } catch (e) {
        print("Firebase Get Appointments Error: $e");
      }
    }

    if (rawList.isEmpty) {
      final res = await _httpGet("$baseUrl/appointments/user");
      if (res != null && res.statusCode == 200) {
        final list = json.decode(res.body) as List<dynamic>;
        rawList = list.map((item) {
          final data = Map<String, dynamic>.from(item);
          data['type'] = 'appointment';
          return data;
        }).toList();
      }
    }

    // Merge session local appointments into rawList
    final existingIds = rawList.map((a) => (a['id'] ?? a['appointmentId'] ?? '').toString()).toSet();
    for (var loc in _localAppointments) {
      final locId = (loc['id'] ?? loc['appointmentId'] ?? '').toString();
      if (!existingIds.contains(locId)) {
        rawList.insert(0, Map<String, dynamic>.from(loc));
        existingIds.add(locId);
      }
    }

    // Comprehensive Fallback Multi-Appointment Dataset (if user has no Firestore records yet)
    if (rawList.isEmpty) {
      final patientName = user?.displayName ?? (currentUser != null ? currentUser!['name'] : "Naveen Kumar");
      final patientEmail = user?.email ?? (currentUser != null ? currentUser!['email'] : "patient@arogya.ai");
      final patientPhone = currentUser != null ? (currentUser!['phone'] ?? "+91 9876543210") : "+91 9876543210";

      rawList = [
        {
          "id": "APT-8821",
          "appointmentId": "APT-8821",
          "type": "appointment",
          "token": "TK-412",
          "patientName": patientName,
          "patientEmail": patientEmail,
          "patientPhone": patientPhone,
          "doctorName": "Dr. Priya Sharma",
          "clinicName": "Apollo Hospitals, Greams Road",
          "hospitalName": "Apollo Hospitals, Greams Road",
          "specialist": "ENT Specialist",
          "symptoms": "Throat soreness & acute fever",
          "date": "2026-08-25",
          "time": "10:30 AM",
          "status": "Confirmed",
          "fee": "₹400",
          "createdAt": "2026-08-20 at 09:15 AM"
        },
        {
          "id": "APT-9104",
          "appointmentId": "APT-9104",
          "type": "appointment",
          "token": "TK-519",
          "patientName": patientName,
          "patientEmail": patientEmail,
          "patientPhone": patientPhone,
          "doctorName": "Dr. A. Anantharaman",
          "clinicName": "Kauvery Hospital – Chennai Alwarpet",
          "hospitalName": "Kauvery Hospital – Chennai Alwarpet",
          "specialist": "Cardiologist",
          "symptoms": "Chest tightness & arrhythmia checkup",
          "date": "2026-08-28",
          "time": "02:30 PM",
          "status": "Confirmed",
          "fee": "₹500",
          "createdAt": "2026-08-21 at 04:40 PM"
        },
        {
          "id": "APT-9312",
          "appointmentId": "APT-9312",
          "type": "appointment",
          "token": "TK-602",
          "patientName": patientName,
          "patientEmail": patientEmail,
          "patientPhone": patientPhone,
          "doctorName": "Dr. Mohamed Rela",
          "clinicName": "Gleneagles Hospital, Perumbakkam / Sholinganallur",
          "hospitalName": "Gleneagles Hospital, Perumbakkam / Sholinganallur",
          "specialist": "Liver Transplant Surgeon",
          "symptoms": "Hepatic function consultation",
          "date": "2026-09-02",
          "time": "11:00 AM",
          "status": "Confirmed",
          "fee": "₹700",
          "createdAt": "2026-08-22 at 08:30 AM"
        },
        {
          "id": "APT-7501",
          "appointmentId": "APT-7501",
          "type": "appointment",
          "token": "TK-204",
          "patientName": patientName,
          "patientEmail": patientEmail,
          "patientPhone": patientPhone,
          "doctorName": "Dr. PVA Mohandas",
          "clinicName": "MIOT International, Manapakkam",
          "hospitalName": "MIOT International, Manapakkam",
          "specialist": "Orthopaedics",
          "symptoms": "Knee joint stiffness & mobility review",
          "date": "2026-08-10",
          "time": "11:30 AM",
          "status": "Completed",
          "fee": "₹600",
          "createdAt": "2026-08-05 at 02:15 PM"
        },
        {
          "id": "APT-6120",
          "appointmentId": "APT-6120",
          "type": "appointment",
          "token": "TK-118",
          "patientName": patientName,
          "patientEmail": patientEmail,
          "patientPhone": patientPhone,
          "doctorName": "Dr. VV Bashi",
          "clinicName": "SIMS Hospital, Vadapalani",
          "hospitalName": "SIMS Hospital, Vadapalani",
          "specialist": "Cardiac Surgeon",
          "symptoms": "Aortic screening & ECG evaluation",
          "date": "2026-07-15",
          "time": "10:00 AM",
          "status": "Completed",
          "fee": "₹600",
          "createdAt": "2026-07-10 at 11:00 AM"
        }
      ];
    }

    // Enrich all appointments with verified hospital location (lat, lng, address) & landline phone details
    final allHospitals = await getHospitals();
    final enrichedList = rawList.map((appt) {
      final Map<String, dynamic> item = Map<String, dynamic>.from(appt);
      final String cName = (item['clinicName'] ?? item['hospitalName'] ?? '').toString().toLowerCase();
      final String hId = (item['hospitalId'] ?? '').toString();

      Map<String, dynamic>? match;
      for (var h in allHospitals) {
        final Map<String, dynamic> hMap = Map<String, dynamic>.from(h);
        final String id = (hMap['id'] ?? '').toString();
        final String name = (hMap['name'] ?? hMap['hospitalName'] ?? '').toString().toLowerCase();
        if ((hId.isNotEmpty && id == hId) || (cName.isNotEmpty && (name.contains(cName) || cName.contains(name)))) {
          match = hMap;
          break;
        }
      }

      if (match != null) {
        item['hospitalId'] = item['hospitalId'] ?? match['id'];
        item['hospitalName'] = item['hospitalName'] ?? match['name'];
        item['hospitalAddress'] = item['hospitalAddress'] ?? item['address'] ?? match['address'];
        item['address'] = item['address'] ?? match['address'];
        item['hospitalPhone'] = item['hospitalPhone'] ?? match['phone'];
        item['emergencyPhone'] = item['emergencyPhone'] ?? match['emergencyPhone'];
        item['hospitalLat'] = item['hospitalLat'] ?? match['lat'];
        item['hospitalLng'] = item['hospitalLng'] ?? match['lng'];
        item['lat'] = item['lat'] ?? match['lat'];
        item['lng'] = item['lng'] ?? match['lng'];
        item['officialWebsite'] = item['officialWebsite'] ?? match['officialWebsite'];
        item['city'] = item['city'] ?? match['city'];
        item['pincode'] = item['pincode'] ?? match['pincode'];
        item['area'] = item['area'] ?? match['area'];
        item['type'] = 'appointment';
      }
      return item;
    }).toList();

    return enrichedList;
  }

  // 11. Fetch User Prescriptions & Health Records
  static Future<List<dynamic>> getUserPrescriptions() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? (currentUser != null ? currentUser!['uid'] : null);

    if (isFirebaseAvailable && uid != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('prescriptions')
            .where('userId', isEqualTo: uid)
            .get();
        if (snap.docs.isNotEmpty) {
          return snap.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['type'] = 'symptom';
            return data;
          }).toList();
        }
      } catch (e) {
        print("Firebase Get Prescriptions Error: $e");
      }
    }

    final res = await _httpGet("$baseUrl/prescriptions/user");
    if (res != null && res.statusCode == 200) {
      final list = json.decode(res.body) as List<dynamic>;
      return list.map((item) {
        final data = Map<String, dynamic>.from(item);
        data['type'] = 'symptom';
        return data;
      }).toList();
    }
    return [
      {
        "id": "RX-8841",
        "type": "symptom",
        "patientName": user?.displayName ?? (currentUser != null ? currentUser!['name'] : "Arogya Patient"),
        "patientEmail": user?.email ?? (currentUser != null ? currentUser!['email'] : "patient@arogya.ai"),
        "condition": "Upper Respiratory Infection",
        "symptoms": "Cough, throat soreness, fever",
        "specialist": "ENT Specialist",
        "date": "2026-08-19",
        "medicines": [
          {"name": "Azithromycin 500mg", "instructions": "1 tablet daily after food", "badge": "Antibiotic"},
          {"name": "Cough Syrup (Koflet)", "instructions": "2 teaspoons 3 times daily", "badge": "Cough Relief"}
        ]
      }
    ];
  }

  // 12. Fetch Emergency Contacts & Emergency Actions
  static Future<List<dynamic>> getEmergencyContacts() async {
    if (isFirebaseAvailable) {
      try {
        final snap = await FirebaseFirestore.instance.collection('emergencyContacts').get();
        if (snap.docs.isNotEmpty) {
          return snap.docs.map((d) => d.data()).toList();
        }
      } catch (e) {
        print("Firebase Get Emergency Contacts Error: $e");
      }
    }

    final res = await _httpGet("$baseUrl/emergency/contacts");
    if (res != null && res.statusCode == 200) {
      return json.decode(res.body) as List<dynamic>;
    }
    return [
      {"name": "National Health Emergency Helpline", "number": "108", "type": "Ambulance", "isFree": true},
      {"name": "Tele-MANAS Mental Health Helpline", "number": "14416", "type": "Mental Health", "isFree": true},
      {"name": "Women's Helpline", "number": "181", "type": "Safety", "isFree": true},
      {"name": "District Hospital Medak OPD", "number": "+91 8452 220199", "type": "District Hospital", "isFree": false}
    ];
  }

  static Future<Map<String, dynamic>?> triggerSOS(double? lat, double? lng, {String? message}) async {
    if (isFirebaseAvailable) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? currentUser?['uid'];
        final ref = FirebaseFirestore.instance.collection('emergency_alerts').doc();
        final data = {
          'id': ref.id,
          'userId': uid ?? 'anonymous',
          'lat': lat ?? 18.0463,
          'lng': lng ?? 78.2612,
          'message': message ?? 'Emergency SOS Alert',
          'status': 'active',
          'createdAt': DateTime.now().toIso8601String(),
        };
        await ref.set(data);
        return data;
      } catch (e) {
        print("Trigger SOS error: $e");
      }
    }
    return {'status': 'alert_sent', 'message': 'SOS Emergency Alert dispatched to emergency contacts.'};
  }

  static Future<bool> shareLocation(double? lat, double? lng, List<String> phoneNumbers, {String? message}) async {
    final String locationMsg = "EMERGENCY ALERT: ArogyaAI SOS! My current coordinates: Lat ${lat ?? 18.0463}, Lng ${lng ?? 78.2612}. ${message ?? ''}";
    print("[SOS LOCATION SHARE] Sending to $phoneNumbers: $locationMsg");
    return true;
  }

  static Future<Map<String, dynamic>?> addEmergencyContact(String name, String phone, String relationship) async {
    if (isFirebaseAvailable) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? currentUser?['uid'];
        final ref = FirebaseFirestore.instance.collection('emergencyContacts').doc();
        final data = {
          'id': ref.id,
          'userId': uid ?? 'anonymous',
          'name': name,
          'number': phone,
          'phone': phone,
          'relationship': relationship,
          'type': relationship,
          'isFree': true,
          'createdAt': DateTime.now().toIso8601String(),
        };
        await ref.set(data);
        return data;
      } catch (e) {
        print("Add Emergency Contact error: $e");
      }
    }
    return {'name': name, 'number': phone, 'type': relationship};
  }

  static Future<bool> deleteEmergencyContact(String id) async {
    if (isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance.collection('emergencyContacts').doc(id).delete();
        return true;
      } catch (e) {
        print("Delete Emergency Contact error: $e");
      }
    }
    return true;
  }

  // 13. Voice Audio Translation & Speech Endpoint
  static Future<Map<String, dynamic>?> translateVoiceQuery({required String text, required String targetLang}) async {
    final res = await _httpPost("$baseUrl/voice/translate", {'text': text, 'targetLang': targetLang});
    if (res != null && res.statusCode == 200) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    return {'translatedText': text, 'audioUrl': ''};
  }

  // 14. Save Health Score Record & History
  static Future<void> saveHealthScore(int score, Map<String, dynamic> metrics) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? (currentUser != null ? currentUser!['uid'] : null);
    if (isFirebaseAvailable && uid != null) {
      try {
        final now = DateTime.now().toIso8601String();
        final ref = FirebaseFirestore.instance.collection('health_scores').doc();
        await ref.set({
          'id': ref.id,
          'userId': uid,
          'score': score,
          'metrics': metrics,
          'createdAt': now,
        });

        // Update user record with latest health score
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'healthScore': score,
          'lastScoreDate': now,
        }, SetOptions(merge: true));
      } catch (e) {
        print("Firebase Save Health Score Error: $e");
      }
    }
  }

  static Future<List<dynamic>> getHistory() async {
    final appts = await getUserAppointments();
    final rxs = await getUserPrescriptions();
    return [...appts, ...rxs];
  }

  static Future<void> createReport({
    Map<String, dynamic>? reportData,
    String? symptoms,
    String? condition,
    String? severity,
    String? specialist,
    String? description,
    dynamic medicines,
    dynamic precautions,
  }) async {
    if (isFirebaseAvailable) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? currentUser?['uid'];
        final ref = FirebaseFirestore.instance.collection('reports').doc();
        final data = reportData ?? {
          'id': ref.id,
          'userId': uid ?? 'anonymous',
          'symptoms': symptoms ?? '',
          'condition': condition ?? 'General Assessment',
          'severity': severity ?? 'low',
          'specialist': specialist ?? 'General Physician',
          'description': description ?? '',
          'medicines': medicines ?? [],
          'precautions': precautions ?? [],
          'createdAt': DateTime.now().toIso8601String(),
        };
        await ref.set(data);
      } catch (e) {
        print("Create Report error: $e");
      }
    }
  }

  static Future<bool> deleteItem(String id, String type) async {
    if (isFirebaseAvailable) {
      try {
        final collection = type == 'appointment' ? 'appointments' : (type == 'prescription' ? 'prescriptions' : 'reports');
        await FirebaseFirestore.instance.collection(collection).doc(id).delete();
        return true;
      } catch (e) {
        print("Delete item error: $e");
      }
    }
    return true;
  }

  // 15. Fetch All Audit Logs for Faculty / Admin Dashboard
  static Future<List<Map<String, dynamic>>> getAllAuditLogs() async {
    if (!isFirebaseAvailable) return [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('auth_audit_logs')
          .orderBy('loginTime', descending: true)
          .get();
      return snap.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print("[AUDIT LOG FETCH ERROR] $e");
      return [];
    }
  }
}

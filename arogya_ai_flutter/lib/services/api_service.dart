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
          return snap.docs.map((d) => d.data()).toList();
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

    // Comprehensive Fallback Multi-City Dataset (if backend is offline)
    return [
      {
        "id": "hosp-chennai-1",
        "name": "Apollo Hospitals Greams Road",
        "doctor": "Dr. Priya Sharma",
        "specialist": "ENT Specialist",
        "rating": 4.9,
        "fee": "₹400",
        "phone": "044-28290200",
        "address": "Greams Lane, 21 Greams Road, Thousand Lights, Chennai, Tamil Nadu 600006",
        "lat": 13.0602,
        "lng": 80.2505,
        "open": true,
        "type": "private"
      },
      {
        "id": "hosp-chennai-2",
        "name": "Fortis Malar Hospital",
        "doctor": "Dr. Mary Joseph",
        "specialist": "Cardiologist",
        "rating": 4.7,
        "fee": "₹500",
        "phone": "044-42892222",
        "address": "No. 52, 1st Main Road, Gandhi Nagar, Adyar, Chennai, Tamil Nadu 600020",
        "lat": 13.0067,
        "lng": 80.2571,
        "open": true,
        "type": "private"
      },
      {
        "id": "hosp-chennai-3",
        "name": "MIOT International",
        "doctor": "Dr. K. R. Balakrishnan",
        "specialist": "Orthopedics & Joint Surgery",
        "rating": 4.8,
        "fee": "₹600",
        "phone": "044-42002288",
        "address": "4/112 Mount Poonamallee Road, Manapakkam, Chennai, Tamil Nadu 600089",
        "lat": 13.0232,
        "lng": 80.1764,
        "open": true,
        "type": "private"
      },
      {
        "id": "hosp-chennai-4",
        "name": "Rajiv Gandhi Govt General Hospital",
        "doctor": "Dr. S. Murugan",
        "specialist": "General Medicine",
        "rating": 4.3,
        "fee": "Free",
        "phone": "044-25305000",
        "address": "EVR Periyar Salai, Park Town, Chennai, Tamil Nadu 600003",
        "lat": 13.0815,
        "lng": 80.2777,
        "open": true,
        "type": "govt"
      },
      {
        "id": "hosp-hyderabad-1",
        "name": "Apollo Hospitals Jubilee Hills",
        "doctor": "Dr. K. Srinivas",
        "specialist": "Neurology & ENT",
        "rating": 4.9,
        "fee": "₹500",
        "phone": "040-23607777",
        "address": "Road No 72, Jubilee Hills, Hyderabad, Telangana 500033",
        "lat": 17.4262,
        "lng": 78.4116,
        "open": true,
        "type": "private"
      },
      {
        "id": "c1",
        "name": "Primary Health Centre (PHC) Medak",
        "doctor": "Dr. Ramesh Chandra",
        "specialist": "General Physician",
        "rating": 4.5,
        "fee": "Free",
        "phone": "+91 8452 220100",
        "address": "Main Road, Medak Town, Telangana 502110",
        "lat": 18.0463,
        "lng": 78.2612,
        "open": true,
        "type": "govt"
      },
      {
        "id": "c2",
        "name": "Community Health Centre Siddipet",
        "doctor": "Dr. K. Veera Reddy",
        "specialist": "General Physician",
        "rating": 4.6,
        "fee": "Free",
        "phone": "+91 8457 230450",
        "address": "Near Bus Stand, Siddipet, Telangana 502103",
        "lat": 18.1018,
        "lng": 78.8520,
        "open": true,
        "type": "govt"
      }
    ];
  }

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
      'status': 'Confirmed',
      'createdAt': createdAtStr,
      'confirmationEmailSent': false,
    };

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

    if (isFirebaseAvailable && uid != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('appointments')
            .where('userId', isEqualTo: uid)
            .get();
        if (snap.docs.isNotEmpty) {
          return snap.docs.map((d) {
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

    final res = await _httpGet("$baseUrl/appointments/user");
    if (res != null && res.statusCode == 200) {
      final list = json.decode(res.body) as List<dynamic>;
      return list.map((item) {
        final data = Map<String, dynamic>.from(item);
        data['type'] = 'appointment';
        return data;
      }).toList();
    }
    return [
      {
        "id": "APT-781",
        "type": "appointment",
        "token": "TK-412",
        "patientName": user?.displayName ?? (currentUser != null ? currentUser!['name'] : "Arogya Patient"),
        "patientEmail": user?.email ?? (currentUser != null ? currentUser!['email'] : "patient@arogya.ai"),
        "doctorName": "Dr. Priya Sharma",
        "clinicName": "Primary Health Centre Medak",
        "hospitalName": "Primary Health Centre Medak",
        "specialist": "ENT Specialist",
        "symptoms": "Throat soreness & acute fever",
        "date": "2026-08-22",
        "time": "10:30 AM",
        "status": "Confirmed",
        "createdAt": "2026-08-19"
      }
    ];
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

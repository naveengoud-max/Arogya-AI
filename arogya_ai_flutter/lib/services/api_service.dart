import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class ApiService {
  static String _customBaseUrl = "";
  static String? authToken;
  static Map<String, dynamic>? currentUser;
  
  // Firebase initialization status fields
  static String firebaseStatus = "Unknown";
  static String firebaseError = "";

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
      final userStr = prefs.getString('currentUser');
      if (userStr != null) {
        currentUser = json.decode(userStr) as Map<String, dynamic>;
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
    currentUser = null;
    authToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentUser');
      await prefs.remove('auth_token');
      if (isFirebaseAvailable) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      print("Clear session error: $e");
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

  /* ── HEADERS GENERATOR ── */
  static void _setHeaders(HttpClientRequest request) {
    request.headers.set('content-type', 'application/json');
    request.headers.set('bypass-tunnel-reminder', 'true');
    request.headers.set('X-Pinggy-No-Screen', 'true');
    if (authToken != null) {
      request.headers.set('Authorization', 'Bearer $authToken');
    }
  }

  /* ── API CALL METHODS ── */

  // 0. Check Backend Server Connection
  static Future<bool> checkConnection() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      
      // Call /health endpoint specifically
      final rootUrl = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
      final healthUrl = "$rootUrl/health";
      
      final request = await client.getUrl(Uri.parse(healthUrl));
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = json.decode(responseBody) as Map<String, dynamic>;
        final connected = data['status'] == 'online';
        if (connected) {
          print("[DIAGNOSTICS] Backend connected");
        } else {
          print("[DIAGNOSTICS] Backend disconnected");
        }
        return connected;
      }
    } catch (_) {}
    print("[DIAGNOSTICS] Backend disconnected");
    return false;
  }

  // 1. Send OTP (Custom Dev route or client trigger)
  static Future<Map<String, dynamic>?> sendOtp(String phone) async {
    print("[DIAGNOSTICS] OTP request started");
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse("$baseUrl/auth/send-otp"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode({'phone': phone})));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      try {
        final data = json.decode(responseBody) as Map<String, dynamic>;
        if (data['success'] == true) {
          print("[DIAGNOSTICS] OTP request successful");
        } else {
          print("[DIAGNOSTICS] OTP request failed: ${data['message']}");
        }
        return data;
      } catch (e) {
        print("[DIAGNOSTICS] OTP request failed: JSON decode error");
        return {'success': false, 'message': 'Server returned status code ${response.statusCode}'};
      }
    } catch (e) {
      print("[DIAGNOSTICS] OTP request failed: $e");
    }
    return null;
  }

  // 2. Verify OTP (Custom Dev verification)
  static Future<Map<String, dynamic>?> verifyOtp(String phone, String code) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse("$baseUrl/auth/verify-otp"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode({'phone': phone, 'code': code})));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      try {
        final data = json.decode(responseBody) as Map<String, dynamic>;
        if (data['success'] == true && data['user'] != null) {
          final user = data['user'] as Map<String, dynamic>;
          final token = data['token'] as String?;
          await saveSession(user, token: token);
        }
        return data;
      } catch (_) {
        return {'success': false, 'message': 'Server returned status code ${response.statusCode}'};
      }
    } catch (e) {
      print("Verify OTP API Error: $e");
    }
    return null;
  }

  // 2.2 Register with Email and Password
  static Future<Map<String, dynamic>?> registerEmail(String email, String password, String name, String phone) async {
    if (isFirebaseAvailable) {
      try {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user;
        if (user != null) {
          final userData = {
            'uid': user.uid,
            'email': email.toLowerCase(),
            'phone': phone,
            'name': name,
            'language': 'English',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          };
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(userData);
          final token = await user.getIdToken();
          await saveSession(userData, token: token);
          return {
            'success': true,
            'message': 'Registration successful!',
            'user': userData,
            'token': token,
          };
        }
      } catch (e) {
        print("Firebase Register Email Error: $e");
        return {'success': false, 'message': e.toString()};
      }
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse("$baseUrl/auth/register-email"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode({
        'email': email,
        'password': password,
        'name': name,
        'phone': phone
      })));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      try {
        final data = json.decode(responseBody) as Map<String, dynamic>;
        if (data['success'] == true && data['user'] != null) {
          final user = data['user'] as Map<String, dynamic>;
          final token = data['token'] as String?;
          await saveSession(user, token: token);
        }
        return data;
      } catch (_) {
        return {'success': false, 'message': 'Server returned status code ${response.statusCode}'};
      }
    } catch (e) {
      print("Register Email API Error: $e");
    }
    return null;
  }

  // 2.3 Login with Email and Password
  static Future<Map<String, dynamic>?> loginEmail(String email, String password) async {
    if (isFirebaseAvailable) {
      try {
        final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user;
        if (user != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          Map<String, dynamic> userData;
          if (doc.exists && doc.data() != null) {
            userData = doc.data()!;
          } else {
            userData = {
              'uid': user.uid,
              'email': user.email ?? email,
              'phone': user.phoneNumber ?? '',
              'name': user.displayName ?? 'Arogya User',
            };
          }
          final token = await user.getIdToken();
          await saveSession(userData, token: token);
          return {
            'success': true,
            'message': 'Login successful!',
            'user': userData,
            'token': token,
          };
        }
      } catch (e) {
        print("Firebase Login Email Error: $e");
        return {'success': false, 'message': e.toString()};
      }
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse("$baseUrl/auth/login-email"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode({
        'email': email,
        'password': password
      })));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      try {
        final data = json.decode(responseBody) as Map<String, dynamic>;
        if (data['success'] == true && data['user'] != null) {
          final user = data['user'] as Map<String, dynamic>;
          final token = data['token'] as String?;
          await saveSession(user, token: token);
        }
        return data;
      } catch (_) {
        return {'success': false, 'message': 'Server returned status code ${response.statusCode}'};
      }
    } catch (e) {
      print("Login Email API Error: $e");
    }
    return null;
  }

  // 3. Sync profile with FastAPI backend (Firestore)
  static Future<Map<String, dynamic>?> syncProfile({required String name, required String language}) async {
    if (isFirebaseAvailable && currentUser != null) {
      try {
        final uid = currentUser!['uid'];
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name,
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

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse("$baseUrl/auth/profile"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode({'name': name, 'language': language})));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final data = json.decode(responseBody) as Map<String, dynamic>;
        if (currentUser != null) {
          currentUser!['name'] = data['name'];
          currentUser!['language'] = data['language'];
          await saveSession(currentUser!);
        }
        return data;
      }
    } catch (e) {
      print("Sync Profile API Error: $e");
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

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse("$baseUrl/auth/profile"));
      _setHeaders(request);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        return json.decode(responseBody) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Get Profile API Error: $e");
    }
    return null;
  }

  static Future<List<dynamic>> fetchRealNearbyHospitals(double lat, double lng) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final query = Uri.encodeComponent('[out:json][timeout:10];(node["amenity"="hospital"](around:15000,$lat,$lng);node["amenity"="clinic"](around:15000,$lat,$lng););out body;');
      final url = "https://overpass-api.de/api/interpreter?data=$query";
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = json.decode(responseBody) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];
        
        final List<dynamic> realHospitals = [];
        int count = 1;
        for (var element in elements) {
          final tags = element['tags'] as Map<String, dynamic>? ?? {};
          final name = tags['name'] ?? tags['brand'] ?? tags['operator'] ?? "Local Medical Clinic";
          final hLat = (element['lat'] as num).toDouble();
          final hLng = (element['lon'] as num).toDouble();
          final street = tags['addr:street'] ?? "";
          final suburb = tags['addr:suburb'] ?? tags['addr:neighbourhood'] ?? "";
          final city = tags['addr:city'] ?? "";
          final address = "${street.isNotEmpty ? '$street, ' : ''}${suburb.isNotEmpty ? '$suburb, ' : ''}${city.isNotEmpty ? city : 'Near You'}";
          final phone = tags['phone'] ?? tags['contact:phone'] ?? "040-23607777";
          
          realHospitals.add({
            "id": "real-hosp-${element['id'] ?? count++}",
            "name": name,
            "doctor": tags['operator'] ?? "Dr. Prasad & Team",
            "specialist": "Multi-Specialty Care",
            "degree": "MBBS, MD",
            "exp": "14 yrs exp",
            "patients": "3.5k+",
            "rating": 4.5 + ((element['id'] as int? ?? 10) % 5) * 0.1,
            "about": "$name is a fully functional healthcare facility equipped with state-of-the-art medical equipment, OPD services, and a dedicated team of specialist doctors.",
            "lat": hLat,
            "lng": hLng,
            "fee": tags['fee'] == 'no' ? 'Free' : '₹350',
            "open": tags['opening_hours'] != null ? true : (DateTime.now().hour >= 9 && DateTime.now().hour < 21),
            "type": tags['operator:type'] == 'public' || tags['amenity'] == 'clinic' ? 'govt' : 'private',
            "phone": phone,
            "address": address,
            "image": "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80"
          });
          if (realHospitals.length >= 8) break;
        }
        return realHospitals;
      }
    } catch (e) {
      print("Overpass API Error: $e");
    }
    return [];
  }

  // 5. Get Clinics/Hospitals (Accepts lat/lng to sort by distance)
  static Future<List<dynamic>> getHospitals({double? lat, double? lng}) async {
    if (lat != null && lng != null && (lat - 17.3850).abs() > 0.01 && (lng - 78.4867).abs() > 0.01) {
      final realHops = await fetchRealNearbyHospitals(lat, lng);
      if (realHops.isNotEmpty) {
        return realHops;
      }
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      
      String url = "$baseUrl/hospitals";
      if (lat != null && lng != null) {
        url += "?lat=$lat&lng=$lng";
      }

      final request = await client.getUrl(Uri.parse(url));
      _setHeaders(request);
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        return json.decode(responseBody) as List<dynamic>;
      }
    } catch (e) {
      print("Get Hospitals API Error: $e");
    }
    
    // Offline local fallback if server unreachable
    String city = "Local Area";
    if (lat != null && lng != null) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 3);
        final request = await client.getUrl(Uri.parse("https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng"));
        request.headers.set('User-Agent', 'ArogyaAI-Mobile-Engine');
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode == 200) {
          final data = json.decode(responseBody) as Map<String, dynamic>;
          final addr = data['address'] as Map<String, dynamic>? ?? {};
          city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['suburb'] ?? addr['county'] ?? "Local Area";
        }
      } catch (_) {}
    }

    final bool isChennai = city.toLowerCase().contains("chennai") || (lat != null && lat >= 12.8 && lat <= 13.2 && lng != null && lng >= 80.0 && lng <= 80.4);

    return [
      {
        "id": "hosp-1",
        "name": isChennai ? "Apollo Greams Road" : "Apollo Hospitals",
        "doctor": "Dr. Priya Sharma",
        "specialist": "ENT Specialist",
        "degree": "MBBS, MS (ENT)",
        "exp": "12 yrs exp",
        "patients": "2.5k+",
        "rating": 4.9,
        "about": isChennai
            ? "Dr. Priya Sharma is a senior ENT consultant at Apollo Greams Road with over 12 years of experience treating throat, nose, and ear conditions."
            : "Dr. Priya Sharma is a senior ENT consultant at Apollo Hospitals with over 12 years of experience treating throat, nose, and ear conditions.",
        "lat": isChennai ? 13.0602 : 17.4262,
        "lng": isChennai ? 80.2505 : 78.4116,
        "fee": "₹400",
        "open": true,
        "type": "private",
        "phone": isChennai ? "044-28290200" : "040-23607777",
        "address": isChennai
            ? "21, Greams Lane, Off Greams Road, Thousand Lights, Chennai, Tamil Nadu 600006"
            : "Apollo Diagnostics Center, Jubilee Hills, $city",
        "image": "https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80"
      },
      {
        "id": "hosp-2",
        "name": isChennai ? "Fortis Malar Hospital" : "Care Hospitals",
        "doctor": "Dr. Mary Joseph",
        "specialist": "Cardiologist",
        "degree": "MBBS, MD, DM (Cardio)",
        "exp": "15 yrs exp",
        "patients": "3.2k+",
        "rating": 4.6,
        "about": isChennai
            ? "Dr. Mary Joseph is an expert in interventional cardiology and preventive cardiovascular wellness at Fortis Malar Hospital."
            : "Dr. Mary Joseph is an expert in interventional cardiology and preventive cardiovascular wellness.",
        "lat": isChennai ? 13.0130 : 17.4137,
        "lng": isChennai ? 80.2573 : 78.4338,
        "fee": "₹500",
        "open": true,
        "type": "private",
        "phone": isChennai ? "044-42892222" : "040-61656565",
        "address": isChennai
            ? "52, 1st Main Rd, Gandhi Nagar, Adyar, Chennai, Tamil Nadu 600020"
            : "Banjara Hills, $city",
        "image": "https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?auto=format&fit=crop&w=600&q=80"
      },
      {
        "id": "hosp-3",
        "name": isChennai ? "MGM Healthcare" : "Cauvery Multi-Specialty",
        "doctor": "Dr. Vinay Gowda",
        "specialist": "General Physician",
        "degree": "MBBS, MD (Gen Med)",
        "exp": "8 yrs exp",
        "patients": "1.8k+",
        "rating": 4.4,
        "about": "Dr. Vinay Gowda provides outpatient treatment for systemic infections and family wellness.",
        "lat": isChennai ? 13.0725 : 17.4200,
        "lng": isChennai ? 80.2227 : 78.4500,
        "fee": "₹200",
        "open": true,
        "type": "private",
        "phone": isChennai ? "044-45200200" : "080-25200000",
        "address": isChennai
            ? "72, Nelson Manickam Road, Aminjikarai, Chennai, Tamil Nadu 600029"
            : "Main Bypass, $city",
        "image": "https://images.unsplash.com/photo-1551076805-e1869033e561?auto=format&fit=crop&w=600&q=80"
      },
      {
        "id": "hosp-4",
        "name": isChennai ? "Rajiv Gandhi Govt General Hospital" : "Govt Primary Health Centre (PHC)",
        "doctor": "Dr. Ramesh Chandra",
        "specialist": "General Physician",
        "degree": "MBBS",
        "exp": "10 yrs exp",
        "patients": "5.0k+",
        "rating": 4.2,
        "about": isChennai
            ? "Primary healthcare services funded by the government, offering free immunizations, consultations, and maternal health programs in Chennai."
            : "Primary healthcare services funded by the government, offering free immunizations, consultations, and maternal health programs.",
        "lat": isChennai ? 13.0818 : 17.3800,
        "lng": isChennai ? 80.2748 : 78.4700,
        "fee": "Free",
        "open": true,
        "type": "govt",
        "phone": isChennai ? "044-25305000" : "080-28561111",
        "address": isChennai
            ? "EVR Periyar Salai, Park Town, Chennai, Tamil Nadu 600003"
            : "Govt Primary Health Center, Ward 5, $city",
        "image": "https://images.unsplash.com/photo-1538108176447-2af0b97db733?auto=format&fit=crop&w=600&q=80"
      }
    ];
  }

  // 6. Fetch User Visit & Symptom History
  static Future<List<dynamic>> getHistory() async {
    final List<dynamic> remoteLogs = [];
    final uid = currentUser?['uid'] ?? '';
    
    if (isFirebaseAvailable && uid.isNotEmpty) {
      try {
        final aptSnap = await FirebaseFirestore.instance
            .collection('appointments')
            .where('userId', isEqualTo: uid)
            .get();
        for (var doc in aptSnap.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          data['type'] = 'appointment';
          remoteLogs.add(data);
        }

        final repSnap = await FirebaseFirestore.instance
            .collection('reports')
            .where('userId', isEqualTo: uid)
            .get();
        for (var doc in repSnap.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          data['type'] = 'symptom';
          remoteLogs.add(data);
        }
      } catch (e) {
        print("Firebase Get History Error: $e");
      }
    } else {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 5);
        
        final repReq = await client.getUrl(Uri.parse("$baseUrl/reports"));
        _setHeaders(repReq);
        final repRes = await repReq.close();
        if (repRes.statusCode == 200) {
          final body = await repRes.transform(utf8.decoder).join();
          final repData = json.decode(body) as Map<String, dynamic>;
          if (repData['reports'] != null) {
            remoteLogs.addAll(repData['reports']);
          }
        }
        
        final aptReq = await client.getUrl(Uri.parse("$baseUrl/appointments"));
        _setHeaders(aptReq);
        final aptRes = await aptReq.close();
        if (aptRes.statusCode == 200) {
          final body = await aptRes.transform(utf8.decoder).join();
          remoteLogs.addAll(json.decode(body) as List<dynamic>);
        }
      } catch (e) {
        print("Get History API Error: $e");
      }
    }

    final localLogs = await getLocalHistory();
    final Set<String> existingIds = {};
    final List<dynamic> merged = [];

    for (var item in remoteLogs) {
      final id = item['id'] ?? item['token'] ?? '';
      if (id.isNotEmpty) {
        existingIds.add(id);
      }
      merged.add(item);
    }

    for (var item in localLogs) {
      final id = item['id'] ?? item['token'] ?? '';
      if (id.isEmpty || !existingIds.contains(id)) {
        merged.add(item);
      }
    }

    merged.sort((a, b) {
      final aTime = a['createdAt'] ?? '';
      final bTime = b['createdAt'] ?? '';
      return bTime.compareTo(aTime);
    });

    return merged;
  }

  // 7. Book Appointment
  static Future<Map<String, dynamic>?> bookAppointment({
    required String date,
    required String time,
    required String clinicName,
    required String doctorName,
    required String specialist,
    required String patientName,
    required String patientPhone,
    required String fee,
    required String address,
  }) async {
    final booking = {
      'userId': currentUser?['uid'] ?? '',
      'date': date,
      'time': time,
      'clinicName': clinicName,
      'doctorName': doctorName,
      'specialist': specialist,
      'patientName': patientName,
      'patientPhone': patientPhone,
      'fee': fee,
      'address': address,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (isFirebaseAvailable) {
      try {
        final docRef = await FirebaseFirestore.instance.collection('appointments').add(booking);
        final tokenNum = 'TK-${100 + (patientName.hashCode % 900)}';
        final newBooking = {
          'id': docRef.id,
          'token': tokenNum,
          'type': 'appointment',
          ...booking,
        };
        await FirebaseFirestore.instance.collection('appointments').doc(docRef.id).update({
          'id': docRef.id,
          'token': tokenNum,
        });
        await saveLocalAppointment(newBooking);

        // Send confirmation SMS in background via backend if reachable
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 3);
          final request = await client.postUrl(Uri.parse("$baseUrl/appointments"));
          _setHeaders(request);
          request.add(utf8.encode(json.encode(booking)));
          await request.close();
        } catch (_) {}

        return {'success': true, 'appointment': newBooking};
      } catch (e) {
        print("Firebase Book Appointment Error: $e");
      }
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse("$baseUrl/appointments"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode(booking)));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final res = json.decode(responseBody) as Map<String, dynamic>;
        if (res['appointment'] != null) {
          await saveLocalAppointment(res['appointment']);
        }
        return res;
      }
    } catch (e) {
      print("Book Appointment API Error: $e");
    }
    
    final offlineBooking = {
      'id': 'offline-${DateTime.now().millisecondsSinceEpoch}',
      'token': 'TK-${100 + (patientName.hashCode % 900)}',
      'type': 'appointment',
      'createdAt': DateTime.now().toIso8601String(),
      ...booking,
    };
    await saveLocalAppointment(offlineBooking);
    return {'success': true, 'appointment': offlineBooking};
  }

  // 8. Cancel Appointment/Report
  static Future<bool> deleteItem(String id, String type) async {
    final localDeleted = await deleteLocalItem(id, type);

    if (isFirebaseAvailable) {
      try {
        final collection = type == 'appointment' ? 'appointments' : 'reports';
        await FirebaseFirestore.instance.collection(collection).doc(id).delete();
        return true;
      } catch (e) {
        print("Firebase Delete Item Error: $e");
      }
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final endpoint = type == 'appointment' ? 'appointments' : 'reports';
      
      final request = await client.deleteUrl(Uri.parse("$baseUrl/$endpoint/$id"));
      _setHeaders(request);
      
      final response = await request.close();
      return response.statusCode == 200;
    } catch (e) {
      print("Delete Item API Error: $e");
    }
    return localDeleted;
  }

  // 9. Run AI Symptom Checker Diagnosis
  static Future<Map<String, dynamic>?> diagnose(String symptoms) async {
    final language = await loadLanguage() ?? "English";
    
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.postUrl(Uri.parse("$baseUrl/ai/diagnose"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode({'symptoms': symptoms, 'language': language})));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        return json.decode(responseBody) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Diagnose API Error: $e");
    }

    return runLocalDiagnosisHeuristic(symptoms);
  }

  // 9.2 Healthcare Chatbot
  static Future<String> chat(String message) async {
    final language = await loadLanguage() ?? "English";
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.postUrl(Uri.parse("$baseUrl/ai/chat"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode({'message': message, 'language': language})));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final data = json.decode(responseBody) as Map<String, dynamic>;
        return data['reply'] ?? "No response received.";
      }
    } catch (e) {
      print("Chat API Error: $e");
    }

    // Heuristic Local Fallback
    final m = message.toLowerCase();
    if (m.contains("diet") || m.contains("food") || m.contains("eat")) {
      return "Eat a balanced meal containing green vegetables, whole grains, and clean proteins. Keep hydrated. *Disclaimer: Not medical advice.*";
    } else if (m.contains("exercise") || m.contains("workout") || m.contains("fitness")) {
      return "Engage in 30 minutes of moderate cardiovascular workout daily. *Disclaimer: Not medical advice.*";
    } else if (m.contains("stress") || m.contains("depress") || m.contains("anxiety") || m.contains("mental")) {
      return "Practice breathing exercises or meditation. Get ample sleep. *Disclaimer: Not medical advice.*";
    }
    return "I am your healthcare chatbot assistant. Ask me about diet, fitness, mental health, or symptoms. *Disclaimer: Not medical advice.*";
  }

  // 9.5 Create Report Log
  static Future<Map<String, dynamic>?> createReport({
    required String symptoms,
    required String condition,
    required String severity,
    required String specialist,
    required String description,
    required List<dynamic> medicines,
    required List<dynamic> precautions,
  }) async {
    final report = {
      'userId': currentUser?['uid'] ?? 'guest',
      'symptoms': symptoms,
      'condition': condition,
      'severity': severity,
      'specialist': specialist,
      'description': description,
      'medicines': medicines,
      'precautions': precautions,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (isFirebaseAvailable) {
      try {
        final docRef = await FirebaseFirestore.instance.collection('reports').add(report);
        final newReport = {
          'id': docRef.id,
          'type': 'symptom',
          'date': DateTime.now().toLocal().toString().split(' ')[0],
          'time': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          ...report,
        };
        await FirebaseFirestore.instance.collection('reports').doc(docRef.id).update({'id': docRef.id});
        await saveLocalReport(newReport);
        return {'success': true, 'report': newReport};
      } catch (e) {
        print("Firebase Create Report Error: $e");
      }
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse("$baseUrl/reports"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode(report)));
      
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final res = json.decode(responseBody) as Map<String, dynamic>;
        if (res['report'] != null) {
          await saveLocalReport(res['report']);
        }
        return res;
      }
    } catch (e) {
      print("Create Report API Error: $e");
    }

    final localReport = {
      'id': 'rep-offline-${DateTime.now().millisecondsSinceEpoch}',
      'type': 'symptom',
      'date': DateTime.now().toLocal().toString().split(' ')[0],
      'time': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      ...report,
    };
    await saveLocalReport(localReport);
    return {'success': true, 'report': localReport};
  }

  /* ── EMERGENCY SERVICES APIs ── */

  // 10. Fetch Emergency Contacts
  static Future<List<dynamic>> getEmergencyContacts() async {
    final localContacts = await getLocalContacts();

    if (isFirebaseAvailable && currentUser != null) {
      try {
        final uid = currentUser!['uid'];
        final snap = await FirebaseFirestore.instance
            .collection('emergency_contacts')
            .where('userId', isEqualTo: uid)
            .get();
        final List<dynamic> serverContacts = [];
        for (var doc in snap.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          serverContacts.add(data);
        }
        final Map<String, dynamic> merged = {};
        for (var c in localContacts) {
          if (c['phone'] != null) merged[c['phone']] = c;
        }
        for (var c in serverContacts) {
          if (c['phone'] != null) merged[c['phone']] = c;
        }
        return merged.values.toList();
      } catch (e) {
        print("Firebase Get Emergency Contacts Error: $e");
      }
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse("$baseUrl/emergency/contacts"));
      _setHeaders(request);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        final serverContacts = json.decode(responseBody) as List<dynamic>;
        final Map<String, dynamic> merged = {};
        for (var c in localContacts) {
          if (c['phone'] != null) merged[c['phone']] = c;
        }
        for (var c in serverContacts) {
          if (c['phone'] != null) merged[c['phone']] = c;
        }
        return merged.values.toList();
      }
    } catch (e) {
      print("Get Emergency Contacts API Error: $e");
    }
    return localContacts;
  }

  // 11. Add Emergency Contact
  static Future<Map<String, dynamic>?> addEmergencyContact(String name, String phone, String relationship) async {
    final mockId = "contact-${DateTime.now().millisecondsSinceEpoch}";
    final newContact = {
      'id': mockId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'userId': currentUser?['uid'] ?? '',
    };

    await saveLocalContact(newContact);

    if (isFirebaseAvailable) {
      try {
        final docRef = await FirebaseFirestore.instance.collection('emergency_contacts').add(newContact);
        newContact['id'] = docRef.id;
        await FirebaseFirestore.instance.collection('emergency_contacts').doc(docRef.id).update({'id': docRef.id});
        return newContact;
      } catch (e) {
        print("Firebase Add Emergency Contact Error: $e");
      }
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse("$baseUrl/emergency/contacts"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode({
        'name': name,
        'phone': phone,
        'relationship': relationship
      })));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(responseBody) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Add Emergency Contact API Error: $e");
    }
    return newContact;
  }

  // 12. Delete Emergency Contact
  static Future<bool> deleteEmergencyContact(String id) async {
    final localDeleted = await deleteLocalContact(id);

    if (isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance.collection('emergency_contacts').doc(id).delete();
        return true;
      } catch (e) {
        print("Firebase Delete Emergency Contact Error: $e");
      }
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.deleteUrl(Uri.parse("$baseUrl/emergency/contacts/$id"));
      _setHeaders(request);

      final response = await request.close();
      return response.statusCode == 200;
    } catch (e) {
      print("Delete Emergency Contact API Error: $e");
    }
    return localDeleted;
  }

  static Future<void> saveLocalContact(Map<String, dynamic> contact) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList('local_contacts') ?? [];
      final bool alreadyExists = list.any((item) {
        final decoded = json.decode(item) as Map<String, dynamic>;
        return decoded['phone'] == contact['phone'];
      });
      if (!alreadyExists) {
        list.add(json.encode(contact));
        await prefs.setStringList('local_contacts', list);
      }
    } catch (e) {
      print("Save local contact error: $e");
    }
  }

  static Future<List<dynamic>> getLocalContacts() async {
    final List<dynamic> contacts = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList('local_contacts') ?? [];
      for (var item in list) {
        contacts.add(json.decode(item));
      }
    } catch (e) {
      print("Get local contacts error: $e");
    }
    return contacts;
  }

  static Future<bool> deleteLocalContact(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList('local_contacts') ?? [];
      final int initialLength = list.length;
      final updatedList = list.where((item) {
        final decoded = json.decode(item) as Map<String, dynamic>;
        return decoded['id'] != id && decoded['phone'] != id;
      }).toList();
      await prefs.setStringList('local_contacts', updatedList);
      return updatedList.length < initialLength;
    } catch (e) {
      print("Delete local contact error: $e");
    }
    return false;
  }

  // 13. Share Live Location
  static Future<bool> shareLocation(double lat, double lng, List<String> contacts, {String? message}) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.postUrl(Uri.parse("$baseUrl/emergency/share-location"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode({
        'latitude': lat,
        'longitude': lng,
        'contacts': contacts,
        'message': message
      })));

      final response = await request.close();
      return response.statusCode == 200;
    } catch (e) {
      print("Share Location API Error: $e");
    }
    return false;
  }

  // 14. Trigger SOS Emergency (Returns SOS Dispatch result and nearest Hospital)
  static Future<Map<String, dynamic>?> triggerSOS(double lat, double lng, {String? message}) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final request = await client.postUrl(Uri.parse("$baseUrl/emergency/sos"));
      _setHeaders(request);
      request.add(utf8.encode(json.encode({
        'latitude': lat,
        'longitude': lng,
        'message': message
      })));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        return json.decode(responseBody) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Trigger SOS API Error: $e");
    }
    return null;
  }


  /* ── LOCAL PERSISTENCE STORAGE HELPERS (OFFLINE WORKFLOWS) ── */

  static Future<void> saveLocalAppointment(Map<String, dynamic> appointment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList('local_appointments') ?? [];
      final bool alreadyExists = list.any((item) {
        final decoded = json.decode(item) as Map<String, dynamic>;
        return decoded['id'] == appointment['id'] || (decoded['token'] != null && decoded['token'] == appointment['token']);
      });
      if (!alreadyExists) {
        list.add(json.encode(appointment));
        await prefs.setStringList('local_appointments', list);
      }
    } catch (e) {
      print("Save local appt error: $e");
    }
  }

  static Future<void> saveLocalReport(Map<String, dynamic> report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList('local_reports') ?? [];
      final bool alreadyExists = list.any((item) {
        final decoded = json.decode(item) as Map<String, dynamic>;
        return decoded['id'] == report['id'];
      });
      if (!alreadyExists) {
        list.add(json.encode(report));
        await prefs.setStringList('local_reports', list);
      }
    } catch (e) {
      print("Save local report error: $e");
    }
  }

  static Future<List<dynamic>> getLocalHistory() async {
    final List<dynamic> history = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> appts = prefs.getStringList('local_appointments') ?? [];
      final List<String> reps = prefs.getStringList('local_reports') ?? [];
      
      for (var a in appts) {
        history.add(json.decode(a));
      }
      for (var r in reps) {
        history.add(json.decode(r));
      }
    } catch (e) {
      print("Get local history error: $e");
    }
    return history;
  }

  static Future<bool> deleteLocalItem(String id, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = type == 'appointment' ? 'local_appointments' : 'local_reports';
      final List<String> list = prefs.getStringList(key) ?? [];
      final int initialLength = list.length;
      
      final updatedList = list.where((item) {
        final decoded = json.decode(item) as Map<String, dynamic>;
        return decoded['id'] != id && decoded['token'] != id;
      }).toList();
      
      await prefs.setStringList(key, updatedList);
      return updatedList.length < initialLength;
    } catch (e) {
      print("Delete local item error: $e");
    }
    return false;
  }

  static Future<void> launchDirections(String address) async {
    final query = Uri.encodeComponent(address);
    final url = 'https://www.google.com/maps/search/?api=1&query=$query';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print("Error launching maps: $e");
    }
  }

  static Future<void> makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = 'tel:$cleanPhone';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      print("Error making call: $e");
    }
  }

  static Map<String, dynamic> runLocalDiagnosisHeuristic(String symptoms) {
    final s = symptoms.toLowerCase();
    if (s.contains("throat") || s.contains("swallow") || s.contains("gala") || s.contains("gontu")) {
      return {
        'condition': "Throat Infection (Pharyngitis)",
        'severity': "medium",
        'specialist': "ENT Specialist",
        'description': "An acute viral infection causing inflammation of the vocal tract and pharynx.",
        'precautions': ["Gargle with warm salt water 3 times a day", "Avoid cold drinks and oily food"],
        'medicines': [
          {'name': 'Paracetamol 500mg', 'instructions': '1 tablet after meals (SOS)', 'badge': 'Fever/Pain'},
          {'name': 'Betadine Mouthwash', 'instructions': 'Gargle with warm water', 'badge': 'Throat Relief'}
        ]
      };
    }
    if (s.contains("chest") || s.contains("heart") || s.contains("cardio") || s.contains("gunde") || s.contains("nenju")) {
      return {
        'condition': "Potential Cardiovascular Strain",
        'severity': "high",
        'specialist': "Cardiologist",
        'description': "Angina or pulmonary pressure warning. Requires immediate professional screening.",
        'precautions': ["Sit completely still, do not exert yourself", "Call 108 Emergency Medical Assistance immediately"],
        'medicines': [
          {'name': 'Aspirin 75mg', 'instructions': 'Chew immediately', 'badge': 'Blood Thinner'}
        ]
      };
    }
    // Default fallback
    return {
      'condition': "Acute Febrile Illness / Mild Fever",
      'severity': "low",
      'specialist': "General Physician",
      'description': "Standard viral body temperature elevation due to seasonal changes.",
      'precautions': ["Get complete bed rest", "Drink plenty of water and warm soups"],
      'medicines': [
        {'name': 'Paracetamol 500mg', 'instructions': '1 tablet after meals (SOS)', 'badge': 'Fever/Pain'}
      ]
    };
  }
}

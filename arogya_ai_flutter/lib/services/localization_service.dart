import 'package:flutter/foundation.dart';
import 'api_service.dart';

class LocalizationService {
  static String currentLanguage = 'English';

  static final Map<String, Map<String, String>> _localizedValues = {
    'English': {
      'app_title': 'ArogyaAI',
      'welcome': 'Hello, Namaste! 👋',
      'emergency_sos': 'Emergency SOS',
      'emergency_desc': 'Tap for healthcare emergency (108)',
      'services_title': 'Arogya Assistant Services',
      'symptom_checker': 'AI Symptom Checker',
      'nearby_hospitals': 'Nearby Hospitals',
      'image_scan': 'Medical Image Scan',
      'visits_tab': 'Appointment Passes',
      'home_tab': 'Home',
      'clinics_tab': 'Clinics',
      'history_tab': 'Visits',
      'profile_tab': 'Profile',
      'logout': 'Logout Session',
      'language_setting': 'Language Setting',
      'local_api_server': 'Local API Server',
      'health_score': 'Health Score',
      'chatbot': 'AI Health Chatbot',
      'reminders': 'Medicine Reminders',
      'records': 'Health Records',
      'admin_panel': 'Admin Dashboard',
      'forgot_password': 'Forgot Password',
      'email': 'Email Address',
      'password': 'Password',
      'phone': 'Phone Number',
      'fullname': 'Full Name',
      'age': 'Age',
      'gender': 'Gender',
      'register': 'Register Account',
      'login': 'Login Session',
    },
    'Hindi': {
      'app_title': 'आरोग्यAI',
      'welcome': 'नमस्ते! 👋',
      'emergency_sos': 'आपातकालीन एसओएस',
      'emergency_desc': 'स्वास्थ्य आपातकाल (108) के लिए टैप करें',
      'services_title': 'आरोग्य सहायक सेवाएं',
      'symptom_checker': 'एआई लक्षण जांचकर्ता',
      'nearby_hospitals': 'आसपास के अस्पताल',
      'image_scan': 'मेडिकल इमेज स्कैन',
      'visits_tab': 'अपॉइंटमेंट पास',
      'home_tab': 'होम',
      'clinics_tab': 'क्लीनिक',
      'history_tab': 'यात्राएं',
      'profile_tab': 'प्रोफ़ाइल',
      'logout': 'लॉगआउट सत्र',
      'language_setting': 'भाषा सेटिंग',
      'local_api_server': 'स्थानीय एपीआई सर्वर',
      'health_score': 'स्वास्थ्य स्कोर',
      'chatbot': 'एआई स्वास्थ्य चैटबॉट',
      'reminders': 'दवा अनुस्मारक',
      'records': 'स्वास्थ्य रिकॉर्ड',
      'admin_panel': 'व्यवस्थापक डैशबोर्ड',
      'forgot_password': 'पासवर्ड भूल गए',
      'email': 'ईमेल पता',
      'password': 'पासवर्ड',
      'phone': 'फ़ोन नंबर',
      'fullname': 'पूरा नाम',
      'age': 'उम्र',
      'gender': 'लिंग',
      'register': 'खाता पंजीकृत करें',
      'login': 'लॉगिन सत्र',
    },
    'Telugu': {
      'app_title': 'ఆరోగ్యAI',
      'welcome': 'నమస్కారం! 👋',
      'emergency_sos': 'అత్యవసర SOS',
      'emergency_desc': 'ఆరోగ్య అత్యవసర పరిస్థితి (108) కోసం నొక్కండి',
      'services_title': 'ఆరోగ్య సహాయక సేవలు',
      'symptom_checker': 'AI లక్షణాల గుర్తింపు',
      'nearby_hospitals': 'సమీప ఆసుపత్రులు',
      'image_scan': 'వైద్య చిత్ర స్కాన్',
      'visits_tab': 'అపాయింట్‌మెంట్ పాస్‌లు',
      'home_tab': 'హోమ్',
      'clinics_tab': 'క్లినిక్‌లు',
      'history_tab': 'సందర్శనలు',
      'profile_tab': 'ప్రొఫైల్',
      'logout': 'లాగౌట్ సెషన్',
      'language_setting': 'భాష అమరిక',
      'local_api_server': 'స్థానిక API సర్వర్',
      'health_score': 'ఆరోగ్య స్కోర్',
      'chatbot': 'AI హెల్త్ చాట్‌బాట్',
      'reminders': 'మందుల రిమైండర్',
      'records': 'ఆరోగ్య రికార్డులు',
      'admin_panel': 'అడ్మిన్ డాష్‌బోర్డ్',
      'forgot_password': 'పాస్‌వర్డ్ మర్చిపోయారా',
      'email': 'ఈమెయిల్ చిరునామా',
      'password': 'పాస్‌వర్డ్',
      'phone': 'ఫోన్ నంబర్',
      'fullname': 'పూర్తి పేరు',
      'age': 'వయస్సు',
      'gender': 'లింగం',
      'register': 'ఖాతా నమోదు',
      'login': 'లాగిన్ సెషన్',
    },
    'Tamil': {
      'app_title': 'ஆரோக்யாAI',
      'welcome': 'வணக்கம்! 👋',
      'emergency_sos': 'அவசரகால SOS',
      'emergency_desc': 'சுகாதார அவசரநிலைக்கு (108) தட்டவும்',
      'services_title': 'ஆரோக்யா உதவி சேவைகள்',
      'symptom_checker': 'AI அறிகுறி சரிபார்ப்பான்',
      'nearby_hospitals': 'அருகிலுள்ள மருத்துவமனைகள்',
      'image_scan': 'மருத்துவ பட ஸ்கேன்',
      'visits_tab': 'அப்பாயிண்ட்மெண்ட் பாஸ்கள்',
      'home_tab': 'முகப்பு',
      'clinics_tab': 'கிளினிக்குகள்',
      'history_tab': 'வருகைகள்',
      'profile_tab': 'சுயவிவரம்',
      'logout': 'வெளியேறுதல்',
      'language_setting': 'மொழி அமைப்பு',
      'local_api_server': 'உள்ளூர் API சர்வர்',
      'health_score': 'உடல்நல மதிப்பெண்',
      'chatbot': 'AI சுகாதார சாட்போட்',
      'reminders': 'மருந்து நினைவூட்டல்கள்',
      'records': 'சுகாதார பதிவுகள்',
      'admin_panel': 'நிர்வாகி டாஷ்போர்டு',
      'forgot_password': 'கடவுச்சொல் மறந்துவிட்டதா',
      'email': 'மின்னஞ்சல் முகவரி',
      'password': 'கடவுச்சொல்',
      'phone': 'தொலைபேசி எண்',
      'fullname': 'முழு பெயர்',
      'age': 'வயது',
      'gender': 'பாலினம்',
      'register': 'கணக்கு பதிவு',
      'login': 'உள்நுழைவு',
    }
  };

  static Future<void> init() async {
    final lang = await ApiService.loadLanguage();
    if (lang != null && _localizedValues.containsKey(lang)) {
      currentLanguage = lang;
    }
  }

  static String translate(String key) {
    final values = _localizedValues[currentLanguage] ?? _localizedValues['English']!;
    return values[key] ?? key;
  }

  static void setLanguage(String lang) {
    if (_localizedValues.containsKey(lang)) {
      currentLanguage = lang;
      ApiService.saveLanguage(lang);
    }
  }
}

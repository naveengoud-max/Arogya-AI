import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'screens/home_dashboard.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/localization_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  await LocalizationService.init();
  
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey.contains("DummyKey") || options.apiKey.contains("placeholder") || options.apiKey.isEmpty) {
      ApiService.firebaseStatus = "Failed";
      ApiService.firebaseError = "API key not valid. Please pass a valid API key.";
      debugPrint("[DIAGNOSTICS] Firebase Status = Failed: API key not valid. Please pass a valid API key.");
      
      // Initialize anyway to avoid core initialization errors in downstream widget trees
      await Firebase.initializeApp(options: options);
    } else {
      await Firebase.initializeApp(options: options);
      ApiService.firebaseStatus = "Connected";
      ApiService.firebaseError = "";
      debugPrint("[DIAGNOSTICS] Firebase Status = Connected");
    }
  } catch (e) {
    ApiService.firebaseStatus = "Failed";
    ApiService.firebaseError = e.toString();
    debugPrint("[DIAGNOSTICS] Firebase Status = Failed: $e");
  }

  // Load saved session on startup
  final session = await ApiService.loadSession();
  final bool isLoggedIn = session != null;
  
  runApp(ArogyaAIApp(isLoggedIn: isLoggedIn));
}

class ArogyaAIApp extends StatelessWidget {
  final bool isLoggedIn;
  const ArogyaAIApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArogyaAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981), // Emerald Green
          primary: const Color(0xFF10B981),
          secondary: const Color(0xFF14B8A6), // Teal
          background: const Color(0xFFF9FAFB), // Light Gray
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import 'home_dashboard.dart';
import 'profile_setup_screen.dart';
import 'forgot_password_screen.dart';
import 'diagnostics_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String selectedLanguage = 'English';
  final List<String> languages = [
    'English', 'Telugu', 'Hindi', 'Tamil', 'Malayalam',
    'Kannada', 'Bengali', 'Marathi', 'Gujarati', 'Punjabi'
  ];

  final TextEditingController _phoneController = TextEditingController(text: '9876543210');
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _registerNameController = TextEditingController();
  final TextEditingController _registerPhoneController = TextEditingController();
  
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _otpSent = false;
  String _serverOtp = "";
  String? _simulatedSmsText;
  
  bool _isEmailMode = false;
  bool _isRegisterMode = false;
  bool _isEmailLoading = false;
  
  // Firebase Auth Properties (lazy getter to prevent startup crash)
  FirebaseAuth get _auth => FirebaseAuth.instance;
  String? _verificationId;
  bool _useFirebase = false; // Set dynamically in initState

  @override
  void initState() {
    super.initState();
    _useFirebase = ApiService.isFirebaseAvailable;
  }

  void _showApiSettingsDialog() {
    final controller = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Server Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the backend base URL (e.g. your PC\'s Wi-Fi IP address):',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://192.168.31.194:5000/api',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              String url = controller.text.trim();
              if (url.isNotEmpty) {
                await ApiService.setBaseUrl(url);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('API URL updated to: $url')),
                  );
                }
              }
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Real Firebase Phone Auth Flow
  void _sendFirebaseOtp(String phone) async {
    final formattedPhone = "+91$phone";
    print("[DIAGNOSTICS] OTP request started");
    
    setState(() {
      _isSendingOtp = true;
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android
          UserCredential? userCred;
          print("[DEBUG-LOG] Step 1: Calling signInWithCredential (Auto)...");
          try {
            userCred = await _auth.signInWithCredential(credential);
            print("[DEBUG-LOG] Step 1: signInWithCredential (Auto) success");
          } catch (e, stack) {
            print("[DEBUG-LOG] Step 1 Failed! Exception in signInWithCredential (Auto): $e");
            print(stack);
            rethrow;
          }

          User? user;
          print("[DEBUG-LOG] Step 2: Extracting userCredential.user (Auto)...");
          try {
            user = userCred.user;
            print("[DEBUG-LOG] Step 2: userCredential.user (Auto) extracted: $user");
          } catch (e, stack) {
            print("[DEBUG-LOG] Step 2 Failed! Exception in userCredential.user (Auto): $e");
            print(stack);
            rethrow;
          }

          if (user != null) {
            String? token;
            print("[DEBUG-LOG] Step 3: Calling user.getIdToken() (Auto)...");
            try {
              token = await user.getIdToken();
              print("[DEBUG-LOG] Step 3: user.getIdToken() (Auto) success: $token");
            } catch (e, stack) {
              print("[DEBUG-LOG] Step 3 Failed! Exception in user.getIdToken() (Auto): $e");
              print(stack);
              rethrow;
            }

            final userData = {
              'uid': user.uid,
              'phone': user.phoneNumber ?? phone,
              'name': 'Arogya User'
            };

            print("[DEBUG-LOG] Step 4: Calling ApiService.saveSession (Auto)...");
            try {
              await ApiService.saveSession(userData, token: token);
              print("[DEBUG-LOG] Step 4: ApiService.saveSession (Auto) success");
            } catch (e, stack) {
              print("[DEBUG-LOG] Step 4 Failed! Exception in ApiService.saveSession (Auto): $e");
              print(stack);
              rethrow;
            }

            print("[DIAGNOSTICS] OTP request successful (Auto verified)");
            _handleSuccessRedirect();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('ERROR CODE: ${e.code}');
          print('ERROR MESSAGE: ${e.message}');
          debugPrint('ERROR CODE: ${e.code}');
          debugPrint('ERROR MESSAGE: ${e.message}');
          setState(() {
            _isSendingOtp = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Code: ${e.code}\nMessage: ${e.message}',
                  ),
                  duration: const Duration(seconds: 8),
                  ),
                  );
                  },
        codeSent: (String verificationId, int? resendToken) {
          print("[DIAGNOSTICS] OTP request successful");
          setState(() {
            _isSendingOtp = false;
            _verificationId = verificationId;
            _otpSent = true;
            _useFirebase = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OTP verification code sent to $formattedPhone')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint("Firebase verification trigger failed: $e");
      print("[DIAGNOSTICS] OTP request failed: $e");
      setState(() {
        _isSendingOtp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firebase verification failed: $e')),
      );
    }
  }

  // Custom Backend Real OTP Flow (Fast2SMS/Twilio)
  void _sendCustomBackendOtp(String phone) async {
    print("[DIAGNOSTICS] OTP request started");
    setState(() {
      _isSendingOtp = true;
    });

    final res = await ApiService.sendOtp(phone);
    
    setState(() {
      _isSendingOtp = false;
    });

    _otpController.clear();

    if (res != null) {
      if (res['success'] == true) {
        final code = res['code'];
        setState(() {
          _otpSent = true;
          _useFirebase = false;
          if (code != null) {
            _serverOtp = code.toString();
            _simulatedSmsText = "Your 6-digit OTP is: $_serverOtp. Valid for 5 minutes.";
          } else {
            _serverOtp = "SMS_SENT";
            _simulatedSmsText = null;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'OTP code sent!')),
        );

        if (_simulatedSmsText != null) {
          Future.delayed(const Duration(seconds: 6), () {
            if (mounted) {
              setState(() {
                _simulatedSmsText = null;
              });
            }
          });
        }
      } else {
        print("[DIAGNOSTICS] OTP request failed: ${res['message']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to send OTP code. Please try again.')),
        );
      }
    } else {
      print("[DIAGNOSTICS] OTP request failed: Backend offline");
      
      // Check connection status
      final isConnected = await ApiService.checkConnection();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.red),
              SizedBox(width: 10),
              Text("Connection Issue"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Login service is currently unavailable. Please try again.",
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              const Text(
                "Error Details: SocketException - Connection refused / Server down.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                "Local Network Status: ${isConnected ? 'Online' : 'Offline (Server unreachable)'}",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isConnected ? Colors.green : Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _sendCustomBackendOtp(phone); // Retry
              },
              child: const Text("Retry Connection", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _sendOtpCode() {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    if (_useFirebase) {
      _sendFirebaseOtp(phone);
    } else {
      _sendCustomBackendOtp(phone);
    }
  }

  void _verifyOtpCode() async {
    final phone = _phoneController.text.trim();
    final code = _otpController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    // 1. Firebase Verification
    if (_useFirebase && _verificationId != null) {
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        UserCredential? userCred;
        print("[DEBUG-LOG] Step 1: Calling signInWithCredential...");
        try {
          userCred = await _auth.signInWithCredential(credential);
          print("[DEBUG-LOG] Step 1: signInWithCredential success");
        } catch (e, stack) {
          print("[DEBUG-LOG] Step 1 Failed! Exception in signInWithCredential: $e");
          print(stack);
          rethrow;
        }

        User? user;
        print("[DEBUG-LOG] Step 2: Extracting userCredential.user...");
        try {
          user = userCred.user;
          print("[DEBUG-LOG] Step 2: userCredential.user extracted: $user");
        } catch (e, stack) {
          print("[DEBUG-LOG] Step 2 Failed! Exception in userCredential.user: $e");
          print(stack);
          rethrow;
        }

        if (user != null) {
          String? token;
          print("[DEBUG-LOG] Step 3: Calling user.getIdToken()...");
          try {
            token = await user.getIdToken();
            print("[DEBUG-LOG] Step 3: user.getIdToken() success: $token");
          } catch (e, stack) {
            print("[DEBUG-LOG] Step 3 Failed! Exception in user.getIdToken(): $e");
            print(stack);
            rethrow;
          }

          final userData = {
            'uid': user.uid,
            'phone': user.phoneNumber ?? phone,
            'name': 'Arogya User'
          };

          print("[DEBUG-LOG] Step 4: Calling ApiService.saveSession...");
          try {
            await ApiService.saveSession(userData, token: token);
            print("[DEBUG-LOG] Step 4: ApiService.saveSession success");
          } catch (e, stack) {
            print("[DEBUG-LOG] Step 4 Failed! Exception in ApiService.saveSession: $e");
            print(stack);
            rethrow;
          }

          await ApiService.saveLanguage(selectedLanguage);

          print("[DEBUG-LOG] Step 5: Calling ApiService.createFirestoreUserRecord...");
          try {
            await ApiService.createFirestoreUserRecord(
              userId: user.uid,
              phone: user.phoneNumber ?? phone,
              language: selectedLanguage,
            );
            print("[DEBUG-LOG] Step 5: ApiService.createFirestoreUserRecord success");
          } catch (e, stack) {
            print("[DEBUG-LOG] Step 5 Failed! Exception in ApiService.createFirestoreUserRecord: $e");
            print(stack);
            rethrow;
          }

          _handleSuccessRedirect();
          return;
        }
      } catch (e) {
        debugPrint("Firebase SMS Verification failed: $e");
        print("[DIAGNOSTICS] OTP request failed: Invalid verification code");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid Firebase verification code: $e')),
        );
        setState(() {
          _isVerifyingOtp = false;
        });
        return;
      }
    }

    // 2. Custom Backend verification (Real OTP verification)
    final res = await ApiService.verifyOtp(phone, code);
    setState(() {
      _isVerifyingOtp = false;
    });

    await ApiService.saveLanguage(selectedLanguage);

    if (res != null) {
      if (res['success'] == true) {
        final user = res['user'] ?? {};
        final uid = user['uid'] ?? 'unknown';
        // Create user record in Firestore
        await ApiService.createFirestoreUserRecord(
          userId: uid,
          phone: phone,
          language: selectedLanguage,
        );
        _handleSuccessRedirect();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Invalid verification code. Please try again.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login service is currently unavailable. Please try again.')),
      );
    }
  }

  void _handleSuccessRedirect() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification Successful! 🎉')),
    );
    
    // Check if user has updated their profile details
    // If not, redirect them to the Profile Setup Screen
    final profile = await ApiService.getProfile();
    
    if (mounted) {
      if (profile != null && profile['name'] != null && profile['name'] != 'Arogya User') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      }
    }
  }

  void _loginWithEmailAndPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both email and password.')),
      );
      return;
    }

    setState(() {
      _isEmailLoading = true;
    });

    final res = await ApiService.loginEmail(email, password);

    setState(() {
      _isEmailLoading = false;
    });

    if (res != null) {
      if (res['success'] == true) {
        await ApiService.saveLanguage(selectedLanguage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Login Successful! 🎉')),
        );
        _handleSuccessRedirect();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Invalid credentials.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach backend server.')),
      );
    }
  }

  void _registerWithEmailAndPassword() async {
    final name = _registerNameController.text.trim();
    final phone = _registerPhoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number.')),
      );
      return;
    }

    setState(() {
      _isEmailLoading = true;
    });

    final res = await ApiService.registerEmail(email, password, name, phone);

    setState(() {
      _isEmailLoading = false;
    });

    if (res != null) {
      if (res['success'] == true) {
        await ApiService.saveLanguage(selectedLanguage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Registration Successful! 🎉')),
        );
        _handleSuccessRedirect();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Registration failed.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach backend server.')),
      );
    }
  }

  void _loginWithGoogle() async {
    setState(() {
      _isEmailLoading = true;
    });
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        UserCredential? userCred;
        print("[DEBUG-LOG] Step 1: Calling signInWithCredential (Google)...");
        try {
          userCred = await FirebaseAuth.instance.signInWithCredential(credential);
          print("[DEBUG-LOG] Step 1: signInWithCredential (Google) success");
        } catch (e, stack) {
          print("[DEBUG-LOG] Step 1 Failed! Exception in signInWithCredential (Google): $e");
          print(stack);
          rethrow;
        }

        User? user;
        print("[DEBUG-LOG] Step 2: Extracting userCredential.user (Google)...");
        try {
          user = userCred.user;
          print("[DEBUG-LOG] Step 2: userCredential.user (Google) extracted: $user");
        } catch (e, stack) {
          print("[DEBUG-LOG] Step 2 Failed! Exception in userCredential.user (Google): $e");
          print(stack);
          rethrow;
        }

        if (user != null) {
          String? token;
          print("[DEBUG-LOG] Step 3: Calling user.getIdToken() (Google)...");
          try {
            token = await user.getIdToken();
            print("[DEBUG-LOG] Step 3: user.getIdToken() (Google) success: $token");
          } catch (e, stack) {
            print("[DEBUG-LOG] Step 3 Failed! Exception in user.getIdToken() (Google): $e");
            print(stack);
            rethrow;
          }

          final userData = {
            'uid': user.uid,
            'phone': user.phoneNumber ?? '',
            'name': user.displayName ?? 'Google User',
            'email': user.email ?? '',
          };

          print("[DEBUG-LOG] Step 4: Calling ApiService.saveSession (Google)...");
          try {
            await ApiService.saveSession(userData, token: token);
            print("[DEBUG-LOG] Step 4: ApiService.saveSession (Google) success");
          } catch (e, stack) {
            print("[DEBUG-LOG] Step 4 Failed! Exception in ApiService.saveSession (Google): $e");
            print(stack);
            rethrow;
          }

          await ApiService.saveLanguage(selectedLanguage);

          print("[DEBUG-LOG] Step 5: Calling ApiService.createFirestoreUserRecord (Google)...");
          try {
            await ApiService.createFirestoreUserRecord(
              userId: user.uid,
              phone: user.phoneNumber ?? '',
              name: user.displayName ?? 'Google User',
              email: user.email ?? '',
              language: selectedLanguage,
            );
            print("[DEBUG-LOG] Step 5: ApiService.createFirestoreUserRecord (Google) success");
          } catch (e, stack) {
            print("[DEBUG-LOG] Step 5 Failed! Exception in ApiService.createFirestoreUserRecord (Google): $e");
            print(stack);
            rethrow;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Sign-In Successful! 🚀')),
          );
          _handleSuccessRedirect();
        }
      }
    } catch (e) {
      debugPrint("Google Sign-In failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $e')),
      );
    } finally {
      setState(() {
        _isEmailLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          GestureDetector(
            onDoubleTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
              );
            },
            onLongPress: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
              );
            },
            child: IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFF64748B)),
              onPressed: _showApiSettingsDialog,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              FadeInDown(
                child: const Icon(
                  Icons.health_and_safety,
                  size: 90,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 16),
              FadeInDown(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  'ArogyaAI',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                        letterSpacing: 0.5,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              FadeInDown(
                delay: const Duration(milliseconds: 300),
                child: Text(
                  'AI-Powered Rural Healthcare Assistant',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              const SizedBox(height: 32),
              
              if (!_otpSent) ...[
                // Tab selector
                FadeInDown(
                  delay: const Duration(milliseconds: 350),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isEmailMode = false;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: !_isEmailMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              child: Text(
                                'Phone OTP',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: !_isEmailMode ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isEmailMode = true;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _isEmailMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              child: Text(
                                'Email & Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _isEmailMode ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (!_isEmailMode) ...[
                  // Phone OTP Form
                  FadeInUp(
                    delay: const Duration(milliseconds: 450),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          counterText: "",
                          hintText: 'Enter Phone Number',
                          prefixText: '+91 ',
                          prefixStyle: TextStyle(fontSize: 16, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedLanguage,
                          isExpanded: true,
                          icon: const Icon(Icons.language, color: Color(0xFF10B981)),
                          items: languages.map((String lang) {
                            return DropdownMenuItem(
                              value: lang,
                              child: Text(lang, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedLanguage = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    delay: const Duration(milliseconds: 750),
                    child: ElevatedButton(
                      onPressed: _isSendingOtp ? null : _sendOtpCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSendingOtp
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Send Verification Code',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ] else ...[
                  // Email & Password Form (Register/Login toggle)
                  if (_isRegisterMode) ...[
                    // Register Fields
                    FadeInUp(
                      delay: const Duration(milliseconds: 100),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: TextField(
                          controller: _registerNameController,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: 'Full Name',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeInUp(
                      delay: const Duration(milliseconds: 150),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: TextField(
                          controller: _registerPhoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            counterText: "",
                            hintText: 'Phone Number',
                            prefixText: '+91 ',
                            prefixStyle: TextStyle(fontSize: 16, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: 'Email Address',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeInUp(
                    delay: const Duration(milliseconds: 250),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: 'Password',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedLanguage,
                          isExpanded: true,
                          icon: const Icon(Icons.language, color: Color(0xFF10B981)),
                          items: languages.map((String lang) {
                            return DropdownMenuItem(
                              value: lang,
                              child: Text(lang, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedLanguage = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  if (!_isRegisterMode) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                          );
                        },
                        child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FadeInUp(
                    delay: const Duration(milliseconds: 350),
                    child: ElevatedButton(
                      onPressed: _isEmailLoading
                          ? null
                          : (_isRegisterMode ? _registerWithEmailAndPassword : _loginWithEmailAndPassword),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isEmailLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _isRegisterMode ? 'Register & Login' : 'Log In',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isRegisterMode = !_isRegisterMode;
                        });
                      },
                      child: Text(
                        _isRegisterMode ? 'Already have an account? Log In' : 'Don\'t have an account? Sign Up',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FadeInUp(
                  delay: const Duration(milliseconds: 800),
                  child: const Row(
                    children: [
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or continue with',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FadeInUp(
                  delay: const Duration(milliseconds: 850),
                  child: OutlinedButton(
                    onPressed: _loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                          height: 24,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 28,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                FadeInUp(
                  child: Text(
                    'Enter 6-digit verification code sent to +91 ${_phoneController.text}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),
                FadeInUp(
                  delay: const Duration(milliseconds: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode], // Autofill OTP Support
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
                      decoration: const InputDecoration(
                        counterText: "",
                        hintText: '••••••',
                        hintStyle: TextStyle(letterSpacing: 2, fontSize: 22, color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: ElevatedButton(
                    onPressed: _isVerifyingOtp ? null : _verifyOtpCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isVerifyingOtp
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Verify & Login',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _otpSent = false;
                      _otpController.clear();
                    });
                  },
                  child: const Text('Change Phone Number', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
        if (_simulatedSmsText != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: FadeInDown(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.message_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "ArogyaAI SMS Gateway",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  "now",
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _simulatedSmsText!,
                              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

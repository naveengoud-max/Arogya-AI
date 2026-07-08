import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import 'ai_analysis_result_screen.dart';

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({super.key});

  @override
  State<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  final TextEditingController _textController = TextEditingController();
  
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isListening = false;
  bool _isLoading = false;
  bool _speechEnabled = false;
  
  String _selectedLangCode = "en-IN"; // English (IN) default
  final List<Map<String, String>> _languages = [
    {"code": "en-IN", "label": "🇬🇧 English"},
    {"code": "te-IN", "label": "🇮🇳 Telugu"},
    {"code": "hi-IN", "label": "🇮🇳 Hindi"},
    {"code": "ta-IN", "label": "🇮🇳 Tamil"},
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (val) {
          debugPrint('Speech Error: $val');
          setState(() {
            _isListening = false;
          });
        },
        onStatus: (val) => debugPrint('Speech Status: $val'),
      );
      setState(() {});
    } catch (e) {
      debugPrint("Speech initialize failed: $e");
    }
  }

  void _initTts() {
    try {
      _flutterTts.setLanguage("en-IN");
      _flutterTts.setSpeechRate(0.5);
      _flutterTts.setVolume(1.0);
    } catch (e) {
      debugPrint("TTS initialize failed: $e");
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    _textController.dispose();
    super.dispose();
  }

  void _startListening() async {
    if (!_speechEnabled) {
      // Try to re-initialize
      _speechEnabled = await _speech.initialize(
        onError: (val) {
          debugPrint('Speech Error: $val');
          setState(() {
            _isListening = false;
          });
        },
        onStatus: (val) => debugPrint('Speech Status: $val'),
      );
    }

    if (!_speechEnabled) {
      setState(() => _isListening = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech services not ready. Simulating throat pain entry...')),
      );
      // Fallback sandbox simulation if permission/service not ready on device
      await Future.delayed(const Duration(seconds: 2));
      if (_isListening && mounted) {
        setState(() {
          _isListening = false;
          _textController.text = "throat pain and swallowing irritation since yesterday";
        });
      }
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      localeId: _selectedLangCode,
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
        });
      },
    );
  }

  void _stopListening() async {
    setState(() => _isListening = false);
    await _speech.stop();
  }

  void _analyzeSymptoms() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please speak or type symptoms first')),
      );
      return;
    }

    // Stop listening / TTS
    _stopListening();
    _flutterTts.stop();

    setState(() {
      _isLoading = true;
    });

    final res = await ApiService.diagnose(text);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (res != null) {
        // Vocalize confirmation
        try {
          final condition = res['condition'] ?? 'symptom report';
          await _flutterTts.speak("Diagnosis analysis completed. Result condition is $condition.");
        } catch (_) {}

        // Navigate to dedicated AI Analysis Result Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AiAnalysisResultScreen(
              diagnosis: res,
              rawSymptoms: text,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diagnosis failed. Please verify connection.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Speak Symptoms',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language Selection Zone
              const Text(
                'RECOGNITION LANGUAGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _languages.map((l) {
                    final isSelected = _selectedLangCode == l['code'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedLangCode = l['code']!;
                          });
                          if (_isListening) {
                            _stopListening();
                            Future.delayed(const Duration(milliseconds: 200), _startListening);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF10B981) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            l['label']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              // Large Mic Trigger Zone
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_isListening) {
                            _stopListening();
                          } else {
                            _startListening();
                          }
                        },
                        child: AvatarGlow(
                          isListening: _isListening,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isListening ? 'Listening... Speak clearly now' : 'Tap mic & describe symptoms',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hold close to your mouth · speak slowly',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ),

              // Live Transcript area
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 14),
                        SizedBox(width: 6),
                        Text(
                          'LIVE TRANSCRIPT / DESCRIPTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Your spoken symptoms will appear here, or you can edit/type them manually...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit row
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _textController.clear();
                      });
                    },
                    icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _analyzeSymptoms,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Analyze Symptoms',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AvatarGlow extends StatelessWidget {
  final bool isListening;
  final Widget child;

  const AvatarGlow({super.key, required this.isListening, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isListening
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 8,
                )
              ],
            )
          : null,
      child: child,
    );
  }
}

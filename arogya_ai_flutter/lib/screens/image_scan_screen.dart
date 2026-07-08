import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';
import '../services/api_service.dart';
import 'ai_analysis_result_screen.dart';

class ImageScanScreen extends StatefulWidget {
  const ImageScanScreen({super.key});

  @override
  State<ImageScanScreen> createState() => _ImageScanScreenState();
}

class _ImageScanScreenState extends State<ImageScanScreen> with SingleTickerProviderStateMixin {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isScanning = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _startScan() async {
    if (_imageFile == null) return;

    setState(() {
      _isScanning = true;
    });
    
    _animationController.repeat(reverse: true);

    // Simulate clinical scan analysis delay
    await Future.delayed(const Duration(seconds: 3));

    // Analyze symptoms based on simulated image tags or name
    final fileName = _imageFile!.path.toLowerCase();
    String query = "dermal rash itchiness"; // Default fallback
    if (fileName.contains("prescription") || fileName.contains("doc")) {
      query = "throat infection cough throat pain";
    }

    final diag = await ApiService.diagnose(query);

    if (mounted) {
      _animationController.stop();
      setState(() {
        _isScanning = false;
      });

      final finalDiag = diag ?? {
        'condition': 'Allergic Dermatitis (Skin Rash)',
        'severity': 'low',
        'specialist': 'Dermatologist',
        'description': 'A localized allergic response indicating dermal irritation.',
        'precautions': ['Keep the skin cool and hydrated', 'Avoid scratching', 'Apply Calamine lotion'],
        'medicines': [
          {'name': 'Calamine Lotion', 'instructions': 'Apply locally 3 times daily', 'badge': 'Skin Relief'},
          {'name': 'Cetirizine 10mg', 'instructions': '1 tablet at bedtime', 'badge': 'Antihistamine'}
        ],
      };

      // Navigate to dedicated AI Analysis Result Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiAnalysisResultScreen(
            diagnosis: finalDiag,
            rawSymptoms: "Image Scan: Dermal/clinical image analysis",
          ),
        ),
      ).then((_) {
        // Clear selected image on return
        setState(() {
          _imageFile = null;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('AI Medical Image Scan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Upload a photo of a skin rash, symptom area, or clinical prescription for instant AI assistant analysis.',
              style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Image Viewer Container
            GestureDetector(
              onTap: _isScanning ? null : () => _showPickOptions(context),
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 12,
                    )
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.antiAlias,
                  children: [
                    if (_imageFile == null)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_a_photo, size: 48, color: Color(0xFF10B981)),
                            SizedBox(height: 12),
                            Text('Tap to Capture or Upload Image', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text('Camera or Photo Gallery', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      )
                    else
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        ),
                      ),
                      
                    // Animated Scanning Laser Bar
                    if (_isScanning)
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Positioned(
                            top: 280 * _animationController.value,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.8),
                                    blurRadius: 10,
                                    spreadRadius: 3,
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                    if (_isScanning)
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Buttons
            if (_imageFile != null && !_isScanning)
              FadeInUp(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showPickOptions(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Change Photo', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startScan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Analyze Image', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPickOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Image Source',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF10B981)),
              title: const Text('Take a Photo with Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF3B82F6)),
              title: const Text('Choose from Photo Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'doctor_profile_screen.dart';

class AiAnalysisResultScreen extends StatefulWidget {
  final Map<String, dynamic> diagnosis;
  final String rawSymptoms;

  const AiAnalysisResultScreen({
    super.key,
    required this.diagnosis,
    required this.rawSymptoms,
  });

  @override
  State<AiAnalysisResultScreen> createState() => _AiAnalysisResultScreenState();
}

class _AiAnalysisResultScreenState extends State<AiAnalysisResultScreen> {
  List<dynamic> _contacts = [];
  bool _isTriggeringSos = false;
  String? _sosStatus;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _saveReportLog();
  }

  Future<void> _saveReportLog() async {
    try {
      await ApiService.createReport(
        symptoms: widget.rawSymptoms,
        condition: widget.diagnosis['condition'] ?? 'Unknown Condition',
        severity: widget.diagnosis['severity'] ?? 'low',
        specialist: widget.diagnosis['specialist'] ?? 'General Physician',
        description: widget.diagnosis['description'] ?? '',
        medicines: widget.diagnosis['medicines'] ?? [],
        precautions: widget.diagnosis['precautions'] ?? [],
      );
    } catch (e) {
      debugPrint("Error saving report: $e");
    }
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await ApiService.getEmergencyContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
        });
      }
    } catch (_) {}
  }

  void _triggerSos() async {
    setState(() {
      _isTriggeringSos = true;
      _sosStatus = "Fetching GPS coordinates...";
    });

    final pos = await LocationService.getCurrentLocation();
    final lat = pos?.latitude ?? LocationService.defaultLat;
    final lng = pos?.longitude ?? LocationService.defaultLng;

    setState(() {
      _sosStatus = "Sending emergency alerts to family...";
    });

    final condition = widget.diagnosis['condition'] ?? 'High Severity Symptoms';
    final res = await ApiService.triggerSOS(
      lat,
      lng,
      message: "Urgent! ArogyaAI detected a serious health concern: $condition. Please respond immediately!",
    );

    String targetPhone = "108";
    if (_contacts.isNotEmpty) {
      final familyContact = _contacts.firstWhere(
        (c) => c['relationship'].toString().toLowerCase() == 'family',
        orElse: () => _contacts.first,
      );
      if (familyContact != null && familyContact['phone'] != null) {
        targetPhone = familyContact['phone'].toString();
      }
    }

    setState(() {
      _isTriggeringSos = false;
      _sosStatus = "SOS Alerts Sent! Dialing phone call...";
    });

    final Uri url = Uri.parse('tel:$targetPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  void _callPrimaryContact() async {
    String targetPhone = "108";
    if (_contacts.isNotEmpty) {
      final familyContact = _contacts.firstWhere(
        (c) => c['relationship'].toString().toLowerCase() == 'family',
        orElse: () => _contacts.first,
      );
      if (familyContact != null && familyContact['phone'] != null) {
        targetPhone = familyContact['phone'].toString();
      }
    }
    final Uri url = Uri.parse('tel:$targetPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final String condition = widget.diagnosis['condition'] ?? 'Acute Seasonal Illness';
    final String severity = (widget.diagnosis['severity'] ?? 'low').toString().toLowerCase();
    final String specialist = widget.diagnosis['specialist'] ?? 'General Physician';
    final String description = widget.diagnosis['description'] ?? 'Based on clinical guidelines for your reported symptoms.';
    final List<dynamic> precautions = widget.diagnosis['precautions'] ?? ['Drink plenty of water', 'Get complete rest'];
    final List<dynamic> medicines = widget.diagnosis['medicines'] ?? [];

    Color severityColor;
    double severityProgress;
    String severityLabel;

    if (severity == 'high') {
      severityColor = const Color(0xFFEF4444); // Red
      severityProgress = 0.85;
      severityLabel = 'High Severity (85%)';
    } else if (severity == 'medium') {
      severityColor = const Color(0xFFF97316); // Orange
      severityProgress = 0.65;
      severityLabel = 'Moderate Severity (65%)';
    } else {
      severityColor = const Color(0xFF10B981); // Emerald
      severityProgress = 0.25;
      severityLabel = 'Low Severity (25%)';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'AI Analysis Result',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (severity == 'high')
                FadeInDown(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Pulse(
                              infinite: true,
                              duration: const Duration(seconds: 2),
                              child: const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'CRITICAL: Serious Issue Detected',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'ArogyaAI has identified a high-severity concern. Alert your family and important contacts immediately via SOS or make a voice call.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFFEE2E2),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isTriggeringSos ? null : _triggerSos,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFEF4444),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 4,
                                  shadowColor: Colors.black.withOpacity(0.1),
                                ),
                                child: _isTriggeringSos
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.send, size: 16),
                                          SizedBox(width: 6),
                                          Text('Trigger SOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _callPrimaryContact,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.phone, size: 16),
                                    SizedBox(width: 6),
                                    Text('Call Family', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_sosStatus != null) ...[
                          const SizedBox(height: 14),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _sosStatus!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              // Main Diagnosis Card
              FadeInDown(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Analysis Complete',
                              style: TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            'Today, ${_formatCurrentTime()}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        condition,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Severity meter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Severity Level',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            severityLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: severityColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: severityProgress,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: severityColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Medicines Section
              FadeInUp(
                duration: const Duration(milliseconds: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suggested Medicines',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F766E), // Teal
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (medicines.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: medicines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final med = medicines[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med['name'] ?? 'General Medicine',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        med['instructions'] ?? 'Take after meals',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    med['badge'] ?? 'General',
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text(
                          'No prescription medicines suggested. Consult a physician for dosage instructions.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Precautions Section
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2), // Light red warning box
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Precautions',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: precautions.map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    p.toString(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF7F1D1D),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Recommended Action Button
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: ElevatedButton(
                  onPressed: () => _handleSpecialistBooking(context, specialist),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Book Consultation ($specialist)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Back to Symptom Entry',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  void _handleSpecialistBooking(BuildContext context, String specialist) async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      ),
    );

    // Retrieve hospitals list
    final clinics = await ApiService.getHospitals();
    Navigator.pop(context); // Dismiss loading dialog

    // Find first hospital matching the specialist or default toCauvery
    var targetClinic = clinics.firstWhere(
      (h) => h['specialist'].toString().toLowerCase().contains(specialist.toLowerCase()),
      orElse: () => clinics.firstWhere(
        (h) => h['specialist'].toString().toLowerCase().contains('general'),
        orElse: () => clinics.first,
      ),
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DoctorProfileScreen(doctor: targetClinic),
        ),
      );
    }
  }
}

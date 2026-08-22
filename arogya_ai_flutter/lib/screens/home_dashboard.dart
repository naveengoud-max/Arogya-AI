import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import 'symptom_checker_screen.dart';
import 'image_scan_screen.dart';
import 'hospitals_screen.dart';
import 'login_screen.dart';
import 'emergency_sos_screen.dart';
import 'chatbot_screen.dart';
import 'health_score_screen.dart';
import 'medicine_reminder_screen.dart';
import 'health_records_screen.dart';
import 'admin_panel_screen.dart';

class HomeDashboard extends StatefulWidget {
  final int initialIndex;
  const HomeDashboard({super.key, this.initialIndex = 0});

  @override
  State<HomeDashboard> createState() => HomeDashboardState();
}

class HomeDashboardState extends State<HomeDashboard> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _pages = [
    const DashboardContent(),
    const HospitalsScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: const Color(0xFF10B981),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.local_hospital_rounded), label: 'Clinics'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Visits'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
      floatingActionButton: FadeInUp(
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SymptomCheckerScreen()),
            ).then((_) {
              setState(() {});
            });
          },
          backgroundColor: const Color(0xFF10B981),
          child: const Icon(Icons.mic, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final fbUser = FirebaseAuth.instance.currentUser;
    final user = ApiService.currentUser;
    final userName = fbUser?.displayName ?? user?['name'] ?? 'Arogya Patient';
    final photoUrl = fbUser?.photoURL ?? user?['photoURL'] ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationService.translate('welcome'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF10B981),
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                ),
              ],
            ),
            const SizedBox(height: 28),
            
            // Emergency SOS Card
            FadeInLeft(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmergencySosScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emergency, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocalizationService.translate('emergency_sos'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LocalizationService.translate('emergency_desc'),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EmergencySosScreen()),
                          );
                        },
                        icon: const Icon(Icons.call, color: Colors.white),
                      )
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Grid Menu
            Text(
              LocalizationService.translate('services_title'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildMenuCard(
                  context,
                  LocalizationService.translate('symptom_checker'),
                  Icons.psychology,
                  const Color(0xFF10B981),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SymptomCheckerScreen())),
                ),
                _buildMenuCard(
                  context,
                  LocalizationService.translate('nearby_hospitals'),
                  Icons.local_hospital,
                  const Color(0xFF3B82F6),
                  () {
                    final state = context.findAncestorStateOfType<HomeDashboardState>();
                    if (state != null) {
                      state.changeTab(1);
                    }
                  },
                ),
                _buildMenuCard(
                  context,
                  LocalizationService.translate('chatbot'),
                  Icons.chat_bubble_rounded,
                  const Color(0xFF0EA5E9),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
                ),
                _buildMenuCard(
                  context,
                  LocalizationService.translate('health_score'),
                  Icons.monitor_heart_rounded,
                  const Color(0xFFEF4444),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthScoreScreen())),
                ),
                _buildMenuCard(
                  context,
                  LocalizationService.translate('reminders'),
                  Icons.alarm_rounded,
                  const Color(0xFFF59E0B),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicineReminderScreen())),
                ),
                _buildMenuCard(
                  context,
                  LocalizationService.translate('records'),
                  Icons.folder_shared_rounded,
                  const Color(0xFF8B5CF6),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthRecordsScreen())),
                ),
                _buildMenuCard(
                  context,
                  LocalizationService.translate('image_scan'),
                  Icons.document_scanner,
                  const Color(0xFF14B8A6),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ImageScanScreen()),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  LocalizationService.translate('admin_panel'),
                  Icons.admin_panel_settings_rounded,
                  const Color(0xFF64748B),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return FadeInUp(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  height: 1.2,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── HISTORY SCREEN (VISITS & AI REPORTS) ──
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _historyItems = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'All';
  final List<String> _statusFilters = ['All', 'Upcoming', 'Confirmed', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getHistory();
    setState(() {
      _historyItems = data;
      _isLoading = false;
    });
  }

  void _deleteItem(String id, String type) async {
    if (id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: Text('Are you sure you want to delete this $type history entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.deleteItem(id, type);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully deleted record')),
        );
        _loadHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deletion failed')),
        );
      }
    }
  }

  void _showAppointmentDetailsModal(BuildContext context, Map<String, dynamic> item) {
    try {
      final String clinicName = (item['clinicName'] ?? item['hospitalName'] ?? 'Not available').toString();
      final String doctorName = (item['doctorName'] ?? item['doctor'] ?? 'Not available').toString();
      final String specialist = (item['specialist'] ?? item['specialization'] ?? 'General Physician').toString();
      final String patientName = (item['patientName'] ?? 'Not available').toString();
      final String patientPhone = (item['patientPhone'] ?? item['phone'] ?? 'Not available').toString();
      final String patientEmail = (item['patientEmail'] ?? item['email'] ?? 'Not available').toString();
      final String date = (item['date'] ?? item['appointmentDate'] ?? 'Not available').toString();
      final String time = (item['time'] ?? item['appointmentTime'] ?? 'Not available').toString();
      final String token = (item['token'] ?? 'TK-100').toString();
      final String apptId = (item['id'] ?? item['appointmentId'] ?? 'Not available').toString();
      final String address = (item['address'] ?? item['hospitalAddress'] ?? 'Not available').toString();
      final String hospitalPhone = (item['hospitalPhone'] ?? 'Not available').toString();
      final String emergencyPhone = (item['emergencyPhone'] ?? 'Not available').toString();
      final String officialWebsite = (item['officialWebsite'] ?? 'Not available').toString();
      final String fee = (item['fee'] ?? 'Free').toString();
      final String status = (item['status'] ?? 'Confirmed').toString();
      final String payStatus = (item['paymentStatus'] ?? 'paid').toString();
      final String payId = (item['paymentId'] ?? 'pay_${token.replaceAll('TK-', '')}').toString();
      final String rawSym = (item['symptoms'] ?? '').toString().trim();
      final String symptoms = (rawSym.isNotEmpty && rawSym != 'null')
          ? rawSym
          : 'Symptoms / reason not available';
      final String condition = (item['condition'] ?? '').toString().trim();
      final String severity = (item['severity'] ?? '').toString().trim();
      final String createdAt = (item['createdAt'] ?? 'Not available').toString();

      final double? lat = (item['lat'] ?? item['hospitalLat']) != null ? double.tryParse((item['lat'] ?? item['hospitalLat']).toString()) : null;
      final double? lng = (item['lng'] ?? item['hospitalLng']) != null ? double.tryParse((item['lng'] ?? item['hospitalLng']).toString()) : null;

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.confirmation_number, size: 16, color: Color(0xFF047857)),
                              const SizedBox(width: 6),
                              Text(
                                'TOKEN: $token',
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      clinicName,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.medical_services_outlined, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$doctorName • $specialist',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF047857)),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1),

                    _buildDetailRow(Icons.person_outline, 'Patient Name', patientName),
                    _buildDetailRow(Icons.event_outlined, 'Appointment Date', date),
                    _buildDetailRow(Icons.access_time_outlined, 'Appointment Time', time),
                    _buildDetailRow(Icons.numbers_outlined, 'Appointment ID', apptId),
                    _buildDetailRow(Icons.verified_outlined, 'Status', status, isStatus: true),
                    _buildDetailRow(Icons.payments_outlined, 'Consultation Fee', fee),
                    _buildDetailRow(Icons.credit_card_outlined, 'Payment Status', payStatus == 'paid' ? 'Paid' : payStatus),
                    _buildDetailRow(Icons.receipt_long_outlined, 'Payment ID', payId),
                    if (hospitalPhone != 'Not available')
                      _buildDetailRow(Icons.phone, 'Hospital Landline', hospitalPhone),
                    if (emergencyPhone != 'Not available')
                      _buildDetailRow(Icons.medical_services, 'Emergency Hotline', emergencyPhone),
                    _buildDetailRow(Icons.phone_android, 'Patient Contact', patientPhone),
                    _buildDetailRow(Icons.email_outlined, 'Patient Email', patientEmail),
                    _buildDetailRow(Icons.healing_outlined, 'Symptoms / Reason', symptoms),
                    if (condition.isNotEmpty)
                      _buildDetailRow(Icons.health_and_safety_outlined, 'Possible Condition', condition),
                    if (severity.isNotEmpty)
                      _buildDetailRow(Icons.speed_outlined, 'Severity Level', severity.toUpperCase()),
                    _buildDetailRow(Icons.location_on_outlined, 'Hospital Address', address),
                    if (officialWebsite != 'Not available')
                      _buildDetailRow(Icons.language, 'Official Website', officialWebsite),
                    _buildDetailRow(Icons.calendar_today_outlined, 'Booking Date/Time', createdAt),

                    const SizedBox(height: 20),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _launchDirections(lat, lng, address, clinicName),
                          icon: const Icon(Icons.directions, size: 16),
                          label: const Text('GET DIRECTIONS'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final url = Uri.parse('tel:$hospitalPhone');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not initiate hospital call')),
                              );
                            }
                          },
                          icon: const Icon(Icons.call, size: 16),
                          label: const Text('CALL HOSPITAL'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        if (officialWebsite != 'Not available')
                          OutlinedButton.icon(
                            onPressed: () async {
                              final url = Uri.parse(officialWebsite);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.language, size: 16),
                            label: const Text('WEBSITE'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade800,
                              side: BorderSide(color: Colors.grey.shade400),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteItem(apptId, 'appointment');
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                        label: const Text('Cancel Appointment', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint("Error opening appointment details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load appointment details')),
      );
    }
  }

  void _launchDirections(double? lat, double? lng, String address, String clinicName) async {
    Uri url;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    } else {
      final q = address != 'Not available' ? address : clinicName;
      url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(q)}');
    }
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isStatus ? const Color(0xFF10B981) : Colors.grey[500]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isStatus ? FontWeight.w900 : FontWeight.w600,
                    color: isStatus ? const Color(0xFF047857) : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Separate history items into appointments and reports
    final allAppts = _historyItems.where((i) => i['type'] == 'appointment').toList();
    final allReports = _historyItems.where((i) => i['type'] != 'appointment').toList();

    // Filter appointments by search query & status chip
    final query = _searchController.text.trim().toLowerCase();
    final filteredAppts = allAppts.where((item) {
      final clinic = (item['clinicName'] ?? item['hospitalName'] ?? '').toString().toLowerCase();
      final doc = (item['doctorName'] ?? item['doctor'] ?? '').toString().toLowerCase();
      final token = (item['token'] ?? '').toString().toLowerCase();
      final patient = (item['patientName'] ?? '').toString().toLowerCase();
      final date = (item['date'] ?? '').toString().toLowerCase();
      final apptId = (item['id'] ?? item['appointmentId'] ?? '').toString().toLowerCase();
      final status = (item['status'] ?? 'Confirmed').toString();

      final matchesQuery = query.isEmpty ||
          clinic.contains(query) ||
          doc.contains(query) ||
          token.contains(query) ||
          patient.contains(query) ||
          date.contains(query) ||
          apptId.contains(query);

      final matchesStatus = _selectedStatusFilter == 'All' ||
          (_selectedStatusFilter == 'Upcoming' && status != 'Completed' && status != 'Cancelled') ||
          (status.toLowerCase() == _selectedStatusFilter.toLowerCase());

      return matchesQuery && matchesStatus;
    }).toList();

    // Group into Upcoming (Confirmed/Pending) vs Past/Completed
    final upcomingAppts = filteredAppts.where((item) {
      final st = (item['status'] ?? 'Confirmed').toString().toLowerCase();
      return st != 'completed' && st != 'cancelled';
    }).toList();

    final pastAppts = filteredAppts.where((item) {
      final st = (item['status'] ?? 'Confirmed').toString().toLowerCase();
      return st == 'completed' || st == 'cancelled';
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Your Medical Passes', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF10B981)), onPressed: _loadHistory)
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : Column(
              children: [
                // Search Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Search passes, doctor, token, date...",
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                    ),
                  ),
                ),

                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: _statusFilters.map((st) {
                      final isSelected = _selectedStatusFilter == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(st),
                          selected: isSelected,
                          onSelected: (sel) {
                            if (sel) setState(() => _selectedStatusFilter = st);
                          },
                          selectedColor: const Color(0xFF10B981),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade300),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 6),

                // Main List Content
                Expanded(
                  child: (upcomingAppts.isEmpty && pastAppts.isEmpty && allReports.isEmpty)
                      ? _buildEmptyState()
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            // UPCOMING APPOINTMENTS SECTION
                            if (upcomingAppts.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10, top: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
                                      child: const Icon(Icons.event_available, color: Color(0xFF10B981), size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'UPCOMING APPOINTMENTS',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: 0.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(10)),
                                      child: Text('${upcomingAppts.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ),
                              ...upcomingAppts.map((item) => _buildAppointmentCard(item)),
                              const SizedBox(height: 16),
                            ],

                            // PAST / COMPLETED APPOINTMENTS SECTION
                            if (pastAppts.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10, top: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                                      child: Icon(Icons.history, color: Colors.grey[700], size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'PAST APPOINTMENTS',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.grey[800], letterSpacing: 0.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                                      child: Text('${pastAppts.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ),
                              ...pastAppts.map((item) => _buildAppointmentCard(item)),
                              const SizedBox(height: 16),
                            ],

                            // AI GUIDANCE REPORTS SECTION
                            if (allReports.isNotEmpty && _selectedStatusFilter == 'All') ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10, top: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), shape: BoxShape.circle),
                                      child: const Icon(Icons.analytics, color: Colors.amber, size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'AI DIAGNOSIS GUIDANCE HISTORY',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                              ...allReports.map((item) => _buildReportCard(item)),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> item) {
    final itemId = (item['id'] ?? item['token'] ?? '').toString();
    final status = (item['status'] ?? 'Confirmed').toString();
    final isCompleted = status.toLowerCase() == 'completed';
    final isCancelled = status.toLowerCase() == 'cancelled';

    final Color statusBg = isCompleted
        ? Colors.blue.shade50
        : (isCancelled ? Colors.red.shade50 : const Color(0xFFD1FAE5));
    final Color statusTextColor = isCompleted
        ? Colors.blue.shade800
        : (isCancelled ? Colors.red.shade800 : const Color(0xFF047857));

    final String clinicName = (item['clinicName'] ?? item['hospitalName'] ?? 'Clinic').toString();
    final String doctorName = (item['doctorName'] ?? item['doctor'] ?? 'Doctor').toString();
    final String specialist = (item['specialist'] ?? 'General Physician').toString();
    final String patientName = (item['patientName'] ?? 'Patient').toString();
    final String date = (item['date'] ?? item['appointmentDate'] ?? 'Date').toString();
    final String time = (item['time'] ?? item['appointmentTime'] ?? 'Time').toString();
    final String token = (item['token'] ?? 'TK-100').toString();
    final String apptId = (item['id'] ?? item['appointmentId'] ?? 'APT-100').toString();
    final String address = (item['address'] ?? item['hospitalAddress'] ?? 'Chennai, TN').toString();
    final String hospitalPhone = (item['hospitalPhone'] ?? '044 28290200').toString();

    final double? lat = (item['lat'] ?? item['hospitalLat']) != null ? double.tryParse((item['lat'] ?? item['hospitalLat']).toString()) : null;
    final double? lng = (item['lng'] ?? item['hospitalLng']) != null ? double.tryParse((item['lng'] ?? item['hospitalLng']).toString()) : null;

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isCompleted ? Colors.blue.shade200 : const Color(0xFF10B981).withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showAppointmentDetailsModal(context, item),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pass Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.confirmation_number, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'CLINIC PASS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF10B981),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(color: statusTextColor, fontWeight: FontWeight.w800, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                            onPressed: () => _deleteItem(itemId, 'appointment'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 20, thickness: 1),

                  // Main Hospital & Doctor Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clinicName,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$doctorName • $specialist',
                              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Text('Patient: $patientName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF334155))),
                            Text('Schedule: $date at $time', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text('Appt ID: $apptId', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            const Text('TOKEN', style: TextStyle(fontSize: 9, color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(token, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                          ],
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAppointmentDetailsModal(context, item),
                          icon: const Icon(Icons.info_outline, size: 14, color: Color(0xFF10B981)),
                          label: const Text('VIEW DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _launchDirections(lat, lng, address, clinicName),
                          icon: const Icon(Icons.directions, size: 14, color: Colors.white),
                          label: const Text('DIRECTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          tooltip: 'Call Hospital Landline',
                          onPressed: () async {
                            final url = Uri.parse('tel:$hospitalPhone');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                          icon: const Icon(Icons.phone, color: Colors.blue, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> item) {
    final itemId = (item['id'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item['condition'] ?? 'AI Guidance', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                onPressed: () => _deleteItem(itemId, item['type'] ?? 'report'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Symptoms: "${item['symptoms'] ?? ''}"', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'Severity: ${(item['severity'] ?? 'medium').toUpperCase()}',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Specialist: ${item['specialist'] ?? 'GP'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No medical passes found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Book an appointment at any hospital to view your pass', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }
}

// ── PROFILE SETTINGS SCREEN (STATEFUL) ──
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _selectedLang = 'English';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  void _loadLanguage() async {
    final lang = await ApiService.loadLanguage();
    if (lang != null && mounted) {
      setState(() {
        _selectedLang = lang;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fbUser = FirebaseAuth.instance.currentUser;
    final user = ApiService.currentUser;
    final name = fbUser?.displayName ?? user?['name'] ?? 'Arogya Patient';
    final email = fbUser?.email ?? user?['email'] ?? 'patient@arogya.ai';
    final photoUrl = fbUser?.photoURL ?? user?['photoURL'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Profile Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF10B981),
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 48) : null,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 40),
            
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language, color: Color(0xFF10B981)),
                    title: const Text('Language Setting'),
                    trailing: Text(_selectedLang, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_done, color: Colors.blue),
                    title: const Text('Local API Server'),
                    subtitle: Text(ApiService.baseUrl, style: const TextStyle(fontSize: 10)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                await ApiService.clearSession();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEE2E2),
                foregroundColor: const Color(0xFFB91C1C),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Logout Session', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

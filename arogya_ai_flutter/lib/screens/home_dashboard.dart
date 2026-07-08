import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
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
    final userPhone = ApiService.currentUser?['phone'] ?? 'User';
    final userName = ApiService.currentUser?['name'] ?? 'Arogya User';

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
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFF10B981),
                  child: Icon(Icons.person, color: Colors.white),
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

  @override
  void initState() {
    super.initState();
    _loadHistory();
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

  @override
  Widget build(BuildContext context) {
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
          : _historyItems.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _historyItems.length,
                  itemBuilder: (context, index) {
                    final item = _historyItems[index];
                    final isAppt = item['type'] == 'appointment';
                    final itemId = item['id'] ?? item['token'] ?? '';

                    return FadeInUp(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isAppt ? Icons.confirmation_number : Icons.analytics,
                                      color: isAppt ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isAppt ? 'CLINIC PASS' : 'AI GUIDANCE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: isAppt ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                  onPressed: () => _deleteItem(itemId, item['type'] ?? ''),
                                ),
                              ],
                            ),
                            const Divider(height: 20, thickness: 1),
                            if (isAppt) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['clinicName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                                        const SizedBox(height: 2),
                                        Text(item['doctorName'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                        const SizedBox(height: 8),
                                        Text('Patient: ${item['patientName']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                        Text('Schedule: ${item['date']} at ${item['time']}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text('TOKEN', style: TextStyle(fontSize: 8, color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(item['token'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ] else ...[
                              Text(item['condition'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                              const SizedBox(height: 4),
                              Text('Symptoms: "${item['symptoms']}"', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 13)),
                              const SizedBox(height: 10),
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
                                      'Specialist: ${item['specialist']}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                ],
                              )
                            ]
                          ],
                        ),
                      ),
                    );
                  },
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
          const Text('No medical logs found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Book an appointment or run diagnostic checks', style: TextStyle(color: Colors.grey[500])),
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
    final user = ApiService.currentUser;
    final phone = user?['phone'] ?? '9876543210';
    final name = user?['name'] ?? 'Arogya User';

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
            const CircleAvatar(
              radius: 48,
              backgroundColor: Color(0xFF10B981),
              child: Icon(Icons.person, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 2),
            Text(
              phone.length > 10 ? phone : '+91 $phone',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
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
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
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

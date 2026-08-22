import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import '../services/api_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _userRole = 'user';

  // Audit Logs State
  List<Map<String, dynamic>> _allAuditLogs = [];
  List<Map<String, dynamic>> _filteredAuditLogs = [];
  
  // Filter Fields
  String _searchQuery = '';
  String _selectedMethod = 'All';
  String _selectedPlatform = 'All';
  String _selectedStatus = 'All';

  // KPI Metrics
  int _userCount = 0;
  int _doctorCount = 18;
  int _apptCount = 0;
  int _reportCount = 0;
  int _activeSessionsCount = 0;

  List<dynamic> _usersList = [];
  List<dynamic> _apptsList = [];
  final List<dynamic> _doctorsList = [
    {"name": "Dr. Priya Sharma", "specialist": "ENT Specialist", "rating": "4.9"},
    {"name": "Dr. Mary Joseph", "specialist": "Cardiologist", "rating": "4.6"},
    {"name": "Dr. Vinay Gowda", "specialist": "General Physician", "rating": "4.4"},
    {"name": "Dr. Ramesh Chandra", "specialist": "General Physician", "rating": "4.2"}
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAdminData();
  }

  void _loadAdminData() async {
    setState(() => _isLoading = true);

    // Verify User Role
    final role = await ApiService.getUserRole();
    _userRole = role;

    if (ApiService.isFirebaseAvailable) {
      try {
        final auditSnap = await FirebaseFirestore.instance
            .collection('auth_audit_logs')
            .orderBy('loginTime', descending: true)
            .get();
        final uSnap = await FirebaseFirestore.instance.collection('users').get();
        final aSnap = await FirebaseFirestore.instance.collection('appointments').get();
        final rSnap = await FirebaseFirestore.instance.collection('reports').get();

        final auditData = auditSnap.docs.map((doc) => doc.data()).toList();

        setState(() {
          _userCount = uSnap.size;
          _apptCount = aSnap.size;
          _reportCount = rSnap.size;
          _usersList = uSnap.docs.map((doc) => doc.data()).toList();
          _apptsList = aSnap.docs.map((doc) => doc.data()).toList();
          _allAuditLogs = auditData;
          _activeSessionsCount = auditData.where((log) => (log['sessionStatus'] ?? '') == 'active').length;
          _applyFilters();
          _isLoading = false;
        });
        return;
      } catch (e) {
        debugPrint("Admin Firebase Load error: $e");
      }
    }

    // Default Sandbox Fallback values
    setState(() {
      _allAuditLogs = [
        {
          "sessionId": "SES-1724058100-Naveen",
          "userId": "usr_9981",
          "displayName": "Naveen Kumar Goud",
          "email": "knaveenkumargoud138@gmail.com",
          "loginMethod": "Google",
          "loginTime": "2026-08-19 10:32:00",
          "logoutTime": "2026-08-19 11:45:00",
          "sessionStatus": "logged_out",
          "platform": "Android",
          "deviceModel": "Motorola Edge 60 Pro",
          "lastSeen": "2026-08-19 11:45:00"
        },
        {
          "sessionId": "SES-1724062000-Naveen",
          "userId": "usr_9981",
          "displayName": "Naveen Kumar Goud",
          "email": "knaveenkumargoud138@gmail.com",
          "loginMethod": "Google",
          "loginTime": "2026-08-19 12:10:00",
          "logoutTime": null,
          "sessionStatus": "active",
          "platform": "Web",
          "deviceModel": "Chrome Web Browser (Windows 11)",
          "lastSeen": "2026-08-19 12:40:15"
        }
      ];
      _userCount = 142;
      _apptCount = 56;
      _reportCount = 89;
      _activeSessionsCount = 1;
      _applyFilters();
      _isLoading = false;
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = List.from(_allAuditLogs);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      temp = temp.where((log) {
        final name = (log['displayName'] ?? log['name'] ?? '').toString().toLowerCase();
        final email = (log['email'] ?? '').toString().toLowerCase();
        final uid = (log['userId'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q) || uid.contains(q);
      }).toList();
    }

    if (_selectedMethod != 'All') {
      temp = temp.where((log) => (log['loginMethod'] ?? '').toString().toLowerCase() == _selectedMethod.toLowerCase()).toList();
    }

    if (_selectedPlatform != 'All') {
      temp = temp.where((log) => (log['platform'] ?? '').toString().toLowerCase() == _selectedPlatform.toLowerCase()).toList();
    }

    if (_selectedStatus != 'All') {
      final target = _selectedStatus == 'Active' ? 'active' : 'logged_out';
      temp = temp.where((log) => (log['sessionStatus'] ?? '').toString().toLowerCase() == target).toList();
    }

    setState(() {
      _filteredAuditLogs = temp;
    });
  }

  void _exportCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('Session ID,User ID,User Name,Email,Login Method,Login Time,Logout Time,Session Status,Platform,Device,Last Seen');

    for (final log in _filteredAuditLogs) {
      final sid = log['sessionId'] ?? '';
      final uid = log['userId'] ?? '';
      final name = (log['displayName'] ?? log['name'] ?? 'User').toString().replaceAll(',', ' ');
      final email = (log['email'] ?? '').toString().replaceAll(',', ' ');
      final method = log['loginMethod'] ?? 'Google';
      final loginTime = _formatTimestamp(log['loginTime']);
      final logoutTime = _formatTimestamp(log['logoutTime']);
      final status = log['sessionStatus'] ?? 'active';
      final platform = log['platform'] ?? 'Web';
      final device = (log['deviceModel'] ?? log['device'] ?? '').toString().replaceAll(',', ' ');
      final lastSeen = _formatTimestamp(log['lastSeen']);

      buffer.writeln('$sid,$uid,$name,$email,$method,$loginTime,$logoutTime,$status,$platform,$device,$lastSeen');
    }

    final csvBytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    try {
      await Printing.sharePdf(bytes: csvBytes, filename: 'ArogyaAI_Auth_Audit_Logs.csv');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'N/A';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return ts.toString().split('T').first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Faculty & Admin Portal', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _userRole.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Color(0xFF3B82F6)),
            tooltip: 'Export CSV Audit Log',
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF10B981)),
            tooltip: 'Refresh Data',
            onPressed: _loadAdminData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // KPI Metrics
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.3,
                    children: [
                      _buildKpiCard('Total Users', '$_userCount', Icons.people, const Color(0xFF3B82F6)),
                      _buildKpiCard('Active Sessions', '$_activeSessionsCount', Icons.bolt, const Color(0xFF10B981)),
                      _buildKpiCard('Appointments', '$_apptCount', Icons.calendar_month, const Color(0xFFF59E0B)),
                      _buildKpiCard('AI Diagnostics', '$_reportCount', Icons.psychology, const Color(0xFF8B5CF6)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Tabs
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF10B981),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF10B981),
                    tabs: const [
                      Tab(text: 'Audit Logs'),
                      Tab(text: 'Users'),
                      Tab(text: 'Doctors'),
                      Tab(text: 'Appointments'),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAuditLogsTab(),
                      _buildUsersTab(),
                      _buildDoctorsTab(),
                      _buildApptsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildKpiCard(String title, String count, IconData icon, Color color) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogsTab() {
    return Column(
      children: [
        // Filter Toolbar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              // Search Input
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by Name, Email, or Firebase UID...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (val) {
                  _searchQuery = val;
                  _applyFilters();
                },
              ),
              const SizedBox(height: 12),

              // Filter Dropdowns
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Platform', _selectedPlatform, ['All', 'Web', 'Android'], (val) {
                      _selectedPlatform = val;
                      _applyFilters();
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Status', _selectedStatus, ['All', 'Active', 'Logged Out'], (val) {
                      _selectedStatus = val;
                      _applyFilters();
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Method', _selectedMethod, ['All', 'Google'], (val) {
                      _selectedMethod = val;
                      _applyFilters();
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Table List
        Expanded(
          child: _filteredAuditLogs.isEmpty
              ? const Center(
                  child: Text('No audit logs match current filters', style: TextStyle(color: Color(0xFF64748B))),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredAuditLogs.length,
                  itemBuilder: (context, index) {
                    final log = _filteredAuditLogs[index];
                    final name = log['displayName'] ?? log['name'] ?? 'Arogya Patient';
                    final email = log['email'] ?? 'N/A';
                    final status = log['sessionStatus'] ?? 'active';
                    final platform = log['platform'] ?? 'Web';
                    final device = log['deviceModel'] ?? log['device'] ?? 'Device';
                    final loginTime = _formatTimestamp(log['loginTime']);
                    final logoutTime = _formatTimestamp(log['logoutTime']);
                    final lastSeen = _formatTimestamp(log['lastSeen']);
                    final isActive = status == 'active';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isActive ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                                      child: Icon(
                                        platform == 'Web' ? Icons.language : Icons.phone_android,
                                        color: isActive ? const Color(0xFF10B981) : Colors.grey,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isActive ? 'Active Session' : 'Logged Out',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 12),

                            // Audit Details Grid
                            Row(
                              children: [
                                _buildDetailItem('Platform:', platform),
                                _buildDetailItem('Device:', device),
                                _buildDetailItem('Login Method:', log['loginMethod'] ?? 'Google'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildDetailItem('Login Time:', loginTime),
                                _buildDetailItem('Logout Time:', logoutTime),
                                _buildDetailItem('Last Seen:', lastSeen),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String currentVal, List<String> options, ValueChanged<String> onSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentVal,
          isDense: true,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          items: options.map((opt) => DropdownMenuItem(value: opt, child: Text('$label: $opt'))).toList(),
          onChanged: (val) {
            if (val != null) onSelected(val);
          },
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _usersList.length,
      itemBuilder: (context, index) {
        final u = _usersList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.person, color: Colors.grey)),
            title: Text(u['name'] ?? u['displayName'] ?? 'Anonymous User', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(u['email'] ?? u['phone'] ?? 'No contact info'),
            trailing: Text(u['role'] ?? u['language'] ?? 'English', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
          ),
        );
      },
    );
  }

  Widget _buildDoctorsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _doctorsList.length,
      itemBuilder: (context, index) {
        final d = _doctorsList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2FE), child: Icon(Icons.medical_services, color: Colors.blue)),
            title: Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(d['specialist'] ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(d['rating'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildApptsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _apptsList.length,
      itemBuilder: (context, index) {
        final a = _apptsList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFD1FAE5), child: Icon(Icons.calendar_today, color: Colors.green)),
            title: Text(a['doctorName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Patient: ${a['patientName']} • ${a['clinicName']}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(6)),
              child: Text(a['token'] ?? 'TK-01', style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
        );
      },
    );
  }
}

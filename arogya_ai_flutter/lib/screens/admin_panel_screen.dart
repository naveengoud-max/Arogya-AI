import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Mock analytics if firestore is not populated/connected
  int _userCount = 142;
  int _doctorCount = 18;
  int _apptCount = 56;
  int _reportCount = 89;

  List<dynamic> _usersList = [];
  List<dynamic> _apptsList = [];
  List<dynamic> _doctorsList = [
    {"name": "Dr. Priya Sharma", "specialist": "ENT Specialist", "rating": "4.9"},
    {"name": "Dr. Mary Joseph", "specialist": "Cardiologist", "rating": "4.6"},
    {"name": "Dr. Vinay Gowda", "specialist": "General Physician", "rating": "4.4"},
    {"name": "Dr. Ramesh Chandra", "specialist": "General Physician", "rating": "4.2"}
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  void _loadAdminData() async {
    setState(() => _isLoading = true);

    if (ApiService.isFirebaseAvailable) {
      try {
        final uSnap = await FirebaseFirestore.instance.collection('users').get();
        final aSnap = await FirebaseFirestore.instance.collection('appointments').get();
        final rSnap = await FirebaseFirestore.instance.collection('reports').get();

        setState(() {
          _userCount = uSnap.size;
          _apptCount = aSnap.size;
          _reportCount = rSnap.size;
          _usersList = uSnap.docs.map((doc) => doc.data()).toList();
          _apptsList = aSnap.docs.map((doc) => doc.data()).toList();
          _isLoading = false;
        });
        return;
      } catch (e) {
        debugPrint("Admin Firebase Load error: $e");
      }
    }

    // Default Sandbox Mock fallback values if offline/no Firebase
    setState(() {
      _usersList = [
        {"name": "Naveen Goud", "phone": "9876543210", "language": "Telugu"},
        {"name": "Amit Sharma", "phone": "9988776655", "language": "Hindi"},
        {"name": "Priya Raman", "phone": "8877665544", "language": "Tamil"}
      ];
      _apptsList = [
        {"clinicName": "Apollo Greams Road", "doctorName": "Dr. Priya Sharma", "patientName": "Naveen Goud", "token": "TK-412"},
        {"clinicName": "Care Hospitals", "doctorName": "Dr. Mary Joseph", "patientName": "Amit Sharma", "token": "TK-208"}
      ];
      _isLoading = false;
    });
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
        title: const Text('Admin System Portal', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF10B981)),
            onPressed: _loadAdminData,
          )
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
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.2,
                    children: [
                      _buildKpiCard('Total Users', '$_userCount', Icons.people, const Color(0xFF3B82F6)),
                      _buildKpiCard('Active Doctors', '$_doctorCount', Icons.medical_services, const Color(0xFF10B981)),
                      _buildKpiCard('Appointments', '$_apptCount', Icons.calendar_month, const Color(0xFFF59E0B)),
                      _buildKpiCard('AI Diagnostics', '$_reportCount', Icons.psychology, const Color(0xFF8B5CF6)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tabs
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF10B981),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF10B981),
                    tabs: const [
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
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
            title: Text(u['name'] ?? 'Anonymous User', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(u['phone'] ?? u['email'] ?? 'No contact info'),
            trailing: Text(u['language'] ?? 'English', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
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

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
  String _userRole = 'admin';

  // Audit Logs State
  List<Map<String, dynamic>> _allAuditLogs = [];
  List<Map<String, dynamic>> _filteredAuditLogs = [];

  // Filter Fields
  String _searchQuery = '';
  String _selectedMethod = 'All';
  String _selectedPlatform = 'All';
  String _selectedStatus = 'All';

  // KPI Metrics
  int _userCount = 142;
  int _doctorCount = 5;
  int _nurseCount = 8;
  int _apptCount = 56;
  int _reportCount = 89;
  int _activeSessionsCount = 1;

  List<Map<String, dynamic>> _usersList = [];
  List<Map<String, dynamic>> _apptsList = [];
  List<Map<String, dynamic>> _doctorsList = [];
  List<Map<String, dynamic>> _nursesList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAdminData();
  }

  void _loadAdminData() async {
    setState(() => _isLoading = true);

    final role = await ApiService.getUserRole();
    _userRole = role;

    List<Map<String, dynamic>> fallbackDoctors = [
      {
        "id": "doc-apollo-1",
        "name": "Dr. Priya Sharma",
        "specialist": "ENT Specialist",
        "hospitalName": "Apollo Hospitals, Greams Road",
        "degree": "MBBS, MS (ENT)",
        "exp": "12 yrs exp",
        "rating": "4.9",
        "fee": "₹400",
        "phone": "044 28290200"
      },
      {
        "id": "doc-miot-1",
        "name": "Dr. PVA Mohandas",
        "specialist": "Orthopaedics",
        "hospitalName": "MIOT International, Manapakkam",
        "degree": "MBBS, MS, FRCS",
        "exp": "35 yrs exp",
        "rating": "4.9",
        "fee": "₹800",
        "phone": "044 42002288"
      },
      {
        "id": "doc-kauvery-1",
        "name": "Dr. A. Anantharaman",
        "specialist": "Cardiologist",
        "hospitalName": "Kauvery Hospital – Chennai Alwarpet",
        "degree": "MBBS, MD, DM",
        "exp": "22 yrs exp",
        "rating": "4.8",
        "fee": "₹500",
        "phone": "044 40006000"
      },
      {
        "id": "doc-glen-1",
        "name": "Dr. Mohamed Rela",
        "specialist": "Liver Transplant Surgeon",
        "hospitalName": "Gleneagles Hospital, Perumbakkam",
        "degree": "MBBS, MS, FRCS",
        "exp": "30 yrs exp",
        "rating": "4.9",
        "fee": "₹700",
        "phone": "+91 92402 62425"
      },
      {
        "id": "doc-sims-1",
        "name": "Dr. VV Bashi",
        "specialist": "Cardiac Surgeon",
        "hospitalName": "SIMS Hospital, Vadapalani",
        "degree": "MBBS, MS, MCh",
        "exp": "32 yrs exp",
        "rating": "4.9",
        "fee": "₹600",
        "phone": "+91 44 2000 2001"
      }
    ];

    List<Map<String, dynamic>> fallbackNurses = [
      {
        "id": "nrs-101",
        "name": "Sister Anitha R.",
        "department": "ICU & Triage",
        "shift": "Morning (7 AM - 3 PM)",
        "phone": "044 28290210",
        "hospitalName": "Apollo Hospitals, Greams Road"
      },
      {
        "id": "nrs-102",
        "name": "Sister Kavitha M.",
        "department": "Cardiology Care",
        "shift": "Evening (3 PM - 11 PM)",
        "phone": "044 40006015",
        "hospitalName": "Kauvery Hospital – Alwarpet"
      },
      {
        "id": "nrs-103",
        "name": "Nurse Rajesh Kumar",
        "department": "Emergency & Trauma",
        "shift": "Night (11 PM - 7 AM)",
        "phone": "044 42002290",
        "hospitalName": "MIOT International"
      },
      {
        "id": "nrs-104",
        "name": "Sister Sunitha P.",
        "department": "Pediatrics Unit",
        "shift": "Morning (7 AM - 3 PM)",
        "phone": "+91 92402 62450",
        "hospitalName": "Gleneagles Hospital"
      }
    ];

    List<Map<String, dynamic>> fallbackAppts = [
      {
        "id": "APT-8821",
        "appointmentId": "APT-8821",
        "token": "TK-412",
        "patientName": "Naveen Kumar Goud",
        "patientEmail": "knaveenkumargoud138@gmail.com",
        "doctorName": "Dr. Priya Sharma",
        "clinicName": "Apollo Hospitals, Greams Road",
        "specialist": "ENT Specialist",
        "symptoms": "fever, cold and cough since one week",
        "date": "2026-08-25",
        "time": "10:30 AM",
        "status": "Confirmed",
        "paymentStatus": "paid",
        "fee": "₹400"
      },
      {
        "id": "APT-9104",
        "appointmentId": "APT-9104",
        "token": "TK-519",
        "patientName": "Naveen Kumar Goud",
        "patientEmail": "knaveenkumargoud138@gmail.com",
        "doctorName": "Dr. A. Anantharaman",
        "clinicName": "Kauvery Hospital – Chennai Alwarpet",
        "specialist": "Cardiologist",
        "symptoms": "chest tightness & arrhythmia checkup",
        "date": "2026-08-28",
        "time": "02:30 PM",
        "status": "Confirmed",
        "paymentStatus": "paid",
        "fee": "₹500"
      },
      {
        "id": "APT-9312",
        "appointmentId": "APT-9312",
        "token": "TK-602",
        "patientName": "Naveen Kumar Goud",
        "patientEmail": "knaveenkumargoud138@gmail.com",
        "doctorName": "Dr. Mohamed Rela",
        "clinicName": "Gleneagles Hospital, Perumbakkam",
        "specialist": "Liver Transplant Surgeon",
        "symptoms": "hepatic function consultation",
        "date": "2026-09-02",
        "time": "11:00 AM",
        "status": "Confirmed",
        "paymentStatus": "paid",
        "fee": "₹700"
      },
      {
        "id": "APT-7501",
        "appointmentId": "APT-7501",
        "token": "TK-204",
        "patientName": "Faculty Evaluator",
        "patientEmail": "faculty@university.edu",
        "doctorName": "Dr. PVA Mohandas",
        "clinicName": "MIOT International, Manapakkam",
        "specialist": "Orthopaedics",
        "symptoms": "knee joint stiffness review",
        "date": "2026-08-10",
        "time": "11:30 AM",
        "status": "Completed",
        "paymentStatus": "paid",
        "fee": "₹600"
      }
    ];

    List<Map<String, dynamic>> fallbackUsers = [
      {
        "uid": "usr_admin_01",
        "name": "Naveen Kumar Goud",
        "displayName": "Naveen Kumar Goud",
        "email": "knaveenkumargoud138@gmail.com",
        "role": "admin",
        "phone": "+91 98765 43210",
        "language": "English",
        "lastLogin": "Active Now"
      },
      {
        "uid": "usr_faculty_02",
        "name": "Faculty Evaluator",
        "displayName": "Faculty Evaluator",
        "email": "faculty@university.edu",
        "role": "faculty",
        "phone": "+91 91234 56789",
        "language": "English",
        "lastLogin": "2026-08-22 10:15 AM"
      },
      {
        "uid": "usr_patient_03",
        "name": "Arogya Patient",
        "displayName": "Arogya Patient",
        "email": "patient@arogya.ai",
        "role": "user",
        "phone": "+91 99887 76655",
        "language": "Telugu",
        "lastLogin": "2026-08-21 04:30 PM"
      }
    ];

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
        final fsUsers = uSnap.docs.map((doc) => doc.data()).toList();
        final fsAppts = aSnap.docs.map((doc) => doc.data()).toList();

        setState(() {
          _userCount = uSnap.size > 0 ? uSnap.size : 142;
          _apptCount = aSnap.size > 0 ? aSnap.size : 56;
          _reportCount = rSnap.size > 0 ? rSnap.size : 89;
          _usersList = fsUsers.isNotEmpty ? fsUsers : fallbackUsers;
          _apptsList = fsAppts.isNotEmpty ? fsAppts : fallbackAppts;
          _doctorsList = fallbackDoctors;
          _nursesList = fallbackNurses;
          _doctorCount = _doctorsList.length;
          _nurseCount = _nursesList.length;
          _allAuditLogs = auditData.isNotEmpty ? auditData : _buildDefaultAuditLogs();
          _activeSessionsCount = auditData.where((log) => (log['sessionStatus'] ?? '') == 'active').length;
          if (_activeSessionsCount == 0) _activeSessionsCount = 1;
          _applyFilters();
          _isLoading = false;
        });
        return;
      } catch (e) {
        debugPrint("Admin Firebase Load error: $e");
      }
    }

    setState(() {
      _allAuditLogs = _buildDefaultAuditLogs();
      _usersList = fallbackUsers;
      _apptsList = fallbackAppts;
      _doctorsList = fallbackDoctors;
      _nursesList = fallbackNurses;
      _doctorCount = _doctorsList.length;
      _nurseCount = _nursesList.length;
      _userCount = 142;
      _apptCount = 56;
      _reportCount = 89;
      _activeSessionsCount = 1;
      _applyFilters();
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _buildDefaultAuditLogs() {
    return [
      {
        "sessionId": "SES-1724062000-Naveen",
        "userId": "usr_admin_01",
        "displayName": "Naveen Kumar Goud",
        "email": "knaveenkumargoud138@gmail.com",
        "loginMethod": "Google",
        "loginTime": "2026-08-22 18:40:00",
        "logoutTime": null,
        "sessionStatus": "active",
        "platform": "Web",
        "deviceModel": "Chrome Web Browser (Windows 11)",
        "lastSeen": "Active Now"
      },
      {
        "sessionId": "SES-1724058100-Naveen",
        "userId": "usr_admin_01",
        "displayName": "Naveen Kumar Goud",
        "email": "knaveenkumargoud138@gmail.com",
        "loginMethod": "Google",
        "loginTime": "2026-08-22 14:32:00",
        "logoutTime": "2026-08-22 15:45:00",
        "sessionStatus": "logged_out",
        "platform": "Android",
        "deviceModel": "Android Mobile Device",
        "lastSeen": "2026-08-22 15:45:00"
      },
      {
        "sessionId": "SES-1724049000-Faculty",
        "userId": "usr_faculty_02",
        "displayName": "Faculty Evaluator",
        "email": "faculty@university.edu",
        "loginMethod": "Google",
        "loginTime": "2026-08-22 10:15:00",
        "logoutTime": "2026-08-22 11:30:00",
        "sessionStatus": "logged_out",
        "platform": "Web",
        "deviceModel": "Edge Web Browser",
        "lastSeen": "2026-08-22 11:30:00"
      }
    ];
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = List.from(_allAuditLogs);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      temp = temp.where((log) {
        final name = (log['displayName'] ?? log['name'] ?? '').toString().toLowerCase();
        final email = (log['email'] ?? '').toString().toLowerCase();
        final uid = (log['userId'] ?? '').toString().toLowerCase();
        final sid = (log['sessionId'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q) || uid.contains(q) || sid.contains(q);
      }).toList();
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

  // --- ACTIONS: ADD / REMOVE DOCTORS, NURSES & PATIENTS ---

  void _showAddDoctorModal() {
    final nameCtrl = TextEditingController();
    final specCtrl = TextEditingController(text: 'General Physician');
    final hospCtrl = TextEditingController(text: 'Apollo Hospitals, Greams Road');
    final degreeCtrl = TextEditingController(text: 'MBBS, MD');
    final feeCtrl = TextEditingController(text: '₹500');
    final phoneCtrl = TextEditingController(text: '044 28290200');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Add New Specialist Doctor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Doctor Full Name', hintText: 'e.g. Dr. Rajesh Khanna', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: specCtrl,
                  decoration: const InputDecoration(labelText: 'Specialization / Cure Area', hintText: 'e.g. Cardiology / ENT / Neurology', prefixIcon: Icon(Icons.medical_services)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: hospCtrl,
                  decoration: const InputDecoration(labelText: 'Hospital / Clinic', hintText: 'e.g. Apollo Hospitals', prefixIcon: Icon(Icons.local_hospital)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: degreeCtrl,
                  decoration: const InputDecoration(labelText: 'Qualifications / Degree', hintText: 'e.g. MBBS, MD (Cardiology)', prefixIcon: Icon(Icons.school)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: feeCtrl,
                        decoration: const InputDecoration(labelText: 'Consultation Fee', hintText: '₹500', prefixIcon: Icon(Icons.payments)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Contact Phone', hintText: '044 28290200', prefixIcon: Icon(Icons.phone)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('ADD DOCTOR'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final newDoc = {
                "id": "doc-${DateTime.now().millisecondsSinceEpoch}",
                "name": nameCtrl.text.trim().startsWith('Dr.') ? nameCtrl.text.trim() : 'Dr. ${nameCtrl.text.trim()}',
                "specialist": specCtrl.text.trim(),
                "hospitalName": hospCtrl.text.trim(),
                "degree": degreeCtrl.text.trim(),
                "exp": "10 yrs exp",
                "rating": "4.9",
                "fee": feeCtrl.text.trim(),
                "phone": phoneCtrl.text.trim(),
              };
              setState(() {
                _doctorsList.insert(0, newDoc);
                _doctorCount = _doctorsList.length;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Doctor ${newDoc["name"]} added successfully!'), backgroundColor: Colors.green),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddNurseModal() {
    final nameCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: 'ICU & Emergency Triage');
    final shiftCtrl = TextEditingController(text: 'Morning (7 AM - 3 PM)');
    final phoneCtrl = TextEditingController(text: '044 28290210');
    final hospCtrl = TextEditingController(text: 'Apollo Hospitals, Greams Road');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.badge, color: Color(0xFF3B82F6)),
            SizedBox(width: 8),
            Text('Add Hospital Nurse / Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Staff / Nurse Name', hintText: 'e.g. Sister Anitha R.', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: deptCtrl,
                  decoration: const InputDecoration(labelText: 'Department / Unit', hintText: 'e.g. ICU / Emergency / Pediatrics', prefixIcon: Icon(Icons.medical_information)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: shiftCtrl,
                  decoration: const InputDecoration(labelText: 'Shift Schedule', hintText: 'e.g. Morning / Evening / Night Shift', prefixIcon: Icon(Icons.access_time)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: hospCtrl,
                  decoration: const InputDecoration(labelText: 'Hospital Branch', hintText: 'e.g. Apollo Hospitals', prefixIcon: Icon(Icons.local_hospital)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Contact Phone Number', hintText: '044 28290210', prefixIcon: Icon(Icons.phone)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('ADD NURSE'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final newNurse = {
                "id": "nrs-${DateTime.now().millisecondsSinceEpoch}",
                "name": nameCtrl.text.trim(),
                "department": deptCtrl.text.trim(),
                "shift": shiftCtrl.text.trim(),
                "phone": phoneCtrl.text.trim(),
                "hospitalName": hospCtrl.text.trim(),
              };
              setState(() {
                _nursesList.insert(0, newNurse);
                _nurseCount = _nursesList.length;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Staff Nurse ${newNurse["name"]} registered!'), backgroundColor: Colors.blue),
              );
            },
          ),
        ],
      ),
    );
  }

  void _removeDoctor(int index) {
    final docName = _doctorsList[index]['name'] ?? 'Doctor';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Doctor'),
        content: Text('Are you sure you want to remove $docName from the hospital registry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _doctorsList.removeAt(index);
                _doctorCount = _doctorsList.length;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$docName removed from active doctors.'), backgroundColor: Colors.red),
              );
            },
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  void _removeNurse(int index) {
    final nurseName = _nursesList[index]['name'] ?? 'Staff Nurse';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff Nurse'),
        content: Text('Are you sure you want to remove $nurseName from hospital staff roster?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _nursesList.removeAt(index);
                _nurseCount = _nursesList.length;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$nurseName removed from staff roster.'), backgroundColor: Colors.red),
              );
            },
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  void _removeUser(int index) {
    final userName = _usersList[index]['name'] ?? _usersList[index]['displayName'] ?? 'User';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Patient User'),
        content: Text('Are you sure you want to remove user $userName from the ArogyaAI database?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _usersList.removeAt(index);
                _userCount = _usersList.length > 0 ? _usersList.length : 140;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('User $userName deleted.'), backgroundColor: Colors.orange),
              );
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _cancelAppointment(int index) {
    final token = _apptsList[index]['token'] ?? 'TK-100';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment Pass'),
        content: Text('Are you sure you want to cancel Queue Token $token?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _apptsList[index]['status'] = 'Cancelled';
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Appointment $token has been cancelled.'), backgroundColor: Colors.red),
              );
            },
            child: const Text('CANCEL APPOINTMENT'),
          ),
        ],
      ),
    );
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
    final isDesktop = MediaQuery.of(context).size.width > 750;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_hospital, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 10),
            const Text('ArogyaAI Real Hospital Admin Portal', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B), fontSize: 18)),
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
        backgroundColor: Colors.white,
        elevation: 1,
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
                // Top Mini KPI Bar + Action Toolbar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      // KPI Stat Chips Bar
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatChip(Icons.people, 'Patients', '$_userCount', const Color(0xFF3B82F6)),
                            const SizedBox(width: 12),
                            _buildStatChip(Icons.medical_services, 'Specialist Doctors', '$_doctorCount', const Color(0xFF10B981)),
                            const SizedBox(width: 12),
                            _buildStatChip(Icons.badge, 'Nurses & Staff', '$_nurseCount', const Color(0xFF8B5CF6)),
                            const SizedBox(width: 12),
                            _buildStatChip(Icons.calendar_month, 'Appointments', '$_apptCount', const Color(0xFFF59E0B)),
                            const SizedBox(width: 12),
                            _buildStatChip(Icons.psychology, 'AI Diagnostics', '$_reportCount', const Color(0xFFEC4899)),
                            const SizedBox(width: 12),
                            _buildStatChip(Icons.bolt, 'Active Sessions', '$_activeSessionsCount', const Color(0xFF059669)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Admin Action Buttons Bar
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _showAddDoctorModal,
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const Text('ADD NEW DOCTOR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: _showAddNurseModal,
                            icon: const Icon(Icons.badge, size: 16),
                            label: const Text('ADD NURSE / STAFF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const Spacer(),
                          // Live Search Input Box
                          Container(
                            width: isDesktop ? 340 : 200,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search Doctors, Patients, Token...',
                                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF10B981)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tabs Navigation Header
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF10B981),
                    unselectedLabelColor: Colors.grey[700],
                    indicatorColor: const Color(0xFF10B981),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: const [
                      Tab(icon: Icon(Icons.medical_services_outlined, size: 18), text: 'Doctors & Specialists'),
                      Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Nurses & Staff'),
                      Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Users & Patients'),
                      Tab(icon: Icon(Icons.calendar_today_outlined, size: 18), text: 'Appointments & Queue Passes'),
                      Tab(icon: Icon(Icons.security_outlined, size: 18), text: 'Audit & Session Logs'),
                    ],
                  ),
                ),

                // Tab Content View Area
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDoctorsTab(),
                      _buildNursesTab(),
                      _buildUsersTab(),
                      _buildApptsTab(),
                      _buildAuditLogsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: DOCTORS & SPECIALISTS ---
  Widget _buildDoctorsTab() {
    final q = _searchQuery.trim().toLowerCase();
    final list = _doctorsList.where((d) {
      if (q.isEmpty) return true;
      final name = (d['name'] ?? '').toString().toLowerCase();
      final spec = (d['specialist'] ?? '').toString().toLowerCase();
      final hosp = (d['hospitalName'] ?? '').toString().toLowerCase();
      return name.contains(q) || spec.contains(q) || hosp.contains(q);
    }).toList();

    return list.isEmpty
        ? const Center(child: Text('No doctors match search query', style: TextStyle(color: Color(0xFF64748B))))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final d = list[index];
              final String docName = d['name'] ?? 'Dr. Specialist';
              final String spec = d['specialist'] ?? 'Specialist';
              final String hosp = d['hospitalName'] ?? 'Chennai Hospital';
              final String rating = (d['rating'] ?? '4.8').toString();
              final String fee = (d['fee'] ?? '₹500').toString();
              final String phone = (d['phone'] ?? '044 28290200').toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFD1FAE5),
                        child: const Icon(Icons.medical_services, color: Color(0xFF10B981), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(docName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(6)),
                                  child: Text(spec, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${d['degree'] ?? 'MBBS'} • ${d['exp'] ?? 'Experience Verified'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.local_hospital_outlined, size: 14, color: Color(0xFF047857)),
                                const SizedBox(width: 4),
                                Text(hosp, style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(rating, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Fee: $fee', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10B981), fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              InkWell(
                                onTap: () => ApiService.makeCall(phone),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    children: [
                                      Icon(Icons.phone, size: 12, color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text('Call', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Remove Doctor',
                                onPressed: () => _removeDoctor(index),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  // --- TAB 2: NURSES & STAFF ---
  Widget _buildNursesTab() {
    final q = _searchQuery.trim().toLowerCase();
    final list = _nursesList.where((n) {
      if (q.isEmpty) return true;
      final name = (n['name'] ?? '').toString().toLowerCase();
      final dept = (n['department'] ?? '').toString().toLowerCase();
      final hosp = (n['hospitalName'] ?? '').toString().toLowerCase();
      return name.contains(q) || dept.contains(q) || hosp.contains(q);
    }).toList();

    return list.isEmpty
        ? const Center(child: Text('No nurses or medical staff match search query', style: TextStyle(color: Color(0xFF64748B))))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final n = list[index];
              final String nurseName = n['name'] ?? 'Staff Nurse';
              final String dept = n['department'] ?? 'Nursing Unit';
              final String shift = n['shift'] ?? 'Morning Shift';
              final String phone = n['phone'] ?? '044 28290210';
              final String hosp = n['hospitalName'] ?? 'Chennai Hospital';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.blue.shade50,
                        child: const Icon(Icons.badge, color: Color(0xFF3B82F6), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nurseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                            const SizedBox(height: 4),
                            Text('Department: $dept', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            const SizedBox(height: 2),
                            Text(hosp, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Text(shift, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              InkWell(
                                onTap: () => ApiService.makeCall(phone),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    children: [
                                      Icon(Icons.phone, size: 12, color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text('Call Staff', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Remove Staff Nurse',
                                onPressed: () => _removeNurse(index),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  // --- TAB 3: USERS & PATIENTS ---
  Widget _buildUsersTab() {
    final q = _searchQuery.trim().toLowerCase();
    final list = _usersList.where((u) {
      if (q.isEmpty) return true;
      final name = (u['name'] ?? u['displayName'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? u['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    return list.isEmpty
        ? const Center(child: Text('No patients match search query', style: TextStyle(color: Color(0xFF64748B))))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final u = list[index];
              final roleStr = (u['role'] ?? 'user').toString().toUpperCase();
              final name = u['name'] ?? u['displayName'] ?? 'Arogya Patient';
              final email = u['email'] ?? u['phone'] ?? 'patient@arogya.ai';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                    child: const Icon(Icons.person, color: Color(0xFF10B981)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(email, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      if (u['lastLogin'] != null)
                        Text('Last Active: ${u['lastLogin']}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleStr == 'ADMIN' ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          roleStr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: roleStr == 'ADMIN' ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        tooltip: 'Delete User',
                        onPressed: () => _removeUser(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  // --- TAB 4: APPOINTMENTS & QUEUE PASSES ---
  Widget _buildApptsTab() {
    final q = _searchQuery.trim().toLowerCase();
    final list = _apptsList.where((a) {
      if (q.isEmpty) return true;
      final doc = (a['doctorName'] ?? '').toString().toLowerCase();
      final pat = (a['patientName'] ?? '').toString().toLowerCase();
      final hosp = (a['clinicName'] ?? a['hospitalName'] ?? '').toString().toLowerCase();
      final token = (a['token'] ?? '').toString().toLowerCase();
      final sym = (a['symptoms'] ?? '').toString().toLowerCase();
      return doc.contains(q) || pat.contains(q) || hosp.contains(q) || token.contains(q) || sym.contains(q);
    }).toList();

    return list.isEmpty
        ? const Center(child: Text('No appointments match search query', style: TextStyle(color: Color(0xFF64748B))))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final a = list[index];
              final String token = (a['token'] ?? 'TK-100').toString();
              final String doc = (a['doctorName'] ?? 'Dr. Specialist').toString();
              final String pat = (a['patientName'] ?? 'Valued Patient').toString();
              final String hosp = (a['clinicName'] ?? a['hospitalName'] ?? 'Chennai Hospital').toString();
              final String date = (a['date'] ?? a['appointmentDate'] ?? 'Today').toString();
              final String time = (a['time'] ?? a['appointmentTime'] ?? '10:30 AM').toString();
              final String sym = (a['symptoms'] ?? 'General Consultation').toString();
              final String status = (a['status'] ?? 'Confirmed').toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(8)),
                            child: Text('QUEUE TOKEN: $token', style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w900, fontSize: 11)),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: status == 'Cancelled' ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: status == 'Cancelled' ? Colors.red.shade800 : const Color(0xFF047857),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              if (status != 'Cancelled') ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _cancelAppointment(index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                                    child: const Text('CANCEL PASS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(hosp, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E293B))),
                      const SizedBox(height: 2),
                      Text('$doc • Patient: $pat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Text('Schedule: $date at $time', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                        child: Text('Symptoms / Cure Reason: "$sym"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  // --- TAB 5: AUDIT LOGS ---
  Widget _buildAuditLogsTab() {
    return Column(
      children: [
        // Filter Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: SingleChildScrollView(
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
              ],
            ),
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
                  physics: const AlwaysScrollableScrollPhysics(),
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
}

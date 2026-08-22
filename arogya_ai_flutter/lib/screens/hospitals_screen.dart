import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'doctor_profile_screen.dart';
import 'map_screen.dart';

class HospitalsScreen extends StatefulWidget {
  const HospitalsScreen({super.key});

  @override
  State<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends State<HospitalsScreen> {
  List<dynamic> _hospitals = [];
  bool _isLoading = true;
  bool _permissionDenied = false;
  double? _userLat;
  double? _userLng;

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  final List<String> _categories = [
    "All",
    "Multispeciality",
    "Cardiology",
    "Neurology",
    "Orthopaedics",
    "Dermatology",
    "ENT",
    "Gastroenterology",
    "Oncology",
    "Paediatrics",
    "General Medicine"
  ];

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHospitals() async {
    setState(() => _isLoading = true);

    final position = await LocationService.getCurrentLocation();
    if (position != null) {
      _userLat = position.latitude;
      _userLng = position.longitude;
      _permissionDenied = false;
    } else {
      _userLat = null;
      _userLng = null;
      _permissionDenied = true;
    }

    final data = await ApiService.getHospitals(lat: _userLat, lng: _userLng);

    final double targetLat = _userLat ?? LocationService.defaultLat;
    final double targetLng = _userLng ?? LocationService.defaultLng;

    final List<dynamic> sortedData = List.from(data);
    sortedData.sort((a, b) {
      final double distA = LocationService.calculateDistance(
          targetLat,
          targetLng,
          (a['lat'] as num?)?.toDouble() ?? (LocationService.defaultLat + ((a['latOffset'] as num?)?.toDouble() ?? 0.0)),
          (a['lng'] as num?)?.toDouble() ?? (LocationService.defaultLng + ((a['lngOffset'] as num?)?.toDouble() ?? 0.0)));
      final double distB = LocationService.calculateDistance(
          targetLat,
          targetLng,
          (b['lat'] as num?)?.toDouble() ?? (LocationService.defaultLat + ((b['latOffset'] as num?)?.toDouble() ?? 0.0)),
          (b['lng'] as num?)?.toDouble() ?? (LocationService.defaultLng + ((b['lngOffset'] as num?)?.toDouble() ?? 0.0)));
      return distA.compareTo(distB);
    });

    setState(() {
      _hospitals = sortedData;
      _isLoading = false;
    });
  }

  List<dynamic> get _filteredHospitals {
    final query = _searchController.text.trim().toLowerCase();
    return _hospitals.where((h) {
      final name = (h['name'] ?? '').toString().toLowerCase();
      final addr = (h['address'] ?? '').toString().toLowerCase();
      final area = (h['area'] ?? '').toString().toLowerCase();
      final doc = (h['doctor'] ?? '').toString().toLowerCase();
      final spec = (h['specialist'] ?? '').toString().toLowerCase();
      final specs = (h['specialties'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [];

      final matchesQuery = query.isEmpty ||
          name.contains(query) ||
          addr.contains(query) ||
          area.contains(query) ||
          doc.contains(query) ||
          spec.contains(query) ||
          specs.any((s) => s.toLowerCase().contains(query));

      final matchesCategory = _selectedCategory == 'All' ||
          (_selectedCategory == 'Multispeciality' && specs.length >= 3) ||
          spec.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
          specs.any((s) => s.toLowerCase().contains(_selectedCategory.toLowerCase()));

      return matchesQuery && matchesCategory;
    }).toList();
  }

  void _navigateToDoctorProfile(Map<String, dynamic> hospital) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorProfileScreen(doctor: hospital),
      ),
    );
  }

  void _openMapRadar() {
    if (_filteredHospitals.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          hospitals: _filteredHospitals,
          userLat: _userLat ?? LocationService.defaultLat,
          userLng: _userLng ?? LocationService.defaultLng,
        ),
      ),
    );
  }

  void _showHospitalDetailsModal(BuildContext context, Map<String, dynamic> hospital) {
    final double targetLat = _userLat ?? LocationService.defaultLat;
    final double targetLng = _userLng ?? LocationService.defaultLng;
    final double hLat = (hospital['lat'] as num?)?.toDouble() ?? LocationService.defaultLat;
    final double hLng = (hospital['lng'] as num?)?.toDouble() ?? LocationService.defaultLng;
    final double distance = LocationService.calculateDistance(targetLat, targetLng, hLat, hLng);

    final String name = hospital['name'] ?? 'Hospital';
    final String address = hospital['address'] ?? 'Chennai, Tamil Nadu';
    final String pincode = hospital['pincode'] ?? 'Not available';
    final String phone = hospital['phone'] ?? 'Not available';
    final String emergencyPhone = hospital['emergencyPhone'] ?? 'Not available';
    final String officialWebsite = hospital['officialWebsite'] ?? 'Not available';
    final String description = hospital['description'] ?? 'Verified Chennai Healthcare Provider.';
    final String imageUrl = hospital['imageUrl'] ?? hospital['image'] ?? 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?auto=format&fit=crop&w=600&q=80';
    final bool isGovt = hospital['type'] == 'govt';

    final List<dynamic> specialties = hospital['specialties'] as List<dynamic>? ?? [];
    final List<dynamic> departments = hospital['departments'] as List<dynamic>? ?? [];
    final List<dynamic> doctors = hospital['doctors'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top Bar Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Image Banner & Badges
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              imageUrl,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                height: 180,
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                child: const Icon(Icons.local_hospital, size: 60, color: Color(0xFF10B981)),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isGovt ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isGovt ? 'GOVT PHC' : 'PRIVATE',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Hospital Title & Rating
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  hospital['rating']?.toString() ?? '4.8',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Distance Badge
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} km away from your location',
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Disclaimer Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "ArogyaAI Appointment Booking — Real Chennai Hospital Data Verified",
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Address Section
                      const Text("Address & Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      SelectableText(
                        address,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                      ),
                      const SizedBox(height: 4),
                      Text("Pincode: $pincode", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 16),

                      // Contact Information
                      const Text("Contact Numbers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text("Hospital Phone: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                          SelectableText(phone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        ],
                      ),
                      if (emergencyPhone != 'Not available') ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.medical_services, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Text("Emergency Hotline: ", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                            SelectableText(emergencyPhone, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Specialties
                      if (specialties.isNotEmpty) ...[
                        const Text("Specialties & Clinical Care", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: specialties.map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                s.toString(),
                                style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Departments
                      if (departments.isNotEmpty) ...[
                        const Text("Departments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: departments.map((d) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                d.toString(),
                                style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Doctors
                      if (doctors.isNotEmpty) ...[
                        const Text("Verified Specialist Doctors", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                        const SizedBox(height: 8),
                        ...doctors.map((doc) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                                  child: const Icon(Icons.person, color: Color(0xFF10B981)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc['name'] ?? 'Dr. Specialist',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        "${doc['specialist']} • ${doc['degree'] ?? ''}",
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                      if (doc['exp'] != null)
                                        Text(
                                          doc['exp'].toString(),
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                        ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    final docHospital = Map<String, dynamic>.from(hospital);
                                    docHospital['doctor'] = doc['name'];
                                    docHospital['specialist'] = doc['specialist'];
                                    docHospital['fee'] = doc['fee'] ?? hospital['fee'];
                                    _navigateToDoctorProfile(docHospital);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Book Doctor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],

                      // Description
                      const Text("About Hospital", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons Grid
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (phone != 'Not available')
                            ElevatedButton.icon(
                              onPressed: () => ApiService.makeCall(phone),
                              icon: const Icon(Icons.phone, size: 16),
                              label: const Text('CALL HOSPITAL'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          if (emergencyPhone != 'Not available')
                            ElevatedButton.icon(
                              onPressed: () => ApiService.makeCall(emergencyPhone),
                              icon: const Icon(Icons.medical_services, size: 16),
                              label: const Text('EMERGENCY'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: () {
                              final query = address;
                              final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
                              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                            },
                            icon: const Icon(Icons.directions, size: 16),
                            label: const Text('GET DIRECTIONS'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          if (officialWebsite != 'Not available')
                            ElevatedButton.icon(
                              onPressed: () => launchUrl(Uri.parse(officialWebsite), mode: LaunchMode.externalApplication),
                              icon: const Icon(Icons.language, size: 16),
                              label: const Text('OFFICIAL WEBSITE'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Bottom Sticky BOOK APPOINTMENT Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    )
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _navigateToDoctorProfile(hospital);
                    },
                    icon: const Icon(Icons.calendar_month, color: Colors.white),
                    label: const Text(
                      'BOOK APPOINTMENT',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredHospitals;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Chennai Hospitals & PHCs',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF10B981)),
            onPressed: _loadHospitals,
          )
        ],
      ),
      floatingActionButton: _isLoading || list.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openMapRadar,
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.map_rounded),
              label: const Text('Show Map View', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Search Apollo, Kauvery, MIOT, Vadapalani, Cardiology...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                ),
              ),
            ),
          ),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      }
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
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade300,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // List View of Hospitals
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : list.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
                        itemCount: _permissionDenied ? list.length + 1 : list.length,
                        itemBuilder: (context, index) {
                          if (_permissionDenied && index == 0) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                border: Border.all(color: Colors.amber.shade400, width: 1.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.location_off_rounded, color: Colors.amber.shade900, size: 24),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "Location Permission Required",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.amber.shade900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Browser/device location permission is disabled. Showing Chennai hospitals. Enable GPS to calculate live distance.",
                                    style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: _loadHospitals,
                                    icon: const Icon(Icons.my_location, size: 16),
                                    label: const Text('Enable Location / Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade800,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final h = list[_permissionDenied ? index - 1 : index];
                          final isGovt = h['type'] == 'govt';

                          final double targetLat = _userLat ?? LocationService.defaultLat;
                          final double targetLng = _userLng ?? LocationService.defaultLng;
                          final double hLat = (h['lat'] as num?)?.toDouble() ?? LocationService.defaultLat;
                          final double hLng = (h['lng'] as num?)?.toDouble() ?? LocationService.defaultLng;
                          final double distance = LocationService.calculateDistance(targetLat, targetLng, hLat, hLng);

                          final List<dynamic> specialties = h['specialties'] as List<dynamic>? ?? [];

                          return FadeInUp(
                            delay: Duration(milliseconds: (index % 10) * 80),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                                border: isGovt ? Border.all(color: const Color(0xFF10B981), width: 1.5) : null,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _showHospitalDetailsModal(context, Map<String, dynamic>.from(h)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    h['name'] ?? 'Clinic',
                                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    h['area'] ?? h['doctor'] ?? 'Chennai, TN',
                                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[600]),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isGovt ? const Color(0xFFD1FAE5) : const Color(0xFFDBEAFE),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    isGovt ? 'GOVT PHC' : 'PRIVATE',
                                                    style: TextStyle(
                                                      color: isGovt ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 10,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: (h['open'] == true) ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    (h['open'] == true) ? 'OPEN' : 'CLOSED',
                                                    style: TextStyle(
                                                      color: (h['open'] == true) ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Rating & Distance Row
                                        Row(
                                          children: [
                                            const Icon(Icons.star, size: 16, color: Colors.amber),
                                            const SizedBox(width: 4),
                                            Text(h['rating']?.toString() ?? '4.8', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                            const SizedBox(width: 14),
                                            const Icon(Icons.location_on, size: 16, color: Color(0xFF10B981)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${distance.toStringAsFixed(1)} km away',
                                              style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            const SizedBox(width: 14),
                                            const Icon(Icons.currency_rupee, size: 15, color: Color(0xFF64748B)),
                                            Text(h['fee'] ?? 'Free', style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 12)),
                                          ],
                                        ),

                                        // Specialties tags preview
                                        if (specialties.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: specialties.take(4).map((s) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  s.toString(),
                                                  style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w500),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],

                                        const SizedBox(height: 6),
                                        Text(
                                          h['address'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                        const SizedBox(height: 12),

                                        // Buttons Row
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () => _showHospitalDetailsModal(context, Map<String, dynamic>.from(h)),
                                                icon: const Icon(Icons.info_outline, size: 15, color: Color(0xFF10B981)),
                                                label: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFF10B981),
                                                  side: const BorderSide(color: Color(0xFF10B981)),
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _navigateToDoctorProfile(Map<String, dynamic>.from(h)),
                                                icon: const Icon(Icons.calendar_month, size: 15, color: Colors.white),
                                                label: const Text('Book Token', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF10B981),
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                                                tooltip: 'Call Hospital',
                                                onPressed: () async {
                                                  final phone = h['phone'] ?? '044 28290200';
                                                  ApiService.makeCall(phone);
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
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No hospitals matched your search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedCategory = 'All';
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Reset Search & Filters'),
          ),
        ],
      ),
    );
  }
}

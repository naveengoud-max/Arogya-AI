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
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    setState(() => _isLoading = true);
    
    // Request current GPS coordinates
    final position = await LocationService.getCurrentLocation();
    if (position != null) {
      _userLat = position.latitude;
      _userLng = position.longitude;
    } else {
      // Default fallback coordinates if denied (Hyderabad)
      _userLat = LocationService.defaultLat;
      _userLng = LocationService.defaultLng;
    }

    final data = await ApiService.getHospitals(lat: _userLat, lng: _userLng);
    
    // Sort hospitals dynamically by nearest distance
    final List<dynamic> sortedData = List.from(data);
    sortedData.sort((a, b) {
      final double distA = LocationService.calculateDistance(
        _userLat ?? LocationService.defaultLat, 
        _userLng ?? LocationService.defaultLng, 
        (a['lat'] as num?)?.toDouble() ?? (LocationService.defaultLat + ((a['latOffset'] as num?)?.toDouble() ?? 0.0)), 
        (a['lng'] as num?)?.toDouble() ?? (LocationService.defaultLng + ((a['lngOffset'] as num?)?.toDouble() ?? 0.0))
      );
      final double distB = LocationService.calculateDistance(
        _userLat ?? LocationService.defaultLat, 
        _userLng ?? LocationService.defaultLng, 
        (b['lat'] as num?)?.toDouble() ?? (LocationService.defaultLat + ((b['latOffset'] as num?)?.toDouble() ?? 0.0)), 
        (b['lng'] as num?)?.toDouble() ?? (LocationService.defaultLng + ((b['lngOffset'] as num?)?.toDouble() ?? 0.0))
      );
      return distA.compareTo(distB);
    });

    setState(() {
      _hospitals = sortedData;
      _isLoading = false;
    });
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
    if (_hospitals.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          hospitals: _hospitals,
          userLat: _userLat ?? LocationService.defaultLat,
          userLng: _userLng ?? LocationService.defaultLng,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Nearby Clinics & PHCs',
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
      floatingActionButton: _isLoading || _hospitals.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openMapRadar,
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.map_rounded),
              label: const Text('Show Map View', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : _hospitals.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                  itemCount: (_userLat == LocationService.defaultLat && _userLng == LocationService.defaultLng)
                      ? _hospitals.length + 1
                      : _hospitals.length,
                  itemBuilder: (context, index) {
                    final hasFallback = _userLat == LocationService.defaultLat && _userLng == LocationService.defaultLng;
                    if (hasFallback && index == 0) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          border: Border.all(color: Colors.amber.shade300, width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.gps_off_rounded, color: Colors.amber.shade800, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "GPS is inactive or permission is denied.\nShowing default clinics in Chennai. Please turn on your phone GPS and refresh.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final h = _hospitals[hasFallback ? index - 1 : index];
                    final isGovt = h['type'] == 'govt';
                    
                    // Fetch calculated distance on the fly
                    final double hLat = (h['lat'] as num?)?.toDouble() ?? (LocationService.defaultLat + ((h['latOffset'] as num?)?.toDouble() ?? 0.0));
                    final double hLng = (h['lng'] as num?)?.toDouble() ?? (LocationService.defaultLng + ((h['lngOffset'] as num?)?.toDouble() ?? 0.0));
                    final double distance = LocationService.calculateDistance(
                      _userLat ?? LocationService.defaultLat, 
                      _userLng ?? LocationService.defaultLng, 
                      hLat, 
                      hLng
                    );

                    return FadeInUp(
                      delay: Duration(milliseconds: index * 100),
                      child: InkWell(
                        onTap: () => _navigateToDoctorProfile(Map<String, dynamic>.from(h)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          h['name'] ?? 'Clinic',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF1E293B)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          h['doctor'] ?? 'Doctor',
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
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
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (h['open'] == true) ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          (h['open'] == true) ? 'OPEN' : 'CLOSED',
                                          style: TextStyle(
                                            color: (h['open'] == true) ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 10,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 16, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(h['rating']?.toString() ?? '4.5', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.location_on, size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${distance.toStringAsFixed(1)} km away',
                                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.currency_rupee, size: 16, color: Color(0xFF64748B)),
                                  Text(h['fee'] ?? 'Free', style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                h['address'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _navigateToDoctorProfile(Map<String, dynamic>.from(h)),
                                      icon: const Icon(Icons.calendar_month, size: 16, color: Colors.white),
                                      label: const Text('Book Token', style: TextStyle(fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      tooltip: 'Call Hospital',
                                      onPressed: () async {
                                        final phone = h['phone'] ?? '040-23607777';
                                        ApiService.makeCall(phone);
                                      },
                                      icon: const Icon(Icons.phone, color: Colors.blue),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      tooltip: 'Get Directions',
                                      onPressed: () async {
                                        final address = h['address'] ?? h['name'] ?? 'Clinic';
                                        ApiService.launchDirections(address);
                                      },
                                      icon: const Icon(Icons.directions, color: Colors.amber),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      tooltip: 'Start Navigation',
                                      onPressed: () async {
                                        final hLat = h['lat'] ?? LocationService.defaultLat;
                                        final hLng = h['lng'] ?? LocationService.defaultLng;
                                        final url = 'https://www.google.com/maps/dir/?api=1&destination=$hLat,$hLng';
                                        if (await canLaunchUrl(Uri.parse(url))) {
                                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      icon: const Icon(Icons.navigation, color: Color(0xFF10B981)),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
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
          Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No clinics found near you', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadHospitals,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }
}

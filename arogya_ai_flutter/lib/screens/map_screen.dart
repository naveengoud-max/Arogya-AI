import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'doctor_profile_screen.dart';

class MapScreen extends StatefulWidget {
  final List<dynamic> hospitals;
  final double userLat;
  final double userLng;
  final String? initialHospitalId;

  const MapScreen({
    super.key,
    required this.hospitals,
    required this.userLat,
    required this.userLng,
    this.initialHospitalId,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Map<String, dynamic>? _selectedHospital;
  bool _mapsError = false;

  @override
  void initState() {
    super.initState();
    _initMarkers();
  }

  void _initMarkers() {
    try {
      // 1. Add User marker
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(widget.userLat, widget.userLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );

      // 2. Add Hospital markers
      for (var h in widget.hospitals) {
        final lat = h['lat'] ?? (17.3850 + (h['latOffset'] ?? 0));
        final lng = h['lng'] ?? (78.4867 + (h['lngOffset'] ?? 0));
        
        _markers.add(
          Marker(
            markerId: MarkerId(h['id']),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              h['type'] == 'govt' ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
            ),
            onTap: () {
              setState(() {
                _selectedHospital = h;
              });
            },
            infoWindow: InfoWindow(
              title: h['name'],
              snippet: '${h['specialist']} · ${h['fee']}',
            ),
          ),
        );
        
        if (widget.initialHospitalId != null && h['id'] == widget.initialHospitalId) {
          _selectedHospital = h;
        }
      }
    } catch (e) {
      debugPrint("Error initializing markers: $e");
      setState(() {
        _mapsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If maps configuration is broken or missing Google Maps SDK configuration
    if (_mapsError) {
      return _buildFallbackRadarUI();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Radar Map', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Google Map Widget
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_selectedHospital != null 
                  ? (_selectedHospital!['lat'] ?? widget.userLat)
                  : widget.userLat, 
                _selectedHospital != null 
                  ? (_selectedHospital!['lng'] ?? widget.userLng)
                  : widget.userLng
              ),
              zoom: 14.0,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Bottom card overlay
          if (_selectedHospital != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: FadeInUp(
                duration: const Duration(milliseconds: 300),
                child: _buildHospitalCard(_selectedHospital!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHospitalCard(Map<String, dynamic> h) {
    final isGovt = h['type'] == 'govt';
    final distance = h['distance_km'] ?? LocationService.calculateDistance(
      widget.userLat,
      widget.userLng,
      h['lat'] ?? widget.userLat,
      h['lng'] ?? widget.userLng,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  h['name'] ?? 'Clinic',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isGovt ? const Color(0xFFD1FAE5) : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isGovt ? 'GOVT PHC' : 'PRIVATE',
                  style: TextStyle(
                    color: isGovt ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(h['rating']?.toString() ?? '4.5', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.location_on, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 4),
              Text('${distance.toStringAsFixed(1)} km away', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            h['address'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DoctorProfileScreen(doctor: h)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  ApiService.launchDirections(h['address'] ?? h['name']);
                },
                icon: const Icon(Icons.directions, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  /// Premium animated Radar Tracking fallback if google maps packages fail to initialize on SDK level
  Widget _buildFallbackRadarUI() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate
      appBar: AppBar(
        title: const Text('Hospital Compass Radar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Pulse(
                  infinite: true,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.6), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.radar,
                        color: Color(0xFF10B981),
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Nearby Clinics & government PHCs',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Showing facilities sorted by distance from your coordinates',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.hospitals.length,
                  itemBuilder: (context, index) {
                    final h = widget.hospitals[index];
                    final dist = h['distance_km'] ?? LocationService.calculateDistance(
                      widget.userLat, widget.userLng, 
                      h['lat'] ?? widget.userLat, h['lng'] ?? widget.userLng
                    );
                    final isGovt = h['type'] == 'govt';

                    return FadeInRight(
                      delay: Duration(milliseconds: index * 100),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isGovt ? const Color(0xFF10B981).withOpacity(0.5) : const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isGovt ? const Color(0xFF065F46).withOpacity(0.2) : const Color(0xFF1E3A8A).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isGovt ? Icons.local_hospital : Icons.healing,
                                color: isGovt ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h['name'],
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${dist.toStringAsFixed(1)} km away · ${h['fee']}',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DoctorProfileScreen(doctor: h)),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Book', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

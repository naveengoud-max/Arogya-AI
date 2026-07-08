import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'home_dashboard.dart';

class BookingSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const BookingSuccessScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final String token = (appointment['token'] ?? 'TK-100').toString();
    final String clinicName = (appointment['clinicName'] ?? 'Arogya Clinic').toString();
    final String doctorName = (appointment['doctorName'] ?? 'General Physician').toString();
    final String specialist = (appointment['specialist'] ?? 'GP').toString();
    final String patientName = (appointment['patientName'] ?? 'Patient').toString();
    final String date = (appointment['date'] ?? 'Today').toString();
    final String time = (appointment['time'] ?? '10:30 AM').toString();
    final String fee = (appointment['fee'] ?? 'Free').toString();
    final String address = (appointment['address'] ?? 'Rural Bypass Road').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4), // Warm light green tint
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Success animation / icon
              ZoomIn(
                child: const CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFF10B981),
                  child: Icon(Icons.check, color: Colors.white, size: 48),
                ),
              ),
              const SizedBox(height: 24),
              FadeInDown(
                delay: const Duration(milliseconds: 150),
                child: const Text(
                  'Booking Confirmed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeInDown(
                delay: const Duration(milliseconds: 300),
                child: const Text(
                  'Your registration pass is generated below',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // The Ticket Card
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header: Token
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFECFDF5),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Queue Registration Token',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              token,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF065F46),
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Dotted Divider
                      _buildTicketSeparator(),

                      // Ticket Details
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          children: [
                            _buildTicketRow('Clinic:', clinicName),
                            _buildTicketRow('Doctor:', '$doctorName ($specialist)'),
                            _buildTicketRow('Patient:', patientName),
                            _buildTicketRow('Schedule:', '$date at $time', highlight: true),
                            _buildTicketRow('Consultation Fee:', fee),
                            _buildTicketRow('Location Address:', address),
                          ],
                        ),
                      ),

                      // Barcode section
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Column(
                          children: [
                            _buildBarcode(),
                            const Text(
                              'Show this pass at the registration desk',
                              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),
              
              // Got It Button
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to dashboard and open Visits History tab (index 2)
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HomeDashboard(initialIndex: 2),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: highlight ? const Color(0xFF10B981) : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketSeparator() {
    return SizedBox(
      height: 12,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Flex(
                  direction: Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    (constraints.constrainWidth() / 10).floor(),
                    (index) => const SizedBox(
                      width: 5,
                      height: 1.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: 6,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcode() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(35, (index) {
          final double width = (index % 3 == 0) ? 4.0 : ((index % 5 == 0) ? 2.5 : 1.5);
          final bool isBlack = index % 2 == 0;
          return Container(
            width: width,
            color: isBlack ? Colors.black87 : Colors.transparent,
          );
        }),
      ),
    );
  }
}

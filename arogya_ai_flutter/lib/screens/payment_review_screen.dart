import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_dashboard.dart';

class PaymentReviewScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final Map<String, dynamic>? hospital;
  final String patientName;
  final String patientPhone;
  final String appointmentDate;
  final String appointmentTime;
  final String symptoms;
  final String condition;
  final String severity;
  final String fee;

  const PaymentReviewScreen({
    Key? key,
    required this.doctor,
    this.hospital,
    required this.patientName,
    required this.patientPhone,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.symptoms,
    required this.condition,
    required this.severity,
    required this.fee,
  }) : super(key: key);

  @override
  State<PaymentReviewScreen> createState() => _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends State<PaymentReviewScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  String? _infoMessage;

  String _cleanFee(String rawFee) {
    final cleaned = rawFee.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.isEmpty) return '400';
    return cleaned;
  }

  void _handlePayNow() async {
    if (_isProcessing) return; // Prevent double click

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final feeAmountStr = _cleanFee(widget.fee);
    final feeAmount = int.tryParse(feeAmountStr) ?? 400;

    try {
      // 1. Create order on backend
      final orderRes = await ApiService.createRazorpayOrder(
        amount: feeAmount * 100, // paise
        doctorName: widget.doctor['name'] ?? 'Doctor',
        patientName: widget.patientName,
      );

      final String orderId = orderRes?['orderId'] ?? 'order_${DateTime.now().millisecondsSinceEpoch}';
      final String razorpayKey = orderRes?['key'] ?? 'rzp_test_arogya_ai_demo';

      // 2. Open Razorpay Test Gateway Dialog
      if (!mounted) return;

      final outcome = await _showRazorpayTestDialog(
        context: context,
        orderId: orderId,
        keyId: razorpayKey,
        amount: feeAmount,
      );

      if (outcome == 'SUCCESS') {
        final paymentId = 'pay_${DateTime.now().millisecondsSinceEpoch}';

        final bookingPayload = {
          'doctorName': widget.doctor['name'] ?? 'Doctor',
          'doctor': widget.doctor['name'] ?? 'Doctor',
          'specialist': widget.doctor['specialist'] ?? 'Specialist',
          'clinicName': widget.hospital?['name'] ?? widget.doctor['clinicName'] ?? 'Apollo Hospitals, Greams Road',
          'hospitalName': widget.hospital?['name'] ?? widget.doctor['clinicName'] ?? 'Apollo Hospitals, Greams Road',
          'address': widget.hospital?['address'] ?? widget.doctor['address'] ?? '21, Greams Lane, Off Greams Road, Chennai',
          'hospitalAddress': widget.hospital?['address'] ?? widget.doctor['address'] ?? '21, Greams Lane, Off Greams Road, Chennai',
          'patientName': widget.patientName,
          'patientPhone': widget.patientPhone,
          'appointmentDate': widget.appointmentDate,
          'date': widget.appointmentDate,
          'appointmentTime': widget.appointmentTime,
          'time': widget.appointmentTime,
          'symptoms': widget.symptoms,
          'condition': widget.condition,
          'severity': widget.severity,
          'fee': widget.fee,
          'paymentStatus': 'paid',
          'paymentId': paymentId,
          'paymentMethod': 'razorpay',
          'status': 'Confirmed',
        };

        // Verify with backend and write appointment
        final confirmRes = await ApiService.verifyPaymentAndBook(
          orderId: orderId,
          paymentId: paymentId,
          signature: 'sig_test_${DateTime.now().millisecondsSinceEpoch}',
          bookingData: bookingPayload,
        );

        if (confirmRes != null && confirmRes['success'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment Successful! Appointment Confirmed.'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate directly to Home Dashboard Visits
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const HomeDashboard(initialIndex: 2),
            ),
            (route) => false,
          );
        } else {
          setState(() {
            _isProcessing = false;
            _errorMessage = 'Payment verification failed. Please try again.';
          });
        }
      } else if (outcome == 'CANCELLED') {
        setState(() {
          _isProcessing = false;
          _infoMessage = 'Payment cancelled. Your appointment has not been confirmed.';
        });
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Payment failed. Your appointment has not been confirmed.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Payment process encountered an error: $e';
      });
    }
  }

  Future<String> _showRazorpayTestDialog({
    required BuildContext context,
    required String orderId,
    required String keyId,
    required int amount,
  }) async {
    return await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payment, color: Colors.blueAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Razorpay Test Checkout',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Arogya AI • Sandbox / Test Mode',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Order ID:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Text(orderId, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Text('₹$amount', style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Test Result:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: Colors.green.withOpacity(0.1),
                    leading: const Icon(Icons.check_circle, color: Colors.greenAccent),
                    title: const Text('Simulate Successful Payment', style: TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: const Text('Test Card / UPI Approved', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    onTap: () => Navigator.pop(ctx, 'SUCCESS'),
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: Colors.red.withOpacity(0.1),
                    leading: const Icon(Icons.cancel, color: Colors.redAccent),
                    title: const Text('Simulate Failed Payment', style: TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: const Text('Declined / Insufficient Funds', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    onTap: () => Navigator.pop(ctx, 'FAILED'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'CANCELLED'),
                  child: const Text('CANCEL PAYMENT', style: TextStyle(color: Colors.white54)),
                ),
              ],
            );
          },
        ) ??
        'CANCELLED';
  }

  @override
  Widget build(BuildContext context) {
    final String hospitalName = widget.hospital?['name'] ?? widget.doctor['clinicName'] ?? 'Apollo Hospitals, Greams Road';
    final String doctorName = widget.doctor['name'] ?? 'Dr. Specialist';
    final String specialist = widget.doctor['specialist'] ?? widget.doctor['specialization'] ?? 'Specialist';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Review Appointment & Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                  ],
                ),
              ),

            if (_infoMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orangeAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_infoMessage!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                    ),
                  ],
                ),
              ),

            // APPOINTMENT SUMMARY CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'APPOINTMENT SUMMARY',
                        style: TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('RAZORPAY TEST', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),

                  _buildItemRow(Icons.local_hospital, 'Hospital', hospitalName),
                  const SizedBox(height: 12),
                  _buildItemRow(Icons.person_pin, 'Doctor', '$doctorName ($specialist)'),
                  const SizedBox(height: 12),
                  _buildItemRow(Icons.person, 'Patient Name', widget.patientName),
                  const SizedBox(height: 12),
                  _buildItemRow(Icons.phone, 'Contact Phone', widget.patientPhone),
                  const SizedBox(height: 12),
                  _buildItemRow(Icons.medical_services_outlined, 'Symptoms / Reason', widget.symptoms),
                  const SizedBox(height: 12),
                  _buildItemRow(Icons.calendar_today, 'Date & Time', '${widget.appointmentDate} at ${widget.appointmentTime}'),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Consultation Fee:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text(widget.fee, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL AMOUNT:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(widget.fee, style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // PAY NOW BUTTON
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A86B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                onPressed: _isProcessing ? null : _handlePayNow,
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          ),
                          SizedBox(width: 12),
                          Text('Processing Razorpay Payment...', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Text(
                        'PAY ${widget.fee}',
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.tealAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}

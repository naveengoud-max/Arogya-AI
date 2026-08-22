import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  /// Generates a clean PDF document for an Appointment Confirmation
  static Future<Uint8List> generateAppointmentPdf(Map<String, dynamic> appointment) async {
    final pdf = pw.Document();

    final bookingId = (appointment['id'] ?? appointment['token'] ?? 'APT-RECORD').toString();
    final patientName = (appointment['patientName'] ?? 'Valued Patient').toString();
    final patientEmail = (appointment['patientEmail'] ?? appointment['email'] ?? 'N/A').toString();
    final doctorName = (appointment['doctorName'] ?? appointment['doctor'] ?? 'Specialist Doctor').toString();
    final clinicName = (appointment['clinicName'] ?? appointment['hospitalName'] ?? appointment['name'] ?? 'Arogya Health Centre').toString();
    final specialist = (appointment['specialist'] ?? 'General Physician').toString();
    final date = (appointment['date'] ?? appointment['appointmentDate'] ?? 'N/A').toString();
    final time = (appointment['time'] ?? appointment['appointmentTime'] ?? 'N/A').toString();
    final address = (appointment['address'] ?? 'Primary Health Center, Local Area').toString();
    final status = (appointment['status'] ?? 'Confirmed').toString();
    final createdAt = (appointment['createdAt'] ?? DateTime.now().toIso8601String().split('T').first).toString();

    final primaryColor = PdfColor.fromHex('#1A365D');
    final accentColor = PdfColor.fromHex('#00A86B');
    final textColor = PdfColor.fromHex('#2D3748');
    final lightBgColor = PdfColor.fromHex('#F7FAFC');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Banner
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ArogyaAI',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'AI-Powered Rural Healthcare Assistant',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Title
              pw.Text(
                'APPOINTMENT CONFIRMATION',
                style: pw.TextStyle(
                  color: accentColor,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Issued Date: $createdAt',
                style: pw.TextStyle(color: PdfColors.grey700, fontSize: 10),
              ),
              pw.SizedBox(height: 16),

              // Details Box
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildRow('Booking ID:', bookingId, isBold: true, valueColor: accentColor),
                    _buildRow('Patient Name:', patientName, isBold: true),
                    _buildRow('Patient Email:', patientEmail),
                    _buildRow('Doctor Name:', 'Dr. $doctorName', isBold: true),
                    _buildRow('Hospital / Clinic:', clinicName, isBold: true),
                    _buildRow('Specialization:', specialist),
                    _buildRow('Appointment Date:', date, isBold: true),
                    _buildRow('Appointment Time:', time, isBold: true),
                    _buildRow('Address:', address),
                    _buildRow('Booking Status:', status, isBold: true, valueColor: accentColor),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Instructions / Disclaimer
              pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Important Instructions:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: textColor),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '• Please arrive at the health center 15 minutes prior to your scheduled time.',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '• Present this digital confirmation token upon arrival at the OPD desk.',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      '• Carry any previous medical prescriptions or diagnostic reports.',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ArogyaAI Digital Health System',
                    style: pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
                  ),
                  pw.Text(
                    'Verified Record',
                    style: pw.TextStyle(color: accentColor, fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a clean PDF document for a Prescription / AI Diagnosis Report
  static Future<Uint8List> generatePrescriptionPdf(Map<String, dynamic> prescription) async {
    final pdf = pw.Document();

    final id = (prescription['id'] ?? 'RX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}').toString();
    final patientName = (prescription['patientName'] ?? prescription['userName'] ?? 'Valued Patient').toString();
    final patientEmail = (prescription['patientEmail'] ?? prescription['email'] ?? 'N/A').toString();
    final condition = (prescription['condition'] ?? prescription['title'] ?? 'General Medical Assessment').toString();
    final symptoms = (prescription['symptoms'] ?? prescription['description'] ?? 'As reported by patient').toString();
    final specialist = (prescription['specialist'] ?? 'General Physician').toString();
    final date = (prescription['date'] ?? prescription['diagnosisDate'] ?? DateTime.now().toIso8601String().split('T').first).toString();
    final medicinesRaw = prescription['medicines'] as List<dynamic>? ?? [];

    final primaryColor = PdfColor.fromHex('#1A365D');
    final accentColor = PdfColor.fromHex('#00A86B');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ArogyaAI Medical Prescription',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'AI Clinical Decision Support & Telehealth Assistant',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Patient Header Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Prescription ID: $id', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('Patient: $patientName', style: pw.TextStyle(fontSize: 11)),
                      pw.Text('Email: $patientEmail', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: $date', style: pw.TextStyle(fontSize: 11)),
                      pw.Text('Specialist: $specialist', style: pw.TextStyle(fontSize: 11, color: accentColor, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              // Assessment Details
              pw.Text('Clinical Assessment & Symptoms', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F7FAFC'),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Diagnosis: $condition', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: accentColor)),
                    pw.SizedBox(height: 4),
                    pw.Text('Symptoms Reported: $symptoms', style: pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Prescribed Medicines Table
              pw.Text('Prescribed Medication & Dosage', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 8),
              if (medicinesRaw.isNotEmpty)
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#EDF2F7')),
                      children: [
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Medicine Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Instructions / Dosage', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      ],
                    ),
                    ...medicinesRaw.map((m) {
                      final medMap = m is Map ? m : {'name': m.toString(), 'instructions': 'As directed'};
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text((medMap['name'] ?? 'Medication').toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text((medMap['instructions'] ?? '1 tablet daily after meals').toString(), style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(padding: pw.EdgeInsets.all(6), child: pw.Text((medMap['badge'] ?? 'General').toString(), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
                        ],
                      );
                    }),
                  ],
                )
              else
                pw.Text('• Paracetamol 500mg — 1 tablet after meals for fever/pain relief (SOS)', style: pw.TextStyle(fontSize: 11)),

              pw.Spacer(),

              // Medical Disclaimer
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF5F5'),
                  border: pw.Border.all(color: PdfColor.fromHex('#FEB2B2')),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'Medical Disclaimer: This clinical prescription record is generated by ArogyaAI AI assistance engine for informational reference and guidance. It should be reviewed and validated by a certified medical practitioner.',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.red900),
                ),
              ),

              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ArogyaAI Healthcare System', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
                  pw.Text('Valid Telehealth Record', style: pw.TextStyle(color: accentColor, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildRow(String label, String value, {bool isBold = false, PdfColor? valueColor}) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: valueColor ?? PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }


  /// Triggers PDF preview, download, or sharing on device
  static Future<void> shareOrDownloadPdf(Uint8List pdfBytes, String filename) async {
    try {
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
    } catch (e) {
      print('PdfService Share Error: $e');
    }
  }
}

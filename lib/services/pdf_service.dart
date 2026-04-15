import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generatePrescription(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(level: 0, child: pw.Text("MEDISYNC CONNECT - CLINICAL RECORD")),
            pw.SizedBox(height: 20),
            pw.Text("Doctor: Dr. ${data['doctor_name']}"),
            pw.Text("Date: ${data['reviewed_at']?.toDate().toString().substring(0, 10)}"),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Text("Diagnosis / Symptoms:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(data['symptom']),
            pw.SizedBox(height: 20),
            pw.Text("Medications:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TableHelper.fromTextArray(
              headers: ['Medicine', 'Duration', 'Timing', 'Intake'],
              data: (data['prescription'] as List).map((m) => [
                m['name'],
                "${m['days']} Days",
                m['timing'],
                m['food']
              ]).toList(),
            ),
            pw.SizedBox(height: 30),
            pw.Text("Instructions:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(data['doctor_notes'] ?? "No additional instructions."),
            pw.Spacer(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text("Digitally Signed by MediSync Connect", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            )
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
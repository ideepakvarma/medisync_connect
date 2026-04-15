import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medisync_connect/services/notification_service.dart';
import 'package:medisync_connect/services/pdf_service.dart';

import 'profile_page.dart'; // Ensure you create this file

class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  // --- STATE & SUBSCRIPTION ---
  StreamSubscription? _prescriptionSubscription;
  DateTime _lastNotificationTime = DateTime.now().subtract(const Duration(seconds: 5));
  
  final _symptomController = TextEditingController();
  String _severity = 'Low';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _listenForPrescription();
  }

  @override
  void dispose() {
    _prescriptionSubscription?.cancel();
    _symptomController.dispose();
    super.dispose();
  }

  // --- NOTIFICATION LOGIC ---
  void _listenForPrescription() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _prescriptionSubscription = FirebaseFirestore.instance
        .collection('health_entries')
        .where('patientId', isEqualTo: uid)
        .where('status', isEqualTo: 'reviewed')
        .orderBy('reviewed_at', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        Timestamp? reviewedAt = data['reviewed_at'] as Timestamp?;

        if (reviewedAt != null && reviewedAt.toDate().isAfter(_lastNotificationTime)) {
          _lastNotificationTime = reviewedAt.toDate();
          NotificationService.showInApp(
            context,
            "New prescription received from Dr. ${data['doctor_name'] ?? 'Staff'}",
          );
        }
      }
    }, onError: (e) => debugPrint("Firestore Listener Error: $e"));
  }

  // --- ACTION LOGIC ---
  void _submitSymptom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (_symptomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please describe your symptoms")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance.collection('health_entries').add({
        'patientId': user?.uid,
        'symptom': _symptomController.text.trim(),
        'severity': _severity,
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
      });
      _symptomController.clear();
      setState(() => _severity = 'Low');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Symptom logged!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return "Pending";
    if (ts is Timestamp) return DateFormat('MMM d, HH:mm').format(ts.toDate());
    return "N/A";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Patient Portal", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: "My Medical Profile",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await _prescriptionSubscription?.cancel();
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputSection(),
            const SizedBox(height: 32),
            const Text("Consultation History", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.indigo)),
            const SizedBox(height: 16),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Describe your current symptoms:", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _symptomController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Headache, fever...",
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Urgency Level", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          _buildSeveritySelector(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmitting ? null : _submitSymptom,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("SUBMIT REPORT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeveritySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _severityChip('Low', Colors.green),
        _severityChip('Medium', Colors.orange),
        _severityChip('High', Colors.red),
      ],
    );
  }

  Widget _severityChip(String label, Color color) {
    bool isSelected = _severity == label;
    return GestureDetector(
      onTap: () => setState(() => _severity = label),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.23,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_entries')
          .where('patientId', isEqualTo: user?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("No history found. Log your first symptom above!", style: TextStyle(color: Colors.grey)),
          ));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            bool isReviewed = data['status'] == 'reviewed';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ExpansionTile(
                leading: Icon(
                  isReviewed ? Icons.verified : Icons.hourglass_top,
                  color: isReviewed ? Colors.green : Colors.orange,
                ),
                title: Text(data['symptom'] ?? "No description", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Priority: ${data['severity'] ?? 'Low'}"),
                children: [
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text("Logged: ${_formatTime(data['timestamp'])}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const Spacer(),
                          if (isReviewed) ...[
                            const Icon(Icons.check_circle, size: 14, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Text("Reviewed: ${_formatTime(data['reviewed_at'])}", 
                              style: const TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                          ]
                        ]),
                        if (isReviewed) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Prescribed by: Dr. ${data['doctor_name'] ?? 'Staff'}",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                              ),
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                                onPressed: () => PdfService.generatePrescription(data),
                                tooltip: "Download PDF",
                              ),
                            ],
                          ),
                          ...(data['prescription'] as List).map((med) => Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(med['name'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text("${med['days']} days | ${med['timing']} | ${med['food']}"),
                              ],
                            ),
                          )),
                          if (data['doctor_notes'] != null && data['doctor_notes'] != "")
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text("Instructions: ${data['doctor_notes']}", 
                                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)),
                            )
                        ]
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medisync_connect/services/notification_service.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});
  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  // --- STATE ---
  StreamSubscription? _urgentSubscription;
  final DateTime _sessionStartTime = DateTime.now().subtract(const Duration(seconds: 5));

  @override
  void initState() {
    super.initState();
    _listenForUrgentCases();
  }

  @override
  void dispose() {
    _urgentSubscription?.cancel();
    super.dispose();
  }

  // --- REAL-TIME URGENT ALERTS ---
  void _listenForUrgentCases() {
    _urgentSubscription = FirebaseFirestore.instance
        .collection('health_entries')
        .where('status', isEqualTo: 'active')
        .where('severity', isEqualTo: 'High')
        .where('timestamp', isGreaterThan: _sessionStartTime)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          NotificationService.showInApp(
            context, 
            "URGENT: A new High Severity case has been logged!", 
            isUrgent: true
          );
        }
      }
    }, onError: (e) => debugPrint("Urgent Listener Error: $e"));
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return "N/A";
    return DateFormat('MMM d, HH:mm').format((ts as Timestamp).toDate());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("Clinical Triage", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout), 
              onPressed: () async {
                await _urgentSubscription?.cancel();
                await FirebaseAuth.instance.signOut();
              }
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelColor: Colors.white,            // Color of the active tab text
            unselectedLabelColor: Colors.white70, // Color of the inactive tab text (slightly faded)
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(icon: Icon(Icons.pending_actions), text: "Open Cases"),
              Tab(icon: Icon(Icons.history), text: "Reviewed Archive"),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('health_entries').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            final allEntries = snapshot.data?.docs ?? [];
            
            return Column(
              children: [
                _buildModernAnalytics(allEntries),
                Expanded(
                  child: TabBarView(
                    children: [
                      // TAB 1: ACTIVE
                      _buildPatientList(allEntries, 'active'),
                      // TAB 2: REVIEWED
                      _buildPatientList(allEntries, 'reviewed'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- DASHBOARD ANALYTICS ---
  Widget _buildModernAnalytics(List<QueryDocumentSnapshot> all) {
    int reviewed = all.where((d) => (d.data() as Map)['status'] == 'reviewed').length;
    int high = all.where((d) => (d.data() as Map)['severity'] == 'High' && (d.data() as Map)['status'] == 'active').length;
    int med = all.where((d) => (d.data() as Map)['severity'] == 'Medium' && (d.data() as Map)['status'] == 'active').length;
    int low = all.where((d) => (d.data() as Map)['severity'] == 'Low' && (d.data() as Map)['status'] == 'active').length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        children: [
          _statBarItem("Reviewed", reviewed, Colors.grey),
          _statBarItem("High", high, Colors.red),
          _statBarItem("Medium", med, Colors.orange),
          _statBarItem("Low", low, Colors.green),
        ],
      ),
    );
  }

  Widget _statBarItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text("$count", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Container(height: 4, width: 30, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  // --- PATIENT LIST BUILDER ---
  Widget _buildPatientList(List<QueryDocumentSnapshot> allEntries, String statusFilter) {
    Map<String, List<QueryDocumentSnapshot>> groupedByPatient = {};
    
    for (var doc in allEntries) {
      var data = doc.data() as Map<String, dynamic>;
      if ((data['status'] ?? 'active') == statusFilter) {
        String pId = data['patientId'] ?? "Unknown";
        groupedByPatient.putIfAbsent(pId, () => []).add(doc);
      }
    }

    if (groupedByPatient.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              statusFilter == 'active' ? "No pending cases!" : "No archive records found.",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: groupedByPatient.keys.length,
      itemBuilder: (context, index) {
        String pId = groupedByPatient.keys.elementAt(index);
        return _buildPatientTile(pId, groupedByPatient[pId]!);
      },
    );
  }

  // --- PATIENT CARD TILE ---
  Widget _buildPatientTile(String pId, List<QueryDocumentSnapshot> symptoms) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(pId).get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const SizedBox.shrink();
        
        var uData = userSnap.data!.data() as Map<String, dynamic>;
        String pName = uData['displayName'] ?? "Patient";

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo, 
              child: Text(pName[0].toUpperCase(), style: const TextStyle(color: Colors.white))
            ),
            title: Text(pName, style: const TextStyle(fontWeight: FontWeight.bold)),
            children: [
              // --- VITAL SIGNS HEADER ---
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo[100]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _vitalInfo("AGE", "${uData['age'] ?? '--'} yrs"),
                    _vitalInfo("GENDER", uData['gender'] ?? '--'),
                    _vitalInfo("HT", "${uData['height'] ?? '--'} cm"),
                    _vitalInfo("WT", "${uData['weight'] ?? '--'} kg"),
                  ],
                ),
              ),
              // --- SYMPTOM ENTRIES ---
              ...symptoms.map((sDoc) {
                var sData = sDoc.data() as Map<String, dynamic>;
                String sev = sData['severity'] ?? 'Low';
                Color sevColor = sev == 'High' ? Colors.red[50]! : (sev == 'Medium' ? Colors.orange[50]! : Colors.green[50]!);
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: sevColor, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sData['symptom'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Logged: ${_formatTime(sData['timestamp'])}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          if (sData['status'] == 'reviewed') 
                            Text("Prescribed: ${_formatTime(sData['reviewed_at'])}", 
                              style: const TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (sData['status'] == 'reviewed') ...[
                        const Divider(),
                        Text("Meds: ${sData['prescription_summary']}", 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit_note, size: 18),
                              onPressed: () => _showPrescriptionForm(context, sDoc.id),
                              label: const Text("Review Now"),
                            ),
                          ),
                        )
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _vitalInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo[900])),
      ],
    );
  }

  // --- PRESCRIPTION BUILDER MODAL ---
  void _showPrescriptionForm(BuildContext context, String eId) {
    List<Map<String, dynamic>> meds = [{'name': '', 'days': '', 'imm': false, 'm': false, 'af': false, 'n': false, 'food': 'After Lunch'}];
    final notes = TextEditingController();
    
    showDialog(
      context: context, 
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Create Prescription"),
          content: SizedBox(
            width: 500, 
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  ...meds.map((m) => Card(
                    color: Colors.white, 
                    child: Padding(
                      padding: const EdgeInsets.all(12), 
                      child: Column(
                        children: [
                          TextField(onChanged: (v) => m['name'] = v, decoration: const InputDecoration(labelText: "Medicine Name")),
                          TextField(onChanged: (v) => m['days'] = v, decoration: const InputDecoration(labelText: "Duration (Days)")),
                          const SizedBox(height: 12),
                          const Align(alignment: Alignment.centerLeft, child: Text("Schedule:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center, 
                            children: [
                              Checkbox(value: m['imm'], onChanged: (v) => setDialogState(() => m['imm'] = v!)), const Text("Imm"),
                              Checkbox(value: m['m'], onChanged: (v) => setDialogState(() => m['m'] = v!)), const Text("M"),
                              Checkbox(value: m['af'], onChanged: (v) => setDialogState(() => m['af'] = v!)), const Text("A"),
                              Checkbox(value: m['n'], onChanged: (v) => setDialogState(() => m['n'] = v!)), const Text("N"),
                            ],
                          ),
                          const Align(alignment: Alignment.centerLeft, child: Text("Intake:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Radio(value: 'After Lunch', groupValue: m['food'], onChanged: (v) => setDialogState(() => m['food'] = v.toString())), const Text("After"),
                                Radio(value: 'Before Lunch', groupValue: m['food'], onChanged: (v) => setDialogState(() => m['food'] = v.toString())), const Text("Before"),
                                Radio(value: 'Anytime', groupValue: m['food'], onChanged: (v) => setDialogState(() => m['food'] = v.toString())), const Text("Anytime"),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  )),
                  TextButton.icon(
                    onPressed: () => setDialogState(() => meds.add({'name': '', 'days': '', 'imm': false, 'm': false, 'af': false, 'n': false, 'food': 'After Lunch'})), 
                    icon: const Icon(Icons.add), 
                    label: const Text("Add More Medicine")
                  ),
                  TextField(controller: notes, decoration: const InputDecoration(labelText: "Doctor's Instructions")),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                final docSnap = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
                String docName = (docSnap.data() as Map)['displayName'] ?? "Doctor";

                await FirebaseFirestore.instance.collection('health_entries').doc(eId).update({
                  'status': 'reviewed',
                  'doctor_name': docName,
                  'reviewed_at': FieldValue.serverTimestamp(),
                  'prescription': meds.map((e) => {
                    'name': e['name'], 
                    'days': e['days'], 
                    'timing': "${e['imm']?'Immediately ':''}${e['m']?'M ':''}${e['af']?'A ':''}${e['n']?'N':''}", 
                    'food': e['food']
                  }).toList(),
                  'prescription_summary': meds.map((e) => e['name']).join(", "),
                  'doctor_notes': notes.text,
                });
                Navigator.pop(context);
              }, 
              child: const Text("Finalize & Submit")
            )
          ],
        ),
      ),
    );
  }
}
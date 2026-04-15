import 'package:cloud_firestore/cloud_firestore.dart';

class HealthEntry {
  final String id;          // Document ID
  final String patientId;   // Who created this entry
  final String symptom;     // What they are feeling
  final String severity;    // Low, Medium, High
  final DateTime timestamp; // When it was recorded

  HealthEntry({
    required this.id,
    required this.patientId,
    required this.symptom,
    required this.severity,
    required this.timestamp,
  });

  factory HealthEntry.fromMap(Map<String, dynamic> map, String documentId) {
    return HealthEntry(
      id: documentId,
      patientId: map['patientId'] ?? '',
      symptom: map['symptom'] ?? '',
      severity: map['severity'] ?? 'Low',
      timestamp: (map['timestamp'] as Timestamp).toDate(), // Firestore uses Timestamps
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'symptom': symptom,
      'severity': severity,
      'timestamp': FieldValue.serverTimestamp(), // Uses the server's clock
    };
  }
}
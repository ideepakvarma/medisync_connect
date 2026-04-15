import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../doctor/doctor_dashboard.dart';
import '../patient/patient_home.dart';

class RoleChecker extends StatelessWidget {
  const RoleChecker({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Scaffold(body: Center(child: Text("Error: No User Found")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        // 1. While waiting for Firestore to respond
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. If the user document exists
        if (snapshot.hasData && snapshot.data!.exists) {
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String role = userData['role'] ?? 'patient';

          if (role == 'doctor') {
            return const DoctorDashboard();
          } else {
            return const PatientHome();
          }
        }

        // 3. If doc doesn't exist yet (Registration lag), show loader
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase core
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medisync_connect/features/auth/login_screen.dart';
import 'package:medisync_connect/features/auth/role_checker.dart'; // Import state management

//main function
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Prepares the Flutter engine
  
  // For Web, Firebase needs the 'options' parameter
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDIMEKCy43BpGaBawWuyBpUPXeYtHO7xlg", // Get this from Firebase Project Settings
      appId: "1:507649860612:web:863ecf82fcbf698b63c151",   // Get this from Firebase Project Settings
      messagingSenderId: "507649860612",
      projectId: "medisync-connect-1",
    ),
  );
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediSync Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      // This is the "Switchboard" of your app
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(), // Listens for login/logout
        builder: (context, snapshot) {
          // 1. If Firebase is still initializing
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          // 2. If a user is logged in
          if (snapshot.hasData) {
            return const RoleChecker(); 
          }
          
          // 3. If no user is found (Logout triggers this automatically)
          return const LoginScreen();
        },
      ),
    );
  }
}
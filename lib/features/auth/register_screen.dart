import 'package:flutter/material.dart';

import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'patient'; 
  bool _isLoading = false;

  void _handleRegister() async {
    if (_name.text.isEmpty || _email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are required")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text.trim(),
        role: _role,
      );
      // After success, we pop back to Login. 
      // main.dart's StreamBuilder will see the Auth change and show RoleChecker.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400, padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                const Text("CREATE ACCOUNT", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: _name, decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person))),
                TextField(controller: _email, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email))),
                TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock))),
                const SizedBox(height: 20),
                const Text("Register as:", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Radio(value: 'patient', groupValue: _role, onChanged: (v) => setState(() => _role = v.toString())),
                    const Text("Patient"),
                    const SizedBox(width: 20),
                    Radio(value: 'doctor', groupValue: _role, onChanged: (v) => setState(() => _role = v.toString())),
                    const Text("Doctor"),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("REGISTER"),
                  ),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Already have an account? Login")),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
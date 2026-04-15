class UserModel {
  final String uid;         // Unique ID from Firebase Auth
  final String email;       // User's email
  final String role;        // 'doctor' or 'patient'
  final String displayName; // User's full name

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.displayName,
  });

  // Converts Firestore document to a Dart object
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'patient', // Default to patient for safety
      displayName: map['displayName'] ?? '',
    );
  }

  // Converts Dart object to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'displayName': displayName,
    };
  }
}
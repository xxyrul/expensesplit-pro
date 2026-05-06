import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name; // You can keep this as a fallback if needed
  final String displayName; // This is the field your UI is looking for
  final String email;

  UserModel({
    required this.id, 
    required this.name, 
    required this.email,
    required this.displayName,
  });

  // Factory constructor for creating a UserModel from a Firestore document
  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception("User data is null");
    }
    return UserModel(
      id: snapshot.id,
      // Default to empty string if field is missing
      name: data['name'] ?? 'User', 
      email: data['email'] ?? '',
      // This is what the UI wants
      displayName: data['displayName'] ?? data['name'] ?? 'User',
    );
  }

  // Method to convert the model to a Firestore map for saving
  Map<String, dynamic> toFirestore() {
    return {
      "id": id,
      "name": name,
      "displayName": displayName,
      "email": email,
      "createdAt": FieldValue.serverTimestamp(),
    };
  }
}
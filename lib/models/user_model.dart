// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;

  UserModel({required this.id, required this.name, required this.email});

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
      name: data['displayName'],
      email: data['email'],
    );
  }

  // Method to convert the model to a Firestore map for saving
  Map<String, dynamic> toFirestore() {
    return {
      "id": id,
      "name": name,
      "email": email,
      "createdAt": FieldValue.serverTimestamp(),
    };
  }
}

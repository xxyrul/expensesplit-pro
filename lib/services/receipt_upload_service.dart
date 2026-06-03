import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

class ReceiptUploadService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Pick an image with built-in compression (imageQuality: 70)
  Future<File?> pickImage(ImageSource source, BuildContext context) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Compresses image to save bandwidth
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
    return null;
  }

  /// Upload the image to Firebase Storage and return the download URL
  Future<String?> uploadReceipt(String userId, File imageFile, BuildContext context) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase() == 'png' ? 'png' : 'jpg';
      final String filePath = 'receipts/$userId/$timestamp.$extension';

      final Reference ref = _storage.ref().child(filePath);
      
      // Add custom metadata
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/$extension',
        customMetadata: {'userId': userId},
      );

      final UploadTask uploadTask = ref.putFile(imageFile, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
      return null;
    }
  }
}

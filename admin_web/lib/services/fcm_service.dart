import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

class FcmService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sends a push notification to all subscribed devices on the `global_broadcast` topic.
  ///
  /// Throws an exception detailing configuration issues or API call failures.
  Future<void> sendBroadcast({
    required String title,
    required String body,
  }) async {
    // 1. Fetch credentials from Firestore
    final doc = await _firestore.collection('admin_secrets').doc('fcm').get();
    if (!doc.exists) {
      throw Exception(
        'FCM configurations not found in Firestore. Please add a document under `/admin_secrets/fcm` with the fields "client_email", "private_key", and "project_id".'
      );
    }

    final data = doc.data()!;
    final clientEmail = data['client_email'] as String?;
    final privateKey = data['private_key'] as String?;
    final projectId = data['project_id'] as String? ?? 'expensesplit-pro-9e1c8';

    if (clientEmail == null || clientEmail.isEmpty) {
      throw Exception('Missing "client_email" field in `/admin_secrets/fcm`.');
    }
    if (privateKey == null || privateKey.isEmpty) {
      throw Exception('Missing "private_key" field in `/admin_secrets/fcm`.');
    }

    // Format the private key (replace escapes with actual newlines if pasted as a single line)
    String formattedPrivateKey = privateKey;
    if (!formattedPrivateKey.contains('\n') && formattedPrivateKey.contains(r'\n')) {
      formattedPrivateKey = formattedPrivateKey.replaceAll(r'\n', '\n');
    }

    // 2. Generate signed JWT assertion for Google OAuth 2.0 token endpoint
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final jwt = JWT(
      {
        'iss': clientEmail,
        'scope': 'https://www.googleapis.com/auth/firebase.messaging',
        'aud': 'https://oauth2.googleapis.com/token',
        'exp': now + 3600,
        'iat': now,
      },
    );

    final assertion = jwt.sign(
      RSAPrivateKey(formattedPrivateKey),
      algorithm: JWTAlgorithm.RS256,
    );

    // 3. Request OAuth 2.0 access token
    final tokenUrl = Uri.parse('https://oauth2.googleapis.com/token');
    final tokenResponse = await http.post(
      tokenUrl,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': assertion,
      },
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception('Failed to obtain OAuth2 token: ${tokenResponse.body}');
    }

    final tokenData = jsonDecode(tokenResponse.body);
    final accessToken = tokenData['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('OAuth2 access token was empty.');
    }

    // 4. Make HTTP request to FCM HTTP v1 API using the access token
    final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'message': {
          'topic': 'global_broadcast',
          'notification': {
            'title': title,
            'body': body,
          },
        },
      }),
    );

    if (response.statusCode != 200) {
      final errorBody = response.body;
      throw Exception('FCM API error (status ${response.statusCode}): $errorBody');
    }
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class SupabaseAuthService {
  static const String _functionUrl =
      '${AppConfig.supabaseUrl}/functions/v1/firebase-auth';

  static Future<String?> getSupabaseToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final firebaseToken = await user.getIdToken();
      if (firebaseToken == null) return null;

      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'firebase_token': firebaseToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['supabase_token'] as String;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

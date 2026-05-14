import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class CreditService {
  final _auth = FirebaseAuth.instance;

  static const packages = [
    {'credits': 3, 'amount': 1500, 'label': '3 Credits', 'price': '₦1,500'},
    {'credits': 5, 'amount': 2250, 'label': '5 Credits', 'price': '₦2,250'},
    {'credits': 8, 'amount': 3400, 'label': '8 Credits', 'price': '₦3,400'},
    {'credits': 10, 'amount': 4000, 'label': '10 Credits', 'price': '₦4,000'},
  ];

  Future<String?> initializePayment(int amount, int credits) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final response = await http.post(
        Uri.parse(AppConfig.paystackInitializeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': user.email,
          'amount': amount,
          'metadata': {
            'user_id': user.uid,
            'credits': credits,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['access_code'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

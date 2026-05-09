import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';

class ImageKitService {
  static Future<String?> uploadPhoto(File file, String userId) async {
    try {
      final authResponse = await http.get(
        Uri.parse(AppConfig.imagekitAuthEndpoint),
      );

      if (authResponse.statusCode != 200) return null;

      final authData = jsonDecode(authResponse.body);
      final token = authData['token'] as String;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://upload.imagekit.io/api/v1/files/upload'),
      );

      request.fields['publicKey'] = AppConfig.imagekitPublicKey;
      request.fields['fileName'] = 'profile_$userId.jpg';
      request.fields['folder'] = '/profile_photos';
      request.fields['useUniqueFileName'] = 'true';
      request.headers['Authorization'] = 'Basic $token';

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final uploadResponse = await request.send();

      if (uploadResponse.statusCode == 200) {
        final responseBody = await uploadResponse.stream.bytesToString();
        final data = jsonDecode(responseBody);
        return data['url'] as String?;
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}

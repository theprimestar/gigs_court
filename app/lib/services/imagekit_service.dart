import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';

class ImageKitUploadResult {
  final String url;
  final String fileId;

  ImageKitUploadResult({required this.url, required this.fileId});
}

class ImageKitService {
  static Future<ImageKitUploadResult?> uploadPhoto(File file, String userId, {String folder = '/profile_photos', String? fileName}) async {
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
      request.fields['fileName'] = fileName ?? '${folder.split('/').last}_$userId.jpg';
      request.fields['folder'] = folder;
      request.fields['useUniqueFileName'] = 'true';
      request.headers['Authorization'] = 'Basic $token';

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final uploadResponse = await request.send();

      if (uploadResponse.statusCode == 200) {
        final responseBody = await uploadResponse.stream.bytesToString();
        final data = jsonDecode(responseBody);
        return ImageKitUploadResult(
          url: data['url'] as String,
          fileId: data['fileId'] as String,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> deletePhoto(String fileId) async {
    try {
      final authResponse = await http.get(
        Uri.parse(AppConfig.imagekitAuthEndpoint),
      );

      if (authResponse.statusCode != 200) return false;

      final authData = jsonDecode(authResponse.body);
      final token = authData['token'] as String;

      final response = await http.delete(
        Uri.parse('https://api.imagekit.io/v1/files/$fileId'),
        headers: {'Authorization': 'Basic $token'},
      );

      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> listFiles({required String path, int skip = 0, int limit = 100}) async {
    try {
      final authResponse = await http.get(
        Uri.parse(AppConfig.imagekitAuthEndpoint),
      );

      if (authResponse.statusCode != 200) return [];

      final authData = jsonDecode(authResponse.body);
      final token = authData['token'] as String;

      final response = await http.get(
        Uri.parse('https://api.imagekit.io/v1/files?path=$path&skip=$skip&limit=$limit'),
        headers: {'Authorization': 'Basic $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<void> deleteAllUserFiles(String userId) async {
    final folders = [
      '/profile_photos',
      '/work_photos/$userId',
      '/chat_images',
    ];

    for (final folder in folders) {
      final files = await listFiles(path: folder);
      for (final file in files) {
        final fileId = file['fileId'] as String?;
        if (fileId != null) {
          await deletePhoto(fileId);
        }
      }
    }
  }
}

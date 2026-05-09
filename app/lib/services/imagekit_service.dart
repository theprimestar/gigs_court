import 'dart:io';
import 'package:imagekit/imagekit.dart';
import '../config.dart';

class ImageKitService {
  static final _imagekit = ImageKit(
    publicKey: AppConfig.imagekitPublicKey,
    urlEndpoint: AppConfig.imagekitUrlEndpoint,
    authenticationEndpoint: AppConfig.imagekitAuthEndpoint,
  );

  static Future<String?> uploadPhoto(File file, String userId) async {
    try {
      final response = await _imagekit.upload(
        file: file.path,
        fileName: 'profile_$userId.jpg',
        folder: '/profile_photos',
        useUniqueFileName: true,
      );
      return response.url;
    } catch (e) {
      return null;
    }
  }
}

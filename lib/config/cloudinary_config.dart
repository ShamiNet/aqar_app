import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';

class CloudinaryConfig {
  static const String _cloudName = 'dvocrpapc';
  static const String _uploadPreset = 'ml_default';

  static final CloudinaryPublic _cloudinary = CloudinaryPublic(
    _cloudName,
    _uploadPreset,
    cache: false,
  );

  /// ✅ رفع صورة واحدة
  static Future<String?> uploadImage(File imageFile) async {
    try {
      // debugPrint('☁️ [Cloudinary] Uploading image...');
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'property_images', // مجلد خاص بالصور
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('❌ [Cloudinary] Image upload failed: $e');
      return null;
    }
  }

  /// ✅ (جديد) رفع مجموعة صور دفعة واحدة
  static Future<List<String>> uploadImages(List<File> images) async {
    debugPrint('☁️ [Cloudinary] Uploading ${images.length} images...');
    try {
      // رفع الصور بالتوازي لسرعة أكبر
      final results = await Future.wait(
        images.map((image) => uploadImage(image)),
      );

      // استبعاد أي عمليات رفع فشلت (null) وإرجاع الروابط الصحيحة فقط
      return results.whereType<String>().toList();
    } catch (e) {
      debugPrint('❌ [Cloudinary] Bulk upload failed: $e');
      return [];
    }
  }

  /// ✅ رفع فيديو
  static Future<String?> uploadVideo(File videoFile) async {
    try {
      debugPrint('🎥 [Cloudinary] Uploading video...');
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          resourceType: CloudinaryResourceType.Video,
          folder: 'property_videos', // مجلد خاص بالفيديوهات
        ),
      );
      debugPrint('✅ [Cloudinary] Video uploaded: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      debugPrint('❌ [Cloudinary] Video upload failed: $e');
      return null;
    }
  }
}

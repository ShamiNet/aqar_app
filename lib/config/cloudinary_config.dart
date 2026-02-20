import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class CloudinaryConfig {
  static const String _cloudName = 'dvocrpapc';
  static const String _uploadPreset = 'ml_default';

  static final CloudinaryPublic _cloudinary = CloudinaryPublic(
    _cloudName,
    _uploadPreset,
    cache: false,
  );

  // =====================================================================
  // 1️⃣ الضغط المحلي (Local Compression) - توفير باقة المستخدم وسرعة الرفع
  // =====================================================================
  static Future<File?> _compressImageLocally(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.absolute.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      debugPrint('🗜️ [Compress] جاري ضغط الصورة قبل الرفع...');

      // ضغط الصورة إلى 70% وتحديد أقصى عرض/طول 1080 بكسل
      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
      );

      if (result != null) {
        final originalSize = file.lengthSync() / 1024 / 1024;
        final compressedSize = await result.length() / 1024 / 1024;
        debugPrint(
          '✅ [Compress] تم الضغط: من ${originalSize.toStringAsFixed(2)}MB إلى ${compressedSize.toStringAsFixed(2)}MB',
        );
        return File(result.path);
      }
    } catch (e) {
      debugPrint(
        '❌ [Compress] فشل ضغط الصورة، سيتم استخدام الأصلية. الخطأ: $e',
      );
    }
    return file; // إذا فشل الضغط لأي سبب، نرجع الصورة الأصلية
  }

  // =====================================================================
  // 2️⃣ الرفع السحابي (Cloud Upload)
  // =====================================================================

  /// ✅ رفع صورة واحدة (مع الضغط المسبق)
  static Future<String?> uploadImage(File imageFile) async {
    try {
      // 1. ضغط الصورة محلياً أولاً
      File? compressedFile = await _compressImageLocally(imageFile);
      File finalFileToUpload = compressedFile ?? imageFile;

      debugPrint('☁️ [Cloudinary] جاري رفع الصورة...');
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          finalFileToUpload.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'property_images',
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('❌ [Cloudinary] Image upload failed: $e');
      return null;
    }
  }

  /// ✅ رفع مجموعة صور دفعة واحدة
  static Future<List<String>> uploadImages(List<File> images) async {
    debugPrint('☁️ [Cloudinary] Uploading ${images.length} images...');
    try {
      final results = await Future.wait(
        images.map((image) => uploadImage(image)),
      );
      return results.whereType<String>().toList();
    } catch (e) {
      debugPrint('❌ [Cloudinary] Bulk upload failed: $e');
      return [];
    }
  }

  /// ✅ رفع فيديو (الفيديوهات تترك كما هي أو تستخدم مكتبات ضغط فيديو مخصصة)
  static Future<String?> uploadVideo(File videoFile) async {
    try {
      debugPrint('🎥 [Cloudinary] Uploading video...');
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          resourceType: CloudinaryResourceType.Video,
          folder: 'property_videos',
        ),
      );
      debugPrint('✅ [Cloudinary] Video uploaded: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      debugPrint('❌ [Cloudinary] Video upload failed: $e');
      return null;
    }
  }

  // =====================================================================
  // 3️⃣ التحسين عند العرض (CDN URL Transformations) - سرعة التصفح
  // =====================================================================

  /// دالة ذكية لتعديل رابط Cloudinary ليجلب صورة محسنة وخفيفة جداً بدلاً من الأصلية
  /// استخدمها دائماً عند عرض الصور في القوائم (ListView / GridView)
  static String getOptimizedImageUrl(String originalUrl, {int width = 800}) {
    // إذا لم يكن الرابط من Cloudinary، نرجعه كما هو
    if (!originalUrl.contains('res.cloudinary.com')) return originalUrl;

    // إضافة أوامر التحسين (q_auto: جودة تلقائية, f_auto: صيغة WebP, w_800: عرض 800)
    // نبحث عن كلمة /upload/ ونضع التحسينات بعدها مباشرة
    if (originalUrl.contains('/upload/')) {
      return originalUrl.replaceFirst(
        '/upload/',
        '/upload/q_auto,f_auto,w_$width/',
      );
    }
    return originalUrl;
  }
}

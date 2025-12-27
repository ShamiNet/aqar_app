import 'package:aqar_app/screens/property_form.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:aqar_app/config/cloudinary_config.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _isSaving = false;
  VoidCallback? _submitForm;

  static const _draftPrefix = 'add_property_';
  // معرف الأدمن لاستلام إشعارات العقارات الجديدة (يمكن تغييره لاحقاً)
  static const _adminId = 'QzX6w0qA8vflx5oGM3jW4GgW2BC2';

  @override
  void initState() {
    super.initState();
    debugPrint('[AddPropertyScreen] initState: Initializing screen.');
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_draftPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  void _saveProperty(Map<String, dynamic> data) async {
    debugPrint('[AddPropertyScreen] Saving property via API...');
    setState(() => _isSaving = true);

    try {
      // 1. الحصول على بيانات المستخدم من SharedPreferences أو الذاكرة
      // في النسخة الحالية، نعتمد على ApiService، لكننا نحتاج للـ ID
      // سنفترض أننا حفظنا الـ ID في SharedPreferences عند تسجيل الدخول
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        throw Exception(
          'لم يتم العثور على بيانات المستخدم. يرجى تسجيل الدخول مجدداً.',
        );
      }

      // 2. رفع الصور والفيديو (ما زال عبر Cloudinary - هذا ممتاز لأنه لا يمر عبر سيرفرك ولا فايربيز)
      final imageUrls = await _uploadImages(data['newImages']);

      String? videoUrl;
      if (data['newVideo'] != null) {
        videoUrl = await _uploadVideo(data['newVideo']);
      }

      // 3. تجهيز البيانات للسيرفر
      // تحويل LatLng إلى Map بسيط لأن JSON لا يفهم LatLng
      final latLng =
          data['location'] as LatLng; // تأكد من استيراد google_maps_flutter
      final locationMap = {
        '_latitude': latLng.latitude,
        '_longitude': latLng.longitude,
      };

      final propertyData = {
        'title': data['title'],
        'price': data['price'],
        'currency': data['currency'],
        'description': data['description'],
        'category': data['category'],
        'propertyType': data['propertyType'],
        'subscriptionPeriod': data['subscriptionPeriod'],
        'floor': data['floor'],
        'rooms': data['rooms'],
        'area': data['area'],
        'isFeatured': data['isFeatured'],
        'discountPercent': data['discountPercent'],
        'location': locationMap, // الموقع المحول
        'userId': userId, // معرف المستخدم من السيرفر
        'imageUrls': imageUrls,
        'videoUrl': videoUrl,
        // 'createdAt': سيتم إضافته في السيرفر
        'address': data['address'],
      };

      // 4. الإرسال للسيرفر
      await ApiService.addProperty(propertyData);

      // (اختياري) إشعار الأدمن يمكن نقله للسيرفر لاحقاً، لكن حالياً هو معطل أو يحتاج تعديل

      await _clearDraft();

      if (!mounted) return;
      Navigator.of(context).pop('تم حفظ العقار بنجاح!');
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}')));
    }
  }

  Future<List<String>> _uploadImages(List<XFile> images) async {
    final List<String> imageUrls = [];
    for (final image in images) {
      try {
        final CloudinaryResponse res = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            image.path,
            resourceType: CloudinaryResourceType.Image,
            folder: 'property_images',
          ),
        );
        imageUrls.add(res.secureUrl);
      } catch (e) {
        debugPrint('Error uploading image: $e');
      }
    }
    return imageUrls;
  }

  Future<String> _uploadVideo(XFile video) async {
    final CloudinaryResponse res = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        video.path,
        resourceType: CloudinaryResourceType.Video,
        folder: 'property_videos',
      ),
    );
    return res.secureUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عقار جديد')),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        child: Column(
          children: [
            Expanded(
              child: PropertyForm(
                formKey: _formKey,
                onSave: (data) => _saveProperty(data),
                bindSubmit: (fn) => _submitForm = fn,
              ),
            ),
            const SizedBox(height: 20),
            if (_isSaving)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('جاري رفع الملفات... قد يستغرق الفيديو وقتاً'),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _submitForm?.call(),
                      child: const Text('حفظ العقار'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () async {
                      await _clearDraft();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const AddPropertyScreen(),
                        ),
                      );
                    },
                    child: const Text('مسح المسودة'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

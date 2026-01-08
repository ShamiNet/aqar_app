import 'dart:io'; // ضروري لاستخدام File
import 'package:aqar_app/screens/property_form.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aqar_app/config/cloudinary_config.dart'; // الكلاس المحدث

class EditPropertyScreen extends StatefulWidget {
  const EditPropertyScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  var _isSaving = false;
  var _isLoading = true;
  Map<String, dynamic> _propertyData = {};
  VoidCallback? _submitForm;

  @override
  void initState() {
    super.initState();
    _loadPropertyData();
  }

  void _loadPropertyData() async {
    try {
      final data = await ApiService.fetchPropertyDetails(widget.propertyId);
      if (data != null) {
        setState(() {
          _propertyData = data;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _updateProperty(Map<String, dynamic> data) async {
    setState(() => _isSaving = true);

    try {
      // 1. رفع الصور الجديدة باستخدام الطريقة الجديدة
      final newImageUrls = await _uploadImages(data['newImages']);
      final List<dynamic> finalImageUrls = [
        ...data['existingImageUrls'],
        ...newImageUrls,
      ];

      // حذف الصور التي طلب المستخدم حذفها
      final imagesToRemove = data['imagesToRemove'] as List<String>?;
      if (imagesToRemove != null) {
        finalImageUrls.removeWhere((url) => imagesToRemove.contains(url));
      }

      // 2. معالجة الفيديو
      String? videoUrl = _propertyData['videoUrl'];
      if (data['removeExistingVideo'] == true || data['newVideo'] != null) {
        videoUrl = null;
      }
      if (data['newVideo'] != null) {
        // ✅ استخدام دالة رفع الفيديو الثابتة من CloudinaryConfig
        videoUrl = await CloudinaryConfig.uploadVideo(
          File((data['newVideo'] as XFile).path),
        );
      }

      // 3. تجهيز البيانات للتحديث
      final updateData = {
        'title': data['title'],
        'price': data['price'],
        'description': data['description'],
        'category': data['category'],
        'propertyType': data['propertyType'],
        'subscriptionPeriod': data['subscriptionPeriod'],
        'currency': data['currency'],
        'isFeatured': data['isFeatured'],
        'discountPercent': data['discountPercent'],
        'area': data['area'],
        'rooms': data['rooms'],
        'floor': data['floor'],
        'imageUrls': finalImageUrls,
        'videoUrl': videoUrl,
        'address': data['address'],
      };

      // 4. الإرسال للسيرفر
      await ApiService.updateProperty(widget.propertyId, updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث العقار بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Update error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<String>> _uploadImages(List<XFile> images) async {
    final List<String> imageUrls = [];
    for (final image in images) {
      try {
        // ✅ استخدام دالة رفع الصور الثابتة من CloudinaryConfig
        final url = await CloudinaryConfig.uploadImage(File(image.path));
        if (url != null) {
          imageUrls.add(url);
        }
      } catch (e) {
        debugPrint('Error uploading image: $e');
      }
    }
    return imageUrls;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل العقار')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: Column(
                children: [
                  Expanded(
                    child: PropertyForm(
                      formKey: _formKey,
                      initialData: _propertyData,
                      isEditMode: true,
                      onSave: (data) => _updateProperty(data),
                      bindSubmit: (fn) => _submitForm = fn,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isSaving)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: () => _submitForm?.call(),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('حفظ التعديلات'),
                    ),
                ],
              ),
            ),
    );
  }
}

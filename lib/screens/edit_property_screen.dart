import 'package:aqar_app/screens/property_form.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aqar_app/config/cloudinary_config.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

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
      final propertyDoc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .get();

      if (propertyDoc.exists) {
        setState(() {
          _propertyData = propertyDoc.data()!;
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
      // 1. الصور
      final newImageUrls = await _uploadImages(data['newImages']);
      final List<dynamic> finalImageUrls = [
        ...data['existingImageUrls'],
        ...newImageUrls,
      ];

      // 2. الفيديو
      String? videoUrl = _propertyData['videoUrl']; // القيمة القديمة

      // إذا طلب المستخدم حذف الفيديو القديم أو رفع فيديو جديد، نلغي الرابط القديم
      if (data['removeExistingVideo'] == true || data['newVideo'] != null) {
        videoUrl = null;
      }

      // رفع الفيديو الجديد إذا وجد
      if (data['newVideo'] != null) {
        final CloudinaryResponse res = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            (data['newVideo'] as XFile).path,
            resourceType: CloudinaryResourceType.Video,
            folder: 'property_videos',
          ),
        );
        videoUrl = res.secureUrl;
      }

      // 3. التحديث
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .update({
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
            'videoUrl': videoUrl, // تحديث رابط الفيديو
            'updatedAt': Timestamp.now(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث العقار بنجاح!')));
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Update error: $e');
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
        /* ignore */
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
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('جاري الحفظ... (الفيديو يأخذ وقتاً)'),
                        ],
                      ),
                    )
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

import 'package:aqar_app/screens/property_form.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aqar_app/config/cloudinary_config.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
// import 'package:uuid/uuid.dart';

class EditPropertyScreen extends StatefulWidget {
  const EditPropertyScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  var _isSaving = false;
  var _isLoading = true;
  Map<String, dynamic> _propertyData = {};
  VoidCallback? _submitForm;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[EditPropertyScreen] initState: Initializing screen for property ID: ${widget.propertyId}',
    );
    _loadPropertyData();
  }

  void _loadPropertyData() async {
    debugPrint(
      '[EditPropertyScreen] _loadPropertyData: Loading data for property ${widget.propertyId}.',
    );
    try {
      final propertyDoc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .get();

      if (propertyDoc.exists) {
        debugPrint(
          '[EditPropertyScreen] _loadPropertyData: Property data found.',
        );
        setState(() {
          _propertyData = propertyDoc.data()!;
          _isLoading = false;
        });
      } else {
        debugPrint(
          '[EditPropertyScreen] _loadPropertyData: Property with ID ${widget.propertyId} not found.',
        );
      }
    } catch (e) {
      debugPrint(
        '[EditPropertyScreen] _loadPropertyData: Error loading data: $e',
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateProperty(Map<String, dynamic> data) async {
    debugPrint(
      '[EditPropertyScreen] _updateProperty: "Save Changes" button pressed.',
    );
    setState(() => _isSaving = true);

    try {
      final newImageUrls = await _uploadImages(data['newImages']);
      // Here you can add logic to delete images from Cloudinary using `data['imagesToRemove']`

      final finalImageUrls = [...data['existingImageUrls'], ...newImageUrls];

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
          });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث العقار بنجاح!')));
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('[EditPropertyScreen] _updateProperty: An error occurred: $e');
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
      final CloudinaryResponse res = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'property_images',
        ),
      );
      imageUrls.add(res.secureUrl);
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
                      onSave: (data) => _updateProperty(data),
                      bindSubmit: (fn) => _submitForm = fn,
                      initialData: _propertyData,
                      isEditMode: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isSaving)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: () {
                        final form = _formKey.currentState;
                        if (form != null && form.validate()) {
                          _submitForm?.call();
                        }
                      },
                      child: const Text('حفظ التعديلات'),
                    ),
                ],
              ),
            ),
    );
  }
}

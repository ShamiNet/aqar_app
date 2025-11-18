import 'package:aqar_app/screens/property_form.dart';
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
// import 'package:uuid/uuid.dart';

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

  @override
  void initState() {
    super.initState();
    debugPrint('[AddPropertyScreen] initState: Initializing screen.');
  }

  Future<void> _clearDraft() async {
    debugPrint(
      '[AddPropertyScreen] _clearDraft: Clearing draft from SharedPreferences.',
    );
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_draftPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  void _saveProperty(Map<String, dynamic> data) async {
    debugPrint(
      '[AddPropertyScreen] _saveProperty: "Save Property" button pressed.',
    );
    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint(
          '[AddPropertyScreen] _saveProperty: Error - User is not logged in.',
        );
        setState(() => _isSaving = false);
        return;
      }

      final imageUrls = await _uploadImages(data['newImages']);

      final LatLng location = data['location'];
      await FirebaseFirestore.instance.collection('properties').add({
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
        'location': GeoPoint(location.latitude, location.longitude),
        'userId': user.uid,
        'imageUrls': imageUrls,
        'createdAt': Timestamp.now(),
        'address': data['address'],
      });

      FirebaseAnalytics.instance.logEvent(
        name: 'add_property',
        parameters: {
          'category': data['category'],
          'property_type': data['propertyType'],
          'price': data['price'],
        },
      );

      await _clearDraft();

      if (!mounted) return;
      Navigator.of(context).pop('تم حفظ العقار بنجاح!');
    } catch (e) {
      debugPrint('[AddPropertyScreen] _saveProperty: An error occurred: $e');
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}')));
    }
  }

  Future<List<String>> _uploadImages(List<XFile> images) async {
    final List<String> imageUrls = [];
    final uploadTasks = images.map((image) async {
      final CloudinaryResponse res = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'property_images',
        ),
      );
      return res.secureUrl;
    }).toList();

    imageUrls.addAll(await Future.wait(uploadTasks));
    return imageUrls;
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
              const Center(child: CircularProgressIndicator())
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
                      final messenger = ScaffoldMessenger.of(context);
                      await _clearDraft();
                      // A better way would be to reset the form state via its own key/controller
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const AddPropertyScreen(),
                        ),
                      );
                      messenger.showSnackBar(
                        const SnackBar(content: Text('تم مسح المسودة.')),
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

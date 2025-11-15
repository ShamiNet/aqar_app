import 'dart:io';
import 'package:aqar_app/screens/map_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  var _enteredTitle = '';
  var _enteredPrice = 0.0;
  var _enteredDescription = '';
  String? _selectedCategory;
  var _enteredFloor = 0;
  var _enteredRooms = 0;
  var _enteredArea = 0.0;
  LatLng? _selectedLocation;
  var _isSaving = false;
  final List<XFile> _selectedImages = [];

  void _pickImages() async {
    final imagePicker = ImagePicker();
    final pickedImages = await imagePicker.pickMultiImage(imageQuality: 50);
    if (pickedImages.isEmpty) {
      return;
    }
    setState(() {
      _selectedImages.addAll(pickedImages);
    });
  }

  void _selectOnMap() async {
    final pickedLocation = await Navigator.of(
      context,
    ).push<LatLng>(MaterialPageRoute(builder: (ctx) => const MapScreen()));
    if (pickedLocation == null) {
      return;
    }
    setState(() {
      _selectedLocation = pickedLocation;
    });
  }

  void _saveProperty() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار صورة واحدة على الأقل.')),
        );
        return;
      }
      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء تحديد موقع العقار على الخريطة.'),
          ),
        );
        return;
      }

      _formKey.currentState!.save();
      setState(() {
        _isSaving = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          setState(() {
            _isSaving = false;
          });
          return;
        }

        final imageUrls = await _uploadImages();

        await FirebaseFirestore.instance.collection('properties').add({
          'title': _enteredTitle,
          'price': _enteredPrice,
          'description': _enteredDescription,
          'category': _selectedCategory,
          'floor': _enteredFloor,
          'rooms': _enteredRooms,
          'area': _enteredArea,
          'location': GeoPoint(
            _selectedLocation!.latitude,
            _selectedLocation!.longitude,
          ),
          'userId': user.uid,
          'imageUrls': imageUrls,
          'createdAt': Timestamp.now(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ العقار بنجاح!')));
        Navigator.of(context).pop();
      } catch (e) {
        setState(() {
          _isSaving = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}')));
      }
    }
  }

  Future<List<String>> _uploadImages() async {
    final List<String> imageUrls = [];
    for (final image in _selectedImages) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('property_images')
          .child('${const Uuid().v4()}.jpg');
      await ref.putFile(File(image.path));
      final downloadUrl = await ref.getDownloadURL();
      imageUrls.add(downloadUrl);
    }
    return imageUrls;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عقار جديد')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'عنوان الإعلان'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال عنوان.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _enteredTitle = value!;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'التصنيف'),
                initialValue: _selectedCategory,
                items: const [
                  DropdownMenuItem(value: 'بيع', child: Text('بيع')),
                  DropdownMenuItem(value: 'إيجار', child: Text('إيجار')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'الرجاء اختيار تصنيف.';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'السعر'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'الرجاء إدخال سعر صحيح.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _enteredPrice = double.parse(value!);
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'المساحة (م²)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'الرجاء إدخال مساحة صحيحة.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _enteredArea = double.parse(value!);
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'عدد الغرف'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      int.tryParse(value) == null ||
                      int.parse(value) <= 0) {
                    return 'الرجاء إدخال عدد غرف صحيح.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _enteredRooms = int.parse(value!);
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'الطابق'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      int.tryParse(value) == null) {
                    return 'الرجاء إدخال رقم طابق صحيح.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _enteredFloor = int.parse(value!);
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'الوصف'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'الرجاء إدخال وصف لا يقل عن 10 أحرف.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _enteredDescription = value!;
                },
              ),
              const SizedBox(height: 20),
              _buildLocationPicker(),
              const SizedBox(height: 20),
              _buildImagePicker(),
              const SizedBox(height: 20),
              if (_isSaving)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _saveProperty,
                  child: const Text('حفظ العقار'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _selectOnMap,
          icon: const Icon(Icons.map),
          label: const Text('تحديد الموقع على الخريطة'),
        ),
        if (_selectedLocation != null)
          Text(
            'الموقع المحدد: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
          ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.image),
          label: const Text('اختر صور'),
        ),
        const SizedBox(height: 10),
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (ctx, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Image.file(
                    File(_selectedImages[index].path),
                    fit: BoxFit.cover,
                    width: 100,
                    height: 100,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

import 'dart:io';
import 'package:aqar_app/screens/map_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aqar_app/config/cloudinary_config.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:uuid/uuid.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _areaController;
  late TextEditingController _roomsController;
  late TextEditingController _floorController;
  var _enteredTitle = '';
  var _enteredPrice = 0.0;
  var _enteredDescription = '';
  String? _selectedCategory;
  String? _selectedPropertyType;
  String? _selectedCurrency = 'ر.س';
  var _enteredFloor = 0;
  var _enteredRooms = 0;
  var _enteredArea = 0.0;
  LatLng? _selectedLocation;
  var _isSaving = false;
  final List<XFile> _selectedImages = [];
  bool _isFeatured = false;
  int _discountPercent = 0;
  String? _addressCountry;
  String? _addressCity;
  String? _addressStreet;

  static const _draftPrefix = 'add_property_';

  @override
  void initState() {
    super.initState();
    debugPrint('[AddPropertyScreen] initState: Initializing screen.');
    _titleController = TextEditingController();
    _priceController = TextEditingController();
    _descriptionController = TextEditingController();
    _areaController = TextEditingController();
    _roomsController = TextEditingController();
    _floorController = TextEditingController();
    _loadDraft();
  }

  @override
  void dispose() {
    debugPrint(
      '[AddPropertyScreen] dispose: Disposing screen and controllers.',
    );
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    _roomsController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    debugPrint(
      '[AddPropertyScreen] _loadDraft: Loading draft from SharedPreferences.',
    );
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _titleController.text = prefs.getString('${_draftPrefix}title') ?? '';
      _priceController.text = prefs.getString('${_draftPrefix}price') ?? '';
      _descriptionController.text =
          prefs.getString('${_draftPrefix}description') ?? '';
      _areaController.text = prefs.getString('${_draftPrefix}area') ?? '';
      _roomsController.text = prefs.getString('${_draftPrefix}rooms') ?? '';
      _floorController.text = prefs.getString('${_draftPrefix}floor') ?? '';
      _selectedCategory = prefs.getString('${_draftPrefix}category');
      _selectedPropertyType = prefs.getString('${_draftPrefix}propertyType');
      _selectedCurrency = prefs.getString('${_draftPrefix}currency') ?? 'ر.س';
      _isFeatured = prefs.getBool('${_draftPrefix}isFeatured') ?? false;
      _discountPercent = prefs.getInt('${_draftPrefix}discountPercent') ?? 0;
      final lat = prefs.getDouble('${_draftPrefix}lat');
      final lng = prefs.getDouble('${_draftPrefix}lng');
      _addressCountry = prefs.getString('${_draftPrefix}addressCountry');
      _addressCity = prefs.getString('${_draftPrefix}addressCity');
      _addressStreet = prefs.getString('${_draftPrefix}addressStreet');

      if (lat != null && lng != null) {
        _selectedLocation = LatLng(lat, lng);
      }
      debugPrint('[AddPropertyScreen] _loadDraft: Draft loaded successfully.');
    });
  }

  Future<void> _saveDraft() async {
    debugPrint(
      '[AddPropertyScreen] _saveDraft: Saving current form state to draft.',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_draftPrefix}title', _titleController.text);
    await prefs.setString('${_draftPrefix}price', _priceController.text);
    await prefs.setString(
      '${_draftPrefix}description',
      _descriptionController.text,
    );
    await prefs.setString('${_draftPrefix}area', _areaController.text);
    await prefs.setString('${_draftPrefix}rooms', _roomsController.text);
    await prefs.setString('${_draftPrefix}floor', _floorController.text);
    if (_selectedCategory != null) {
      await prefs.setString('${_draftPrefix}category', _selectedCategory!);
    }
    if (_selectedPropertyType != null) {
      await prefs.setString(
        '${_draftPrefix}propertyType',
        _selectedPropertyType!,
      );
    }
    if (_selectedCurrency != null) {
      await prefs.setString('${_draftPrefix}currency', _selectedCurrency!);
    }
    await prefs.setBool('${_draftPrefix}isFeatured', _isFeatured);
    await prefs.setInt('${_draftPrefix}discountPercent', _discountPercent);
    if (_selectedLocation != null) {
      await prefs.setDouble('${_draftPrefix}lat', _selectedLocation!.latitude);
      await prefs.setDouble('${_draftPrefix}lng', _selectedLocation!.longitude);
    }
    if (_addressCountry != null) {
      await prefs.setString('${_draftPrefix}addressCountry', _addressCountry!);
    }
    if (_addressCity != null) {
      await prefs.setString('${_draftPrefix}addressCity', _addressCity!);
    }
    if (_addressStreet != null) {
      await prefs.setString('${_draftPrefix}addressStreet', _addressStreet!);
    }
  }

  Future<void> _clearDraft() async {
    debugPrint(
      '[AddPropertyScreen] _clearDraft: Clearing draft from SharedPreferences.',
    );
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'title',
      'price',
      'description',
      'area',
      'rooms',
      'floor',
      'category',
      'propertyType',
      'currency',
      'isFeatured',
      'discountPercent',
      'lat',
      'lng',
      'addressCountry',
      'addressCity',
      'addressStreet',
    ]) {
      await prefs.remove('$_draftPrefix$key');
    }
  }

  void _pickImages() async {
    debugPrint('[AddPropertyScreen] _pickImages: Opening image picker.');
    final imagePicker = ImagePicker();
    final pickedImages = await imagePicker.pickMultiImage(imageQuality: 50);
    if (pickedImages.isEmpty) {
      debugPrint('[AddPropertyScreen] _pickImages: No images selected.');
      return;
    }
    setState(() {
      _selectedImages.addAll(pickedImages);
    });
    debugPrint(
      '[AddPropertyScreen] _pickImages: Added ${pickedImages.length} images.',
    );
  }

  void _selectOnMap() async {
    debugPrint('[AddPropertyScreen] _selectOnMap: Opening map screen.');
    final pickedLocation = await Navigator.of(
      context,
    ).push<LatLng>(MaterialPageRoute(builder: (ctx) => const MapScreen()));
    if (pickedLocation == null) {
      debugPrint('[AddPropertyScreen] _selectOnMap: No location picked.');
      return;
    }
    setState(() {
      _selectedLocation = pickedLocation;
    });
    await _getAddressFromLatLng(pickedLocation);
    await _saveDraft();
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      debugPrint(
        '[AddPropertyScreen] _getAddressFromLatLng: Fetching address for $position',
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _addressCountry = place.country;
          _addressCity = place.locality;
          _addressStreet = place.street;
        });
        debugPrint(
          '[AddPropertyScreen] _getAddressFromLatLng: Address found: ${place.street}, ${place.locality}, ${place.country}',
        );
      }
    } catch (e) {
      debugPrint('[AddPropertyScreen] _getAddressFromLatLng: Error: $e');
    }
  }

  void _saveProperty() async {
    debugPrint(
      '[AddPropertyScreen] _saveProperty: "Save Property" button pressed.',
    );
    if (_formKey.currentState!.validate()) {
      if (_selectedImages.isEmpty) {
        debugPrint(
          '[AddPropertyScreen] _saveProperty: Validation failed - No images selected.',
        );
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
      debugPrint('[AddPropertyScreen] _saveProperty: Form is valid and saved.');
      setState(() {
        _isSaving = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          debugPrint(
            '[AddPropertyScreen] _saveProperty: Error - User is not logged in.',
          );
          setState(() {
            _isSaving = false;
          });
          return;
        }

        debugPrint(
          '[AddPropertyScreen] _saveProperty: Uploading images to Cloudinary.',
        );
        final imageUrls = await _uploadImages();
        debugPrint(
          '[AddPropertyScreen] _saveProperty: Images uploaded successfully. URLs: $imageUrls',
        );

        debugPrint(
          '[AddPropertyScreen] _saveProperty: Adding property data to Firestore.',
        );
        await FirebaseFirestore.instance.collection('properties').add({
          'title': _enteredTitle,
          'price': _enteredPrice,
          'currency': _selectedCurrency,
          'description': _enteredDescription,
          'category': _selectedCategory,
          'propertyType': _selectedPropertyType,
          'floor': _enteredFloor,
          'rooms': _enteredRooms,
          'area': _enteredArea,
          'isFeatured': _isFeatured,
          'discountPercent': _discountPercent,
          'location': GeoPoint(
            _selectedLocation!.latitude,
            _selectedLocation!.longitude,
          ),
          'userId': user.uid,
          'imageUrls': imageUrls,
          'createdAt': Timestamp.now(),
          'addressCountry': _addressCountry,
          'addressCity': _addressCity,
          'addressStreet': _addressStreet,
        });

        debugPrint(
          '[AddPropertyScreen] _saveProperty: Property added to Firestore. Clearing draft.',
        );
        await _clearDraft();

        if (!mounted) return;
        debugPrint(
          '[AddPropertyScreen] _saveProperty: Process completed successfully. Navigating back.',
        );
        Navigator.of(context).pop('تم حفظ العقار بنجاح!');
      } catch (e) {
        debugPrint('[AddPropertyScreen] _saveProperty: An error occurred: $e');
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
    debugPrint(
      '[AddPropertyScreen] _uploadImages: Starting image upload loop.',
    );
    final List<String> imageUrls = [];
    for (final image in _selectedImages) {
      final CloudinaryResponse res = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'property_images',
        ),
      );
      imageUrls.add(res.secureUrl);
    }
    debugPrint(
      '[AddPropertyScreen] _uploadImages: Finished image upload loop.',
    );
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
                controller: _titleController,
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
                onChanged: (_) => _saveDraft(),
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
                  _saveDraft();
                },
                validator: (value) {
                  if (value == null) {
                    return 'الرجاء اختيار تصنيف.';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'نوع العقار'),
                initialValue: _selectedPropertyType,
                items: const [
                  DropdownMenuItem(value: 'بيت', child: Text('بيت')),
                  DropdownMenuItem(value: 'فيلا', child: Text('فيلا')),
                  DropdownMenuItem(value: 'بناية', child: Text('بناية')),
                  DropdownMenuItem(value: 'ارض', child: Text('ارض')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPropertyType = value;
                    // إذا كان نوع العقار "ارض"، قم بمسح قيم الغرف والطابق
                    if (_selectedPropertyType == 'ارض') {
                      _roomsController.clear();
                      _floorController.clear();
                      _enteredRooms = 0;
                      _enteredFloor = 0;
                    }
                  });
                  _saveDraft();
                },
                validator: (value) {
                  if (value == null) {
                    return 'الرجاء اختيار نوع العقار.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _priceController,
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
                onChanged: (_) => _saveDraft(),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'العملة'),
                initialValue: _selectedCurrency,
                items: const [
                  DropdownMenuItem(value: 'ر.س', child: Text('ريال سعودي')),
                  DropdownMenuItem(value: 'ل.ت', child: Text('ليرة تركية')),
                  DropdownMenuItem(value: 'ل.س', child: Text('ليرة سورية')),
                  DropdownMenuItem(value: '\$', child: Text('دولار أمريكي')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCurrency = value;
                  });
                  _saveDraft();
                },
                validator: (value) {
                  if (value == null) return 'الرجاء اختيار العملة.';
                  return null;
                },
              ),
              SwitchListTile(
                title: const Text('عرض مميز'),
                value: _isFeatured,
                onChanged: (v) {
                  setState(() => _isFeatured = v);
                  _saveDraft();
                },
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'نسبة التخفيض (%) — اختياري',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null; // اختياري
                  }
                  final n = int.tryParse(value);
                  if (n == null || n < 0 || n > 100) {
                    return 'الرجاء إدخال نسبة بين 0 و 100';
                  }
                  return null;
                },
                onSaved: (value) {
                  _discountPercent = int.tryParse(value ?? '') ?? 0;
                },
                onChanged: (v) {
                  _discountPercent = int.tryParse(v) ?? 0;
                  _saveDraft();
                },
              ),
              TextFormField(
                controller: _areaController,
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
                onChanged: (_) => _saveDraft(),
              ),
              if (_selectedPropertyType != 'ارض') ...[
                TextFormField(
                  controller: _roomsController,
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
                  onChanged: (_) => _saveDraft(),
                ),
                TextFormField(
                  controller: _floorController,
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
                  onChanged: (_) => _saveDraft(),
                ),
              ],
              TextFormField(
                controller: _descriptionController,
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
                onChanged: (_) => _saveDraft(),
              ),
              const SizedBox(height: 20),
              _buildLocationPicker(),
              const SizedBox(height: 20),
              _buildImagePicker(),
              const SizedBox(height: 20),
              if (_isSaving)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveProperty,
                        child: const Text('حفظ العقار'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () async {
                        debugPrint(
                          '[AddPropertyScreen] "Clear Draft" button pressed.',
                        );
                        final messenger = ScaffoldMessenger.of(context);
                        await _clearDraft();
                        setState(() {
                          _titleController.clear();
                          _priceController.clear();
                          _descriptionController.clear();
                          _areaController.clear();
                          _roomsController.clear();
                          _floorController.clear();
                          _selectedCategory = null;
                          _selectedPropertyType = null;
                          _selectedCurrency = 'ر.س';
                          _isFeatured = false;
                          _discountPercent = 0;
                          _selectedLocation = null;
                          _addressCountry = null;
                          _addressCity = null;
                          _addressStreet = null;
                        });
                        debugPrint(
                          '[AddPropertyScreen] Draft cleared and state reset.',
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
        if (_selectedLocation != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_addressStreet ?? '...'}, ${_addressCity ?? '...'}, ${_addressCountry ?? '...'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'الإحداثيات: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
          ),
        ],
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

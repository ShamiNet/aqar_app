import 'dart:io';
import 'package:aqar_app/screens/map_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PropertyForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic> data) onSave;
  final bool isEditMode;
  final void Function(VoidCallback submit) bindSubmit;

  const PropertyForm({
    super.key,
    required this.formKey,
    required this.onSave,
    required this.bindSubmit,
    this.initialData = const {},
    this.isEditMode = false,
  });

  @override
  State<PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends State<PropertyForm> {
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _areaController;
  late TextEditingController _roomsController;
  late TextEditingController _floorController;
  late TextEditingController _discountController;

  String? _selectedCategory;
  String? _selectedPropertyType;
  String? _selectedSubscriptionPeriod;
  String? _selectedCurrency;
  bool _isFeatured = false;
  LatLng? _selectedLocation;
  String? _addressCountry;
  String? _addressCity;
  String? _addressStreet;

  final List<dynamic> _images = []; // Can hold XFile or String (URL)
  final List<String> _imagesToRemove = [];

  static const _draftPrefix = 'add_property_';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadInitialData();
    if (!widget.isEditMode) {
      _loadDraft();
    }
    // Expose submit function to parent so it can trigger save
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.bindSubmit(_onSave);
    });
  }

  void _initializeControllers() {
    _titleController = TextEditingController();
    _priceController = TextEditingController();
    _descriptionController = TextEditingController();
    _areaController = TextEditingController();
    _roomsController = TextEditingController();
    _floorController = TextEditingController();
    _discountController = TextEditingController();
  }

  void _loadInitialData() {
    if (widget.initialData.isNotEmpty) {
      _titleController.text = widget.initialData['title'] ?? '';
      _priceController.text = (widget.initialData['price'] ?? '').toString();
      _descriptionController.text = widget.initialData['description'] ?? '';
      _areaController.text = (widget.initialData['area'] ?? '').toString();
      _roomsController.text = (widget.initialData['rooms'] ?? '').toString();
      _floorController.text = (widget.initialData['floor'] ?? '').toString();
      _discountController.text = (widget.initialData['discountPercent'] ?? 0)
          .toString();
      _selectedCategory = widget.initialData['category'];
      _selectedPropertyType = widget.initialData['propertyType'];
      _selectedSubscriptionPeriod = widget.initialData['subscriptionPeriod'];
      _selectedCurrency = widget.initialData['currency'] ?? 'ر.س';
      _isFeatured = widget.initialData['isFeatured'] ?? false;
      if (widget.initialData['location'] != null) {
        final location = widget.initialData['location'];
        if (location is LatLng) {
          _selectedLocation = location;
        } else if (location is Map) {
          _selectedLocation = LatLng(
            location['latitude'] ?? 0.0,
            location['longitude'] ?? 0.0,
          );
        }
        if (_selectedLocation != null) {
          _getAddressFromLatLng(_selectedLocation!);
        }
      }
      _images.addAll(widget.initialData['imageUrls'] ?? []);
    }
  }

  @override
  void dispose() {
    _saveDraft();
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    _roomsController.dispose();
    _floorController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _titleController.text = prefs.getString('${_draftPrefix}title') ?? '';
      _priceController.text = prefs.getString('${_draftPrefix}price') ?? '';
      _descriptionController.text =
          prefs.getString('${_draftPrefix}description') ?? '';
      _areaController.text = prefs.getString('${_draftPrefix}area') ?? '';
      _roomsController.text = prefs.getString('${_draftPrefix}rooms') ?? '';
      _floorController.text = prefs.getString('${_draftPrefix}floor') ?? '';
      _discountController.text =
          (prefs.getInt('${_draftPrefix}discountPercent') ?? 0).toString();
      _selectedCategory = prefs.getString('${_draftPrefix}category');
      _selectedPropertyType = prefs.getString('${_draftPrefix}propertyType');
      _selectedSubscriptionPeriod = prefs.getString(
        '${_draftPrefix}subscriptionPeriod',
      );
      _selectedCurrency = prefs.getString('${_draftPrefix}currency') ?? 'ر.س';
      _isFeatured = prefs.getBool('${_draftPrefix}isFeatured') ?? false;
      final lat = prefs.getDouble('${_draftPrefix}lat');
      final lng = prefs.getDouble('${_draftPrefix}lng');
      if (lat != null && lng != null) {
        _selectedLocation = LatLng(lat, lng);
        _getAddressFromLatLng(_selectedLocation!);
      }
    });
  }

  Future<void> _saveDraft() async {
    if (widget.isEditMode) return;
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
    await prefs.setInt(
      '${_draftPrefix}discountPercent',
      int.tryParse(_discountController.text) ?? 0,
    );
    if (_selectedCategory != null)
      await prefs.setString('${_draftPrefix}category', _selectedCategory!);
    if (_selectedPropertyType != null)
      await prefs.setString(
        '${_draftPrefix}propertyType',
        _selectedPropertyType!,
      );
    if (_selectedSubscriptionPeriod != null)
      await prefs.setString(
        '${_draftPrefix}subscriptionPeriod',
        _selectedSubscriptionPeriod!,
      );
    if (_selectedCurrency != null)
      await prefs.setString('${_draftPrefix}currency', _selectedCurrency!);
    await prefs.setBool('${_draftPrefix}isFeatured', _isFeatured);
    if (_selectedLocation != null) {
      await prefs.setDouble('${_draftPrefix}lat', _selectedLocation!.latitude);
      await prefs.setDouble('${_draftPrefix}lng', _selectedLocation!.longitude);
    }
  }

  void _onSave() {
    if (widget.formKey.currentState!.validate()) {
      if (_images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار صورة واحدة على الأقل.')),
        );
        return;
      }
      if (_selectedLocation == null && !widget.isEditMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء تحديد موقع العقار على الخريطة.'),
          ),
        );
        return;
      }

      widget.formKey.currentState!.save();

      final data = {
        'title': _titleController.text,
        'price': double.parse(_priceController.text),
        'description': _descriptionController.text,
        'area': double.tryParse(_areaController.text) ?? 0.0,
        'rooms': _selectedPropertyType == 'ارض'
            ? 0
            : int.parse(_roomsController.text),
        'floor': _selectedPropertyType == 'ارض'
            ? 0
            : int.parse(_floorController.text),
        'discountPercent': int.tryParse(_discountController.text) ?? 0,
        'category': _selectedCategory,
        'propertyType': _selectedPropertyType,
        'subscriptionPeriod': _selectedCategory == 'إيجار'
            ? _selectedSubscriptionPeriod
            : null,
        'currency': _selectedCurrency,
        'isFeatured': _isFeatured,
        'location': _selectedLocation,
        'addressCountry': _addressCountry,
        'addressCity': _addressCity,
        'addressStreet': _addressStreet,
        'newImages': _images.whereType<XFile>().toList(),
        'existingImageUrls': _images.whereType<String>().toList(),
        'imagesToRemove': _imagesToRemove,
      };

      widget.onSave(data);
    }
  }

  void _pickImages() async {
    final imagePicker = ImagePicker();
    final pickedImages = await imagePicker.pickMultiImage(imageQuality: 50);
    if (pickedImages.isEmpty) return;
    setState(() {
      _images.addAll(pickedImages);
    });
  }

  void _selectOnMap() async {
    final pickedLocation = await Navigator.of(
      context,
    ).push<LatLng>(MaterialPageRoute(builder: (ctx) => const MapScreen()));
    if (pickedLocation == null) return;
    setState(() {
      _selectedLocation = pickedLocation;
    });
    await _getAddressFromLatLng(pickedLocation);
    await _saveDraft();
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
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
      }
    } catch (e) {
      debugPrint('[PropertyForm] _getAddressFromLatLng: Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'عنوان الإعلان'),
            validator: (value) {
              if (_selectedCategory == 'إيجار') return null;
              if (value == null || value.trim().isEmpty)
                return 'الرجاء إدخال عنوان.';
              return null;
            },
            onChanged: (_) => _saveDraft(),
          ),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'التصنيف'),
            value: _selectedCategory,
            items: const [
              DropdownMenuItem(value: 'بيع', child: Text('بيع')),
              DropdownMenuItem(value: 'إيجار', child: Text('إيجار')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
                if (_selectedCategory != 'إيجار') {
                  _selectedSubscriptionPeriod = null;
                }
              });
              _saveDraft();
            },
            validator: (value) => value == null ? 'الرجاء اختيار تصنيف.' : null,
          ),
          if (_selectedCategory == 'إيجار')
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'مدة الإيجار'),
              value: _selectedSubscriptionPeriod,
              items: const [
                DropdownMenuItem(value: 'يومي', child: Text('يومي')),
                DropdownMenuItem(value: 'شهري', child: Text('شهري')),
                DropdownMenuItem(value: '3 شهور', child: Text('3 شهور')),
                DropdownMenuItem(value: 'سنوي', child: Text('سنوي')),
              ],
              onChanged: (value) {
                setState(() => _selectedSubscriptionPeriod = value);
                _saveDraft();
              },
              validator: (value) =>
                  value == null ? 'الرجاء اختيار مدة الإيجار.' : null,
            ),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'نوع العقار'),
            value: _selectedPropertyType,
            items: const [
              DropdownMenuItem(value: 'بيت', child: Text('بيت')),
              DropdownMenuItem(value: 'فيلا', child: Text('فيلا')),
              DropdownMenuItem(value: 'بناية', child: Text('بناية')),
              DropdownMenuItem(value: 'ارض', child: Text('ارض')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedPropertyType = value;
                if (_selectedPropertyType == 'ارض') {
                  _roomsController.clear();
                  _floorController.clear();
                }
              });
              _saveDraft();
            },
            validator: (value) =>
                value == null ? 'الرجاء اختيار نوع العقار.' : null,
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
            onChanged: (_) => _saveDraft(),
          ),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'العملة'),
            value: _selectedCurrency,
            items: const [
              DropdownMenuItem(value: 'ر.س', child: Text('ريال سعودي')),
              DropdownMenuItem(value: 'ل.ت', child: Text('ليرة تركية')),
              DropdownMenuItem(value: 'ل.س', child: Text('ليرة سورية')),
              DropdownMenuItem(value: '\$', child: Text('دولار أمريكي')),
            ],
            onChanged: (value) {
              setState(() => _selectedCurrency = value);
              _saveDraft();
            },
            validator: (value) =>
                value == null ? 'الرجاء اختيار العملة.' : null,
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
            controller: _discountController,
            decoration: const InputDecoration(
              labelText: 'نسبة التخفيض (%) — اختياري',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final n = int.tryParse(value);
              if (n == null || n < 0 || n > 100)
                return 'الرجاء إدخال نسبة بين 0 و 100';
              return null;
            },
            onChanged: (_) => _saveDraft(),
          ),
          TextFormField(
            controller: _areaController,
            decoration: const InputDecoration(labelText: 'المساحة (م²)'),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (_selectedCategory == 'إيجار' &&
                  (value == null || value.trim().isEmpty))
                return null;
              if (value == null ||
                  value.isEmpty ||
                  double.tryParse(value) == null ||
                  double.parse(value) <= 0) {
                return 'الرجاء إدخال مساحة صحيحة أكبر من صفر.';
              }
              return null;
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
            onChanged: (_) => _saveDraft(),
          ),
          const SizedBox(height: 20),
          if (!widget.isEditMode) _buildLocationPicker(),
          const SizedBox(height: 20),
          _buildImagePicker(),
        ],
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
        Text('صور العقار', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _images.length + 1,
            itemBuilder: (ctx, index) {
              if (index == _images.length) {
                return _buildAddImageButton();
              }
              final image = _images[index];
              return _buildImageThumbnail(image, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(dynamic image, int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          if (image is XFile)
            Image.file(
              File(image.path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else if (image is String)
            CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.broken_image),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (image is String) {
                    _imagesToRemove.add(image);
                  }
                  _images.removeAt(index);
                });
              },
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton() {
    return InkWell(
      onTap: _pickImages,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                'إضافة صورة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

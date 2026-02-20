import 'dart:io';
import 'package:aqar_app/screens/map_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ✅ استيراد مزودات الحالة (Providers)
import 'package:provider/provider.dart';
import 'package:aqar_app/providers/user_provider.dart';

class PropertyForm extends StatefulWidget {
  final GlobalKey<FormBuilderState> formKey;
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
  LatLng? _selectedLocation;
  String? _addressCountry;
  String? _addressCity;
  String? _addressStreet;

  final List<dynamic> _images = [];
  final List<String> _imagesToRemove = [];

  XFile? _pickedVideo;
  String? _existingVideoUrl;
  bool _removeExistingVideo = false;

  late Map<String, dynamic> _processedInitialData;
  static const _draftPrefix = 'add_property_';

  @override
  void initState() {
    super.initState();
    _processedInitialData = _processDataForDisplay(widget.initialData);

    // 1. تهيئة الموقع
    _initializeLocation();

    // 2. تحميل الصور بشكل صحيح عند بدء الشاشة
    final existingImages =
        widget.initialData['images'] ?? widget.initialData['imageUrls'];
    if (existingImages != null && existingImages is List) {
      _images.addAll(
        existingImages
            .where((e) => e != null)
            .map((e) => e.toString())
            .toList(),
      );
    }

    // 3. تحميل الفيديو
    if (widget.initialData['videoUrl'] != null) {
      _existingVideoUrl = widget.initialData['videoUrl'];
    }

    // 4. تحميل المسودة (فقط في حالة الإضافة الجديدة)
    if (!widget.isEditMode) {
      _loadDraft();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.bindSubmit(_onSave);
    });
  }

  void _initializeLocation() {
    if (widget.initialData['location'] != null) {
      final loc = widget.initialData['location'];

      if (loc is Map) {
        final double? lat = (loc['_latitude'] ?? loc['latitude'])?.toDouble();
        final double? lng = (loc['_longitude'] ?? loc['longitude'])?.toDouble();
        if (lat != null && lng != null) {
          _selectedLocation = LatLng(lat, lng);
          _getAddressFromLatLng(_selectedLocation!);
        }
      } else if (loc is LatLng) {
        _selectedLocation = loc;
        _getAddressFromLatLng(_selectedLocation!);
      }
    } else if (widget.initialData['latitude'] != null &&
        widget.initialData['longitude'] != null) {
      final double lat = double.parse(
        widget.initialData['latitude'].toString(),
      );
      final double lng = double.parse(
        widget.initialData['longitude'].toString(),
      );
      _selectedLocation = LatLng(lat, lng);
      _getAddressFromLatLng(_selectedLocation!);
    }
  }

  Map<String, dynamic> _processDataForDisplay(Map<String, dynamic> data) {
    final Map<String, dynamic> processed = Map.from(data);
    final numericFields = [
      'price',
      'rooms',
      'floor',
      'area',
      'discountPercent',
      'bedrooms',
      'bathrooms',
      'livingRooms',
      'streetWidth',
      'age',
    ];
    for (var field in numericFields) {
      if (processed[field] != null) {
        processed[field] = processed[field].toString();
      }
    }

    if (processed['rooms'] == null && processed['bedrooms'] != null) {
      processed['rooms'] = processed['bedrooms'].toString();
    }

    return processed;
  }

  @override
  void dispose() {
    _saveDraft();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    await Future.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    if (widget.formKey.currentState != null) {
      final Map<String, dynamic> draftData = {};
      for (final key in widget.formKey.currentState!.fields.keys) {
        final draftValue = prefs.get('${_draftPrefix}$key');
        if (draftValue != null) {
          draftData[key] = draftValue.toString();
          final fieldState = widget.formKey.currentState!.fields[key];
          if (fieldState?.value is bool) {
            if (draftValue is bool)
              draftData[key] = draftValue;
            else if (draftValue == 'true')
              draftData[key] = true;
            else
              draftData[key] = false;
          }
        }
      }
      widget.formKey.currentState!.patchValue(draftData);
    }
    setState(() {
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
    if (widget.formKey.currentState == null) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in widget.formKey.currentState!.fields.keys) {
      final value = widget.formKey.currentState!.fields[key]?.value;
      if (value is bool) {
        await prefs.setBool('${_draftPrefix}$key', value);
      } else if (value != null) {
        await prefs.setString('${_draftPrefix}$key', value.toString());
      } else {
        await prefs.remove('${_draftPrefix}$key');
      }
    }
    if (_selectedLocation != null) {
      await prefs.setDouble('${_draftPrefix}lat', _selectedLocation!.latitude);
      await prefs.setDouble('${_draftPrefix}lng', _selectedLocation!.longitude);
    }
  }

  void _onSave() {
    if (widget.formKey.currentState!.saveAndValidate()) {
      if (_images.isEmpty) {
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

      final data = Map<String, dynamic>.from(
        widget.formKey.currentState!.value,
      );

      // ✅ الحفاظ على ميزة "عرض مميز" للمستخدم العادي عند التعديل
      // إذا لم يكن الحقل موجوداً في بيانات الفورم، نأخذ القيمة القديمة أو نعطيها false
      if (!data.containsKey('isFeatured')) {
        data['isFeatured'] = widget.initialData['isFeatured'] ?? false;
      }

      data.addAll({
        'location': _selectedLocation,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'address':
            '${_addressStreet ?? ''}, ${_addressCity ?? ''}, ${_addressCountry ?? ''}',
        'newImages': _images.whereType<XFile>().toList(),
        'existingImageUrls': _images.whereType<String>().toList(),
        'imagesToRemove': _imagesToRemove,
        'newVideo': _pickedVideo,
        'removeExistingVideo': _removeExistingVideo,
      });

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

  void _pickVideo() async {
    final imagePicker = ImagePicker();
    final video = await imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (video == null) return;
    setState(() {
      _pickedVideo = video;
      _removeExistingVideo = true;
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
      debugPrint('[PropertyForm] Error getting address: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ جلب حالة المستخدم لمعرفة ما إذا كان يمتلك صلاحية أدمن
    final isAdmin = Provider.of<UserProvider>(context, listen: false).isAdmin;

    return FormBuilder(
      key: widget.formKey,
      initialValue: _processedInitialData,
      onChanged: _saveDraft,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          FormBuilderTextField(
            name: 'title',
            decoration: InputDecoration(
              labelText: 'عنوان الإعلان',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              prefixIcon: const Icon(Icons.title_outlined),
            ),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: 'مطلوب'),
              FormBuilderValidators.minLength(5, errorText: 'قصير جداً'),
            ]),
          ),
          const SizedBox(height: 16),
          FormBuilderDropdown<String>(
            name: 'category',
            decoration: InputDecoration(
              labelText: 'التصنيف',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              prefixIcon: const Icon(Icons.category_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'بيع', child: Text('بيع')),
              DropdownMenuItem(value: 'إيجار', child: Text('إيجار')),
            ],
            validator: FormBuilderValidators.required(errorText: 'مطلوب'),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (widget.formKey.currentState?.fields['category']?.value == 'إيجار')
            FormBuilderDropdown<String>(
              name: 'subscriptionPeriod',
              decoration: InputDecoration(
                labelText: 'مدة الإيجار',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'يومي', child: Text('يومي')),
                DropdownMenuItem(value: 'شهري', child: Text('شهري')),
                DropdownMenuItem(value: 'سنوي', child: Text('سنوي')),
              ],
              validator: FormBuilderValidators.required(errorText: 'مطلوب'),
            ),
          const SizedBox(height: 16),
          FormBuilderDropdown<String>(
            name: 'propertyType',
            decoration: InputDecoration(
              labelText: 'النوع',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.home),
            ),
            items: const [
              DropdownMenuItem(value: 'بيت', child: Text('بيت')),
              DropdownMenuItem(value: 'فيلا', child: Text('فيلا')),
              DropdownMenuItem(value: 'بناية', child: Text('بناية')),
              DropdownMenuItem(value: 'ارض', child: Text('ارض')),
              DropdownMenuItem(value: 'دكان', child: Text('دكان')),
            ],
            validator: FormBuilderValidators.required(errorText: 'مطلوب'),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FormBuilderTextField(
            name: 'price',
            decoration: InputDecoration(
              labelText: 'السعر',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.attach_money),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: FormBuilderValidators.required(errorText: 'مطلوب'),
          ),
          const SizedBox(height: 16),
          FormBuilderDropdown<String>(
            name: 'currency',
            decoration: InputDecoration(
              labelText: 'العملة',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            initialValue: 'ر.س',
            items: const [
              DropdownMenuItem(value: 'ر.س', child: Text('ريال سعودي')),
              DropdownMenuItem(value: 'ل.ت', child: Text('ليرة تركية')),
              DropdownMenuItem(value: '\$', child: Text('دولار')),
            ],
            validator: FormBuilderValidators.required(errorText: 'مطلوب'),
          ),
          const SizedBox(height: 16),

          // ✅ إظهار زر التميز فقط في حال كان المستخدم أدمن
          if (isAdmin)
            FormBuilderSwitch(
              name: 'isFeatured',
              title: const Text(
                '⭐ عرض مميز (صلاحية إدارة)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              initialValue: false,
            ),

          FormBuilderSwitch(
            name: 'isFurnished',
            title: const Text('مؤثث'),
            initialValue: false,
          ),
          FormBuilderSwitch(
            name: 'hasKitchen',
            title: const Text('يوجد مطبخ'),
            initialValue: false,
          ),
          FormBuilderSwitch(
            name: 'hasAnnex',
            title: const Text('يوجد ملحق'),
            initialValue: false,
          ),
          FormBuilderSwitch(
            name: 'hasCarEntrance',
            title: const Text('مدخل سيارة'),
            initialValue: false,
          ),
          FormBuilderSwitch(
            name: 'hasElevator',
            title: const Text('يوجد مصعد'),
            initialValue: false,
          ),
          FormBuilderSwitch(
            name: 'hasPool',
            title: const Text('يوجد مسبح'),
            initialValue: false,
          ),
          const SizedBox(height: 16),

          FormBuilderTextField(
            name: 'discountPercent',
            decoration: InputDecoration(
              labelText: 'خصم (%)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.number,
            initialValue: '0',
          ),
          const SizedBox(height: 16),
          FormBuilderTextField(
            name: 'area',
            decoration: InputDecoration(
              labelText: 'المساحة (م²)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.number,
            validator: FormBuilderValidators.required(errorText: 'مطلوب'),
          ),
          const SizedBox(height: 16),

          // عرض الحقول حسب نوع العقار
          if (widget.formKey.currentState?.fields['propertyType']?.value !=
                  'ارض' &&
              widget.formKey.currentState?.fields['propertyType']?.value !=
                  'دكان') ...[
            Row(
              children: [
                Expanded(
                  child: FormBuilderTextField(
                    name: 'rooms',
                    decoration: InputDecoration(
                      labelText: 'غرف النوم',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'livingRooms',
                    decoration: InputDecoration(
                      labelText: 'الصالات',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FormBuilderTextField(
                    name: 'bathrooms',
                    decoration: InputDecoration(
                      labelText: 'دورات المياه',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FormBuilderTextField(
                    name: 'floor',
                    decoration: InputDecoration(
                      labelText: 'الطابق',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FormBuilderTextField(
                  name: 'streetWidth',
                  decoration: InputDecoration(
                    labelText: 'عرض الشارع (م)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FormBuilderTextField(
                  name: 'age',
                  decoration: InputDecoration(
                    labelText: 'عمر العقار (سنة)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          FormBuilderTextField(
            name: 'description',
            decoration: InputDecoration(
              labelText: 'الوصف',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              prefixIcon: const Icon(Icons.description_outlined),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: 'مطلوب'),
              FormBuilderValidators.minLength(10, errorText: 'قصير جداً'),
            ]),
          ),
          const SizedBox(height: 20),
          _buildLocationPicker(),
          const SizedBox(height: 20),
          _buildImagePicker(),
          const SizedBox(height: 20),
          _buildVideoPicker(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLocationPicker() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.map),
        title: Text(
          _selectedLocation == null ? 'تحديد الموقع' : 'تم تحديد الموقع',
        ),
        subtitle: Text(_addressCity ?? 'اضغط للاختيار'),
        onTap: _selectOnMap,
        trailing: _selectedLocation != null
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
      ),
    );
  }

  Widget _buildImagePicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'صور العقار',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            if (_images.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (ctx, index) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildImageThumbnail(_images[index], index),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPicker() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.videocam,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'فيديو العقار (اختياري)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_pickedVideo != null)
              ListTile(
                leading: const Icon(Icons.file_present, color: Colors.green),
                title: const Text('تم اختيار فيديو جديد'),
                subtitle: Text(_pickedVideo!.name),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => setState(() => _pickedVideo = null),
                ),
              )
            else if (_existingVideoUrl != null && !_removeExistingVideo)
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.blue),
                title: const Text('يوجد فيديو مرفق'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _removeExistingVideo = true),
                ),
              )
            else
              FilledButton.tonalIcon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_call),
                label: const Text('إضافة جولة فيديو'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(dynamic image, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 100,
            height: 100,
            child: image is XFile
                ? Image.file(File(image.path), fit: BoxFit.cover)
                : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () => setState(() {
              if (image is String) _imagesToRemove.add(image);
              _images.removeAt(index);
            }),
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.red,
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

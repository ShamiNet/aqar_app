import 'dart:io';
import 'package:aqar_app/screens/map_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  final List<dynamic> _images = []; // Can hold XFile or String (URL)
  final List<String> _imagesToRemove = [];

  static const _draftPrefix = 'add_property_';

  @override
  void initState() {
    super.initState();
    if (!widget.isEditMode) {
      _loadDraft();
    }
    // Expose submit function to parent so it can trigger save
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.bindSubmit(_onSave);
    });
  }

  @override
  void dispose() {
    _saveDraft();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    // Wait for the first frame to ensure the form state is available.
    await Future.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    if (widget.formKey.currentState != null) {
      final Map<String, dynamic> draftData = {};
      for (final key in widget.formKey.currentState!.fields.keys) {
        final draftValue = prefs.get('${_draftPrefix}$key');
        if (draftValue != null) {
          // Convert all values to String for FormBuilderTextField compatibility
          if (draftValue is String) {
            draftData[key] = draftValue;
          } else if (draftValue is bool) {
            draftData[key] = draftValue;
          } else {
            // Convert int, double, or any other type to String
            draftData[key] = draftValue.toString();
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
    final values = widget.formKey.currentState!.value;

    for (final key in values.keys) {
      final value = values[key];
      // To prevent type errors on load, save everything as a string if possible,
      // except for booleans which have a dedicated field type (Switch).
      if (value is bool) {
        await prefs.setBool('${_draftPrefix}$key', value);
      } else if (value != null) {
        // For text fields that might contain numbers (price, area, etc.),
        // saving them as strings ensures they load correctly into FormBuilderTextField.
        await prefs.setString('${_draftPrefix}$key', value.toString());
      } else {
        // If value is null, remove it from draft.
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
      if (_selectedLocation == null && !widget.isEditMode) {
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
      data.addAll({
        'location': _selectedLocation ?? widget.initialData['location'],
        'address':
            '${_addressStreet ?? ''}, ${_addressCity ?? ''}, ${_addressCountry ?? ''}',
        'newImages': _images.whereType<XFile>().toList(),
        'existingImageUrls': _images.whereType<String>().toList(),
        'imagesToRemove': _imagesToRemove,
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
    // Initialize images from initialData only once
    if (_images.isEmpty && widget.initialData['imageUrls'] != null) {
      _images.addAll(widget.initialData['imageUrls']);
    }
    if (_selectedLocation == null && widget.initialData['location'] != null) {
      final location = widget.initialData['location'] as GeoPoint;
      _selectedLocation = LatLng(location.latitude, location.longitude);
      _getAddressFromLatLng(_selectedLocation!);
    }

    return FormBuilder(
      key: widget.formKey,
      initialValue: Map<String, dynamic>.from(widget.initialData),
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
              fillColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              prefixIcon: const Icon(Icons.title_outlined),
            ),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: 'الرجاء إدخال عنوان.'),
              FormBuilderValidators.minLength(
                5,
                errorText: 'العنوان قصير جداً.',
              ),
            ]),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, end: 0),
          const SizedBox(height: 16),
          FormBuilderDropdown<String>(
                name: 'category',
                decoration: InputDecoration(
                  labelText: 'التصنيف',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'بيع', child: Text('بيع')),
                  DropdownMenuItem(value: 'إيجار', child: Text('إيجار')),
                ],
                validator: FormBuilderValidators.required(
                  errorText: 'الرجاء اختيار تصنيف.',
                ),
                onChanged: (val) {
                  if (val == 'دكان') {
                    // Clear rooms value when switching to shop type
                    widget.formKey.currentState?.patchValue({'rooms': null});
                  }
                  setState(() {});
                },
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .slideX(begin: -0.2, end: 0),
          const SizedBox(height: 16),
          if (widget.formKey.currentState?.fields['category']?.value ==
              'إيجار') ...[
            FormBuilderDropdown<String>(
              name: 'subscriptionPeriod',
              decoration: InputDecoration(
                labelText: 'مدة الإيجار',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                prefixIcon: const Icon(Icons.access_time_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'يومي', child: Text('يومي')),
                DropdownMenuItem(value: 'شهري', child: Text('شهري')),
                DropdownMenuItem(value: '3 شهور', child: Text('3 شهور')),
                DropdownMenuItem(value: 'سنوي', child: Text('سنوي')),
              ],
              validator: FormBuilderValidators.required(
                errorText: 'الرجاء اختيار مدة الإيجار.',
              ),
            ).animate().fadeIn(duration: 300.ms).scale(),
            const SizedBox(height: 16),
          ],
          FormBuilderDropdown<String>(
                name: 'propertyType',
                decoration: InputDecoration(
                  labelText: 'نوع العقار',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  prefixIcon: const Icon(Icons.home_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'بيت', child: Text('بيت')),
                  DropdownMenuItem(value: 'فيلا', child: Text('فيلا')),
                  DropdownMenuItem(value: 'بناية', child: Text('بناية')),
                  DropdownMenuItem(value: 'ارض', child: Text('ارض')),
                  DropdownMenuItem(value: 'دكان', child: Text('دكان')),
                ],
                validator: FormBuilderValidators.required(
                  errorText: 'الرجاء اختيار نوع العقار.',
                ),
                onChanged: (val) =>
                    setState(() {}), // To rebuild and show/hide fields
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 200.ms)
              .slideX(begin: -0.2, end: 0),
          const SizedBox(height: 16),
          FormBuilderTextField(
                name: 'price',
                decoration: InputDecoration(
                  labelText: 'السعر',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  prefixIcon: const Icon(Icons.attach_money_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                valueTransformer: (val) => num.tryParse(val ?? ''),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(
                    errorText: 'الرجاء إدخال السعر.',
                  ),
                  FormBuilderValidators.numeric(
                    errorText: 'الرجاء إدخال رقم صحيح.',
                  ),
                  FormBuilderValidators.min(
                    1,
                    errorText: 'يجب أن يكون السعر أكبر من صفر.',
                  ),
                ]),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 300.ms)
              .slideX(begin: -0.2, end: 0),
          const SizedBox(height: 16),
          FormBuilderDropdown<String>(
                name: 'currency',
                decoration: InputDecoration(
                  labelText: 'العملة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  prefixIcon: const Icon(Icons.monetization_on_outlined),
                ),
                initialValue: 'ر.س',
                items: const [
                  DropdownMenuItem(value: 'ر.س', child: Text('ريال سعودي')),
                  DropdownMenuItem(value: 'ل.ت', child: Text('ليرة تركية')),
                  DropdownMenuItem(value: 'ل.س', child: Text('ليرة سورية')),
                  DropdownMenuItem(value: '\$', child: Text('دولار أمريكي')),
                ],
                validator: FormBuilderValidators.required(
                  errorText: 'الرجاء اختيار العملة.',
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 400.ms)
              .slideX(begin: -0.2, end: 0),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: FormBuilderSwitch(
                name: 'isFeatured',
                title: Row(
                  children: [
                    Icon(
                      Icons.star_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text('عرض مميز'),
                  ],
                ),
                initialValue: false,
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms).scale(),
          const SizedBox(height: 16),
          FormBuilderTextField(
                name: 'discountPercent',
                decoration: InputDecoration(
                  labelText: 'نسبة التخفيض (%) — اختياري',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  helperText: 'أدخل 0 لعدم وجود تخفيض',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                valueTransformer: (val) => int.tryParse(val ?? '0'),
                initialValue: '0',
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.numeric(errorText: 'الرجاء إدخال رقم.'),
                  FormBuilderValidators.min(
                    0,
                    errorText: 'النسبة لا يمكن أن تكون سالبة.',
                  ),
                  FormBuilderValidators.max(
                    100,
                    errorText: 'النسبة لا يمكن أن تتجاوز 100.',
                  ),
                ]),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 600.ms)
              .slideX(begin: -0.2, end: 0),
          const SizedBox(height: 16),
          FormBuilderTextField(
                name: 'area',
                decoration: InputDecoration(
                  labelText: 'المساحة (م²)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  prefixIcon: const Icon(Icons.square_foot_outlined),
                ),
                keyboardType: TextInputType.number,
                valueTransformer: (val) => num.tryParse(val ?? ''),
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'الرجاء إدخال مساحة صحيحة.';
                  }
                  return null;
                },
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 700.ms)
              .slideX(begin: -0.2, end: 0),
          const SizedBox(height: 16),
          if (widget.formKey.currentState?.fields['propertyType']?.value !=
              'ارض') ...[
            if (widget.formKey.currentState?.fields['propertyType']?.value !=
                'دكان') ...[
              FormBuilderTextField(
                name: 'rooms',
                decoration: InputDecoration(
                  labelText: 'عدد الغرف',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  prefixIcon: const Icon(Icons.meeting_room_outlined),
                ),
                keyboardType: TextInputType.number,
                valueTransformer: (val) => int.tryParse(val ?? ''),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(
                    errorText: 'الرجاء إدخال عدد الغرف.',
                  ),
                  FormBuilderValidators.integer(
                    errorText: 'الرجاء إدخال رقم صحيح.',
                  ),
                  FormBuilderValidators.min(
                    1,
                    errorText: 'يجب أن يكون هناك غرفة واحدة على الأقل.',
                  ),
                ]),
              ).animate().fadeIn(duration: 300.ms).scale(),
              const SizedBox(height: 16),
            ],
            FormBuilderTextField(
              name: 'floor',
              decoration: InputDecoration(
                labelText: 'الطابق',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                prefixIcon: const Icon(Icons.layers_outlined),
                helperText: 'أدخل 0 للطابق الأرضي',
              ),
              keyboardType: TextInputType.number,
              valueTransformer: (val) => int.tryParse(val ?? ''),
              validator: FormBuilderValidators.compose(
                (widget.formKey.currentState?.fields['propertyType']?.value ==
                        'دكان')
                    ? [
                        FormBuilderValidators.integer(
                          errorText: 'الرجاء إدخال رقم صحيح (0 للطابق الأرضي).',
                        ),
                      ]
                    : [
                        FormBuilderValidators.required(
                          errorText: 'الرجاء إدخال رقم الطابق.',
                        ),
                        FormBuilderValidators.integer(
                          errorText: 'الرجاء إدخال رقم صحيح (0 للطابق الأرضي).',
                        ),
                      ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 100.ms).scale(),
            const SizedBox(height: 16),
          ],
          FormBuilderTextField(
                name: 'description',
                decoration: InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  prefixIcon: const Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(
                    errorText: 'الرجاء إدخال وصف للعقار.',
                  ),
                  FormBuilderValidators.minLength(
                    10,
                    errorText: 'الرجاء إدخال وصف لا يقل عن 10 أحرف.',
                  ),
                ]),
              )
              .animate()
              .fadeIn(duration: 400.ms, delay: 800.ms)
              .slideX(begin: -0.2, end: 0),
          const SizedBox(height: 20),
          if (!widget.isEditMode) _buildLocationPicker(),
          const SizedBox(height: 20),
          _buildImagePicker(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLocationPicker() {
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
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'الموقع',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _selectOnMap,
              icon: const Icon(Icons.map),
              label: const Text('تحديد الموقع على الخريطة'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (_selectedLocation != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_addressStreet ?? '...'}, ${_addressCity ?? '...'}, ${_addressCountry ?? '...'}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الإحداثيات: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 900.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildImagePicker() {
    return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.photo_library,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'صور العقار',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_images.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_images.length}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
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
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 1000.ms)
        .slideY(begin: 0.2, end: 0);
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

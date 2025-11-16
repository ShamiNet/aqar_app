import 'dart:io';
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
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _areaController;
  late TextEditingController _roomsController;
  late TextEditingController _floorController;
  late TextEditingController _discountController;
  String? _selectedCategory;
  String? _selectedPropertyType;
  String? _selectedCurrency;
  var _isSaving = false;
  var _isLoading = true;
  bool _isFeatured = false;

  final List<dynamic> _existingImageUrls = [];
  final List<XFile> _newImages = [];
  final List<String> _imagesToRemove = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _priceController = TextEditingController();
    _descriptionController = TextEditingController();
    _areaController = TextEditingController();
    _roomsController = TextEditingController();
    _floorController = TextEditingController();
    _discountController = TextEditingController();
    _loadPropertyData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _areaController.dispose();
    _roomsController.dispose();
    _floorController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _loadPropertyData() async {
    try {
      final propertyDoc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .get();

      if (propertyDoc.exists) {
        final data = propertyDoc.data()!;
        _titleController.text = data['title'];
        _priceController.text = data['price'].toString();
        _descriptionController.text = data['description'];
        _areaController.text = data['area'].toString();
        _roomsController.text = data['rooms'].toString();
        _floorController.text = data['floor'].toString();
        _discountController.text = (data['discountPercent'] ?? 0).toString();
        setState(() {
          _selectedCategory = data['category'];
          _selectedPropertyType = data['propertyType'];
          _selectedCurrency = data['currency'] ?? 'ر.س';
          _isFeatured = data['isFeatured'] == true;
          _existingImageUrls.addAll(data['imageUrls'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _pickImages() async {
    final imagePicker = ImagePicker();
    final pickedImages = await imagePicker.pickMultiImage(imageQuality: 50);
    if (pickedImages.isEmpty) {
      return;
    }
    setState(() {
      _newImages.addAll(pickedImages);
    });
  }

  void _updateProperty() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isSaving = true;
      });

      try {
        final List<String> newImageUrls = [];
        for (final image in _newImages) {
          final CloudinaryResponse res = await cloudinary.uploadFile(
            CloudinaryFile.fromFile(
              image.path,
              resourceType: CloudinaryResourceType.Image,
              folder: 'property_images',
            ),
          );
          newImageUrls.add(res.secureUrl);
        }

        // ملاحظة: حذف الصور من التخزين يتطلب الاحتفاظ بالمسار أو اسم الملف الأصلي.
        // يمكن تنفيذ منطق الحذف هنا لاحقاً إذا رغبت.

        final finalImageUrls = [..._existingImageUrls, ...newImageUrls];

        await FirebaseFirestore.instance
            .collection('properties')
            .doc(widget.propertyId)
            .update({
              'title': _titleController.text,
              'price': double.parse(_priceController.text),
              'description': _descriptionController.text,
              'category': _selectedCategory,
              'propertyType': _selectedPropertyType,
              'currency': _selectedCurrency,
              'isFeatured': _isFeatured,
              'discountPercent': int.tryParse(_discountController.text) ?? 0,
              'area': double.parse(_areaController.text),
              'rooms': int.parse(_roomsController.text),
              'floor': int.parse(_floorController.text),
              'imageUrls': finalImageUrls,
            });

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث العقار بنجاح!')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل العقار')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الإعلان',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'الرجاء إدخال عنوان.';
                        }
                        return null;
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
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'نوع العقار',
                      ),
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
                        });
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
                    ),
                    SwitchListTile(
                      title: const Text('عرض مميز'),
                      value: _isFeatured,
                      onChanged: (v) => setState(() => _isFeatured = v),
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
                        if (n == null || n < 0 || n > 100) {
                          return 'الرجاء إدخال نسبة بين 0 و 100';
                        }
                        return null;
                      },
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'العملة'),
                      initialValue: _selectedCurrency,
                      items: const [
                        DropdownMenuItem(
                          value: 'ر.س',
                          child: Text('ريال سعودي'),
                        ),
                        DropdownMenuItem(
                          value: 'ل.ت',
                          child: Text('ليرة تركية'),
                        ),
                        DropdownMenuItem(
                          value: 'ل.س',
                          child: Text('ليرة سورية'),
                        ),
                        DropdownMenuItem(
                          value: '\$',
                          child: Text('دولار أمريكي'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCurrency = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) return 'الرجاء اختيار العملة.';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _areaController,
                      decoration: const InputDecoration(
                        labelText: 'المساحة (م²)',
                      ),
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
                    ),
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
                    ),
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
                    ),
                    const SizedBox(height: 20),
                    _buildImagePicker(),
                    const SizedBox(height: 20),
                    if (_isSaving)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton(
                        onPressed: _updateProperty,
                        child: const Text('حفظ التعديلات'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الصور', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._existingImageUrls.map((url) {
                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image.network(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _existingImageUrls.remove(url);
                            _imagesToRemove.add(url);
                          });
                        },
                      ),
                    ),
                  ],
                );
              }),
              ..._newImages.map((file) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Image.file(
                    File(file.path),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                );
              }),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _pickImages,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('إضافة صور'),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'package:aqar_app/services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aqar_app/config/cloudinary_config.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  File? _imageFile;
  String? _imageUrl;
  bool _isLoading = false;
  String _selectedRole = 'user';

  final Map<String, String> _roles = {
    'user': 'باحث عن عقار (عضو عادي)',
    'owner': 'صاحب مكتب عقاري / مالك',
  };

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.userData['username'],
    );
    _phoneController = TextEditingController(
      text: widget.userData['phoneNumber'] ?? '',
    );
    _bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    _imageUrl = widget.userData['profileImageUrl'];

    String currentRole = widget.userData['role'] ?? 'user';
    if (_roles.containsKey(currentRole)) {
      _selectedRole = currentRole;
    } else if (currentRole == 'broker' || currentRole == 'agency') {
      _selectedRole = 'owner';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    debugPrint('🔵 [UI] تم النقر على زر حفظ التغييرات'); // Debug 1

    if (!_formKey.currentState!.validate()) {
      debugPrint('🔴 [UI] التحقق من الحقول فشل (Validation Error)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? finalImageUrl = _imageUrl;

      if (_imageFile != null) {
        debugPrint('🔵 [UI] جاري رفع الصورة الجديدة...');
        finalImageUrl = await CloudinaryConfig.uploadImage(_imageFile!);
        debugPrint('🟢 [UI] تم رفع الصورة: $finalImageUrl');
        if (finalImageUrl == null) throw Exception('فشل رفع الصورة');
      }

      final userId =
          widget.userData['id'] ??
          widget.userData['uid'] ??
          widget.userData['userId'];
      debugPrint('🔵 [UI] User ID: $userId');

      final Map<String, dynamic> updateData = {
        'username': _usernameController.text,
        'phoneNumber': _phoneController.text,
        'bio': _bioController.text,
        'role': _selectedRole,
        if (finalImageUrl != null) 'profileImageUrl': finalImageUrl,
      };

      debugPrint('🚀 [UI] استدعاء ApiService.updateUserProfile...');
      await ApiService.updateUserProfile(userId, updateData);

      debugPrint('✅ [UI] تم الانتهاء من ApiService بنجاح!');

      if (mounted) {
        debugPrint('🔵 [UI] إغلاق الشاشة والعودة...');
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الملف الشخصي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [UI Error] تم التقاط خطأ في الواجهة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // منطق الصورة الآمن
    ImageProvider? imageProvider;
    if (_imageFile != null) {
      imageProvider = FileImage(_imageFile!);
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      imageProvider = CachedNetworkImageProvider(_imageUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.primary,
                                width: 3,
                              ),
                              image: imageProvider != null
                                  ? DecorationImage(
                                      image: imageProvider,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: imageProvider == null
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary,
                              radius: 18,
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'يرجى إدخال الاسم' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف',
                        prefixIcon: const Icon(Icons.phone_android),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'نوع الحساب',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _roles.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'نبذة عني',
                        prefixIcon: const Icon(Icons.info_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'حفظ التغييرات',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

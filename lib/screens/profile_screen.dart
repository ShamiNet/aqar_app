import 'dart:io';
import 'package:aqar_app/services/api_service.dart'; // ✅ المصدر الوحيد للبيانات
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aqar_app/config/cloudinary_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _userId;
  // نستخدم Future بدلاً من Stream لأننا نتصل بالسيرفر
  Future<Map<String, dynamic>?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    debugPrint('👤 [Profile] initState called.');
    _loadUser();
  }

  Future<void> _loadUser() async {
    debugPrint('👤 [Profile] Loading user ID from SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');

    debugPrint('👤 [Profile] Found User ID: $uid');

    if (mounted) {
      setState(() {
        _userId = uid;
        if (uid != null) {
          debugPrint('🚀 [Profile] Fetching profile data from API for: $uid');
          _profileFuture = ApiService.fetchUserProfile(uid)
              .then((data) {
                debugPrint(
                  '✅ [Profile] Data received successfully: ${data?.keys}',
                );
                return data;
              })
              .catchError((e) {
                debugPrint('❌ [Profile] Error fetching profile: $e');
                return null;
              });
        } else {
          debugPrint('⚠️ [Profile] No user ID found (Guest mode).');
        }
      });
    }
  }

  // تحديث البروفايل
  Future<void> _updateProfile(
    String newUsername,
    String newPhone,
    String newBio,
    XFile? newImage,
  ) async {
    if (_userId == null) return;
    debugPrint('🔄 [Profile] Updating profile...');

    try {
      String? newImageUrl;
      if (newImage != null) {
        debugPrint('📤 [Profile] Uploading new image to Cloudinary...');
        final CloudinaryResponse res = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            newImage.path,
            resourceType: CloudinaryResourceType.Image,
            folder: 'profile_pictures',
          ),
        );
        newImageUrl = res.secureUrl;
        debugPrint('✅ [Profile] Image uploaded: $newImageUrl');
      }

      // تحديث البيانات (مؤقتاً عبر Firestore المباشر إذا كان مسموحاً للكتابة، أو يجب إضافة Endpoint في السيرفر)
      // الأفضل استخدام endpoint، لكن للسرعة سنحاول التحديث المباشر ونراقبه
      final Map<String, dynamic> updatedData = {
        'username': newUsername,
        'phone': newPhone,
        'bio': newBio,
      };
      if (newImageUrl != null) {
        updatedData['profileImageUrl'] = newImageUrl;
      }

      // ملاحظة: هذا السطر قد يفشل إذا كان الاتصال محظوراً بالكامل.
      // الحل الأمثل هو إضافة دالة updateProfile في ApiService والسيرفر.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .update(updatedData);

      debugPrint('✅ [Profile] Firestore document updated.');

      // إعادة تحميل البيانات لتحديث الواجهة
      _loadUser();
    } catch (e) {
      debugPrint('❌ [Profile] Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
      }
    }
  }

  void _showEditProfileDialog(Map<String, dynamic> currentUserData) {
    final usernameController = TextEditingController(
      text: currentUserData['username'] ?? '',
    );
    final phoneController = TextEditingController(
      text: currentUserData['phone'] ?? '',
    );
    final bioController = TextEditingController(
      text: currentUserData['bio'] ?? '',
    );
    XFile? newImage;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تعديل الملف الشخصي'),
          scrollable: true,
          content: StatefulBuilder(
            builder: (context, setStateImg) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (picked != null) {
                        setStateImg(() => newImage = picked);
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: newImage != null
                          ? FileImage(File(newImage!.path))
                          : (currentUserData['profileImageUrl'] != null
                                    ? NetworkImage(
                                        currentUserData['profileImageUrl'],
                                      )
                                    : null)
                                as ImageProvider?,
                      child:
                          newImage == null &&
                              currentUserData['profileImageUrl'] == null
                          ? const Icon(Icons.add_a_photo, size: 30)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      icon: Icon(Icons.person),
                    ),
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      icon: Icon(Icons.phone),
                    ),
                  ),
                  TextFormField(
                    controller: bioController,
                    decoration: const InputDecoration(
                      labelText: 'نبذة عني',
                      icon: Icon(Icons.info),
                    ),
                    maxLines: 3,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateProfile(
                  usernameController.text,
                  phoneController.text,
                  bioController.text,
                  newImage,
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ملفي الشخصي'), centerTitle: true),
      // ✅ استخدام FutureBuilder بدلاً من StreamBuilder
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('لم يتم العثور على بيانات المستخدم.'),
            );
          }

          final userData = snapshot.data!;
          final username = userData['username'] ?? 'لا يوجد اسم';
          final email = userData['email'] ?? 'لا يوجد بريد';
          final phone = userData['phone'] ?? '';
          final bio = userData['bio'] ?? '';
          final profileImageUrl = userData['profileImageUrl'];
          // تحويل القيم بأمان لتجنب الأخطاء
          final reputationScore =
              (num.tryParse(userData['reputationScore'].toString()) ?? 0.0)
                  .toDouble();
          final reputationCount =
              (num.tryParse(userData['reputationCount'].toString()) ?? 0)
                  .toInt();

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: profileImageUrl != null
                            ? CachedNetworkImageProvider(profileImageUrl)
                            : null,
                        child: profileImageUrl == null
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 20,
                              color: Colors.white,
                            ),
                            onPressed: () => _showEditProfileDialog(userData),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    username,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(email, style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  _buildReputation(reputationScore, reputationCount),
                  const Divider(height: 30),
                  if (phone.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: Text(phone),
                    ),
                  if (bio.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(bio),
                    ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReputation(double score, int count) {
    if (count == 0) return const Text('لا توجد تقييمات بعد');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RatingBarIndicator(
          rating: score,
          itemBuilder: (context, index) =>
              const Icon(Icons.star, color: Colors.amber),
          itemCount: 5,
          itemSize: 20.0,
        ),
        const SizedBox(width: 8),
        Text('${score.toStringAsFixed(1)} ($count تقييم)'),
      ],
    );
  }
}

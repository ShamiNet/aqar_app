// import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aqar_app/screens/admin_dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aqar_app/config/cloudinary_config.dart';
import 'package:about/about.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io'; // ضروري جداً لاستخدام File

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _user = FirebaseAuth.instance.currentUser;

  // تحديث الدالة لتقبل البيانات الإضافية (الهاتف والنبذة)
  Future<void> _updateProfile(
    String newUsername,
    String newPhone,
    String newBio,
    XFile? newImage,
  ) async {
    debugPrint('[ProfileScreen] _updateProfile: Starting profile update.');
    if (_user == null) return;

    try {
      String? newImageUrl;
      if (newImage != null) {
        debugPrint(
          '[ProfileScreen] _updateProfile: Uploading new profile image.',
        );
        final CloudinaryResponse res = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            newImage.path,
            resourceType: CloudinaryResourceType.Image,
            folder: 'profile_pictures',
          ),
        );
        newImageUrl = res.secureUrl;
      }

      // تجهيز البيانات للتحديث
      final Map<String, dynamic> updatedData = {
        'username': newUsername,
        'phone': newPhone, // حقل جديد
        'bio': newBio, // حقل جديد
      };

      if (newImageUrl != null) {
        updatedData['profileImageUrl'] = newImageUrl;
      }

      debugPrint('[ProfileScreen] _updateProfile: Updating user in Firestore.');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .update(updatedData);

      debugPrint('[ProfileScreen] _updateProfile: Update successful.');
      setState(() {}); // Refresh UI
    } catch (e) {
      debugPrint('[ProfileScreen] _updateProfile: An error occurred: $e');
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

    debugPrint('[ProfileScreen] _showEditProfileDialog: Showing dialog.');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تعديل الملف الشخصي'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. صورة الملف الشخصي
              StatefulBuilder(
                builder: (context, setStateImg) {
                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[200],
                        // هنا تم إصلاح الخطأ
                        backgroundImage: newImage != null
                            ? FileImage(
                                File(newImage!.path),
                              ) // تحويل XFile إلى File
                            : (currentUserData['profileImageUrl'] != null
                                      ? NetworkImage(
                                          currentUserData['profileImageUrl'],
                                        )
                                      : null)
                                  as ImageProvider?,
                        child:
                            newImage == null &&
                                currentUserData['profileImageUrl'] == null
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (picked != null) {
                            setStateImg(() {
                              newImage = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: const Text('تغيير الصورة'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),

              // 2. اسم المستخدم
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // 3. رقم الهاتف
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone_android),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // 4. نبذة عني
              TextFormField(
                controller: bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'نبذة عني',
                  prefixIcon: Icon(Icons.info_outline),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateProfile(
                  usernameController.text,
                  phoneController.text,
                  bioController.text,
                  newImage,
                );
                Navigator.of(ctx).pop();
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
    if (_user == null) {
      return const Center(child: Text('لم يتم العثور على مستخدم.'));
    }

    return Scaffold(
      // قمنا بإزالة العنوان (title) لتجنب التكرار مع الصفحة الرئيسية
      // وأبقينا فقط زر الخروج في الـ AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // جعل الخلفية شفافة لدمجها
        elevation: 0, // إزالة الظل
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'تسجيل الخروج',
            onPressed: () {
              debugPrint('[ProfileScreen] Signing out user.');
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_user.uid)
            .snapshots(),
        builder: (ctx, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userSnapshot.hasError) {
            return const Center(child: Text('حدث خطأ ما.'));
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(
              child: Text('لم يتم العثور على بيانات المستخدم.'),
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final username = userData['username'] ?? 'لا يوجد اسم';
          final email = userData['email'] ?? 'لا يوجد بريد إلكتروني';
          final phone = userData['phone'] ?? '';
          final bio = userData['bio'] ?? '';
          final profileImageUrl = userData['profileImageUrl'];
          final String userRole = userData['role'] ?? 'مشترك';

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // صورة الملف الشخصي وزر التعديل
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        backgroundImage: profileImageUrl != null
                            ? CachedNetworkImageProvider(profileImageUrl)
                            : null,
                        child: profileImageUrl == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: () => _showEditProfileDialog(userData),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // الاسم والبريد
                  Text(
                    username,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    email,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),

                  // عرض رقم الهاتف إذا وجد
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],

                  // عرض النبذة إذا وجدت
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(),

                  // الإحصائيات
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('properties')
                        .where('userId', isEqualTo: _user.uid)
                        .snapshots(),
                    builder: (ctx, propertySnapshot) {
                      if (!propertySnapshot.hasData) {
                        return const SizedBox();
                      }
                      final propertyCount = propertySnapshot.data!.docs.length;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.home_work),
                          title: const Text('عقاراتي المعروضة'),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$propertyCount',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // لوحة التحكم للمدير
                  if (userRole == 'مدير' || userRole == 'admin') ...[
                    const SizedBox(height: 10),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.dashboard_customize),
                        title: const Text('لوحة تحكم المدير'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => const AdminDashboardScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // حول التطبيق
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('حول التطبيق'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        showAboutPage(
                          context: context,
                          applicationName: 'تطبيق عقار',
                          applicationVersion: '1.0.0+1',
                          applicationIcon: const Icon(
                            Icons.house_rounded,
                            size: 64,
                          ),
                          applicationLegalese: '© 2024 فريق التطوير',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

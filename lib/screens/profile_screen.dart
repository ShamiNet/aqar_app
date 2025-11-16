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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _user = FirebaseAuth.instance.currentUser;

  Future<void> _updateProfile(String newUsername, XFile? newImage) async {
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

      final Map<String, dynamic> updatedData = {'username': newUsername};

      if (newImageUrl != null) {
        debugPrint(
          '[ProfileScreen] _updateProfile: New image URL: $newImageUrl',
        );
        updatedData['profileImageUrl'] = newImageUrl;
      }

      debugPrint('[ProfileScreen] _updateProfile: Updating user in Firestore.');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .update(updatedData);

      debugPrint('[ProfileScreen] _updateProfile: Update successful.');
      setState(() {}); // Re-fetch user data
    } catch (e) {
      debugPrint('[ProfileScreen] _updateProfile: An error occurred: $e');
      // Handle error
    }
  }

  void _showEditProfileDialog(Map<String, dynamic> currentUserData) {
    final usernameController = TextEditingController(
      text: currentUserData['username'],
    );
    XFile? newImage;

    debugPrint('[ProfileScreen] _showEditProfileDialog: Showing dialog.');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تعديل الملف الشخصي'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image picker placeholder
                CircleAvatar(
                  radius: 40,
                  backgroundImage: currentUserData['profileImageUrl'] != null
                      ? NetworkImage(currentUserData['profileImageUrl'])
                      : null,
                  child: currentUserData['profileImageUrl'] == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    newImage = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                  },
                  icon: const Icon(Icons.image),
                  label: const Text('تغيير الصورة'),
                ),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateProfile(usernameController.text, newImage);
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

    return StreamBuilder<DocumentSnapshot>(
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
        final profileImageUrl = userData['profileImageUrl'];
        final String userRole = userData['role'] ?? 'مشترك';

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant,
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
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.black,
                        ),
                        onPressed: () => _showEditProfileDialog(userData),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(username, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(email, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              // User stats
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('properties')
                    .where('userId', isEqualTo: _user.uid)
                    .snapshots(),
                builder: (ctx, propertySnapshot) {
                  if (!propertySnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final propertyCount = propertySnapshot.data!.docs.length;
                  return Text(
                    'عدد العقارات: $propertyCount',
                    style: Theme.of(context).textTheme.titleMedium,
                  );
                },
              ),
              if (userRole == 'مدير' || userRole == 'admin') ...[
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: const Text('لوحة تحكم المدير'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const AdminDashboardScreen(),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('حول التطبيق'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  showAboutPage(
                    context: context,
                    applicationName: 'تطبيق عقار',
                    applicationVersion: '1.0.0+1',
                    applicationIcon: const Icon(Icons.house_rounded, size: 64),
                    applicationLegalese: '© 2024 فريق التطوير',
                  );
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  debugPrint('[ProfileScreen] Signing out user.');
                  FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aqar_app/providers/user_provider.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/screens/login_screen.dart';
import 'package:aqar_app/screens/admin_dashboard_screen.dart';
import 'package:aqar_app/screens/my_properties_screen.dart';
import 'package:aqar_app/screens/favorites_screen.dart';
import 'package:aqar_app/screens/edit_profile_screen.dart';
import 'package:aqar_app/screens/my_archived_properties_screen.dart';
import 'package:aqar_app/property_card.dart';
import 'package:aqar_app/screens/property_details_screen.dart';

class ProfileScreen extends StatelessWidget {
  /// userData: بيانات مستخدم آخر (اختياري)
  /// عندما يكون موجوداً، سيتم عرض ملفه الشخصي فقط
  final Map<String, dynamic>? otherUserData;

  const ProfileScreen({super.key, this.otherUserData});

  // ✅ فتح الرابط
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      // نحاول فتح الرابط في التطبيق الخارجي (مثل تلغرام) مباشرة بدون فحص مسبق
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching URL: $e');
      // خطة بديلة: الفتح في المتصفح الداخلي للتطبيق
      launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  // ✅ إجراء مكالمة هاتفية
  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      // إجبار فتح تطبيق الاتصال
      await launchUrl(uri);
    } catch (e) {
      debugPrint('Error launching Phone Call: $e');
    }
  }

  // ✅ تنسيق التاريخ بالعربية
  String _formatDate(dynamic date) {
    if (date == null) return 'غير محدد';

    try {
      DateTime dateTime;

      // معالجة Firestore Timestamp كـ Map
      if (date is Map) {
        // Firestore timestamp format: {_seconds: xxx, _nanoseconds: xxx}
        if (date.containsKey('_seconds')) {
          final seconds = date['_seconds'];
          if (seconds is int) {
            dateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          } else {
            return 'غير محدد';
          }
        } else {
          return 'غير محدد';
        }
      } else if (date.runtimeType.toString().contains('Timestamp')) {
        dateTime = date.toDate();
      } else if (date is DateTime) {
        dateTime = date;
      } else if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is int) {
        if (date.toString().length > 10) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(date);
        } else {
          dateTime = DateTime.fromMillisecondsSinceEpoch(date * 1000);
        }
      } else if (date is double) {
        dateTime = DateTime.fromMillisecondsSinceEpoch((date * 1000).toInt());
      } else {
        debugPrint('⚠️ Unknown date format: ${date.runtimeType}');
        return 'غير محدد';
      }

      final year = dateTime.year;
      final month = _getArabicMonth(dateTime.month);
      final day = dateTime.day;

      return '$day $month $year';
    } catch (e) {
      debugPrint('❌ Error formatting date: $e');
      debugPrint('   Date value: $date');
      debugPrint('   Date type: ${date.runtimeType}');
      return 'غير محدد';
    }
  }

  String _getArabicMonth(int month) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return months[month - 1];
  }

  void _showAboutApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            const Text(
              'حول التطبيق',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.real_estate_agent, size: 60, color: Colors.blue),
            const SizedBox(height: 10),
            const Text(
              'عقار بلص',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text('الإصدار 1.0.0', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.telegram, color: Colors.blue, size: 30),
              title: const Text('قناة التطبيق'),
              subtitle: const Text('انضم لمعرفة الجديد'),
              onTap: () => _launchURL('https://t.me/+yj3zSKtT_mYyZmU0'),
            ),
            ListTile(
              leading: const Icon(
                Icons.code,
                color: Colors.deepPurple,
                size: 30,
              ),
              title: const Text('مراسلة المطور'),
              subtitle: const Text(
                '@DevDrond',
                textDirection: TextDirection.ltr,
              ),
              onTap: () => _launchURL('https://t.me/DevDrond'),
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green, size: 30),
              title: const Text('الاتصال المباشر'),
              subtitle: const Text(
                '+963991260012',
                textDirection: TextDirection.ltr,
              ),
              onTap: () => _makePhoneCall('+963991260012'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // إذا كنا نعرض ملف مستخدم آخر
    if (otherUserData != null) {
      return _buildOtherUserProfile(context, otherUserData!);
    }

    // و إلا نعرض ملف المستخدم الحالي
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.userData;
    final isAdmin = userProvider.isAdmin;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول لعرض الملف الشخصي')),
      );
    }

    return _buildCurrentUserProfile(context, user, isAdmin);
  }

  // بناء ملف المستخدم الحالي (مع زر التعديل والقوائم)
  Widget _buildCurrentUserProfile(
    BuildContext context,
    Map<String, dynamic> user,
    bool isAdmin,
  ) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: user['profileImageUrl'] != null
                      ? NetworkImage(user['profileImageUrl'])
                      : null,
                  child: user['profileImageUrl'] == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user['username'] ?? 'مستخدم',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user['email'] ?? '',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => EditProfileScreen(userData: user),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('تعديل الحساب'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (isAdmin) ...[
            const Text(
              'إدارة التطبيق',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(
                Icons.admin_panel_settings,
                color: Colors.red,
              ),
              title: const Text('لوحة تحكم الإدارة'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const AdminDashboardScreen(),
                ),
              ),
            ),
            const Divider(),
          ],
          const Text(
            'عقاراتي ونشاطي',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.real_estate_agent, color: Colors.blue),
            title: const Text('إعلاناتي'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const MyPropertiesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.redAccent),
            title: const Text('المفضلة'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (ctx) => const FavoritesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.archive, color: Colors.orange),
            title: const Text('الأرشيف'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => const MyArchivedPropertiesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'الإعدادات والدعم',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.purple),
            title: const Text('حول التطبيق والمطور'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showAboutApp(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج'),
            onTap: () async {
              await ApiService.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // بناء ملف مستخدم آخر (للقراءة فقط)
  Widget _buildOtherUserProfile(
    BuildContext context,
    Map<String, dynamic> user,
  ) {
    // استخراج جميع البيانات
    final username = user['username'] ?? 'مستخدم';
    final email = user['email'] ?? '';
    final phone = user['phone'] ?? user['phoneNumber'] ?? '';
    final bio = user['bio'] ?? '';
    final profileImage = user['profileImageUrl'];
    final isVerified = user['isVerified'] == true;
    final isBanned = user['isBanned'] == true;
    final isAdmin = user['isAdmin'] == true;
    final role = user['role'] ?? 'user';
    final reputationScore = user['reputationScore'] ?? 0;
    final reputationCount = user['reputationCount'] ?? 0;
    final createdAt = user['createdAt'];
    final lastSeen = user['lastSeen'];

    // حساب حالة الاتصال بناءً على lastSeen (آخر 5 دقائق)
    bool isOnline = false;
    if (lastSeen != null) {
      try {
        DateTime lastSeenTime;
        if (lastSeen is Map && lastSeen.containsKey('_seconds')) {
          lastSeenTime = DateTime.fromMillisecondsSinceEpoch(
            (lastSeen['_seconds'] as int) * 1000,
          );
        } else if (lastSeen is String) {
          lastSeenTime = DateTime.parse(lastSeen);
        } else if (lastSeen is int) {
          lastSeenTime = DateTime.fromMillisecondsSinceEpoch(lastSeen * 1000);
        } else {
          lastSeenTime = DateTime.now().subtract(const Duration(hours: 1));
        }

        final difference = DateTime.now().difference(lastSeenTime);
        isOnline =
            difference.inMinutes < 5; // متصل إذا كان آخر نشاط خلال 5 دقائق
      } catch (e) {
        debugPrint('Error parsing lastSeen: $e');
        isOnline = false;
      }
    }

    // ترجمة نوع الحساب
    String getRoleText(String role) {
      switch (role.toLowerCase()) {
        case 'admin':
          return 'مشرف';
        case 'owner':
        case 'broker':
        case 'agency':
          return 'صاحب مكتب عقاري / مالك';
        default:
          return 'باحث عن عقار';
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // صورة البروفايل والاسم
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: profileImage != null
                          ? NetworkImage(profileImage)
                          : null,
                      child: profileImage == null
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    // مؤشر الاتصال
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, color: Colors.blue, size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: Colors.grey)),

                // شارات الحالة
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (isAdmin)
                      _buildStatusBadge('مشرف', Colors.amber, Icons.shield),
                    if (isBanned)
                      _buildStatusBadge('محظور', Colors.red, Icons.block),
                    if (isVerified)
                      _buildStatusBadge('موثق', Colors.blue, Icons.verified),
                    if (isOnline)
                      _buildStatusBadge('متصل', Colors.green, Icons.circle),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),

          // السيرة الذاتية
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'نبذة عني',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(bio, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 16),
            const Divider(),
          ],

          // معلومات الحساب
          const SizedBox(height: 16),
          const Text(
            'معلومات الحساب',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),

          // نوع الحساب
          ListTile(
            leading: const Icon(Icons.badge, color: Colors.purple),
            title: const Text('نوع الحساب'),
            subtitle: Text(getRoleText(role)),
          ),

          // رقم الهاتف
          if (phone.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.blue),
              title: const Text('رقم الهاتف'),
              subtitle: Text(phone),
              trailing: IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () => _makePhoneCall(phone),
              ),
            ),

          // تاريخ الانضمام
          if (createdAt != null && createdAt.toString().isNotEmpty)
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.orange),
              title: const Text('تاريخ الانضمام'),
              subtitle: Text(_formatDate(createdAt)),
            ),

          // نقاط السمعة
          if (reputationScore > 0 || reputationCount > 0)
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: const Text('تقييم المستخدم'),
              subtitle: Text('$reputationScore نقطة من $reputationCount تقييم'),
            ),

          const SizedBox(height: 16),
          const Divider(),

          // معلومات إضافية للمشرف
          if (isAdmin || isBanned) ...[
            const SizedBox(height: 16),
            const Text(
              'حالة الحساب',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.shield, color: Colors.amber),
                title: const Text('صلاحيات المشرف'),
                subtitle: const Text('هذا المستخدم لديه صلاحيات إدارة النظام'),
              ),
            if (isBanned)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('محظور'),
                subtitle: const Text('هذا المستخدم محظور من استخدام التطبيق'),
                tileColor: Colors.red.withOpacity(0.1),
              ),
          ],

          const SizedBox(height: 24),
          const Divider(thickness: 2),
          const SizedBox(height: 16),

          // ✅ قسم عقارات المستخدم
          _buildPropertiesSection(
            context,
            user['id'] ?? user['uid'] ?? '',
            'عقارات ${username}',
            Icons.home,
            Colors.blue,
            'user',
          ),

          const SizedBox(height: 16),

          // ✅ قسم العقارات المفضلة
          _buildPropertiesSection(
            context,
            user['id'] ?? user['uid'] ?? '',
            'العقارات المفضلة',
            Icons.favorite,
            Colors.red,
            'favorites',
          ),

          const SizedBox(height: 16),

          // ✅ قسم العقارات المشاهدة
          _buildPropertiesSection(
            context,
            user['id'] ?? user['uid'] ?? '',
            'العقارات التي شاهدها',
            Icons.visibility,
            Colors.purple,
            'viewed',
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // بناء شارة الحالة
  Widget _buildStatusBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ بناء قسم العقارات (عقارات المستخدم / المفضلة)
  Widget _buildPropertiesSection(
    BuildContext context,
    String userId,
    String title,
    IconData icon,
    Color color,
    String type, // 'user' أو 'favorites' أو 'viewed'
  ) {
    if (userId.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // العنوان
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // جلب وعرض العقارات
        FutureBuilder<List<Map<String, dynamic>>>(
          future: () {
            debugPrint(
              '🔍 [PROFILE] Fetching properties - type: $type, userId: $userId',
            );
            if (type == 'user') {
              return ApiService.fetchUserProperties(userId);
            } else if (type == 'favorites') {
              return ApiService.fetchFavorites(userId);
            } else {
              return ApiService.fetchViewedProperties(userId);
            }
          }(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              debugPrint('❌ [PROFILE] Error fetching $type: ${snapshot.error}');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'خطأ في تحميل العقارات',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              );
            }

            final properties = snapshot.data ?? [];
            debugPrint('✅ [PROFILE] Fetched $type: ${properties.length} items');

            if (properties.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        type == 'user'
                            ? Icons.home_outlined
                            : type == 'favorites'
                            ? Icons.favorite_border
                            : Icons.visibility_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        type == 'user'
                            ? 'لا توجد عقارات مضافة'
                            : type == 'favorites'
                            ? 'لا توجد عقارات مفضلة'
                            : 'لا توجد عقارات مشاهدة',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }

            // عرض أول 3 عقارات فقط
            final displayProperties = properties.take(3).toList();

            return Column(
              children: [
                ...displayProperties.map((property) {
                  final propertyId = property['id'] ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 140,
                    child: PropertyCard(
                      property: property,
                      onTap: () {
                        if (propertyId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PropertyDetailsScreen(propertyId: propertyId),
                            ),
                          );
                        }
                      },
                    ),
                  );
                }).toList(),

                // إذا كان هناك أكثر من 3 عقارات
                if (properties.length > 3)
                  TextButton.icon(
                    onPressed: () {
                      // يمكن فتح صفحة تعرض جميع العقارات
                      // للتبسيط سنعرض رسالة
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('عدد العقارات: ${properties.length}'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: Text('عرض الكل (${properties.length})'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

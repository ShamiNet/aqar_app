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

      if (date.runtimeType.toString().contains('Timestamp')) {
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
        return 'غير محدد';
      }

      final year = dateTime.year;
      final month = _getArabicMonth(dateTime.month);
      final day = dateTime.day;

      return '$day $month $year';
    } catch (e) {
      debugPrint('❌ Error formatting date: $e');
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
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'معلومات الحساب',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if ((user['phone'] ?? '').isNotEmpty)
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.blue),
              title: const Text('رقم الهاتف'),
              subtitle: Text(user['phone'] ?? ''),
            ),
          if ((user['createdAt'] ?? '').toString().isNotEmpty)
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.blue),
              title: const Text('تاريخ الانضمام'),
              subtitle: Text(_formatDate(user['createdAt'])),
            ),
        ],
      ),
    );
  }
}

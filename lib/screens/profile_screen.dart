import 'package:aqar_app/screens/auth_gate.dart';
import 'package:aqar_app/screens/edit_profile_screen.dart';
import 'package:aqar_app/screens/favorites_screen.dart'; // تم إضافة استيراد شاشة المفضلة
import 'package:aqar_app/screens/my_properties_screen.dart';
import 'package:aqar_app/screens/privacy_policy_screen.dart';
import 'package:aqar_app/screens/ratings_screen.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/widgets/verified_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _favoritesCount = 0; // متغير لتخزين عدد المفضلة
  int _propertiesCount = 0; // متغير لتخزين عدد العقارات

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final localEmail = prefs.getString('user_email');

      if (userId != null) {
        // جلب بيانات المستخدم
        final data = await ApiService.fetchUserProfile(userId);

        // ✅ طباعة البيانات للتحقق
        debugPrint('👤 [Profile] User data: $data');
        debugPrint(
          '📅 [Profile] createdAt: ${data?['createdAt']} (type: ${data?['createdAt'].runtimeType})',
        );

        // جلب قائمة المفضلة لحساب عددها بدقة
        final favorites = await ApiService.fetchFavorites(userId);

        // جلب عقارات المستخدم لحساب عددها
        final myProperties = await ApiService.fetchMyProperties(userId);

        if (data != null &&
            (data['email'] == null || data['email'].toString().isEmpty)) {
          if (localEmail != null) data['email'] = localEmail;
        }

        if (mounted) {
          setState(() {
            _userData = data;
            _favoritesCount = favorites.length; // تحديث عدد المفضلة
            _propertiesCount = myProperties.length; // تحديث عدد العقارات
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في المغادرة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (ctx) => const AuthGate()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('تعذر تحميل بيانات الملف الشخصي'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchUserData,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    // استخراج البيانات
    final String username = _userData!['username'] ?? 'مستخدم';
    final String email = _userData!['email'] ?? 'البريد غير متوفر';
    final String? phone = _userData!['phoneNumber'];
    final String? bio = _userData!['bio']; // جلب النبذة
    final String? profileImage = _userData!['profileImageUrl'];
    final bool isVerified = _userData!['isVerified'] ?? false;

    // تحويل الدور حسب الطلب
    final String rawRole = _userData!['role'] ?? 'user';
    final String roleDisplay = _translateRole(rawRole);

    final int reputation =
        (_userData!['reputationScore'] as num?)?.toInt() ?? 0;

    // استخدام العداد المُحدّث من الحالة
    final int propertiesCount = _propertiesCount;

    final String createdAt = _formatDate(
      _userData!['createdAt'] ??
          _userData!['registeredAt'] ??
          _userData!['joinedAt'],
    );

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // الهيدر والصورة
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  child: Text(
                    'الملف الشخصي',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: profileImage != null
                          ? CachedNetworkImageProvider(profileImage)
                          : null,
                      child: profileImage == null
                          ? Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey[400],
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),

            // الاسم والتوثيق
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  username,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  const VerifiedBadge(size: 20),
                ],
              ],
            ),
            const SizedBox(height: 4),

            // عرض نوع العضوية
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _getRoleColor(rawRole).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getRoleColor(rawRole).withOpacity(0.3),
                ),
              ),
              child: Text(
                roleDisplay,
                style: TextStyle(
                  color: _getRoleColor(rawRole),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),

            // عرض النبذة (Bio) إذا وجدت
            if (bio != null && bio.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // شريط الإحصائيات (عقاراتي، المفضلة، السمعة، تاريخ الاشتراك)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. عقاراتي
                  Expanded(
                    child: _buildStatItem(
                      context,
                      label: 'عقاراتي',
                      value: propertiesCount.toString(),
                      icon: Icons.home_work_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyPropertiesScreen(),
                        ),
                      ),
                    ),
                  ),
                  _buildStatDivider(),

                  // 2. المفضلة (تمت الإضافة)
                  Expanded(
                    child: _buildStatItem(
                      context,
                      label: 'المفضلة',
                      value: _favoritesCount.toString(),
                      icon: Icons.favorite_border_rounded,
                      color: Colors.redAccent,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FavoritesScreen(),
                        ),
                      ),
                    ),
                  ),
                  _buildStatDivider(),

                  // 3. السمعة
                  Expanded(
                    child: _buildStatItem(
                      context,
                      label: 'السمعة',
                      value: reputation.toString(),
                      icon: Icons.star_rate_rounded,
                      color: Colors.amber,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RatingsScreen(
                            targetUserId: _userData!['id'],
                            targetUserName: username,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildStatDivider(),

                  // 4. تاريخ الاشتراك
                  Expanded(
                    child: _buildStatItem(
                      context,
                      label: 'انضممت',
                      value: createdAt,
                      icon: Icons.date_range_rounded,
                      fontSize: 11, // تصغير الخط قليلاً ليناسب المساحة
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(thickness: 1, indent: 20, endIndent: 20),
            const SizedBox(height: 16),

            // المعلومات
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildInfoTile(
                    context,
                    icon: Icons.email_outlined,
                    title: 'البريد الإلكتروني',
                    value: email,
                  ),
                  if (phone != null && phone.isNotEmpty)
                    _buildInfoTile(
                      context,
                      icon: Icons.phone_android,
                      title: 'رقم الهاتف',
                      value: phone,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // الإعدادات
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الإعدادات',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsTile(
                    context,
                    icon: Icons.edit_note_rounded,
                    title: 'تعديل الملف والنبذة',
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EditProfileScreen(userData: _userData!),
                        ),
                      );
                      if (result == true) {
                        _fetchUserData(); // تحديث الصفحة بعد العودة
                      }
                    },
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.lock_outline,
                    title: 'تغيير كلمة المرور',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يرجى التواصل مع الدعم لتغيير كلمة المرور حالياً',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'سياسة الخصوصية',
                    onTap: () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.logout,
                    title: 'تسجيل الخروج',
                    isDestructive: true,
                    onTap: _logout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Helper Widgets
  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    Color? color,
    VoidCallback? onTap,
    double fontSize = 13,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
        child: Column(
          children: [
            Icon(
              icon,
              color: color ?? Theme.of(context).colorScheme.primary,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: fontSize + 1,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: fontSize - 2),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider() =>
      Container(height: 30, width: 1, color: Colors.grey[300]);

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? Colors.red
        : Theme.of(context).iconTheme.color;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.grey[400],
      ),
    );
  }

  // دالة ترجمة الأدوار
  String _translateRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
      case 'broker':
      case 'agency':
        return 'صاحب مكتب عقاري';
      case 'honorary':
      case 'vip':
        return 'عضو شرف';
      case 'user':
      default:
        return 'عضو عادي';
    }
  }

  // لون مميز لكل دور
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
      case 'broker':
        return Colors.blue.shade800;
      case 'honorary':
      case 'vip':
        return Colors.amber.shade800; // ذهبي لعضو الشرف
      default:
        return Colors.grey.shade700;
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'غير محدد';

    try {
      DateTime date;

      // ✅ معالجة String
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      }
      // ✅ معالجة Int (timestamp بالميلي ثواني)
      else if (dateValue is int) {
        date = DateTime.fromMillisecondsSinceEpoch(dateValue);
      }
      // ✅ معالجة Firestore Map {_seconds: ..., _nanoseconds: ...}
      else if (dateValue is Map && dateValue.containsKey('_seconds')) {
        date = DateTime.fromMillisecondsSinceEpoch(
          (dateValue['_seconds'] as int) * 1000,
        );
      }
      // ✅ معالجة DateTime مباشرة
      else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return dateValue.toString();
      }

      return DateFormat('d MMM yyyy', 'ar').format(date);
    } catch (e) {
      debugPrint('❌ خطأ في تنسيق التاريخ: $e');
      return 'غير محدد';
    }
  }
}

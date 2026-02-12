import 'package:aqar_app/providers/user_provider.dart';
import 'package:aqar_app/screens/favorites_screen.dart';
import 'package:aqar_app/screens/home_screen.dart';
import 'package:aqar_app/screens/profile_screen.dart';
import 'package:aqar_app/screens/add_property_screen.dart';
import 'package:aqar_app/screens/my_properties_screen.dart';
import 'package:aqar_app/screens/properties_map_screen.dart';
import 'package:aqar_app/screens/search_screen.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/widgets/verified_badge.dart'; // تأكد من استيراد الودجت
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:aqar_app/config/theme_controller.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:aqar_app/screens/chats_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aqar_app/screens/admin_dashboard_screen.dart';
import 'package:aqar_app/screens/auth_gate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = [
    const HomeScreen(),
    const PropertiesMapScreen(),
    const MyPropertiesScreen(),
    const ChatsScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    'عقار بلص',
    'الخريطة العقارية',
    'عقاراتي',
    'المحادثات',
    'ملفي الشخصي',
  ];

  Map<String, dynamic>? _currentUserData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _saveUserFCMToken();
  }

  Future<void> _loadUserData() async {
    var userData = await ApiService.getCurrentUser();
    if (userData == null) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        try {
          userData = await ApiService.fetchUserProfile(userId);
        } catch (_) {}
      }
    }
    if (mounted) {
      setState(() {
        _currentUserData = userData;
      });
    }
  }

  void _onItemTapped(int index) {
    if (index >= _pages.length) return;
    setState(() {
      _selectedIndex = index;
    });
    FirebaseAnalytics.instance.logScreenView(
      screenName: _titles[index],
      screenClass: _pages[index].runtimeType.toString(),
    );
  }

  void _navigateToAddProperty() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (ctx) => const AddPropertyScreen()));

    if (result != null && result is String && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(result),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() {
        _selectedIndex = 2;
      });
    }
  }

  void _saveUserFCMToken() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      ApiService.updateFcmToken(userId, fcmToken);
    }
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      // ✅ استخدام البروفايدر لتسجيل الخروج
      await Provider.of<UserProvider>(context, listen: false).logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (ctx) => const AuthGate()),
          (route) => false,
        );
      }
    }
  }

  void _showAboutApp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.home_work_rounded,
                    size: 60,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'عقار بلص',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Text(
                  'المنصة العقارية الأذكى في جيبك',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'مرحباً بك في "عقار بلص"، التطبيق الذي يعيد تعريف تجربة البيع والشراء والاستئجار. نحن نجمع بين أحدث التقنيات وسهولة الاستخدام لنقدم لك سوقاً عقارياً متكاملاً بين يديك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.6, fontSize: 15),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                _buildFeatureSection(
                  context,
                  title: 'للباحثين عن التميز 🏠',
                  features: [
                    '🗺️ خريطة تفاعلية: استكشف العقارات والأحياء بدقة عالية.',
                    '🎥 جولات افتراضية: شاهد العقار بالفيديو قبل زيارته.',
                    '🔍 بحث ذكي: فلترة متقدمة حسب السعر، المساحة، والمواصفات.',
                    '⭐ تقييمات موثوقة: تصفح تقييمات الملاك والوسطاء لضمان المصداقية.',
                    '💬 تواصل مباشر: محادثات فورية آمنة للتفاوض دون وسطاء.',
                  ],
                ),
                const SizedBox(height: 24),
                _buildFeatureSection(
                  context,
                  title: 'للملاك والمسوقين 📈',
                  features: [
                    '🚀 نشر فوري: أضف عقارك في خطوات بسيطة مع رفع الصور والفيديو.',
                    '📊 لوحة تحكم: تتبع أداء إعلاناتك وعدد المشاهدات.',
                    '🏅 شارات التوثيق: احصل على ثقة العملاء عبر توثيق حسابك.',
                    '🤝 إدارة العروض: استقبل طلبات الشراء والإيجار وقم بإدارتها بسهولة.',
                  ],
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'نحن هنا لمساعدتك دائماً',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialButton(
                            Icons.telegram,
                            'قناة التطبيق',
                            'https://t.me/+yj3zSKtT_mYyZmU0',
                          ),
                          const SizedBox(width: 20),
                          _buildSocialButton(
                            Icons.send,
                            '@DevDrond',
                            'https://t.me/DevDrond',
                          ),
                          const SizedBox(width: 20),
                          _buildSocialButton(
                            Icons.phone_in_talk,
                            'اتصال',
                            'tel:+963991260012',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'الإصدار 1.0.0',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureSection(
    BuildContext context, {
    required String title,
    required List<String> features,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        ...features.map(
          (feature) => Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(IconData icon, String label, String url) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح الرابط على هذا الجهاز')),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.grey[800], size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAppDrawer(context),
      extendBody: true,
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<Color>(
            tooltip: 'لون التطبيق',
            icon: Icon(
              Icons.palette_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            onSelected: (color) {
              ThemeController.setSeedColor(color);
            },
            itemBuilder: (context) => [
              _buildColorMenuItem(
                const Color(0xFF1565C0),
                'أزرق ملكي',
                Icons.circle,
              ),
              _buildColorMenuItem(
                const Color(0xFF00695C),
                'أخضر زمردي',
                Icons.circle,
              ),
              _buildColorMenuItem(
                const Color(0xFFAD1457),
                'توتي غامق',
                Icons.circle,
              ),
              _buildColorMenuItem(Colors.amber.shade800, 'ذهبي', Icons.circle),
              _buildColorMenuItem(Colors.blueGrey, 'رمادي مزرق', Icons.circle),
            ],
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) => IconButton(
              onPressed: () {
                ThemeController.toggle();
              },
              icon: Icon(ThemeController.iconFor(mode)),
              tooltip: 'تبديل المظهر',
            ),
          ),
          IconButton(
            onPressed: () {
              FirebaseAnalytics.instance.logEvent(name: 'view_search_screen');
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (ctx) => const SearchScreen()));
            },
            icon: const Icon(Icons.search),
            tooltip: 'بحث',
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButton: (_selectedIndex == 0 || _selectedIndex == 2)
          ? FloatingActionButton(
              onPressed: _navigateToAddProperty,
              child: const Icon(Icons.add_home_work),
              tooltip: 'إضافة عقار',
            )
          : null,
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        onTap: _onItemTapped,
        height: 60.0,
        color: Theme.of(context).colorScheme.surface,
        buttonBackgroundColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Colors.transparent,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 400),
        items: const <Widget>[
          Icon(Icons.home_outlined, size: 30),
          Icon(Icons.map_outlined, size: 30),
          Icon(Icons.business_outlined, size: 30),
          Icon(Icons.chat_bubble_outline, size: 30),
          Icon(Icons.person_outline, size: 30),
        ],
      ),
    );
  }

  Widget _buildAppDrawer(BuildContext context) {
    // ✅ 1. استخدام Provider للوصول لبيانات المستخدم
    final userProvider = Provider.of<UserProvider>(context);
    final userData = userProvider.userData ?? {};

    // ✅ 2. استخراج البيانات من الـ Provider مباشرة
    String username = userProvider.username;
    String email = userProvider.email.isNotEmpty
        ? userProvider.email
        : 'يرجى تسجيل الدخول';
    String? profileImage = userProvider.profileImage;
    bool isVerified = userProvider.isVerified;

    // ✅ 3. التحقق من الصلاحيات أصبح نظيفاً جداً بفضل الـ Provider
    bool isAdmin = userProvider.isAdmin;

    // جلب بيانات التقييم
    double reputationScore = (userData['reputationScore'] ?? 0.0).toDouble();
    int reputationCount = userData['reputationCount'] ?? 0;

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        profileImage != null && profileImage.isNotEmpty
                        ? CachedNetworkImageProvider(profileImage)
                        : null,
                    child: profileImage == null || profileImage.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 50,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // عرض شارة التوثيق
                    if (isVerified)
                      const VerifiedBadge(size: 20, iconColor: Colors.white),

                    // عرض نجمة للأدمن غير الموثق (حالة نادرة)
                    if (isAdmin && !isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                if (reputationCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${reputationScore.toStringAsFixed(1)} ($reputationCount)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                _buildDrawerItem(
                  context,
                  icon: Icons.home_rounded,
                  title: 'الرئيسية',
                  onTap: () {
                    Navigator.pop(context);
                    _onItemTapped(0);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.business_rounded,
                  title: 'عقاراتي',
                  onTap: () {
                    Navigator.pop(context);
                    _onItemTapped(2);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.favorite_rounded,
                  title: 'المفضلة',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FavoritesScreen(),
                      ),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.person_rounded,
                  title: 'الملف الشخصي',
                  onTap: () {
                    Navigator.pop(context);
                    _onItemTapped(4);
                  },
                ),
                // ✅ عرض خيار لوحة التحكم بناءً على الـ Provider
                if (isAdmin)
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard_customize_rounded,
                    title: 'لوحة التحكم (أدمن)',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminDashboardScreen(),
                        ),
                      );
                    },
                  ),

                _buildDrawerItem(
                  context,
                  icon: Icons.info_outline_rounded,
                  title: 'حول التطبيق',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutApp(context);
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.logout_rounded,
                  title: 'تسجيل الخروج',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _signOut(); // هذه الدالة يجب أن تُحدث لتستخدم userProvider.logout()
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? Theme.of(context).textTheme.bodyLarge?.color;
    final iconColor = color ?? Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ), // تباعد أفضل
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // إضافة لون خفيف عند التركيز أو التحويم (اختياري، هنا نعتمد على inkwell)
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1), // خلفية خفيفة للأيقونة
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600, // خط أسمك قليلاً
                      color: itemColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: itemColor?.withOpacity(0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<Color> _buildColorMenuItem(
    Color color,
    String label,
    IconData icon,
  ) {
    return PopupMenuItem(
      value: color,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

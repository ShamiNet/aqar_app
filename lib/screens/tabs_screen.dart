import 'package:aqar_app/screens/favorites_screen.dart';
import 'package:aqar_app/screens/home_screen.dart';
import 'package:aqar_app/screens/profile_screen.dart';
import 'package:aqar_app/screens/add_property_screen.dart';
import 'package:aqar_app/screens/my_properties_screen.dart';
import 'package:aqar_app/screens/properties_map_screen.dart';
import 'package:aqar_app/screens/search_screen.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:aqar_app/config/theme_controller.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:aqar_app/screens/chats_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aqar_app/screens/admin_dashboard_screen.dart';
import 'package:aqar_app/screens/auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    'العقارات المتاحة',
    'الخريطة العقارية',
    'عقاراتي',
    'المحادثات',
    'ملفي الشخصي',
  ];

  Map<String, dynamic>? _currentUserData;

  @override
  void initState() {
    super.initState();
    _loadUserData(); // تحميل البيانات
    _saveUserFCMToken();
  }

  // ✅ دالة ذكية لجلب البيانات (من الذاكرة أو السيرفر)
  Future<void> _loadUserData() async {
    // 1. محاولة الجلب من الذاكرة المحلية
    var userData = await ApiService.getCurrentUser();

    // 2. إذا لم نجد بيانات في الذاكرة، ولكن يوجد معرف مستخدم، نجلبها من السيرفر
    if (userData == null) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        debugPrint(
          "🔄 [Tabs] بيانات المستخدم غير موجودة محلياً، جاري جلبها من السيرفر...",
        );
        try {
          userData = await ApiService.fetchUserProfile(userId);
          // (اختياري) يمكن حفظها في الذاكرة هنا للمستقبل
        } catch (e) {
          debugPrint("❌ [Tabs] فشل جلب البيانات: $e");
        }
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
              _buildColorMenuItem(Colors.teal, 'تيركواز', Icons.circle),
              _buildColorMenuItem(Colors.indigo, 'نيلي', Icons.circle),
              _buildColorMenuItem(Colors.green, 'أخضر', Icons.circle),
              _buildColorMenuItem(Colors.amber, 'ذهبي', Icons.circle),
              _buildColorMenuItem(Colors.deepOrange, 'برتقالي', Icons.circle),
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
        letIndexChange: (index) => true,
        items: <Widget>[
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
    // التحقق من البيانات بدقة
    final userData = _currentUserData ?? {};
    String username = userData['username'] ?? 'ضيف';
    // محاولة جلب الإيميل، إذا لم يوجد نعرض "مستخدم مسجل" بدلاً من رسالة الخطأ
    String email =
        userData['email'] ??
        (userData['id'] != null ? 'مستخدم مسجل' : 'يرجى تسجيل الدخول');
    String? profileImage = userData['profileImageUrl'];
    final role = userData['role'];
    bool isAdmin = (role == 'admin' || role == 'مدير' || role == 'owner');

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            accountName: Text(
              username,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: profileImage != null
                  ? CachedNetworkImageProvider(profileImage)
                  : null,
              child: profileImage == null
                  ? Icon(
                      Icons.person,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
            otherAccountsPictures: [
              if (isAdmin)
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.security, color: Colors.red),
                ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('الرئيسية'),
                  onTap: () {
                    Navigator.pop(context);
                    _onItemTapped(0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('عقاراتي'),
                  onTap: () {
                    Navigator.pop(context);
                    _onItemTapped(2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.favorite),
                  title: const Text('المفضلة'),
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
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('الملف الشخصي'),
                  onTap: () {
                    Navigator.pop(context);
                    _onItemTapped(4);
                  },
                ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(
                      Icons.dashboard_customize,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'لوحة التحكم (أدمن)',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('حول التطبيق'),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('عقار بلص'),
                        content: const Text('بوابتك الذكية لمستقبل العقار 🏠'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('إغلاق'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('تسجيل الخروج'),
                  onTap: () {
                    Navigator.pop(context);
                    _signOut();
                  },
                ),
              ],
            ),
          ),
        ],
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

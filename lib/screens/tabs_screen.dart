import 'package:aqar_app/providers/user_provider.dart';
import 'package:aqar_app/screens/favorites_screen.dart';
import 'package:aqar_app/screens/home_screen.dart';
import 'package:aqar_app/screens/profile_screen.dart';
import 'package:aqar_app/screens/add_property_screen.dart';
import 'package:aqar_app/screens/my_properties_screen.dart';
import 'package:aqar_app/screens/properties_map_screen.dart';
import 'package:aqar_app/screens/search_screen.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/services/websocket_service.dart';
import 'package:aqar_app/widgets/verified_badge.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aqar_app/config/theme_controller.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:aqar_app/screens/chats_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aqar_app/screens/admin_dashboard_screen.dart';
import 'package:aqar_app/screens/auth_gate.dart';
import 'package:aqar_app/screens/about_app_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aqar_app/providers/chat_provider.dart';
import 'package:badges/badges.dart' as badges;

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
    'عقار بلس',
    'الخريطة العقارية',
    'عقاراتي',
    'المحادثات',
    'ملفي الشخصي',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _saveUserFCMToken();

    // ✅ 1. تحميل الرسائل الغير مقروءة فور فتح التطبيق
    _loadInitialUnreadChats();

    // ✅ 2. الاستماع لأي رسالة جديدة تأتي عبر الـ Socket
    WebSocketService.addListener(_onGlobalWebSocketData);
  }

  @override
  void dispose() {
    // ✅ إيقاف الاستماع عند الخروج من الشاشة
    WebSocketService.removeListener(_onGlobalWebSocketData);
    super.dispose();
  }

  // ✅ دالة لمعالجة الرسائل القادمة في الوقت الفعلي
  void _onGlobalWebSocketData(dynamic data) {
    if (data['type'] == 'chats_update' || data['type'] == 'new_message') {
      _loadInitialUnreadChats(); // تحديث النقطة الحمراء
    }
  }

  // ✅ دالة جلب عدد المحادثات غير المقروءة في الخلفية
  Future<void> _loadInitialUnreadChats() async {
    final isLoggedIn = await ApiService.isLoggedIn();
    if (!isLoggedIn) return;

    try {
      final chats = await ApiService.fetchMyChats();
      int totalUnread = 0;
      for (var chat in chats) {
        totalUnread += (chat['unreadCount'] ?? 0) as int;
      }
      if (mounted) {
        Provider.of<ChatProvider>(
          context,
          listen: false,
        ).setUnreadChatsCount(totalUnread);
      }
    } catch (e) {
      debugPrint('Error loading unread chats globally: $e');
    }
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
  }

  void _onItemTapped(int index) {
    if (index >= _pages.length) return;
    setState(() {
      _selectedIndex = index;
    });

    // إذا قام المستخدم بفتح شاشة المحادثات، نقوم بتحديث العداد فوراً
    if (index == 3) {
      _loadInitialUnreadChats();
    }

    FirebaseAnalytics.instance.logScreenView(
      screenName: _titles[index],
      screenClass: _pages[index].runtimeType.toString(),
    );
  }

  void _navigateToAddProperty() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (ctx) => const AddPropertyScreen()));

    if (!mounted) {
      return;
    }
    if (result != null && result is String) {
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

    if (!mounted) {
      return;
    }
    if (shouldSignOut == true) {
      await Provider.of<UserProvider>(context, listen: false).logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (ctx) => const AuthGate()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _openAboutPage(BuildContext context) async {
    if (kIsWeb) {
      final aboutUri = Uri.base.resolve('about.html');
      final launched = await launchUrl(aboutUri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح صفحة حول التطبيق.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AboutAppScreen()));
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
              tooltip: 'إضافة عقار',
              child: const Icon(Icons.add_home_work),
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
        items: <Widget>[
          const Icon(Icons.home_outlined, size: 30),
          const Icon(Icons.map_outlined, size: 30),
          const Icon(Icons.business_outlined, size: 30),
          // ✅ شارة محادثات محسّنة مع عدد الرسائل
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              return badges.Badge(
                position: badges.BadgePosition.topEnd(top: -8, end: -8),
                showBadge: chatProvider.unreadChatsCount > 0,
                badgeContent: Text(
                  chatProvider.unreadChatsCount > 99
                      ? '99+'
                      : chatProvider.unreadChatsCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                badgeStyle: badges.BadgeStyle(
                  badgeColor: Colors.red,
                  padding: const EdgeInsets.all(5),
                  borderRadius: BorderRadius.circular(12),
                  elevation: 2,
                ),
                child: const Icon(Icons.chat_bubble_outline, size: 30),
              );
            },
          ),
          const Icon(Icons.person_outline, size: 30),
        ],
      ),
    );
  }

  Widget _buildAppDrawer(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userData = userProvider.userData ?? {};

    String username = userProvider.username;
    String email = userProvider.email.isNotEmpty
        ? userProvider.email
        : 'يرجى تسجيل الدخول';
    String? profileImage = userProvider.profileImage;
    bool isVerified = userProvider.isVerified;

    bool isAdmin = userProvider.isAdmin;

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
                        color: Colors.black.withValues(alpha: 0.2),
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
                    if (isVerified)
                      const VerifiedBadge(size: 20, iconColor: Colors.white),

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
                    color: Colors.white.withValues(alpha: 0.9),
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
                      color: Colors.white.withValues(alpha: 0.2),
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
                    _openAboutPage(context);
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
                    _signOut();
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
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
                      fontWeight: FontWeight.w600,
                      color: itemColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: itemColor?.withValues(alpha: 0.4),
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

import 'package:aqar_app/screens/favorites_screen.dart';
import 'package:aqar_app/screens/home_screen.dart';
import 'package:aqar_app/screens/profile_screen.dart';
import 'package:aqar_app/screens/add_property_screen.dart';
import 'package:aqar_app/screens/my_properties_screen.dart';
import 'package:aqar_app/screens/properties_map_screen.dart';
import 'package:aqar_app/screens/search_screen.dart';
import 'package:aqar_app/services/notification_service.dart';
// import 'package:aqar_app/screens/map_legend_screen.dart'; // غير مستخدم هنا مباشرة
import 'package:flutter/material.dart';
import 'package:aqar_app/config/theme_controller.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:aqar_app/screens/chats_screen.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  int _selectedIndex = 0;

  // مفاتيح للحفاظ على حالة الصفحات (اختياري لكن مفيد للأداء)
  final List<Widget> _pages = [
    const HomeScreen(),
    const PropertiesMapScreen(),
    const MyPropertiesScreen(),
    const ChatsScreen(),
    const FavoritesScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    'العقارات المتاحة',
    'الخريطة العقارية',
    'عقاراتي',
    'المحادثات',
    'المفضلة',
    'ملفي الشخصي',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // تسجيل الحدث في التحليلات
    FirebaseAnalytics.instance.logScreenView(
      screenName: _titles[index],
      screenClass: _pages[index].runtimeType.toString(),
    );
  }

  void _navigateToAddProperty() async {
    // ننتظر النتيجة عند العودة من صفحة الإضافة
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (ctx) => const AddPropertyScreen()));

    // إذا عاد المستخدم برسالة نجاح (String)، نعرضها ونحدث الواجهة
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

      // إذا كان المستخدم في صفحة "عقاراتي"، قد نحتاج لتحديثها (StreamBuilder يقوم بذلك تلقائياً)
      // لكن يمكننا تحويله لصفحة "عقاراتي" لرؤية العقار الجديد
      setState(() {
        _selectedIndex = 2; // الانتقال لصفحة "عقاراتي"
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // حفظ التوكن عند بدء الشاشة الرئيسية لضمان استلام الإشعارات
    NotificationService.saveTokenToFirestore();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody:
          true, // يجعل المحتوى يمتد خلف شريط التنقل (مهم لـ CurvedNavigationBar)
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // زر تغيير اللون (Theme Color Picker)
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

          // زر الوضع الليلي/النهاري
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

          // زر البحث
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

      // الزر العائم يظهر فقط في الرئيسية (0) وعقاراتي (2)
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
        // ضبط الألوان بناءً على الثيم
        color: Theme.of(context).colorScheme.surface, // لون خلفية الشريط
        buttonBackgroundColor: Theme.of(
          context,
        ).colorScheme.primary, // لون الدائرة المختارة
        backgroundColor: Colors.transparent, // شفاف لكي تظهر الخلفية من ورائه
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 400),
        letIndexChange: (index) => true,
        items: <Widget>[
          Icon(
            Icons.home_outlined,
            size: 30,
            color: _selectedIndex == 0 ? Colors.white : null,
          ),
          Icon(
            Icons.map_outlined,
            size: 30,
            color: _selectedIndex == 1 ? Colors.white : null,
          ),
          Icon(
            Icons.business_outlined,
            size: 30,
            color: _selectedIndex == 2 ? Colors.white : null,
          ),
          Icon(
            Icons.chat_bubble_outline,
            size: 30,
            color: _selectedIndex == 3 ? Colors.white : null,
          ),
          Icon(
            Icons.favorite_border,
            size: 30,
            color: _selectedIndex == 3 ? Colors.white : null,
          ),
          Icon(
            Icons.person_outline,
            size: 30,
            color: _selectedIndex == 4 ? Colors.white : null,
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

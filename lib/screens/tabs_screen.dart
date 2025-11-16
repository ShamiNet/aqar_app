import 'package:aqar_app/screens/favorites_screen.dart';
import 'package:aqar_app/screens/home_screen.dart';
import 'package:aqar_app/screens/profile_screen.dart';
import 'package:aqar_app/screens/add_property_screen.dart';
import 'package:aqar_app/screens/my_properties_screen.dart';
import 'package:aqar_app/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:aqar_app/config/theme_controller.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const MyPropertiesScreen(),
    const FavoritesScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    'العقارات المتاحة',
    'عقاراتي',
    'المفضلة',
    'ملفي الشخصي',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          PopupMenuButton<Color>(
            tooltip: 'لون العلامة',
            icon: const Icon(Icons.palette),
            onSelected: ThemeController.setSeedColor,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: Colors.teal,
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Teal'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: Colors.indigo,
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('Indigo'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: Colors.green,
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Green'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: Colors.amber,
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Amber'),
                  ],
                ),
              ),
            ],
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) => IconButton(
              onPressed: ThemeController.toggle,
              icon: Icon(ThemeController.iconFor(mode)),
              tooltip: 'تبديل النمط',
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (ctx) => const SearchScreen()));
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      floatingActionButton:
          _selectedIndex <
              2 // Show FAB for Home and My Properties
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (ctx) => const AddPropertyScreen(),
                      ),
                    )
                    .then((result) {
                      if (result != null && result is String && mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(result)));
                      }
                    });
              },
              child: const Icon(Icons.add_home_work),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // To allow more than 3 items
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'عقاراتي'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'المفضلة'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'ملفي الشخصي',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

import 'package:aqar_app/features/favorites/screens/favorites_screen.dart';
import 'package:aqar_app/features/home/screens/home_screen.dart';
import 'package:aqar_app/features/profile/screens/profile_screen.dart';
import 'package:aqar_app/features/properties/screens/add_property_screen.dart';
import 'package:aqar_app/features/properties/screens/my_properties_screen.dart';
import 'package:aqar_app/features/search/screens/search_screen.dart';
import 'package:flutter/material.dart';

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
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const AddPropertyScreen(),
                  ),
                );
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

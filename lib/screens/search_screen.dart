import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/widgets/properties_list.dart';
import 'package:aqar_app/widgets/properties_list_skeleton.dart';
import 'package:aqar_app/filter_dialog.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  // لتخزين البيانات القادمة من السيرفر
  late Future<List<Map<String, dynamic>>> _allPropertiesFuture;

  String? _selectedCategory;
  RangeValues _priceRange = const RangeValues(0, 10000000);
  int _minRooms = 0;

  @override
  void initState() {
    super.initState();
    // جلب البيانات مرة واحدة عند فتح الشاشة
    _allPropertiesFuture = ApiService.fetchProperties();

    // تحديث الواجهة عند الكتابة
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => FilterDialog(
        initialCategory: _selectedCategory,
        initialPriceRange: _priceRange,
        initialRooms: _minRooms,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedCategory = result['category'];
        _priceRange = result['priceRange'];
        _minRooms = result['rooms'];
      });
    }
  }

  // دالة الفلترة المحلية
  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> allProperties,
  ) {
    final searchQuery = _searchController.text.trim().toLowerCase();

    return allProperties.where((property) {
      // 1. فلترة التصنيف
      if (_selectedCategory != null &&
          property['category'] != _selectedCategory) {
        return false;
      }

      // 2. فلترة السعر
      final price = num.tryParse(property['price'].toString()) ?? 0;
      if (price < _priceRange.start || price > _priceRange.end) {
        return false;
      }

      // 3. فلترة الغرف
      final rooms = int.tryParse(property['rooms'].toString()) ?? 0;
      if (_minRooms > 0 && rooms < _minRooms) {
        return false;
      }

      // 4. فلترة البحث بالنص
      final title = (property['title'] ?? '').toString().toLowerCase();
      if (searchQuery.isNotEmpty && !title.contains(searchQuery)) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'ابحث عن عقار (العنوان)...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Colors.white.withAlpha((255 * 0.8).round()),
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'تصفية النتائج',
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
      ),
      // نستخدم FutureBuilder بدلاً من StreamBuilder
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _allPropertiesFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PropertiesListSkeleton();
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('حدث خطأ في جلب البيانات من السيرفر'),
            );
          }

          final allProperties = snapshot.data ?? [];

          // تطبيق الفلترة محلياً
          final filteredProperties = _applyFilters(allProperties);

          if (filteredProperties.isEmpty) {
            return const Center(child: Text('لا توجد نتائج مطابقة.'));
          }

          return PropertiesList(properties: filteredProperties);
        },
      ),
    );
  }
}

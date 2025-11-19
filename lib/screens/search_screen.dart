import 'package:aqar_app/widgets/properties_list.dart';
import 'package:aqar_app/widgets/properties_list_skeleton.dart';
import 'package:aqar_app/filter_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();

  // القيم الافتراضية للفلاتر
  String? _selectedCategory;
  RangeValues _priceRange = const RangeValues(
    0,
    10000000,
  ); // رفعنا الحد الأعلى لضمان شمول العقارات الغالية
  int _minRooms = 0;

  @override
  void initState() {
    super.initState();
    // الاستماع لتغييرات النص لتحديث الواجهة فوراً
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

  @override
  Widget build(BuildContext context) {
    // 1. بناء الاستعلام الأساسي (Server-Side Filtering)
    // نفلتر بالسعر والتصنيف على السيرفر لأنها بيانات مهيكلة
    Query query = FirebaseFirestore.instance.collection('properties');

    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    // تصفية السعر على السيرفر
    // ملاحظة: عند استخدام فلترة بالنطاق، يجب الترتيب بنفس الحقل
    query = query
        .where('price', isGreaterThanOrEqualTo: _priceRange.start)
        .where('price', isLessThanOrEqualTo: _priceRange.end)
        .orderBy('price');

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
                // يمكن أيضاً إعادة تعيين الفلاتر هنا إذا أردت
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PropertiesListSkeleton();
          }

          if (snapshot.hasError) {
            debugPrint('Search Error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'حدث خطأ في البحث.\nتأكد من وجود الفهارس (Indexes) في Firebase Console إذا ظهر رابط في السجلات.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('لا توجد عقارات ضمن نطاق السعر والتصنيف المحددين.'),
            );
          }

          // 2. التصفية المتقدمة (Client-Side Filtering)
          // نقوم بتصفية العنوان وعدد الغرف هنا لتجنب قيود Firestore
          final searchQuery = _searchController.text.trim().toLowerCase();

          final filteredProperties = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            // تصفية العنوان (بحث ذكي يحتوي على النص)
            final title = (data['title'] ?? '').toString().toLowerCase();
            final matchesSearch =
                searchQuery.isEmpty || title.contains(searchQuery);

            // تصفية عدد الغرف
            // نحول القيمة لرقم للتأكد من المقارنة الصحيحة
            final rooms = int.tryParse(data['rooms'].toString()) ?? 0;
            final matchesRooms = _minRooms == 0 || rooms >= _minRooms;

            return matchesSearch && matchesRooms;
          }).toList();

          if (filteredProperties.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'لا توجد نتائج مطابقة لـ "$searchQuery"',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_minRooms > 0)
                  Text(
                    'مع حد أدنى $_minRooms غرف',
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            );
          }

          return PropertiesList(properties: filteredProperties);
        },
      ),
    );
  }
}

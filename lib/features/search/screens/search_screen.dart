import 'package:aqar_app/features/home/widgets/properties_list.dart';
import 'package:aqar_app/features/home/widgets/properties_list_skeleton.dart';
import 'package:aqar_app/features/search/widgets/filter_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Stream<QuerySnapshot>? _resultsStream;

  // Filter state
  String? _selectedCategory;
  RangeValues _priceRange = const RangeValues(0, 5000000);
  int _minRooms = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_updateQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateQuery() {
    final searchQuery = _searchController.text;

    if (searchQuery.isEmpty &&
        _selectedCategory == null &&
        _minRooms == 0 &&
        _priceRange.start == 0 &&
        _priceRange.end == 5000000) {
      setState(() {
        _resultsStream = null;
      });
      return;
    }

    Query query = FirebaseFirestore.instance.collection('properties');

    if (searchQuery.isNotEmpty) {
      query = query
          .where('title', isGreaterThanOrEqualTo: searchQuery)
          .where('title', isLessThanOrEqualTo: '$searchQuery\uf8ff');
    }

    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    if (_minRooms > 0) {
      query = query.where('rooms', isGreaterThanOrEqualTo: _minRooms);
    }

    // Price range query - can only be on one field
    query = query.where('price', isGreaterThanOrEqualTo: _priceRange.start);
    query = query.where('price', isLessThanOrEqualTo: _priceRange.end);

    // Order by price when a price range is active, otherwise by title
    if (_priceRange.start > 0 || _priceRange.end < 5000000) {
      query = query.orderBy('price');
    } else if (searchQuery.isNotEmpty) {
      query = query.orderBy('title');
    }

    setState(() {
      _resultsStream = query.snapshots();
    });
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
        _updateQuery();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'ابحث عن عقار...',
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
      body: _resultsStream == null
          ? const Center(child: Text('ابدأ بالكتابة أو استخدم الفلتر للبحث.'))
          : StreamBuilder<QuerySnapshot>(
              stream: _resultsStream,
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const PropertiesListSkeleton();
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ. قد تحتاج إلى إنشاء فهارس Firestore.\n${snapshot.error}',
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('لا توجد عقارات مطابقة للبحث.'),
                  );
                }
                final properties = snapshot.data!.docs;
                return PropertiesList(properties: properties);
              },
            ),
    );
  }
}

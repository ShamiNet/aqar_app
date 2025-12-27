import 'package:aqar_app/services/api_service.dart'; // ✅ استيراد الخدمة
import 'package:aqar_app/widgets/properties_list.dart';
import 'package:aqar_app/widgets/properties_list_skeleton.dart';
import 'package:flutter/material.dart';

class FilteredPropertiesScreen extends StatefulWidget {
  final String filterTitle;
  final String filterType;
  final dynamic filterValue;

  const FilteredPropertiesScreen({
    super.key,
    required this.filterTitle,
    required this.filterType,
    required this.filterValue,
  });

  @override
  State<FilteredPropertiesScreen> createState() =>
      _FilteredPropertiesScreenState();
}

class _FilteredPropertiesScreenState extends State<FilteredPropertiesScreen> {
  late Future<List<Map<String, dynamic>>> _filteredFuture;

  @override
  void initState() {
    super.initState();
    _filteredFuture = _fetchAndFilter();
  }

  Future<List<Map<String, dynamic>>> _fetchAndFilter() async {
    // 1. جلب كل العقارات من السيرفر
    final allProperties = await ApiService.fetchProperties();

    // 2. تصفية البيانات محلياً
    return allProperties.where((doc) {
      switch (widget.filterType) {
        case 'hasDiscount':
          return (doc['discountPercent'] ?? 0) > 0;
        case 'isFeatured':
          return doc['isFeatured'] == true;
        case 'category':
          return doc['category'] == widget.filterValue;
        case 'propertyType':
          return doc['propertyType'] == widget.filterValue;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.filterTitle)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _filteredFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PropertiesListSkeleton();
          }
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ ما!'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'لا توجد عقارات تطابق هذا الفلتر.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          final properties = snapshot.data!;
          return PropertiesList(properties: properties);
        },
      ),
    );
  }
}

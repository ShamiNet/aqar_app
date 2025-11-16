import 'package:aqar_app/widgets/properties_list.dart';
import 'package:aqar_app/widgets/properties_list_skeleton.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FilteredPropertiesScreen extends StatelessWidget {
  final String filterTitle;
  final String filterType;
  final dynamic filterValue;

  const FilteredPropertiesScreen({
    super.key,
    required this.filterTitle,
    required this.filterType,
    required this.filterValue,
  });

  Query<Map<String, dynamic>> _buildQuery() {
    final collection = FirebaseFirestore.instance.collection('properties');
    switch (filterType) {
      case 'hasDiscount':
        return collection.where('discountPercent', isGreaterThan: 0);
      case 'isFeatured':
        return collection.where('isFeatured', isEqualTo: true);
      case 'category':
        return collection.where('category', isEqualTo: filterValue);
      default:
        // Return a query for no results if filter is unknown
        return collection.where('__unknown__', isEqualTo: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(filterTitle)),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery().snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PropertiesListSkeleton();
          }
          if (snapshot.hasError) {
            debugPrint('Error fetching filtered properties: ${snapshot.error}');
            return const Center(child: Text('حدث خطأ ما!'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'لا توجد عقارات تطابق هذا الفلتر.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          final properties = snapshot.data!.docs;
          return PropertiesList(properties: properties);
        },
      ),
    );
  }
}

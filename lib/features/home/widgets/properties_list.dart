import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ويدجت لعرض قائمة العقارات
class PropertiesList extends StatelessWidget {
  const PropertiesList({super.key, required this.properties});

  final List<QueryDocumentSnapshot> properties;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: properties.length,
      itemBuilder: (ctx, index) {
        final property = properties[index].data() as Map<String, dynamic>;
        final title = property['title'] ?? 'بدون عنوان';
        final price = property['price'] ?? 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListTile(
            title: Text(title),
            subtitle: Text('السعر: ${price.toStringAsFixed(2)} ر.س'),
            // يمكنك إضافة المزيد من التفاصيل أو الأزرار هنا
          ),
        );
      },
    );
  }
}

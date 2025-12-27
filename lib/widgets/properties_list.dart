import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/screens/filtered_properties_screen.dart';
import 'package:aqar_app/property_card.dart'; // تأكد من استيراد الكلاس المعدل
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PropertiesList extends StatelessWidget {
  // التغيير هنا: قائمة من Maps بدلاً من Snapshots
  final List<Map<String, dynamic>> properties;

  const PropertiesList({super.key, required this.properties});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: properties.length,
      itemBuilder: (ctx, index) {
        final property = properties[index];
        // المعرف يأتي الآن كجزء من الـ Map من السيرفر
        final propertyId = property['id'] ?? 'unknown';

        return SizedBox(
          height: 280, // تحديد ارتفاع ثابت لتجنب مشاكل التصميم
          child: PropertyCard(
            property: property,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) =>
                      PropertyDetailsScreen(propertyId: propertyId),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

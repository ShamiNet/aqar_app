import 'package:aqar_app/screens/filtered_properties_screen.dart';
import 'package:aqar_app/property_card.dart';
import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:flutter/material.dart';

class HorizontalPropertiesSection extends StatelessWidget {
  final String title;
  // التغيير: نستقبل قائمة بيانات بدلاً من استعلام قاعدة بيانات
  final List<Map<String, dynamic>> properties;
  final String filterType;
  final dynamic filterValue;

  const HorizontalPropertiesSection({
    super.key,
    required this.title,
    required this.properties,
    required this.filterType,
    required this.filterValue,
  });

  @override
  Widget build(BuildContext context) {
    // إذا القائمة فارغة لا نعرض شيئاً
    if (properties.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? null
                      : Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => FilteredPropertiesScreen(
                        filterTitle: title,
                        filterType: filterType,
                        filterValue: filterValue,
                      ),
                    ),
                  );
                },
                child: const Text('عرض الكل'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: properties.length,
            itemBuilder: (ctx, index) {
              final propertyData = properties[index];
              final propertyId = propertyData['id'] ?? 'unknown';

              return SizedBox(
                width: 280,
                child: PropertyCard(
                  property: propertyData,
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
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleGradient = isDark
        ? const LinearGradient(colors: [Color(0xFF7EC9FF), Color(0xFF4A79FF)])
        : const LinearGradient(colors: [Color(0xFF0D2B5B), Color(0xFF2B7BFF)]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionTitlePill(title: title, gradient: titleGradient),
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
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: properties.length,
            itemBuilder: (ctx, index) {
              final propertyData = properties[index];
              final propertyId = propertyData['id'] ?? 'unknown';

              return SizedBox(
                width: 240,
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

class _SectionTitlePill extends StatelessWidget {
  final String title;
  final Gradient gradient;

  const _SectionTitlePill({required this.title, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

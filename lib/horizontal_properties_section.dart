import 'package:aqar_app/screens/filtered_properties_screen.dart';
import 'package:aqar_app/property_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HorizontalPropertiesSection extends StatelessWidget {
  final String title;
  final Query query;
  final String filterType;
  final dynamic filterValue;

  const HorizontalPropertiesSection({
    super.key,
    required this.title,
    required this.query,
    required this.filterType,
    required this.filterValue,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        if (snapshot.hasError) {
          return const Center(child: Text('حدث خطأ ما!'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // لا تعرض شيئاً إذا كانت القائمة فارغة
        }

        final properties = snapshot.data!.docs;

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
              height: 200, // ارتفاع القائمة الأفقية
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: properties.length,
                itemBuilder: (ctx, index) {
                  final property =
                      properties[index].data() as Map<String, dynamic>;
                  final propertyId = properties[index].id;
                  return SizedBox(
                    width: 250, // عرض بطاقة العقار
                    child: PropertyCard(
                      property: property,
                      propertyId: propertyId,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(height: 24, width: 150, color: Colors.grey.shade300),
        ),
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 2,
            itemBuilder: (ctx, index) => const Card(margin: EdgeInsets.all(8)),
          ),
        ),
      ],
    );
  }
}

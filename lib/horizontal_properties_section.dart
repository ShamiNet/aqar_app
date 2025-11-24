import 'package:aqar_app/screens/filtered_properties_screen.dart';
import 'package:aqar_app/property_card.dart'; // تأكد من مسار الملف الصحيح
import 'package:aqar_app/screens/property_details_screen.dart'; // <--- ضروري للتنقل
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
          return const SizedBox.shrink();
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
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: properties.length,
                itemBuilder: (ctx, index) {
                  final doc = properties[index];
                  return SizedBox(
                    width: 280,
                    child: PropertyCard(
                      property: doc, // نمرر الـ doc كاملاً
                      onTap: () {
                        // نمرر منطق التنقل هنا
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) =>
                                PropertyDetailsScreen(propertyId: doc.id),
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
            itemBuilder: (ctx, index) => Container(
              margin: const EdgeInsets.all(8),
              width: 260,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

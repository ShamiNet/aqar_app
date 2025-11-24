import 'package:aqar_app/horizontal_properties_section.dart';
import 'package:aqar_app/property_card.dart';
import 'package:aqar_app/screens/filtered_properties_screen.dart';
import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final featuredPropertiesQuery = FirebaseFirestore.instance
        .collection('properties')
        .where('isFeatured', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(10);
    final featuredPropertiesQueryd = FirebaseFirestore.instance
        .collection('properties')
        .where('propertyType', isEqualTo: 'دكان')
        .orderBy('createdAt', descending: true)
        .limit(10);
    final featuredPropertiesQueryA = FirebaseFirestore.instance
        .collection('properties')
        .where('propertyType', isEqualTo: 'ارض')
        .orderBy('createdAt', descending: true)
        .limit(10);

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade100,
                  Colors.blue.shade300,
                  Colors.grey.shade200,
                ],
              ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عقارات مميزة
            _FeaturedPropertiesCarousel(query: featuredPropertiesQuery),

            // عقارات للبيع
            HorizontalPropertiesSection(
              title: 'عقارات للبيع',
              query: FirebaseFirestore.instance
                  .collection('properties')
                  .where('category', isEqualTo: 'بيع')
                  .orderBy('createdAt', descending: true)
                  .limit(10),
              filterType: 'category',
              filterValue: 'بيع',
            ),

            // عقارات للإيجار
            HorizontalPropertiesSection(
              title: 'عقارات للإيجار',
              query: FirebaseFirestore.instance
                  .collection('properties')
                  .where('category', isEqualTo: 'إيجار')
                  .orderBy('createdAt', descending: true)
                  .limit(10),
              filterType: 'category',
              filterValue: 'إيجار',
            ),

            // بيوت
            HorizontalPropertiesSection(
              title: 'بيوت',
              query: FirebaseFirestore.instance
                  .collection('properties')
                  .where('propertyType', isEqualTo: 'بيت')
                  .orderBy('createdAt', descending: true)
                  .limit(10),
              filterType: 'propertyType',
              filterValue: 'بيت',
            ),

            // فلل
            HorizontalPropertiesSection(
              title: 'فلل',
              query: FirebaseFirestore.instance
                  .collection('properties')
                  .where('propertyType', isEqualTo: 'فيلا')
                  .orderBy('createdAt', descending: true)
                  .limit(10),
              filterType: 'propertyType',
              filterValue: 'فيلا',
            ),
            // عقارات أراضي
            _FeaturedPropertiesCarousel(query: featuredPropertiesQueryA),

            // أراضي
            HorizontalPropertiesSection(
              title: 'أراضي',
              query: FirebaseFirestore.instance
                  .collection('properties')
                  .where('propertyType', isEqualTo: 'ارض')
                  .orderBy('createdAt', descending: true)
                  .limit(10),
              filterType: 'propertyType',
              filterValue: 'ارض',
            ),

            // بنايات
            HorizontalPropertiesSection(
              title: 'بنايات',
              query: FirebaseFirestore.instance
                  .collection('properties')
                  .where('propertyType', isEqualTo: 'بناية')
                  .orderBy('createdAt', descending: true)
                  .limit(10),
              filterType: 'propertyType',
              filterValue: 'بناية',
            ),
            // عقارات دكاكين
            _FeaturedPropertiesCarousel(query: featuredPropertiesQueryd),

            // دكاكين
            HorizontalPropertiesSection(
              title: 'دكاكين',
              query: FirebaseFirestore.instance
                  .collection('properties')
                  .where('propertyType', isEqualTo: 'دكان')
                  .orderBy('createdAt', descending: true)
                  .limit(10),
              filterType: 'propertyType',
              filterValue: 'دكان',
            ),

            // عقارات بخصم
            HorizontalPropertiesSection(
              title: 'عقارات بخصم',
              query: FirebaseFirestore.instance
                  .collection('properties')
                  .where('discountPercent', isGreaterThan: 0)
                  .orderBy('discountPercent', descending: true)
                  .orderBy('createdAt', descending: true)
                  .limit(10),
              filterType: 'hasDiscount',
              filterValue: true,
            ),

            const SizedBox(height: 55),
          ],
        ),
      ),
    );
  }
}

class _FeaturedPropertiesCarousel extends StatelessWidget {
  final Query query;

  const _FeaturedPropertiesCarousel({required this.query});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
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
                    'عقارات مميزة',
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
                          builder: (ctx) => const FilteredPropertiesScreen(
                            filterTitle: 'عقارات مميزة',
                            filterType: 'isFeatured',
                            filterValue: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('عرض الكل'),
                  ),
                ],
              ),
            ),
            CarouselSlider.builder(
              itemCount: properties.length,
              itemBuilder: (context, index, realIndex) {
                final doc = properties[index];
                return SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: PropertyCard(
                    property: doc,
                    onTap: () {
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
              options: CarouselOptions(
                height: 280,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 2),
                autoPlayAnimationDuration: const Duration(milliseconds: 1200),
                autoPlayCurve: Curves.fastOutSlowIn,
                enlargeCenterPage: true,
                viewportFraction: 0.85,
                aspectRatio: 16 / 9,
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

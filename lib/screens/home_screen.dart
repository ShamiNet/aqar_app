import 'package:aqar_app/horizontal_properties_section.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // عقارات مميزة
          HorizontalPropertiesSection(
            title: 'عقارات مميزة',
            query: FirebaseFirestore.instance
                .collection('properties')
                .where('isFeatured', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .limit(10),
            filterType: 'isFeatured',
            filterValue: true,
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

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

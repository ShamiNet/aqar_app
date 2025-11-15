import 'package:aqar_app/widgets/properties_list_skeleton.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:aqar_app/widgets/properties_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PropertiesListSkeleton();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا توجد عقارات متاحة حالياً.'));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('حدث خطأ ما!'));
        }
        final properties = snapshot.data!.docs;
        return PropertiesList(properties: properties);
      },
    );
  }
}

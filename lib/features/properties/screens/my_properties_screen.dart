import 'package:aqar_app/features/home/widgets/properties_list.dart';
import 'package:aqar_app/features/home/widgets/properties_list_skeleton.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyPropertiesScreen extends StatelessWidget {
  const MyPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('الرجاء تسجيل الدخول لعرض عقاراتك.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PropertiesListSkeleton();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لم تقم بإضافة أي عقارات بعد.'));
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

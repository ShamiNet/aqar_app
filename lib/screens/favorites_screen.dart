import 'package:aqar_app/widgets/properties_list.dart';
import 'package:aqar_app/widgets/properties_list_skeleton.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('الرجاء تسجيل الدخول لعرض مفضلتك.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .snapshots(),
      builder: (ctx, favoriteSnapshot) {
        if (favoriteSnapshot.connectionState == ConnectionState.waiting) {
          return const PropertiesListSkeleton();
        }
        if (!favoriteSnapshot.hasData || favoriteSnapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لم تقم بإضافة أي عقارات للمفضلة.'));
        }
        if (favoriteSnapshot.hasError) {
          return const Center(child: Text('حدث خطأ ما!'));
        }

        final favoriteIds = favoriteSnapshot.data!.docs
            .map((doc) => doc.id)
            .toList();

        if (favoriteIds.isEmpty) {
          return const Center(child: Text('لم تقم بإضافة أي عقارات للمفضلة.'));
        }

        return FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _getFavoriteProperties(favoriteIds),
          builder: (context, propertySnapshot) {
            if (propertySnapshot.connectionState == ConnectionState.waiting) {
              return const PropertiesListSkeleton();
            }
            if (!propertySnapshot.hasData || propertySnapshot.data!.isEmpty) {
              return const Center(child: Text('لا توجد عقارات في المفضلة.'));
            }
            if (propertySnapshot.hasError) {
              return const Center(child: Text('حدث خطأ أثناء جلب العقارات.'));
            }
            return PropertiesList(properties: propertySnapshot.data!);
          },
        );
      },
    );
  }

  Future<List<QueryDocumentSnapshot>> _getFavoriteProperties(
    List<String> ids,
  ) async {
    if (ids.isEmpty) {
      return [];
    }
    final propertiesQuery = await FirebaseFirestore.instance
        .collection('properties')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    return propertiesQuery.docs;
  }
}

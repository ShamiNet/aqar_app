import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:aqar_app/features/properties/screens/add_property_screen.dart';
import '../widgets/properties_list.dart';

// الصفحة الرئيسية التي تعرض قائمة العقارات
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العقارات المتاحة'),
        actions: [
          // زر تسجيل الخروج
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // الاستماع إلى التغييرات في collection 'properties'
        stream: FirebaseFirestore.instance
            .collection('properties')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (ctx, snapshot) {
          // في حالة التحميل
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // في حالة عدم وجود بيانات
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد عقارات متاحة حالياً.'));
          }
          // في حالة وجود خطأ
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ ما!'));
          }
          // عرض قائمة العقارات
          final properties = snapshot.data!.docs;
          return PropertiesList(properties: properties);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // الانتقال إلى شاشة إضافة عقار
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const AddPropertyScreen()),
          );
        },
        child: const Icon(Icons.add_home_work),
      ),
    );
  }
}

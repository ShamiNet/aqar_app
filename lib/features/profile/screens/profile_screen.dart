import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('لم يتم العثور على مستخدم.'));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('حدث خطأ ما.'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text('لم يتم العثور على بيانات المستخدم.'),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final username = userData['username'] ?? 'لا يوجد اسم';
        final email = userData['email'] ?? 'لا يوجد بريد إلكتروني';

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 20),
              Text(username, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(email, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

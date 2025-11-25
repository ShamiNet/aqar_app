import 'package:aqar_app/screens/tabs_screen.dart';
import 'package:aqar_app/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. مراقبة حالة تسجيل الدخول
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // حالة انتظار الاتصال
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // إذا لم يكن المستخدم مسجلاً للدخول -> توجيه لصفحة الدخول
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        // المستخدم مسجل دخول، الآن نتحقق من "إعدادات التطبيق" (الحارس)
        final User user = authSnapshot.data!;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('app_settings')
              .doc('config')
              .snapshots(),
          builder: (context, configSnapshot) {
            if (configSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            bool isMaintenance = false;
            String maintenanceMsg =
                'التطبيق مغلق حالياً للصيانة، يرجى المحاولة لاحقاً.';

            // قراءة الإعدادات من قاعدة البيانات
            if (configSnapshot.hasData && configSnapshot.data!.exists) {
              final data = configSnapshot.data!.data() as Map<String, dynamic>;
              isMaintenance = data['maintenance_mode'] ?? false;
              maintenanceMsg = data['maintenance_message'] ?? maintenanceMsg;

              // يمكنك هنا إضافة التحقق من إصدار التطبيق (Min Version) مستقبلاً
            }

            // إذا كان التطبيق يعمل بشكل طبيعي، ادخل فوراً
            if (!isMaintenance) {
              return const TabsScreen();
            }

            // 🛑 إذا كان وضع الصيانة مفعلاً، يجب التحقق: هل المستخدم "أدمن"؟
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (ctx, userDocSnapshot) {
                // أثناء التحقق من الصلاحية
                if (!userDocSnapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final userData =
                    userDocSnapshot.data!.data() as Map<String, dynamic>?;
                final role = userData?['role'];

                // ✅ السماح بالدخول فقط إذا كان "admin"
                if (role == 'admin' || role == 'مدير' || role == 'owner') {
                  return const TabsScreen();
                }

                // ⛔ منع الدخول وعرض شاشة الصيانة
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.construction_rounded,
                            size: 80,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'نعتذر منك 🙏',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            maintenanceMsg,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 40),
                          // زر لتسجيل الخروج أو المحاولة مرة أخرى
                          OutlinedButton.icon(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text('تسجيل الخروج'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

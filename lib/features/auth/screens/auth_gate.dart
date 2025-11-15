import 'package:aqar_app/features/tabs/screens/tabs_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// استيراد الشاشات التي سننتقل إليها من مساراتها الجديدة
import 'package:aqar_app/features/auth/screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // الاستماع إلى التغيرات في حالة المصادقة للمستخدم
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // إذا كان المستخدم لا يزال ينتظر التحقق
        if (snapshot.connectionState == ConnectionState.waiting) {
          // يمكنك عرض شاشة تحميل هنا لاحقاً
          return const Center(child: CircularProgressIndicator());
        }

        // إذا كان هناك بيانات في الـ snapshot، فهذا يعني أن المستخدم مسجل دخوله
        if (snapshot.hasData) {
          return const TabsScreen();
        }

        // إذا لم يكن هناك بيانات، اعرض شاشة تسجيل الدخول
        return const LoginScreen();
      },
    );
  }
}

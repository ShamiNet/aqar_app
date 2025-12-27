import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/screens/tabs_screen.dart';
import 'package:aqar_app/screens/banned_user_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isBanned = false;
  String? _bannedEmail;

  Duration get loginTime => const Duration(milliseconds: 2250);

  // 1. دالة تسجيل الدخول
  Future<String?> _authUser(LoginData data) async {
    debugPrint('\n========================================');
    debugPrint('👤 [UI] المستخدم ضغط على زر الدخول: ${data.name}');

    try {
      // ✅✅✅ هذا هو السطر الأهم! الاتصال بالسيرفر الوسيط
      await ApiService.login(data.name, data.password);

      debugPrint('✅ [UI] العملية اكتملت بنجاح، سيتم التوجيه للرئيسية.');
      setState(() {
        _isBanned = false;
      });
      return null; // نجاح
    } catch (error) {
      final errorMessage = error.toString().replaceAll('Exception: ', '');
      debugPrint('⚠️ [UI] حدث خطأ: $errorMessage');

      // ✅ التحقق من رسالة الحظر المحددة
      if (errorMessage.contains('تم حظر') ||
          errorMessage.contains('banned') ||
          errorMessage.toLowerCase().contains('ban')) {
        debugPrint('🚫 [UI] تم الكشف عن المستخدم المحظور');
        setState(() {
          _isBanned = true;
          _bannedEmail = data.name;
        });
        return null; // لا نعرض رسالة خطأ - نعرض صفحة منفصلة
      }

      return errorMessage;
    }
  }

  // 2. دالة إنشاء الحساب
  Future<String?> _signupUser(SignupData data) async {
    debugPrint('\n========================================');
    debugPrint('📝 [UI] المستخدم يحاول إنشاء حساب: ${data.name}');

    final username = data.additionalSignupData?['username']?.trim() ?? '';
    final phone = data.additionalSignupData?['phone']?.trim() ?? '';

    if (username.isEmpty) return 'الرجاء إدخال اسم المستخدم.';
    if (username.length < 4) return 'اسم المستخدم قصير جداً.';

    try {
      // ✅ خطوة 1: إنشاء الحساب عبر السيرفر
      debugPrint('📝 [UI] إنشاء الحساب...');
      await ApiService.signup(data.name!, data.password!, username, phone);

      debugPrint('✅ [UI] تم إنشاء الحساب وتسجيل الدخول بنجاح!');
      setState(() {
        _isBanned = false;
      });
      return null;
    } catch (error) {
      debugPrint('⚠️ [UI] خطأ في إنشاء الحساب: $error');
      return error.toString().replaceAll('Exception: ', '');
    }
  }

  Future<String?> _recoverPassword(String name) async {
    return 'هذه الميزة غير مفعلة حالياً عبر السيرفر.';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ إذا كان المستخدم محظوراً، عرض صفحة الحظر بدلاً من نموذج تسجيل الدخول
    if (_isBanned && _bannedEmail != null) {
      return BannedUserScreen(email: _bannedEmail);
    }

    return FlutterLogin(
      title: 'عقار بلص',
      logo: const AssetImage('assets/logo.png'),
      onLogin: _authUser,
      onSignup: _signupUser,
      onRecoverPassword: _recoverPassword,
      onSubmitAnimationCompleted: () {
        // إذا كان المستخدم محظوراً، لا نذهب للرئيسية
        if (_isBanned) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BannedUserScreen(email: _bannedEmail),
            ),
          );
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const TabsScreen()),
          );
        });
      },
      userValidator: (value) {
        if (value == null || !value.contains('@')) return 'البريد غير صالح';
        return null;
      },
      passwordValidator: (value) {
        if (value == null || value.length < 6) return 'كلمة المرور قصيرة';
        return null;
      },
      additionalSignupFields: [
        const UserFormField(
          keyName: 'username',
          displayName: 'اسم المستخدم',
          icon: Icon(Icons.person),
        ),
        const UserFormField(
          keyName: 'phone',
          displayName: 'رقم الهاتف (اختياري)',
          icon: Icon(Icons.phone),
          userType: LoginUserType.phone,
        ),
      ],
      loginProviders: [],
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:aqar_app/screens/tabs_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Duration get loginTime => const Duration(milliseconds: 2250);

  Future<String?> _authUser(LoginData data) async {
    debugPrint('Name: ${data.name}, Password: ${data.password}');
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: data.name,
        password: data.password,
      );
      debugPrint('[LoginScreen] _authUser: Sign in successful.');
    } on FirebaseAuthException catch (error) {
      return _handleAuthError(error);
    }
    return null;
  }

  Future<String?> _signupUser(SignupData data) async {
    debugPrint('Signup Name: ${data.name}, Password: ${data.password}');
    final username = data.additionalSignupData?['username']?.trim();
    if (username == null || username.isEmpty) {
      return 'الرجاء إدخال اسم المستخدم.';
    }
    try {
      final userCredentials = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: data.name!,
            password: data.password!,
          );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredentials.user!.uid)
          .set({
            'username': username,
            'email': data.name,
            'role': 'مشترك',
            'createdAt': Timestamp.now(),
          });
      debugPrint('[LoginScreen] _signupUser: User created successfully.');
    } on FirebaseAuthException catch (error) {
      return _handleAuthError(error);
    }
    return null;
  }

  Future<String?> _recoverPassword(String name) async {
    debugPrint('Name: $name');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: name);
    } on FirebaseAuthException catch (error) {
      return _handleAuthError(error);
    }
    return null;
  }

  String _handleAuthError(FirebaseAuthException error) {
    debugPrint('[LoginScreen] FirebaseAuthException: ${error.code}');
    switch (error.code) {
      case 'user-not-found':
        return 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة.';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح.';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مستخدم بالفعل.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً.';
      default:
        return 'حدث خطأ غير متوقع. الرجاء المحاولة مرة أخرى.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      title: 'عقار بلص',
      backgroundImage: const AssetImage(
        'images/aqar_gr_log.jpg',
      ), // تأكد من وجود هذا الملف
      logo: const AssetImage('assets/logo.png'), // تأكد من وجود هذا الملف
      onLogin: _authUser,
      onSignup: _signupUser,
      onRecoverPassword: _recoverPassword,
      onSubmitAnimationCompleted: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const TabsScreen()),
        );
      },
      userValidator: (value) {
        if (value == null || !value.contains('@')) {
          return 'البريد الإلكتروني غير صالح';
        }
        return null;
      },
      passwordValidator: (value) {
        if (value == null || value.length < 6) {
          return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
        }
        return null;
      },
      additionalSignupFields: [
        UserFormField(
          keyName: 'username',
          displayName: 'اسم المستخدم',
          icon: const Icon(Icons.person),
          userType: LoginUserType.name,
          fieldValidator: (value) {
            if (value == null || value.isEmpty || value.length < 4) {
              return 'يجب أن يكون 4 أحرف على الأقل';
            }
            return null;
          },
        ),
      ],
      messages: LoginMessages(
        userHint: 'البريد الإلكتروني',
        passwordHint: 'كلمة المرور',
        confirmPasswordHint: 'تأكيد كلمة المرور',
        loginButton: 'تسجيل الدخول',
        signupButton: 'إنشاء حساب',
        forgotPasswordButton: 'نسيت كلمة المرور؟',
        recoverPasswordButton: 'إرسال',
        goBackButton: 'رجوع',
        confirmPasswordError: 'كلمتا المرور غير متطابقتين!',
        recoverPasswordDescription:
            'سنرسل رابطًا إلى بريدك الإلكتروني لإعادة تعيين كلمة المرور.',
        recoverPasswordSuccess: 'تم إرسال الرابط بنجاح!',
        flushbarTitleSuccess: 'نجاح',
        flushbarTitleError: 'خطأ',
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:aqar_app/screens/tabs_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
    final username = data.additionalSignupData?['username']?.trim() ?? '';
    if (username.isEmpty) {
      return 'الرجاء إدخال اسم المستخدم.';
    }
    if (username.length < 4) {
      return 'اسم المستخدم يجب أن يكون 4 أحرف على الأقل.';
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
    } catch (e) {
      return 'حدث خطأ غير متوقع: $e';
    }
    return null;
  }

  Future<String?> _signInWithGoogle() async {
    try {
      debugPrint(
        '[LoginScreen] _signInWithGoogle: Starting Google sign-in process...',
      );
      // Trigger the Google sign-in flow.
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        debugPrint(
          '[LoginScreen] _signInWithGoogle: User cancelled the sign-in process.',
        );
        return 'تم إلغاء تسجيل الدخول.';
      }

      debugPrint(
        '[LoginScreen] _signInWithGoogle: Google user obtained: ${googleUser.email}',
      );

      // Obtain the auth details from the request.
      debugPrint(
        '[LoginScreen] _signInWithGoogle: Obtaining Google auth details...',
      );
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential.
      debugPrint(
        '[LoginScreen] _signInWithGoogle: Creating Firebase credential...',
      );
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential.
      debugPrint(
        '[LoginScreen] _signInWithGoogle: Signing in to Firebase with credential...',
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      debugPrint(
        '[LoginScreen] _signInWithGoogle: Firebase sign-in successful. User UID: ${userCredential.user?.uid}',
      );

      // If it's a new user, create a document in Firestore.
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        debugPrint(
          '[LoginScreen] _signInWithGoogle: New user detected. Creating Firestore document...',
        );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'username': userCredential.user!.displayName ?? 'مستخدم جوجل',
              'email': userCredential.user!.email,
              'role': 'مشترك',
              'createdAt': Timestamp.now(),
            });
        debugPrint(
          '[LoginScreen] _signInWithGoogle: Firestore document created for new user.',
        );
      }

      debugPrint(
        '[LoginScreen] _signInWithGoogle: Process completed successfully.',
      );
      // <<<< أضف هذا السطر هنا >>>>
      // ننتظر قليلاً للسماح للتطبيق باستعادة واجهته بعد العودة من شاشة جوجل
      await Future.delayed(const Duration(milliseconds: 600));

      return null; // Success
    } on FirebaseAuthException catch (error) {
      debugPrint(
        '[LoginScreen] _signInWithGoogle: FirebaseAuthException: ${error.code} - ${error.message}',
      );
      return _handleAuthError(error);
    } catch (e) {
      debugPrint(
        '[LoginScreen] _signInWithGoogle: An unexpected error occurred: $e',
      );
      return 'حدث خطأ غير متوقع أثناء تسجيل الدخول: $e';
    }
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
          fieldValidator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال اسم المستخدم';
            }
            if (value.length < 4) {
              return 'يجب أن يكون 4 أحرف على الأقل';
            }
            return null;
          },
        ),
      ],
      loginProviders: <LoginProvider>[
        LoginProvider(
          icon: FontAwesomeIcons.google,
          label: 'Google',
          callback: _signInWithGoogle,
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

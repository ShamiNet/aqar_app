// استيراد مكتبة المواد من فلاتر
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// صفحة تسجيل الدخول وإنشاء حساب
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // مفتاح للتحكم في الفورم والتحقق من صحة المدخلات
  final _formKey = GlobalKey<FormState>();

  // متغيرات لتخزين مدخلات المستخدم
  var _enteredEmail = '';
  var _enteredPassword = '';
  var _enteredUsername = '';

  // متغير لتحديد ما إذا كنا في وضع تسجيل الدخول أم إنشاء حساب
  var _isLoginMode = true;

  // متغير للتحكم في إظهار مؤشر التحميل
  var _isLoading = false;

  // دالة لتنفيذ عملية تسجيل الدخول أو إنشاء الحساب
  void _submit() async {
    // 1. التحقق من صحة المدخلات في الفورم
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      return; // إذا كانت المدخلات غير صحيحة، لا تكمل العملية
    }

    // 2. حفظ المدخلات
    _formKey.currentState!.save();

    try {
      // 3. إظهار مؤشر التحميل
      setState(() {
        _isLoading = true;
      });

      if (_isLoginMode) {
        // 4. في وضع تسجيل الدخول
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _enteredEmail,
          password: _enteredPassword,
        );
      } else {
        // 5. في وضع إنشاء حساب جديد
        final userCredentials = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _enteredEmail,
              password: _enteredPassword,
            );

        // 6. حفظ بيانات المستخدم الإضافية في Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredentials.user!.uid)
            .set({
              'username': _enteredUsername,
              'email': _enteredEmail,
              'role': 'مشترك', // نعطي دور "مشترك" كقيمة افتراضية
              'createdAt': Timestamp.now(), // لحفظ تاريخ إنشاء الحساب
            });
      }
      // عند نجاح العملية، سيقوم الـ AuthGate بنقلنا تلقائياً إلى الصفحة الرئيسية
    } on FirebaseAuthException catch (error) {
      // في حال حدوث خطأ من Firebase
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? 'فشل المصادقة.')));
      // إخفاء مؤشر التحميل
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // حقل اسم المستخدم (يظهر فقط في وضع إنشاء حساب)
                if (!_isLoginMode)
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                    ),
                    enableSuggestions: false,
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          value.trim().length < 4) {
                        return 'الرجاء إدخال 4 أحرف على الأقل.';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _enteredUsername = value!;
                    },
                  ),
                // حقل البريد الإلكتروني
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty ||
                        !value.contains('@')) {
                      return 'الرجاء إدخال بريد إلكتروني صحيح.';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _enteredEmail = value!;
                  },
                ),
                const SizedBox(height: 12),
                // حقل كلمة المرور
                TextFormField(
                  decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  obscureText: true, // لإخفاء كلمة المرور
                  validator: (value) {
                    if (value == null || value.trim().length < 6) {
                      return 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _enteredPassword = value!;
                  },
                ),
                const SizedBox(height: 20),
                // زر تسجيل الدخول / إنشاء حساب
                if (_isLoading) const CircularProgressIndicator(),
                if (!_isLoading)
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(_isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب'),
                  ),
                const SizedBox(height: 12),
                // زر التبديل بين الوضعين
                if (!_isLoading)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                      });
                    },
                    child: Text(
                      _isLoginMode
                          ? 'ليس لديك حساب؟ أنشئ واحداً'
                          : 'لديك حساب بالفعل؟ سجل الدخول',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

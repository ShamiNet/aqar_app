import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  var _enteredEmail = '';
  var _enteredPassword = '';
  var _enteredUsername = '';
  var _isLoginMode = true;
  var _isLoading = false;

  void _submit() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      return;
    }
    _formKey.currentState!.save();

    try {
      setState(() {
        _isLoading = true;
      });

      if (_isLoginMode) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _enteredEmail,
          password: _enteredPassword,
        );
      } else {
        final userCredentials = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _enteredEmail,
              password: _enteredPassword,
            );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredentials.user!.uid)
            .set({
              'username': _enteredUsername,
              'email': _enteredEmail,
              'role': 'مشترك',
              'createdAt': Timestamp.now(),
            });
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? 'فشل المصادقة.')));
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
                TextFormField(
                  decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  obscureText: true,
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
                if (_isLoading) const CircularProgressIndicator(),
                if (!_isLoading)
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(_isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب'),
                  ),
                const SizedBox(height: 12),
                if (!_isLoading)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                      });
                    },
                    child: Text(
                      _isLoginMode
                          ? 'إنشاء حساب جديد'
                          : 'لديك حساب؟ تسجيل الدخول',
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

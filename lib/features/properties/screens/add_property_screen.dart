// استيراد مكتبات فايربيز والمواد من فلاتر
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// شاشة لإضافة عقار جديد
class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  var _enteredTitle = '';
  var _enteredPrice = 0.0;
  var _isSaving = false;

  // دالة لحفظ بيانات العقار في Firestore
  void _saveProperty() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isSaving = true;
      });

      try {
        // الحصول على المستخدم الحالي
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          // يمكنك التعامل مع حالة عدم وجود مستخدم مسجل دخوله هنا
          return;
        }

        // إضافة مستند جديد إلى collection 'properties'
        await FirebaseFirestore.instance.collection('properties').add({
          'title': _enteredTitle,
          'price': _enteredPrice,
          'userId': user.uid, // ربط العقار بالمستخدم الذي أضافه
          'createdAt': Timestamp.now(), // إضافة تاريخ الإنشاء
        });

        // عرض رسالة تأكيد والعودة للشاشة السابقة
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم حفظ العقار بنجاح!')));
          Navigator.of(context).pop();
        }
      } catch (e) {
        // التعامل مع الأخطاء
        setState(() {
          _isSaving = false;
        });
        // يمكنك عرض رسالة خطأ هنا
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عقار جديد')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'عنوان الإعلان'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال عنوان.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _enteredTitle = value!;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'السعر'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'الرجاء إدخال سعر صحيح.';
                  }
                  return null;
                },
                onSaved: (value) {
                  _enteredPrice = double.parse(value!);
                },
              ),
              const SizedBox(height: 20),
              if (_isSaving)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _saveProperty,
                  child: const Text('حفظ العقار'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

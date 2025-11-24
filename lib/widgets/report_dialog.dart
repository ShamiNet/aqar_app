import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportDialog extends StatefulWidget {
  final String propertyId;

  const ReportDialog({super.key, required this.propertyId});

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final _detailsController = TextEditingController();
  String? _selectedReason;
  bool _isSubmitting = false;

  // قائمة أسباب الإبلاغ
  final List<String> _reasons = [
    'احتيال أو نصب',
    'معلومات خاطئة أو مضللة',
    'العقار مباع أو غير متاح',
    'صور غير لائقة أو مسيئة',
    'سعر غير منطقي',
    'أخرى',
  ];

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار سبب للإبلاغ.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      // تجهيز بيانات البلاغ
      final reportData = {
        'propertyId': widget.propertyId,
        'reporterId': user?.uid ?? 'anonymous', // يمكن السماح للمجهولين أو لا
        'reason': _selectedReason,
        'details': _detailsController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // حالة البلاغ: قيد المراجعة
      };

      // حفظ البلاغ في مجموعة جديدة اسمها reports
      await FirebaseFirestore.instance.collection('reports').add(reportData);

      if (!mounted) return;
      Navigator.of(context).pop(); // إغلاق النافذة

      // رسالة شكر للمستخدم
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
          content: const Text(
            'شكراً لك!\nتم استلام بلاغك وسنوم بمراجعته قريباً للحفاظ على جودة التطبيق.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء الإرسال.')));
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.report_problem_rounded, color: Colors.red.shade700),
          const SizedBox(width: 8),
          const Text('إبلاغ عن مخالفة', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ساعدنا في الحفاظ على بيئة آمنة. لماذا تريد الإبلاغ عن هذا العقار؟',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // قائمة اختيار السبب
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'السبب',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
              value: _selectedReason,
              items: _reasons.map((reason) {
                return DropdownMenuItem(
                  value: reason,
                  child: Text(reason, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedReason = val),
            ),

            const SizedBox(height: 16),

            // حقل التفاصيل الإضافية
            TextField(
              controller: _detailsController,
              decoration: InputDecoration(
                labelText: 'تفاصيل إضافية (اختياري)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
        if (_isSubmitting)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          ElevatedButton.icon(
            onPressed: _submitReport,
            icon: const Icon(Icons.flag),
            label: const Text('إرسال البلاغ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
            ),
          ),
      ],
    );
  }
}

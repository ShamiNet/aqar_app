import 'package:aqar_app/services/api_service.dart'; // ✅
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      final reportData = {
        'propertyId': widget.propertyId,
        'reporterId': userId ?? 'anonymous',
        'reason': _selectedReason,
        'details': _detailsController.text.trim(),
        'status': 'pending',
      };

      // ✅ الإرسال للسيرفر
      await ApiService.submitReport(reportData);

      if (!mounted) return;
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
          content: const Text(
            'شكراً لك!\nتم استلام بلاغك.',
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إبلاغ عن مخالفة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'السبب',
                border: OutlineInputBorder(),
              ),
              value: _selectedReason,
              items: _reasons
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedReason = val),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _detailsController,
              decoration: const InputDecoration(
                labelText: 'تفاصيل إضافية',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        if (_isSubmitting)
          const CircularProgressIndicator()
        else
          ElevatedButton(onPressed: _submitReport, child: const Text('إرسال')),
      ],
    );
  }
}

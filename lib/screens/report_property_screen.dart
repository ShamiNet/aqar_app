import 'package:flutter/material.dart';
import 'package:aqar_app/services/api_service.dart';

class ReportPropertyScreen extends StatefulWidget {
  final String propertyId;
  final String propertyTitle;

  const ReportPropertyScreen({
    Key? key,
    required this.propertyId,
    required this.propertyTitle,
  }) : super(key: key);

  @override
  State<ReportPropertyScreen> createState() => _ReportPropertyScreenState();
}

class _ReportPropertyScreenState extends State<ReportPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedReason = 'غيــر دقيق في الوصف';
  bool _isSubmitting = false;

  final List<String> _reportReasons = [
    'غيــر دقيق في الوصف',
    'صور مضللة',
    'سعر غير واقعي',
    'معلومات مزيفة',
    'محتوى مسيء',
    'عقار مكرر',
    'محتوى غير قانوني',
    'أخرى',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      print('📤 [ReportProperty] Submitting report...');
      print('💾 [ReportProperty] Report Data:');
      print('   - propertyId: ${widget.propertyId}');
      print('   - propertyTitle: ${widget.propertyTitle}');
      print('   - reason: $_selectedReason');
      print('   - description: ${_descriptionController.text}');

      await ApiService.submitReport({
        'propertyId': widget.propertyId,
        'propertyTitle': widget.propertyTitle,
        'reason': _selectedReason,
        'description': _descriptionController.text,
      });

      if (!mounted) return;

      print('✅ [ReportProperty] Report submitted successfully');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال الإبلاغ بنجاح. شكراً لك على المساعدة'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      print('❌ [ReportProperty] Error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إبلاغ عن عقار'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بطاقة المعلومات
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'العقار:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.propertyTitle,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'معرف العقار: ${widget.propertyId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // سبب الإبلاغ
              Text(
                'سبب الإبلاغ *',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                items: _reportReasons
                    .map(
                      (reason) =>
                          DropdownMenuItem(value: reason, child: Text(reason)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedReason = value);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'اختر سبب الإبلاغ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.flag),
                ),
                validator: (value) => value == null ? 'يجب اختيار السبب' : null,
              ),
              const SizedBox(height: 20),

              // الوصف التفصيلي
              Text(
                'التفاصيل الإضافية *',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                minLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'الرجاء إدخال تفاصيل الإبلاغ...\nتأكد من توضيح المشكلة بشكل دقيق',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يجب إدخال التفاصيل';
                  }
                  if (value.length < 10) {
                    return 'يجب أن تكون التفاصيل على الأقل 10 أحرف';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // تنبيه مهم
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ تنبيه مهم',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الإبلاغات الكاذبة أو المسيئة قد تؤدي إلى إغلاق حسابك. يرجى الإبلاغ فقط عن العقارات المخالفة بصدق.',
                      style: TextStyle(color: Colors.orange[700], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // زر الإرسال
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting ? 'جاري الإرسال...' : 'إرسال الإبلاغ',
                  ),
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.red[600],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // زر الإلغاء
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('إلغاء'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

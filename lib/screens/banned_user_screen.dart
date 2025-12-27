import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BannedUserScreen extends StatelessWidget {
  final String? email;
  final String? reason;

  const BannedUserScreen({super.key, this.email, this.reason});

  // فتح البريد الإلكتروني للإدارة
  Future<void> _contactAdmin(BuildContext context) async {
    final adminEmail = 'shami313p@gmail.com';
    final subject = 'استفسار حول حظر الحساب';
    final body =
        '''
السلام عليكم ورحمة الله وبركاته

أود الاستفسار حول حظر حسابي:
البريد الإلكتروني: $email

أتمنى مراجعة الحالة والاعتراض على قرار الحظر إذا كان هناك خطأ.

شكراً لتعاونكم
    ''';

    final mailtoLink =
        'mailto:$adminEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';

    try {
      if (await canLaunchUrl(Uri.parse(mailtoLink))) {
        await launchUrl(Uri.parse(mailtoLink));
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('البريد الإلكتروني للإدارة: $adminEmail'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching mail: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('البريد الإلكتروني للإدارة: $adminEmail'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // فتح WhatsApp للتواصل مع الإدارة
    Future<void> _contactAdminWhatsApp(BuildContext context) async {
      final adminPhone = '963951727833'; // استبدل برقم الإدارة الفعلي
      final message = Uri.encodeComponent(
        'السلام عليكم، أود الاستفسار حول حظر حسابي في تطبيق عقار بلص. البريد: $email',
      );
      final whatsappUrl = 'https://wa.me/$adminPhone?text=$message';

      try {
        if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
          await launchUrl(Uri.parse(whatsappUrl));
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('يرجى تثبيت تطبيق WhatsApp أولاً'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error launching WhatsApp: $e');
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ⛔ أيقونة الحظر
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.block,
                      size: 60,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // العنوان الرئيسي
                  Text(
                    'تم حظر حسابك',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // الوصف
                  Text(
                    'عذراً، تم حظر حسابك من قبل إدارة التطبيق',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // معلومات إضافية
                  if (email != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'البريد الإلكتروني: $email',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),

                  // الأسباب المحتملة
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الأسباب المحتملة:',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• سلوك غير مناسب في التطبيق\n'
                          '• محتوى مخالف لشروط الاستخدام\n'
                          '• تقارير من مستخدمين آخرين\n'
                          '• انتهاك أمان البيانات\n'
                          '• استخدام غير قانوني للتطبيق',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.orange.shade900,
                                height: 1.8,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // الأزرار
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // زر التواصل مع الإدارة
                      ElevatedButton.icon(
                        onPressed: () => _contactAdmin(context),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text(
                          'التواصل مع الإدارة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // زر الاعتراض على الحظر
                      OutlinedButton.icon(
                        onPressed: () => _contactAdminWhatsApp(context),
                        icon: const Icon(Icons.chat),
                        label: const Text(
                          'التواصل عبر WhatsApp',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade700),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ملاحظة نهائية
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'إذا كنت تعتقد أن هذا خطأ، يرجى التواصل مع فريق الدعم فوراً. سيقومون بمراجعة حالتك في أسرع وقت.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

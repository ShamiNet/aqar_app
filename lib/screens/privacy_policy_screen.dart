import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // لتأثيرات الحركة الجذابة (اختياري، يمكن حذفه إذا لم تكن المكتبة مضافة)

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // --- رأس الصفحة الجذاب ---
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'سياسة الخصوصية',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.privacy_tip_outlined,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            backgroundColor: primaryColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // --- محتوى السياسة ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'آخر تحديث: 30 ديسمبر 2025',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'نحن في "عقار بلس" نأخذ خصوصيتك على محمل الجد. توضح هذه السياسة كيف نجمع ونستخدم ونحمي معلوماتك الشخصية عند استخدامك لتطبيقنا.',
                    style: TextStyle(fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 24),

                  // --- الأقسام ---
                  _buildSection(
                    context,
                    title: 'المعلومات التي نجمعها',
                    content:
                        'نقوم بجمع المعلومات التي تقدمها لنا مباشرة، مثل:\n'
                        '• المعلومات الشخصية (الاسم، البريد الإلكتروني، رقم الهاتف).\n'
                        '• تفاصيل العقارات التي تعلن عنها.\n'
                        '• الصور والملفات التي تقوم برفعها.',
                    icon: Icons.data_usage_rounded,
                    color: Colors.blue,
                    delay: 100,
                  ),
                  _buildSection(
                    context,
                    title: 'كيف نستخدم معلوماتك',
                    content:
                        'نستخدم المعلومات لـ:\n'
                        '• تقديم خدماتنا وتحسينها.\n'
                        '• التواصل معك بخصوص حسابك أو عقاراتك.\n'
                        '• ضمان أمان وسلامة المنصة ومكافحة الاحتيال.',
                    icon: Icons.manage_accounts_rounded,
                    color: Colors.orange,
                    delay: 200,
                  ),
                  _buildSection(
                    context,
                    title: 'أمان البيانات',
                    content:
                        'نحن نطبق إجراءات أمان تقنية وتنظيمية مناسبة لحماية بياناتك من الوصول غير المصرح به أو التغيير أو الإفصاح أو الإتلاف.',
                    icon: Icons.security_rounded,
                    color: Colors.green,
                    delay: 300,
                  ),
                  _buildSection(
                    context,
                    title: 'مشاركة البيانات',
                    content:
                        'لا نقوم ببيع بياناتك الشخصية لأطراف ثالثة. قد نشارك بيانات محدودة مع مقدمي الخدمات الذين يساعدوننا في تشغيل التطبيق (مثل خدمات الاستضافة).',
                    icon: Icons.share_rounded,
                    color: Colors.purple,
                    delay: 400,
                  ),
                  _buildSection(
                    context,
                    title: 'حقوقك',
                    content:
                        'لديك الحق في:\n'
                        '• الوصول إلى بياناتك الشخصية.\n'
                        '• طلب تصحيح أو حذف بياناتك.\n'
                        '• الاعتراض على معالجة بياناتك.',
                    icon: Icons.gavel_rounded,
                    color: Colors.redAccent,
                    delay: 500,
                  ),
                  _buildSection(
                    context,
                    title: 'اتصل بنا',
                    content:
                        'إذا كان لديك أي أسئلة حول سياسة الخصوصية هذه، يرجى التواصل معنا عبر:\n'
                        'shami313p@gmail.com',
                    icon: Icons.contact_support_rounded,
                    color: Colors.teal,
                    delay: 600,
                  ),

                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'جميع الحقوق محفوظة © عقار بلس 2025',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    required int delay,
  }) {
    // استخدام Animate لإضافة حركة بسيطة (إذا لم تكن تستخدم المكتبة، احذف .animate(...) والنهاية)
    return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        )
        // يمكنك حذف الأسطر التالية إذا لم تكن تستخدم flutter_animate
        .animate()
        .fadeIn(duration: 600.ms, delay: delay.ms)
        .slideY(begin: 0.2, end: 0);
  }
}

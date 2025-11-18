import 'package:flutter/material.dart';

class MapLegendScreen extends StatelessWidget {
  const MapLegendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('دليل الخريطة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'دلالة الألوان',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              context,
              Icon(Icons.circle, color: Colors.red.shade700, size: 28),
              'عقارات للبيع',
              'العلامات باللون الأحمر تمثل العقارات المتاحة للبيع.',
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              context,
              Icon(Icons.circle, color: Colors.blue.shade700, size: 28),
              'عقارات للإيجار',
              'العلامات باللون الأزرق تمثل العقارات المتاحة للإيجار.',
            ),
            const Divider(height: 40, thickness: 1),
            Text(
              'دلالة الأيقونات',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              context,
              const Icon(Icons.house_rounded, size: 28),
              'بيت',
              'يمثل عقار من نوع "بيت".',
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              context,
              const Icon(Icons.villa_rounded, size: 28),
              'فيلا',
              'يمثل عقار من نوع "فيلا".',
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              context,
              const Icon(Icons.apartment_rounded, size: 28),
              'بناية',
              'يمثل عقار من نوع "بناية".',
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              context,
              const Icon(Icons.landscape_rounded, size: 28),
              'أرض',
              'يمثل قطعة "أرض".',
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              context,
              const Icon(Icons.store_rounded, size: 28),
              'دكان',
              'يمثل عقار من نوع "دكان".',
            ),
            const Divider(height: 40, thickness: 1),
            Text(
              'كيفية الاستخدام',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              context,
              const Icon(Icons.touch_app_rounded, size: 28),
              'عرض المعلومات',
              'اضغط على أي علامة على الخريطة لعرض معلومات سريعة عن العقار.',
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              context,
              const Icon(Icons.directions_rounded, size: 28),
              'رسم المسار',
              'من نافذة المعلومات، اضغط على "رسم المسار" لرسم خط بين موقعك الحالي وموقع العقار.',
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              context,
              const Icon(Icons.info_rounded, size: 28),
              'عرض التفاصيل',
              'اضغط على "التفاصيل" للانتقال إلى صفحة العقار الكاملة.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    Widget icon,
    String title,
    String subtitle,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.1),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: icon,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
}

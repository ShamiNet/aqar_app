import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'property_details_screen.dart'; // تأكد من المسار

class ReportDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const ReportDetailsScreen({Key? key, required this.report}) : super(key: key);

  @override
  _ReportDetailsScreenState createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  bool _isLoadingProperty = true;
  Map<String, dynamic>? _propertyData;
  bool _isProcessing = false;

  // 🎨 نظام الألوان المحسّن
  static const Color primaryColor = Color(0xFF2563EB); // أزرق داكن
  static const Color successColor = Color(0xFF059669); // أخضر زمردي
  static const Color warningColor = Color(0xFFD97706); // برتقالي دافئ
  static const Color dangerColor = Color(0xFFDC2626); // أحمر قوي
  static const Color lightBg = Color(0xFFF3F4F6); // خلفية رمادية فاتحة
  static const Color cardBg = Color(0xFFFFFFFF); // خلفية بيضاء للكروت
  static const Color darkText = Color(0xFF111827); // نص أسود داكن
  static const Color greyText = Color(0xFF6B7280); // نص رمادي متوسط
  static const Color borderColor = Color(0xFFD1D5DB); // حدود رمادية

  @override
  void initState() {
    super.initState();
    _fetchReportedProperty();
  }

  // جلب تفاصيل العقار المبلغ عنه
  Future<void> _fetchReportedProperty() async {
    final propertyId = widget.report['propertyId'];
    if (propertyId != null) {
      final data = await ApiService.fetchPropertyDetails(propertyId);
      if (mounted) {
        setState(() {
          _propertyData = data;
          _isLoadingProperty = false;
        });
      }
    } else {
      setState(() => _isLoadingProperty = false);
    }
  }

  // حذف البلاغ
  Future<void> _deleteReport() async {
    final confirm = await _showConfirmDialog(
      'حذف البلاغ',
      'هل أنت متأكد من حذف هذا البلاغ؟',
    );
    if (!confirm) return;

    setState(() => _isProcessing = true);
    final success = await ApiService.deleteReport(widget.report['id']);
    setState(() => _isProcessing = false);

    if (success && mounted) {
      Navigator.pop(context, true); // العودة وتحديث القائمة
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف البلاغ')));
    }
  }

  // حذف العقار المخالف
  Future<void> _deleteProperty() async {
    final confirm = await _showConfirmDialog(
      'حذف العقار',
      'تحذير: سيتم حذف العقار نهائياً. هل أنت متأكد؟',
    );
    if (!confirm) return;

    setState(() => _isProcessing = true);
    final success = await ApiService.deletePropertyAdmin(
      widget.report['propertyId'],
    );

    // بعد حذف العقار، نغير حالة البلاغ لـ "تم الحل"
    if (success) {
      await ApiService.updateReportStatus(widget.report['id'], 'resolved');
    }

    setState(() => _isProcessing = false);

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف العقار بنجاح')));
      Navigator.pop(context, true);
    }
  }

  // حظر المستخدم المبلغ (إذا كان بلاغ كيدي)
  Future<void> _banReporter() async {
    final reporterId = widget.report['reporterId'];
    if (reporterId == null) return;

    final confirm = await _showConfirmDialog(
      'حظر المستخدم',
      'هل تريد حظر صاحب هذا البلاغ؟',
    );
    if (!confirm) return;

    setState(() => _isProcessing = true);
    await ApiService.toggleUserBan(reporterId, true);
    setState(() => _isProcessing = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حظر المستخدم')));
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('نعم', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'لم يتم تحديده';
    try {
      String dateStr = timestamp.toString();
      // إذا كان التاريخ كاملاً مثل "2025-12-30T10:30:00"
      if (dateStr.contains('T')) {
        return dateStr.substring(0, 10);
      }
      // إذا كان التاريخ بصيغة أخرى
      return dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    } catch (e) {
      return 'تاريخ غير صحيح';
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final isResolved = report['status'] == 'resolved';

    // محاولة الحصول على التاريخ من عدة مصادر
    final timestamp =
        report['timestamp'] ??
        report['createdAt'] ??
        report['created_at'] ??
        report['date'] ??
        DateTime.now().toString();
    final reportDate = _formatDate(timestamp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل البلاغ'),
        backgroundColor: isResolved ? successColor : dangerColor,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: lightBg,
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. كارت حالة البلاغ
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isResolved
                            ? [successColor, successColor.withOpacity(0.7)]
                            : [warningColor, dangerColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isResolved ? successColor : dangerColor)
                              .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isResolved
                                  ? Icons.check_circle
                                  : Icons.warning_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isResolved
                                      ? 'تم حل البلاغ'
                                      : 'بلاغ قيد المراجعة',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'تاريخ البلاغ: $reportDate',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. تفاصيل البلاغ
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 12),
                    child: Text(
                      '📝 تفاصيل الشكوى',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Card(
                    color: cardBg,
                    elevation: 1,
                    shadowColor: Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: borderColor, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            'السبب:',
                            report['reason'] ?? 'غير محدد',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: borderColor, height: 1),
                          ),
                          _buildInfoRow(
                            'التفاصيل:',
                            report['details'] ?? 'لا يوجد تفاصيل إضافية',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. معلومات المبلغ
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Text(
                      '👤 المُبَلِّغ (صاحب الشكوى)',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Card(
                    color: cardBg,
                    elevation: 1,
                    shadowColor: Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: borderColor, width: 1),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: primaryColor.withOpacity(0.1),
                        backgroundImage: report['reporterImage'] != null
                            ? NetworkImage(report['reporterImage'])
                            : null,
                        child: report['reporterImage'] == null
                            ? Icon(Icons.person, color: primaryColor, size: 28)
                            : null,
                      ),
                      title: Text(
                        report['reporterName'] ?? 'مجهول',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: darkText,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          report['reporterEmail'] ?? '',
                          style: TextStyle(color: greyText, fontSize: 14),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.block_rounded,
                          color: dangerColor,
                        ),
                        onPressed: _banReporter,
                        tooltip: 'حظر هذا المستخدم',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. العقار المبلغ عنه
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Text(
                      '🏠 العقار المُبَلَّغ عنه',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (_isLoadingProperty)
                    const Center(child: CircularProgressIndicator())
                  else if (_propertyData == null)
                    Card(
                      color: cardBg,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'لم يتم العثور على العقار (ربما تم حذفه)',
                            style: TextStyle(color: greyText, fontSize: 15),
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      color: cardBg,
                      elevation: 1,
                      shadowColor: Colors.black.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: borderColor, width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          if (_propertyData!['images'] != null &&
                              (_propertyData!['images'] as List).isNotEmpty)
                            Image.network(
                              _propertyData!['images'][0],
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ListTile(
                            title: Text(
                              _propertyData!['title'] ?? 'بدون عنوان',
                            ),
                            subtitle: Text(
                              '${_propertyData!['price'] ?? 0} د.ع',
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PropertyDetailsScreen(
                                    propertyId: _propertyData!['id'] ?? '',
                                  ),
                                ),
                              );
                            },
                          ),
                          // أزرار التحكم بالعقار
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.delete_forever,
                                      color: Colors.white,
                                    ),
                                    label: const Text('حذف العقار'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: _deleteProperty,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),

                  // 5. أزرار التحكم النهائية
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('تمييز كمحلول'),
                          onPressed: () async {
                            setState(() => _isProcessing = true);
                            await ApiService.updateReportStatus(
                              report['id'],
                              'resolved',
                            );
                            setState(() => _isProcessing = false);
                            Navigator.pop(context, true);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          label: const Text(
                            'حذف البلاغ',
                            style: TextStyle(color: Colors.grey),
                          ),
                          onPressed: _deleteReport,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: greyText,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: darkText,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

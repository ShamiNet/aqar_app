import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAppControlScreen extends StatefulWidget {
  const AdminAppControlScreen({super.key});

  @override
  State<AdminAppControlScreen> createState() => _AdminAppControlScreenState();
}

class _AdminAppControlScreenState extends State<AdminAppControlScreen> {
  final _minVersionController = TextEditingController();
  final _maintenanceMsgController = TextEditingController();
  bool _isMaintenanceMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _minVersionController.text = data['min_version'] ?? '1.0.0';
          _isMaintenanceMode = data['maintenance_mode'] ?? false;
          _maintenanceMsgController.text =
              data['maintenance_message'] ??
              'التطبيق مغلق حالياً للصيانة، يرجى المحاولة لاحقاً.';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .set({
            'min_version': _minVersionController.text.trim(),
            'maintenance_mode': _isMaintenanceMode,
            'maintenance_message': _maintenanceMsgController.text.trim(),
            'last_updated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث إعدادات التطبيق بنجاح ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحكم في التطبيق ⚙️')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCard(
                  title: 'إصدار التطبيق الإجباري',
                  icon: Icons.system_update,
                  color: Colors.blue,
                  child: Column(
                    children: [
                      const Text(
                        'أي مستخدم لديه إصدار أقل من هذا الرقم سيتم إجباره على التحديث.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _minVersionController,
                        decoration: const InputDecoration(
                          labelText: 'رقم الإصدار (مثلاً 1.0.2)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildCard(
                  title: 'وضع الصيانة (Maintenance Mode)',
                  icon: Icons.construction,
                  color: Colors.orange,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('تفعيل وضع الصيانة'),
                        subtitle: const Text(
                          'سيتم منع دخول جميع المستخدمين ما عدا الأدمن.',
                        ),
                        value: _isMaintenanceMode,
                        activeColor: Colors.orange,
                        onChanged: (val) {
                          setState(() => _isMaintenanceMode = val);
                        },
                      ),
                      if (_isMaintenanceMode)
                        TextField(
                          controller: _maintenanceMsgController,
                          decoration: const InputDecoration(
                            labelText: 'رسالة الصيانة',
                            border: OutlineInputBorder(),
                            helperText:
                                'الرسالة التي ستظهر للمستخدمين عند محاولة الدخول',
                          ),
                          maxLines: 2,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ الإعدادات الجديدة'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

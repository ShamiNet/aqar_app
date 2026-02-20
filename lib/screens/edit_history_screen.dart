import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class EditHistoryScreen extends StatelessWidget {
  final List<dynamic> editHistory;

  const EditHistoryScreen({super.key, required this.editHistory});

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return intl.DateFormat('yyyy-MM-dd HH:mm', 'ar').format(date);
    } catch (e) {
      return 'تاريخ غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ترتيب السجل ليكون الأحدث في الأعلى
    final reversedHistory = editHistory.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('سجل تعديلات العقار')),
      body: reversedHistory.isEmpty
          ? const Center(child: Text('لم يتم تعديل هذا العقار من قبل.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reversedHistory.length,
              itemBuilder: (context, index) {
                final entry = reversedHistory[index];
                final editorName = entry['editorName'] ?? 'مجهول';
                final role = entry['role'] ?? 'صاحب العقار';
                final timestamp = entry['timestamp'];

                final isAdmin = role == 'إدارة التطبيق';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAdmin
                          ? Colors.blue.shade100
                          : Colors.green.shade100,
                      child: Icon(
                        isAdmin ? Icons.admin_panel_settings : Icons.person,
                        color: isAdmin ? Colors.blue : Colors.green,
                      ),
                    ),
                    title: Text(
                      'تم التعديل بواسطة: $editorName',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'الصلاحية: $role',
                          style: TextStyle(
                            color: isAdmin ? Colors.blue : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(timestamp),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

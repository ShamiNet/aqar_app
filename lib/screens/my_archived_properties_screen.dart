import 'package:aqar_app/screens/archived_property_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyArchivedPropertiesScreen extends StatefulWidget {
  const MyArchivedPropertiesScreen({super.key});

  @override
  State<MyArchivedPropertiesScreen> createState() =>
      _MyArchivedPropertiesScreenState();
}

class _MyArchivedPropertiesScreenState
    extends State<MyArchivedPropertiesScreen> {
  final _user = FirebaseAuth.instance.currentUser;

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _restoreProperty(String docId, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة عقار'),
        content: Text(
          'هل أنت متأكد من استعادة "${data['title'] ?? 'عقار'}"؟ سيتم إعادته للقائمة العامة وحذفه من الأرشيف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // إزالة البيانات الخاصة بالأرشفة قبل الاستعادة
      data.remove('originalId');
      data.remove('archivedAt');
      data.remove('archiveReason');
      data.remove('archivedByUserId');
      data.remove('archivedByUserName');

      // إضافة العقار مجدداً لمجموعة properties
      await FirebaseFirestore.instance.collection('properties').add(data);
      // حذف العقار من الأرشيف
      await FirebaseFirestore.instance
          .collection('archived_properties')
          .doc(docId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم استعادة العقار بنجاح.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    }
  }

  Future<void> _permanentlyDelete(String docId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف نهائي'),
        content: Text('هل أنت متأكد من حذف "$title" نهائياً من الأرشيف؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('archived_properties')
          .doc(docId)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف العقار نهائياً من الأرشيف.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('أرشيفي')),
        body: const Center(child: Text('يرجى تسجيل الدخول لعرض أرشيفك.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('عقاراتي المؤرشفة')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('archived_properties')
            .where('userId', isEqualTo: _user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text('الأرشيف فارغ حالياً.'),
                  Text(
                    'العقارات التي تبيعها أو تؤجرها ستظهر هنا.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final archivedDocs = snapshot.data!.docs;
          // ترتيب النتائج يدوياً داخل التطبيق لضمان عرض الأحدث أولاً
          archivedDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>?;
            final bData = b.data() as Map<String, dynamic>?;
            final aTimestamp = aData?['archivedAt'] as Timestamp?;
            final bTimestamp = bData?['archivedAt'] as Timestamp?;
            return (bTimestamp?.compareTo(aTimestamp ?? Timestamp(0, 0)) ?? 0);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: archivedDocs.length,
            itemBuilder: (ctx, index) {
              final doc = archivedDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'بدون عنوان';
              final imageUrl = (data['imageUrls'] as List?)?.firstOrNull;
              final reason = data['archiveReason'] ?? 'سبب غير معروف';
              final timestamp = data['archivedAt'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ArchivedPropertyDetailsScreen(propertyData: data),
                      ),
                    );
                  },
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[300],
                            child: const Icon(Icons.house_siding),
                          ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'السبب: $reason\nتاريخ الأرشفة: ${_formatTimestamp(timestamp)}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'restore') {
                        _restoreProperty(doc.id, data);
                      } else if (value == 'delete') {
                        _permanentlyDelete(doc.id, title);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'restore',
                        child: ListTile(
                          leading: Icon(Icons.restore_from_trash),
                          title: Text('استعادة'),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          title: Text(
                            'حذف نهائي',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

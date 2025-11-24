import 'package:aqar_app/screens/archived_property_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyArchivedPropertiesScreen extends StatefulWidget {
  const MyArchivedPropertiesScreen({super.key});

  @override
  State<MyArchivedPropertiesScreen> createState() =>
      _MyArchivedPropertiesScreenState();
}

class _MyArchivedPropertiesScreenState
    extends State<MyArchivedPropertiesScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _restoreProperty(String docId, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة العقار'),
        content: Text(
          'هل أنت متأكد من استعادة "${data['title'] ?? 'عقار'}"؟ سيتم إعادته لقائمة عقاراتك المعروضة.',
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
      // إزالة البيانات الخاصة بالأرشفة
      data.remove('originalId');
      data.remove('archivedAt');
      data.remove('archiveReason');

      // إضافة العقار مجدداً لمجموعة properties
      await FirebaseFirestore.instance.collection('properties').add(data);
      // حذف العقار من الأرشيف
      await FirebaseFirestore.instance
          .collection('archived_properties')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم استعادة العقار بنجاح.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عقاراتي المؤرشفة')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('archived_properties')
            .where('userId', isEqualTo: _currentUser!.uid)
            .orderBy('archivedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد عقارات مؤرشفة لديك.'),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            itemBuilder: (ctx, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'بدون عنوان';
              final imageUrl = (data['imageUrls'] as List?)?.firstOrNull;
              final reason = data['archiveReason'] ?? 'غير معروف';

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
                    'السبب: $reason',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.restore_from_trash,
                      color: Colors.blue,
                    ),
                    tooltip: 'استعادة العقار',
                    onPressed: () => _restoreProperty(doc.id, data),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

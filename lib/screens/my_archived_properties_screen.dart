import 'package:aqar_app/screens/archived_property_details_screen.dart';
import 'package:aqar_app/services/api_service.dart'; // ✅
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyArchivedPropertiesScreen extends StatefulWidget {
  const MyArchivedPropertiesScreen({super.key});

  @override
  State<MyArchivedPropertiesScreen> createState() =>
      _MyArchivedPropertiesScreenState();
}

class _MyArchivedPropertiesScreenState
    extends State<MyArchivedPropertiesScreen> {
  late Future<List<Map<String, dynamic>>> _archivedFuture;

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');
    if (uid != null) {
      _archivedFuture = ApiService.fetchArchivedProperties(uid);
    } else {
      _archivedFuture = Future.value([]);
    }
    setState(() {});
  }

  Future<void> _restoreProperty(String docId) async {
    await ApiService.restoreProperty(docId);
    _loadArchive(); // تحديث القائمة
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت الاستعادة.')));
  }

  Future<void> _permanentlyDelete(String docId) async {
    await ApiService.deleteArchivedProperty(docId);
    _loadArchive();
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم الحذف نهائياً.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عقاراتي المؤرشفة')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _archivedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('الأرشيف فارغ حالياً.'));
          }

          final archivedDocs = snapshot.data!;

          return ListView.builder(
            itemCount: archivedDocs.length,
            itemBuilder: (ctx, index) {
              final data = archivedDocs[index];
              final docId = data['id'];
              final title = data['title'] ?? 'بدون عنوان';
              final imageUrl = (data['imageUrls'] as List?)?.firstOrNull;

              return Card(
                child: ListTile(
                  leading: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.house),
                  title: Text(title),
                  subtitle: Text('السبب: ${data['archiveReason'] ?? '---'}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'restore') _restoreProperty(docId);
                      if (value == 'delete') _permanentlyDelete(docId);
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'restore',
                        child: Text('استعادة'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'حذف نهائي',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ArchivedPropertyDetailsScreen(propertyData: data),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:aqar_app/screens/auth_gate.dart';
import 'package:aqar_app/screens/property_details_screen.dart'; // لعرض العقار
import 'package:aqar_app/screens/archived_property_details_screen.dart'; // <-- استيراد
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 👇 جعلنا العدد 4 لإضافة تبويب الأرشيف
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (ctx) => const AuthGate()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'نظرة عامة', icon: Icon(Icons.dashboard)),
            Tab(text: 'المستخدمين', icon: Icon(Icons.people)),
            // 👇 التبويب الجديد
            Tab(text: 'البلاغات', icon: Icon(Icons.report_problem_outlined)),
            Tab(text: 'الأرشيف', icon: Icon(Icons.archive_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _signOut,
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OverviewTab(),
          _UsersTab(),
          _ReportsTab(),
          _ArchiveTab(), // 👇 ويدجت الأرشيف الجديدة
        ],
      ),
    );
  }
}

// --- دالة مساعدة لتنسيق الوقت ---
// تم نقلها هنا لتكون متاحة لكل التبويبات
String _formatTimestamp(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final now = DateTime.now();
  final date = timestamp.toDate();
  final diff = now.difference(date);

  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
  if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
  return '${date.day}/${date.month}/${date.year}';
}

// --- تبويب البلاغات (جديد) ---
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  void _dismissReport(String reportId) {
    FirebaseFirestore.instance.collection('reports').doc(reportId).delete();
  }

  void _deletePropertyAndReport(
    BuildContext context,
    String propertyId,
    String reportId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العقار'),
        content: const Text(
          'هل أنت متأكد؟ سيتم حذف العقار نهائياً وإغلاق البلاغ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف العقار'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final propRef = FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId);
      final propDoc = await propRef.get();

      if (propDoc.exists) {
        // --- جلب اسم المدير الحالي ---
        final adminUser = FirebaseAuth.instance.currentUser;
        String adminName = 'مدير';
        if (adminUser != null) {
          final adminDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(adminUser.uid)
              .get();
          if (adminDoc.exists) {
            adminName = adminDoc.data()?['username'] ?? 'مدير';
          }
        }
        // أرشفة العقار قبل حذفه
        await FirebaseFirestore.instance.collection('archived_properties').add({
          ...propDoc.data()!,
          'originalId': propertyId,
          'archivedAt': FieldValue.serverTimestamp(),
          'archiveReason': 'حذف بواسطة المدير بسبب بلاغ',
          'archivedByUserId': adminUser?.uid, // هوية من قام بالأرشفة
          'archivedByUserName': adminName, // اسم من قام بالأرشفة
        });
        // حذف العقار
        await propRef.delete();
      }

      // حذف البلاغ بعد التعامل معه
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف العقار وإغلاق البلاغ.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
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
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('لا توجد بلاغات جديدة!'),
              ],
            ),
          );
        }

        final reports = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: reports.length,
          itemBuilder: (ctx, index) {
            final reportDoc = reports[index];
            final report = reportDoc.data() as Map<String, dynamic>;
            final propertyId = report['propertyId'];
            final reporterId = report['reporterId'] as String?;

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // رأس البطاقة: السبب
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            report['reason'] ?? 'سبب غير محدد',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          _formatTimestamp(report['timestamp']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    if (report['details'] != null &&
                        report['details'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '📝 "${report['details']}"',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                    const Divider(),

                    // -- معلومات المُبلّغ --
                    if (reporterId != null && reporterId != 'anonymous')
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(reporterId)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const SizedBox(); // لا تظهر شيئاً أثناء التحميل
                          }
                          if (!userSnapshot.data!.exists) {
                            return const Text('المستخدم غير موجود');
                          }
                          final userData =
                              userSnapshot.data!.data() as Map<String, dynamic>;
                          final username =
                              userData['username'] ?? 'مستخدم مجهول';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_pin_circle_outlined,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'مُقدّم من: ',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                Text(
                                  username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    // جلب معلومات العقار المبلغ عنه
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('properties')
                          .doc(propertyId)
                          .get(),
                      builder: (context, propSnapshot) {
                        if (!propSnapshot.hasData) {
                          return const LinearProgressIndicator();
                        }

                        if (!propSnapshot.data!.exists) {
                          return const ListTile(
                            leading: Icon(
                              Icons.delete_outline,
                              color: Colors.grey,
                            ),
                            title: Text('العقار محذوف بالفعل'),
                          );
                        }

                        final propData =
                            propSnapshot.data!.data() as Map<String, dynamic>;
                        final title = propData['title'] ?? 'بدون عنوان';
                        final img =
                            (propData['imageUrls'] as List?)?.firstOrNull;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: img != null
                                ? CachedNetworkImage(
                                    imageUrl: img,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.home),
                                  ),
                          ),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'ID: $propertyId',
                            style: const TextStyle(fontSize: 10),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.visibility,
                              color: Colors.blue,
                            ),
                            tooltip: 'معاينة العقار',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PropertyDetailsScreen(
                                    propertyId: propertyId,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    // أزرار التحكم
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _dismissReport(reportDoc.id),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('تجاهل البلاغ'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _deletePropertyAndReport(
                            context,
                            propertyId,
                            reportDoc.id,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red,
                          ),
                          icon: const Icon(Icons.delete_forever, size: 18),
                          label: const Text('حذف العقار'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- التبويبات القديمة (كما هي) ---

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Future<Map<String, int>> _statsFuture;

  Future<Map<String, int>> _fetchStats() async {
    final usersCountFuture = FirebaseFirestore.instance
        .collection('users')
        .count()
        .get();
    final propertiesCountFuture = FirebaseFirestore.instance
        .collection('properties')
        .count()
        .get();
    final sellPropertiesFuture = FirebaseFirestore.instance
        .collection('properties')
        .where('category', isEqualTo: 'بيع')
        .count()
        .get();

    final results = await Future.wait([
      usersCountFuture,
      propertiesCountFuture,
      sellPropertiesFuture,
    ]);

    return {
      'users': results[0].count ?? 0,
      'properties': results[1].count ?? 0,
      'sell': results[2].count ?? 0,
    };
  }

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchStats();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('حدث خطأ في جلب الإحصائيات.'));
        }

        final stats = snapshot.data ?? {'users': 0, 'properties': 0, 'sell': 0};

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _statsFuture = _fetchStats();
            });
            await _statsFuture;
          },
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildStatCard(
                context,
                icon: Icons.people_alt_outlined,
                label: 'المستخدمين المسجلين',
                value: '${stats['users']}',
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                context,
                icon: Icons.home_work_outlined,
                label: 'إجمالي العقارات',
                value: '${stats['properties']}',
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      icon: Icons.sell_outlined,
                      label: 'للبيع',
                      value: '${stats['sell']}',
                      color: Colors.redAccent,
                      isSmall: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      icon: Icons.key,
                      label: 'للإيجار',
                      value: '${(stats['properties']! - stats['sell']!)}',
                      color: Colors.green,
                      isSmall: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isSmall = false,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 16.0 : 24.0),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmall ? 10 : 16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: isSmall ? 24 : 32, color: color),
            ),
            SizedBox(width: isSmall ? 12 : 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: isSmall ? 24 : 32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- تبويب الأرشيف (جديد) ---
class _ArchiveTab extends StatelessWidget {
  const _ArchiveTab();

  // --- دالة جديدة لاستعادة العقار ---
  Future<void> _restoreProperty(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
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
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  Future<void> _permanentlyDelete(
    BuildContext context,
    String docId,
    String title,
  ) async {
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('archived_properties')
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
                Text('الأرشيف فارغ حالياً.'),
              ],
            ),
          );
        }

        final archivedDocs = snapshot.data!.docs;

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
            final archiverName = data['archivedByUserName'] as String?;

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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'السبب: $reason',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    if (archiverName != null)
                      Text(
                        'بواسطة: $archiverName',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    if (timestamp != null)
                      Text(
                        'تاريخ الأرشفة: ${_formatTimestamp(timestamp)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'restore') {
                      _restoreProperty(context, doc.id, data);
                    } else if (value == 'delete') {
                      _permanentlyDelete(context, doc.id, title);
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
                        leading: Icon(Icons.delete_forever, color: Colors.red),
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
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  void _deleteUser(BuildContext context, String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف مستخدم'),
        content: Text(
          'هل أنت متأكد من حذف "$username"؟\nسيتم فقدان بياناته نهائياً.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المستخدم من قاعدة البيانات.')),
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
  }

  void _toggleBlockUser(
    BuildContext context,
    String userId,
    bool currentStatus,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isBanned': !currentStatus,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentStatus ? 'تم حظر المستخدم.' : 'تم رفع الحظر.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling block: $e');
    }
  }

  void _toggleAdminRole(
    BuildContext context,
    String userId,
    String currentRole,
  ) async {
    final newRole = currentRole == 'admin' ? 'مشترك' : 'admin';
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': newRole,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تغيير الصلاحية إلى $newRole.')),
        );
      }
    } catch (e) {
      debugPrint('Error toggling role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('لا يوجد مستخدمين مسجلين.'));
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: users.length,
          itemBuilder: (ctx, index) {
            final userDoc = users[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            final userId = userDoc.id;
            final username = userData['username'] ?? 'مجهول';
            final email = userData['email'] ?? '';
            final profileImageUrl = userData['profileImageUrl'];
            final role = userData['role'] ?? 'مشترك';
            final isBanned = userData['isBanned'] == true;

            final isAdmin = role == 'admin' || role == 'مدير';
            final isMe = userId == currentAdminId;

            return Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage: profileImageUrl != null
                      ? CachedNetworkImageProvider(profileImageUrl)
                      : null,
                  child: profileImageUrl == null
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                        )
                      : null,
                ),
                title: Row(
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: isBanned
                            ? TextDecoration.lineThrough
                            : null,
                        color: isBanned ? Colors.grey : null,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'مدير',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(email),
                trailing: isMe
                    ? const Chip(label: Text('أنت'))
                    : PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteUser(context, userId, username);
                          } else if (value == 'block') {
                            _toggleBlockUser(context, userId, isBanned);
                          } else if (value == 'role') {
                            _toggleAdminRole(context, userId, role);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem(
                            value: 'role',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  color: isAdmin ? Colors.orange : Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(isAdmin ? 'إزالة الإدارة' : 'تعيين كمدير'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.block,
                                  color: isBanned ? Colors.green : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(isBanned ? 'فك الحظر' : 'حظر المستخدم'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'حذف نهائي',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

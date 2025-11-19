import 'package:aqar_app/screens/auth_gate.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
        children: const [_OverviewTab(), _UsersTab()],
      ),
    );
  }
}

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

    // مثال: إحصائيات إضافية (عقارات البيع vs الإيجار)
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
        // ملاحظة: لحذف المستخدم من Authentication أيضاً، يتطلب الأمر Cloud Functions
        // أو تسجيل الدخول بحسابه، لذا نكتفي بحذفه من قاعدة البيانات حالياً.
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
                    ? const Chip(label: Text('أنت')) // لا يمكن للمدير حذف نفسه
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

import 'package:aqar_app/screens/auth_gate.dart';
import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/screens/archived_property_details_screen.dart';
import 'package:aqar_app/screens/chat_messages_screen.dart'; // هام للدخول للمحادثة
import 'package:aqar_app/screens/public_profile_screen.dart'; // هام للملف الشخصي
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

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
    // 5 تبويبات شاملة لكل أدوات الإدارة
    _tabController = TabController(length: 5, vsync: this);
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
        title: const Text('لوحة القيادة 🛡️'),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // يسمح بالتمرير إذا كانت الشاشة صغيرة
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'نظرة عامة', icon: Icon(Icons.dashboard)),
            Tab(text: 'المستخدمين', icon: Icon(Icons.people_alt)),
            Tab(text: 'التحكم', icon: Icon(Icons.settings_applications)),
            Tab(text: 'مراقبة الشات', icon: Icon(Icons.chat)),
            Tab(text: 'البلاغات والأرشيف', icon: Icon(Icons.report_problem)),
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
          _UsersManagementTab(), // التبويب الجديد لإدارة المستخدمين
          _AppControlTab(), // التبويب الجديد للتحكم في التطبيق
          _ChatMonitoringTab(), // التبويب الجديد لمراقبة المحادثات
          _ReportsAndArchiveTab(), // دمجنا البلاغات والأرشيف لتوفير المساحة
        ],
      ),
    );
  }
}

// --- 1. تبويب نظرة عامة (Overview) ---
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
    final chatsCountFuture = FirebaseFirestore.instance
        .collection('chats')
        .count()
        .get();

    final results = await Future.wait([
      usersCountFuture,
      propertiesCountFuture,
      chatsCountFuture,
    ]);

    return {
      'users': results[0].count ?? 0,
      'properties': results[1].count ?? 0,
      'chats': results[2].count ?? 0,
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
        final stats =
            snapshot.data ?? {'users': 0, 'properties': 0, 'chats': 0};

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
              _buildStatCard(
                context,
                icon: Icons.chat_bubble_outline,
                label: 'المحادثات النشطة',
                value: '${stats['chats']}',
                color: Colors.purple,
              ),
              const SizedBox(height: 16),
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
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
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

// --- 2. تبويب إدارة المستخدمين (Users Management) ---
class _UsersManagementTab extends StatefulWidget {
  const _UsersManagementTab();

  @override
  State<_UsersManagementTab> createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<_UsersManagementTab> {
  String _searchQuery = '';
  final _currentUser = FirebaseAuth.instance.currentUser;

  void _toggleUserBan(
    BuildContext context,
    String userId,
    bool currentStatus,
    String username,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentStatus ? 'إلغاء الحظر' : 'حظر المستخدم'),
        content: Text(
          currentStatus
              ? 'هل تريد فك الحظر عن $username؟'
              : 'هل أنت متأكد من حظر $username؟ لن يتمكن من الدخول للتطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.green : Colors.red,
            ),
            child: Text(currentStatus ? 'فك الحظر' : 'حظر'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isBanned': !currentStatus,
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentStatus ? 'تم فك الحظر' : 'تم حظر المستخدم'),
          ),
        );
    }
  }

  void _toggleAdminRole(
    BuildContext context,
    String userId,
    String currentRole,
  ) async {
    final newRole = currentRole == 'admin' ? 'user' : 'admin';
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'role': newRole,
    });
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم تغيير الصلاحية إلى $newRole')));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو الإيميل...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (ctx, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              final users = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['username'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) ||
                    email.contains(_searchQuery);
              }).toList();

              if (users.isEmpty)
                return const Center(child: Text('لا يوجد مستخدمين مطابقين.'));

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (ctx, index) {
                  final userData = users[index].data() as Map<String, dynamic>;
                  final userId = users[index].id;
                  if (userId == _currentUser?.uid)
                    return const SizedBox.shrink();

                  final isBanned = userData['isBanned'] == true;
                  final isAdmin = userData['role'] == 'admin';
                  final username = userData['username'] ?? 'مجهول';

                  return Card(
                    color: isBanned ? Colors.red.shade50 : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userData['profileImageUrl'] != null
                            ? CachedNetworkImageProvider(
                                userData['profileImageUrl'],
                              )
                            : null,
                        child: userData['profileImageUrl'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Row(
                        children: [
                          Text(
                            username,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (isAdmin)
                            const Padding(
                              padding: EdgeInsets.only(right: 5),
                              child: Icon(
                                Icons.verified_user,
                                color: Colors.blue,
                                size: 16,
                              ),
                            ),
                          if (isBanned)
                            const Padding(
                              padding: EdgeInsets.only(right: 5),
                              child: Icon(
                                Icons.block,
                                color: Colors.red,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(userData['email'] ?? ''),
                      trailing: PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'block')
                            _toggleUserBan(context, userId, isBanned, username);
                          if (val == 'role')
                            _toggleAdminRole(
                              context,
                              userId,
                              userData['role'] ?? 'user',
                            );
                          if (val == 'profile')
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PublicProfileScreen(
                                  userId: userId,
                                  userName: username,
                                ),
                              ),
                            );
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'profile',
                            child: const Text('عرض الملف الشخصي'),
                          ),
                          PopupMenuItem(
                            value: 'role',
                            child: Text(
                              isAdmin ? 'إزالة الإدارة' : 'تعيين كمدير',
                            ),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Text(
                              isBanned ? 'فك الحظر' : 'حظر المستخدم',
                              style: TextStyle(
                                color: isBanned ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- 3. تبويب التحكم في التطبيق (App Control) ---
class _AppControlTab extends StatefulWidget {
  const _AppControlTab();

  @override
  State<_AppControlTab> createState() => _AppControlTabState();
}

class _AppControlTabState extends State<_AppControlTab> {
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
              data['maintenance_message'] ?? 'التطبيق في صيانة حالياً';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('config')
        .set({
          'min_version': _minVersionController.text.trim(),
          'maintenance_mode': _isMaintenanceMode,
          'maintenance_message': _maintenanceMsgController.text.trim(),
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    setState(() => _isLoading = false);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الحفظ بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إصدار التطبيق الإجباري',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _minVersionController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الإصدار (مثلاً 1.0.5)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: _isMaintenanceMode ? Colors.orange.shade50 : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'وضع الصيانة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'إغلاق التطبيق أمام الجميع ما عدا الأدمن',
                  ),
                  value: _isMaintenanceMode,
                  activeColor: Colors.orange,
                  onChanged: (val) => setState(() => _isMaintenanceMode = val),
                ),
                if (_isMaintenanceMode)
                  TextField(
                    controller: _maintenanceMsgController,
                    decoration: const InputDecoration(
                      labelText: 'رسالة الصيانة',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          onPressed: _saveSettings,
          icon: const Icon(Icons.save),
          label: const Text('حفظ الإعدادات'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// --- 4. تبويب مراقبة المحادثات (Chat Monitoring) ---
class _ChatMonitoringTab extends StatelessWidget {
  const _ChatMonitoringTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text('لا توجد محادثات.'));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (ctx, index) => const Divider(),
          itemBuilder: (ctx, index) {
            final chatData =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final chatId = snapshot.data!.docs[index].id;
            final Map<String, dynamic> names =
                chatData['participantNames'] ?? {};
            final namesString = names.values.join(' ↔️ ');
            final lastMessage = chatData['lastMessage'] ?? '';
            final timestamp = chatData['lastMessageTimestamp'] as Timestamp?;
            final timeString = timestamp != null
                ? intl.DateFormat('dd/MM hh:mm a').format(timestamp.toDate())
                : '';

            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.purple,
                child: Icon(Icons.remove_red_eye, color: Colors.white),
              ),
              title: Text(
                namesString.isEmpty ? 'محادثة مجهولة' : namesString,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
              ),
              subtitle: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                timeString,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatMessagesScreen(
                      chatId: chatId,
                      recipientId: 'monitor',
                      recipientName: 'وضع المراقبة',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// --- 5. تبويب البلاغات والأرشيف (Reports & Archive) ---
class _ReportsAndArchiveTab extends StatefulWidget {
  const _ReportsAndArchiveTab();

  @override
  State<_ReportsAndArchiveTab> createState() => _ReportsAndArchiveTabState();
}

class _ReportsAndArchiveTabState extends State<_ReportsAndArchiveTab>
    with SingleTickerProviderStateMixin {
  late TabController _innerTabController;

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _innerTabController,
          labelColor: Colors.red,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'البلاغات النشطة'),
            Tab(text: 'أرشيف العقارات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _innerTabController,
            children: const [_ReportsList(), _ArchiveList()],
          ),
        ),
      ],
    );
  }
}

class _ReportsList extends StatelessWidget {
  const _ReportsList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 50),
                Text('لا توجد بلاغات!'),
              ],
            ),
          );

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (ctx, index) {
            final report =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final reportId = snapshot.data!.docs[index].id;
            final propertyId = report['propertyId'];

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: Text(report['reason'] ?? 'سبب غير محدد'),
                subtitle: Text(report['details'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PropertyDetailsScreen(propertyId: propertyId),
                      ),
                    );
                  },
                ),
                onLongPress: () async {
                  // خيار الحذف السريع للبلاغ
                  await FirebaseFirestore.instance
                      .collection('reports')
                      .doc(reportId)
                      .delete();
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ArchiveList extends StatelessWidget {
  const _ArchiveList();

  Future<void> _restoreProperty(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استعادة عقار'),
        content: const Text('هل أنت متأكد من استعادة هذا العقار؟'),
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

    if (confirm == true) {
      data.remove('archivedAt');
      data.remove('archiveReason');
      await FirebaseFirestore.instance.collection('properties').add(data);
      await FirebaseFirestore.instance
          .collection('archived_properties')
          .doc(docId)
          .delete();
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الاستعادة بنجاح')));
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
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return const Center(child: Text('الأرشيف فارغ.'));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (ctx, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              child: ListTile(
                title: Text(data['title'] ?? 'بدون عنوان'),
                subtitle: Text('السبب: ${data['archiveReason'] ?? '---'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.restore),
                  tooltip: 'استعادة',
                  onPressed: () => _restoreProperty(context, doc.id, data),
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
    );
  }
}

import 'package:aqar_app/screens/auth_gate.dart';
import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:aqar_app/screens/admin_chat_monitor_screen.dart';
import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/screens/public_profile_screen.dart';
import 'package:aqar_app/services/api_service.dart'; // ✅ استخدام السيرفر
import 'package:cached_network_image/cached_network_image.dart';
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
    _tabController = TabController(length: 5, vsync: this);
    print('🔴 [AdminDashboard] بدء لوحة القيادة الإدارية!');
    print('🔴 [AdminDashboard] Admin Dashboard Initialized!');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (ctx) => const AuthGate()),
        (route) => false,
      );
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
          isScrollable: true,
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
          _UsersManagementTab(),
          _AppControlTab(),
          _ChatMonitoringTab(),
          _ReportsAndArchiveTab(),
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
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    // ✅ جلب الإحصائيات من السيرفر
    print('🟠 [OverviewTab] بدء تبويب نظرة عامة - جلب الإحصائيات!');
    _statsFuture = ApiService.fetchAdminStats();
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = ApiService.fetchAdminStats();
    });
    await _statsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // خريطة البيانات من API
        final apiData = snapshot.data ?? {};
        final stats = {
          'users': apiData['totalUsers'] ?? 0,
          'properties': apiData['totalProperties'] ?? 0,
          'chats': apiData['totalChats'] ?? 0,
          'activeUsers': apiData['activeUsers'] ?? 0,
          'bannedUsers': apiData['bannedUsers'] ?? 0,
          'reports': apiData['totalReports'] ?? 0,
        };

        return RefreshIndicator(
          onRefresh: _refresh,
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

// --- 2. تبويب إدارة المستخدمين ---
class _UsersManagementTab extends StatefulWidget {
  const _UsersManagementTab();
  @override
  State<_UsersManagementTab> createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<_UsersManagementTab> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _usersFuture = ApiService.fetchAllUsers();
  }

  Future<void> _refreshUsers() async {
    setState(() {
      _usersFuture = ApiService.fetchAllUsers();
    });
    await _usersFuture;
  }

  void _toggleUserBan(
    String userId,
    bool currentStatus,
    String username,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentStatus ? 'إلغاء الحظر' : 'حظر المستخدم'),
        content: Text(
          'هل تريد ${currentStatus ? "إلغاء حظر" : "حظر"} "$username"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.toggleUserBan(userId, !currentStatus);
        setState(() {
          _usersFuture = ApiService.fetchAllUsers();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentStatus ? 'تم إلغاء حظر المستخدم' : 'تم حظر المستخدم',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشلت العملية: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _toggleUserAdmin(
    String userId,
    bool currentStatus,
    String username,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentStatus ? 'إزالة صلاحيات المدير' : 'ترقية لمدير'),
        content: Text(
          currentStatus
              ? 'هل تريد إزالة صلاحيات المدير من "$username"؟'
              : 'هل تريد منح "$username" صلاحيات المدير؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? Colors.red : Colors.green,
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.toggleUserAdmin(userId, !currentStatus);
        setState(() {
          _usersFuture = ApiService.fetchAllUsers();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentStatus
                    ? 'تم إزالة صلاحيات المدير'
                    : 'تم ترقية المستخدم لمدير',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشلت العملية: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'بحث...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _usersFuture,
            builder: (ctx, snapshot) {
              // Build a child widget based on snapshot and wrap with RefreshIndicator
              Widget child;
              if (snapshot.connectionState == ConnectionState.waiting) {
                child = const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                child = ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text('خطأ في تحميل المستخدمين: ${snapshot.error}'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: _refreshUsers,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ),
                  ],
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                child = ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Center(child: Text('لا يوجد مستخدمين.')),
                    SizedBox(height: 16),
                  ],
                );
              } else {
                final users = snapshot.data!.where((user) {
                  final name = (user['username'] ?? '')
                      .toString()
                      .toLowerCase();
                  final email = (user['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }).toList();

                child = ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (ctx, index) {
                    final user = users[index];
                    final isBanned = user['isBanned'] == true;
                    final isAdmin = user['isAdmin'] == true;
                    final isSuperAdmin = user['isSuperAdmin'] == true;
                    final isOnline = user['isOnline'] == true;
                    final lastSeen = user['lastSeen'];

                    // حساب آخر ظهور
                    String lastSeenText = '';
                    if (isOnline) {
                      lastSeenText = 'متصل الآن';
                    } else if (lastSeen != null) {
                      try {
                        final DateTime lastSeenDate = DateTime.parse(
                          lastSeen.toString(),
                        );
                        final Duration diff = DateTime.now().difference(
                          lastSeenDate,
                        );

                        if (diff.inMinutes < 1) {
                          lastSeenText = 'منذ لحظات';
                        } else if (diff.inMinutes < 60) {
                          lastSeenText = 'منذ ${diff.inMinutes} د';
                        } else if (diff.inHours < 24) {
                          lastSeenText = 'منذ ${diff.inHours} ساعة';
                        } else {
                          lastSeenText = 'منذ ${diff.inDays} يوم';
                        }
                      } catch (e) {
                        lastSeenText = 'غير متصل';
                      }
                    } else {
                      lastSeenText = 'لم يتصل';
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: isAdmin
                                  ? Colors.orange
                                  : Colors.blue,
                              child: Icon(
                                isSuperAdmin
                                    ? Icons.shield
                                    : isAdmin
                                    ? Icons.admin_panel_settings
                                    : Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            // نقطة خضراء إذا كان متصل
                            if (isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Text(user['username'] ?? 'مستخدم'),
                            if (isSuperAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'المدير العام',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else if (isAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'مدير',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['email'] ?? ''),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: isOnline ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  lastSeenText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOnline
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: isOnline
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // زر إدارة صلاحيات المشرف
                            IconButton(
                              icon: Icon(
                                isAdmin
                                    ? Icons.remove_moderator
                                    : Icons.add_moderator,
                                color: isAdmin ? Colors.red : Colors.green,
                              ),
                              tooltip: isAdmin
                                  ? 'إزالة الإشراف'
                                  : 'ترقية لمشرف',
                              onPressed: () => _toggleUserAdmin(
                                user['id'],
                                isAdmin,
                                user['username'],
                              ),
                            ),
                            // زر الحظر
                            IconButton(
                              icon: Icon(
                                isBanned ? Icons.block : Icons.check_circle,
                                color: isBanned ? Colors.red : Colors.grey,
                              ),
                              tooltip: isBanned ? 'إلغاء الحظر' : 'حظر',
                              onPressed: () => _toggleUserBan(
                                user['id'],
                                isBanned,
                                user['username'],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }

              return RefreshIndicator(onRefresh: _refreshUsers, child: child);
            },
          ),
        ),
      ],
    );
  }
}

// --- 3. تبويب التحكم في التطبيق ---
// --- 3. تبويب التحكم في التطبيق (مفعل) ---
class _AppControlTab extends StatefulWidget {
  const _AppControlTab();
  @override
  State<_AppControlTab> createState() => _AppControlTabState();
}

class _AppControlTabState extends State<_AppControlTab> {
  final _versionController = TextEditingController();
  final _msgController = TextEditingController();
  bool _maintenance = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ApiService.fetchAppSettings();
    if (mounted) {
      setState(() {
        _versionController.text = settings['min_version'] ?? '1.0.0';
        _maintenance = settings['maintenance_mode'] ?? false;
        _msgController.text = settings['maintenance_message'] ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ApiService.updateAppSettings({
        'min_version': _versionController.text,
        'maintenance_mode': _maintenance,
        'maintenance_message': _msgController.text,
      });
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
        if (_maintenance) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('وضع الصيانة مفعّل. لن يظهر للمشرفين.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'إصدار التطبيق الإجباري',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  controller: _versionController,
                  decoration: const InputDecoration(labelText: 'رقم الإصدار'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'وضع الصيانة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SwitchListTile(
                  title: const Text('تفعيل الصيانة'),
                  value: _maintenance,
                  onChanged: (v) => setState(() => _maintenance = v),
                ),
                TextField(
                  controller: _msgController,
                  decoration: const InputDecoration(labelText: 'رسالة الصيانة'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _save, child: const Text('حفظ الإعدادات')),
      ],
    );
  }
}

// --- 4. تبويب مراقبة الشات ---
class _ChatMonitoringTab extends StatefulWidget {
  const _ChatMonitoringTab();

  @override
  State<_ChatMonitoringTab> createState() => _ChatMonitoringTabState();
}

class _ChatMonitoringTabState extends State<_ChatMonitoringTab> {
  late Future<List<Map<String, dynamic>>> _chatsFuture;
  String _searchQuery = '';
  bool _showOnlineOnly = false;

  @override
  void initState() {
    super.initState();
    // ✅ جلب جميع المحادثات عند بدء التشغيل
    _chatsFuture = ApiService.fetchAllChats();
  }

  void _refreshChats() {
    setState(() {
      _chatsFuture = ApiService.fetchAllChats();
    });
  }

  List<Map<String, dynamic>> _filterChats(List<Map<String, dynamic>> chats) {
    var filtered = chats;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((chat) {
        final user1 = chat['user1'] as Map<String, dynamic>?;
        final user2 = chat['user2'] as Map<String, dynamic>?;
        final query = _searchQuery.toLowerCase();
        return (user1?['username']?.toString().toLowerCase().contains(query) ??
                false) ||
            (user1?['email']?.toString().toLowerCase().contains(query) ??
                false) ||
            (user2?['username']?.toString().toLowerCase().contains(query) ??
                false) ||
            (user2?['email']?.toString().toLowerCase().contains(query) ??
                false);
      }).toList();
    }

    if (_showOnlineOnly) {
      filtered = filtered.where((chat) {
        final user1 = chat['user1'] as Map<String, dynamic>?;
        final user2 = chat['user2'] as Map<String, dynamic>?;
        return (user1?['isOnline'] == true) || (user2?['isOnline'] == true);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المستخدم أو البريد الإلكتروني...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilterChip(
                    label: const Text('المتصلين فقط'),
                    selected: _showOnlineOnly,
                    onSelected: (selected) =>
                        setState(() => _showOnlineOnly = selected),
                    avatar: Icon(
                      Icons.circle,
                      color: _showOnlineOnly ? Colors.green : Colors.grey,
                      size: 12,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshChats,
                    tooltip: 'تحديث',
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _chatsFuture,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text('لا توجد محادثات حالياً'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _refreshChats,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تحديث'),
                      ),
                    ],
                  ),
                );
              }
              final filteredChats = _filterChats(snapshot.data!);
              if (filteredChats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text('لا توجد نتائج للبحث'),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refreshChats(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredChats.length,
                  itemBuilder: (ctx, index) =>
                      _buildChatCard(filteredChats[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatCard(Map<String, dynamic> chat) {
    final user1 = chat['user1'] as Map<String, dynamic>?;
    final user2 = chat['user2'] as Map<String, dynamic>?;
    final messagesCount = chat['messagesCount'] ?? 0;
    final lastMessage = chat['lastMessage']?.toString() ?? '';
    final lastMessageTime = chat['lastMessageTimestamp'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 3,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) =>
                  AdminChatMonitorScreen(chatId: chat['id'], chatData: chat),
            ),
          );
          if (result == true) _refreshChats();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildUserChip(user1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.chat, color: Colors.orange, size: 20),
                  ),
                  Expanded(child: _buildUserChip(user2)),
                ],
              ),
              const SizedBox(height: 12),
              if (lastMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.message, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    avatar: const Icon(Icons.chat_bubble, size: 16),
                    label: Text('$messagesCount رسالة'),
                    backgroundColor: Colors.blue.shade50,
                    labelStyle: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  if (lastMessageTime != null)
                    Chip(
                      avatar: const Icon(Icons.access_time, size: 16),
                      label: Text(_formatTimestamp(lastMessageTime)),
                      backgroundColor: Colors.orange.shade50,
                      labelStyle: const TextStyle(fontSize: 11),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.blue),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => AdminChatMonitorScreen(
                            chatId: chat['id'],
                            chatData: chat,
                          ),
                        ),
                      );
                      if (result == true) _refreshChats();
                    },
                    tooltip: 'عرض المحادثة',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserChip(Map<String, dynamic>? user) {
    if (user == null) {
      return const Chip(
        label: Text('مستخدم محذوف', style: TextStyle(fontSize: 11)),
        avatar: Icon(Icons.person_off, size: 16),
        backgroundColor: Colors.grey,
      );
    }
    final username = user['username']?.toString() ?? 'مستخدم';
    final isOnline = user['isOnline'] == true;
    final isBanned = user['isBanned'] == true;
    return Chip(
      avatar: CircleAvatar(
        radius: 12,
        backgroundImage: user['profileImage'] != null
            ? CachedNetworkImageProvider(user['profileImage'])
            : null,
        child: user['profileImage'] == null
            ? const Icon(Icons.person, size: 12)
            : null,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              username,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          if (isOnline)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          if (isBanned) const Icon(Icons.block, size: 12, color: Colors.red),
        ],
      ),
      backgroundColor: isOnline ? Colors.green.shade50 : Colors.grey.shade200,
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'غير معروف';
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else {
        return 'غير معروف';
      }
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inMinutes < 1) return 'الآن';
      if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
      if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة';
      if (difference.inDays < 7) return 'منذ ${difference.inDays} يوم';
      return intl.DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return 'غير معروف';
    }
  }
}

// --- 5. تبويب البلاغات والأرشيف ---
class _ReportsAndArchiveTab extends StatelessWidget {
  const _ReportsAndArchiveTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ApiService.fetchReports(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(child: Text('لا توجد بلاغات.'));

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (ctx, index) {
            final report = snapshot.data![index];
            return ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: Text(report['reason'] ?? 'بلاغ'),
              subtitle: Text(report['details'] ?? ''),
            );
          },
        );
      },
    );
  }
}

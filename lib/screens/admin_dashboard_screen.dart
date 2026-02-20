import 'package:aqar_app/screens/auth_gate.dart';
import 'package:aqar_app/screens/admin_chat_monitor_screen.dart';
import 'package:aqar_app/screens/report_details_screen.dart';
import 'package:aqar_app/screens/profile_screen.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/widgets/verified_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  // --- لوحة الألوان الداكنة (Dark Theme Palette) ---
  final Color primaryColor = const Color(0xFF3B82F6); // أزرق ساطع للوضع الليلي
  final Color backgroundColor = const Color(
    0xFF111827,
  ); // خلفية سوداء مائلة للكحلي
  final Color surfaceColor = const Color(0xFF1F2937); // رمادي غامق للبطاقات
  final Color textPrimary = const Color(0xFFF3F4F6); // أبيض مائل للرمادي
  final Color textSecondary = const Color(0xFF9CA3AF); // رمادي فاتح
  final Color inputFillColor = const Color(0xFF374151); // لون حقول الإدخال

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'لوحة الإدارة',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: IconThemeData(color: textSecondary),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _signOut,
            tooltip: 'تسجيل الخروج',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: primaryColor,
          unselectedLabelColor: textSecondary,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'الرئيسية'),
            Tab(text: 'المستخدمين'),
            Tab(text: 'الإعدادات'),
            Tab(text: 'المحادثات'),
            Tab(text: 'البلاغات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(
            backgroundColor,
            surfaceColor,
            textPrimary,
            textSecondary,
          ),
          // ✅ تم تحديث هذا التبويب ليدعم Pagination
          _UsersManagementTab(
            backgroundColor,
            surfaceColor,
            textPrimary,
            textSecondary,
            inputFillColor,
          ),
          _AppControlTab(
            backgroundColor,
            surfaceColor,
            textPrimary,
            textSecondary,
            inputFillColor,
          ),
          _ChatMonitoringTab(surfaceColor, textPrimary, textSecondary),
          _ReportsAndArchiveTab(surfaceColor, textPrimary, textSecondary),
        ],
      ),
    );
  }
}

// ==========================================
// 1. تبويب النظرة العامة
// ==========================================
class _OverviewTab extends StatefulWidget {
  final Color bgColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;

  const _OverviewTab(
    this.bgColor,
    this.surfaceColor,
    this.textPrimary,
    this.textSecondary,
  );

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
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

        final apiData = snapshot.data ?? {};
        final totalUsers = apiData['totalUsers'] ?? apiData['users'] ?? 0;
        final totalProperties =
            apiData['totalProperties'] ?? apiData['properties'] ?? 0;
        final totalChats = apiData['totalChats'] ?? apiData['chats'] ?? 0;

        return RefreshIndicator(
          onRefresh: _refresh,
          backgroundColor: widget.surfaceColor,
          color: Colors.blue,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'ملخص النظام',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.textPrimary,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      'المستخدمين',
                      '$totalUsers',
                      Icons.people_outline,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildInfoCard(
                      'العقارات',
                      '$totalProperties',
                      Icons.home_work_outlined,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildInfoCard(
                'المحادثات النشطة',
                '$totalChats',
                Icons.chat_bubble_outline,
                Colors.purpleAccent,
                isFullWidth: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: isFullWidth ? 110 : 170,
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isFullWidth
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: widget.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: widget.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    color: widget.textPrimary,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: widget.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

// ==========================================
// 2. إدارة المستخدمين (مع Pagination & Search)
// ==========================================
class _UsersManagementTab extends StatefulWidget {
  final Color bgColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color inputFillColor;

  const _UsersManagementTab(
    this.bgColor,
    this.surfaceColor,
    this.textPrimary,
    this.textSecondary,
    this.inputFillColor,
  );

  @override
  State<_UsersManagementTab> createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<_UsersManagementTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  dynamic _lastCreatedAt; // ✅ يقبل String أو Map (Firestore timestamp)
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers(); // تحميل أولي
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchUsers();
    }
  }

  Future<void> _fetchUsers({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (refresh) {
      _users.clear();
      _lastCreatedAt = null;
      _hasMore = true;
    }

    try {
      final newUsers = await ApiService.fetchAllUsers(
        limit: 20,
        lastCreatedAt: _lastCreatedAt,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) {
        setState(() {
          if (newUsers.isEmpty) {
            // إذا لم تأتِ بيانات وكان تحديثاً، القائمة فارغة أصلاً
            // إذا كان تحميل المزيد، فهذا يعني وصلنا للنهاية
            _hasMore = false;
          } else {
            _users.addAll(newUsers);
            // نحفظ تاريخ آخر عنصر لاستخدامه في الطلب القادم
            // ✅ يقبل String أو Map (Firestore timestamp)
            _lastCreatedAt = newUsers.last['createdAt'];
            debugPrint(
              '📍 Last createdAt type: ${newUsers.last['createdAt'].runtimeType}',
            );
            // إذا جاءت بيانات أقل من الحد المطلوب (20)، فهذا يعني وصلنا للنهاية
            if (newUsers.length < 20) _hasMore = false;
          }
        });
      }
    } catch (e) {
      debugPrint("❌ خطأ في جلب المستخدمين: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshUsers() async {
    _users.clear();
    _lastCreatedAt = null;
    _hasMore = true;
    await _fetchUsers(refresh: true);
  }

  // جلب البيانات الكاملة للمستخدم وفتح البروفايل
  Future<void> _openUserProfile(String userId) async {
    try {
      // إظهار مؤشر التحميل
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
      }

      // جلب البيانات الكاملة للمستخدم
      final fullUserData = await ApiService.fetchUserProfile(userId);

      // إغلاق مؤشر التحميل
      if (mounted) Navigator.pop(context);

      if (fullUserData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل في تحميل بيانات المستخدم'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // فتح صفحة البروفايل بالبيانات الكاملة
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(otherUserData: fullUserData),
          ),
        );
      }
    } catch (e) {
      // إغلاق مؤشر التحميل إذا كان مفتوحاً
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
      debugPrint('❌ Error opening user profile: $e');
    }
  }

  void _onSearchChanged(String value) {
    // نستخدم Debounce بسيط لتجنب الطلبات الكثيرة يمكن تطبيقه هنا،
    // لكن للتبسيط سنطلب عند الكتابة مباشرة أو عند الضغط زر البحث
    // هنا سنحدث القيمة ونعيد التحميل
    setState(() => _searchQuery = value);
    _fetchUsers(refresh: true);
  }

  Future<void> _handleAction(
    String userId,
    String action,
    bool currentStatus,
  ) async {
    try {
      if (action == 'verify')
        await ApiService.toggleUserVerification(userId, !currentStatus);
      if (action == 'ban')
        await ApiService.toggleUserBan(userId, !currentStatus);
      if (action == 'admin')
        await ApiService.toggleUserAdmin(userId, !currentStatus);

      // تحديث الحالة محلياً بدلاً من إعادة تحميل القائمة بالكامل (لتحسين التجربة)
      setState(() {
        final index = _users.indexWhere((u) => u['id'] == userId);
        if (index != -1) {
          if (action == 'verify') _users[index]['isVerified'] = !currentStatus;
          if (action == 'ban') _users[index]['isBanned'] = !currentStatus;
          if (action == 'admin') _users[index]['isAdmin'] = !currentStatus;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التحديث بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          color: Colors.transparent,
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: widget.textPrimary),
            decoration: InputDecoration(
              hintText: 'بحث عن اسم...',
              hintStyle: TextStyle(color: widget.textSecondary),
              prefixIcon: Icon(Icons.search, color: widget.textSecondary),
              filled: true,
              fillColor: widget.inputFillColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blueAccent),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetchUsers(refresh: true),
            backgroundColor: widget.surfaceColor,
            color: Colors.blue,
            child: _users.isEmpty && !_isLoading
                ? Center(
                    child: Text(
                      'لا يوجد مستخدمين',
                      style: TextStyle(color: widget.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: _users.length + (_hasMore ? 1 : 0),
                    itemBuilder: (ctx, index) {
                      if (index == _users.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _buildUserCard(_users[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final userId = user['id'];
    final username = user['username'] ?? 'مستخدم';
    final email = user['email'] ?? '';
    final profileImage = user['profileImageUrl'];
    final isBanned = user['isBanned'] == true;
    final isAdmin = user['isAdmin'] == true;
    final isVerified = user['isVerified'] == true;
    final isOnline = user['isOnline'] == true;

    return InkWell(
      onTap: () => _openUserProfile(userId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.inputFillColor,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: widget.inputFillColor,
                      backgroundImage: profileImage != null
                          ? CachedNetworkImageProvider(profileImage)
                          : null,
                      child: profileImage == null
                          ? Icon(Icons.person, color: widget.textSecondary)
                          : null,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.surfaceColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            username,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: widget.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (isVerified) const VerifiedBadge(size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: widget.textSecondary,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (isAdmin)
                          _buildStatusChip(
                            'مشرف',
                            Colors.amberAccent,
                            Colors.amber.withOpacity(0.15),
                            Icons.shield,
                          ),
                        if (isBanned)
                          _buildStatusChip(
                            'محظور',
                            Colors.redAccent,
                            Colors.red.withOpacity(0.15),
                            Icons.block,
                          ),
                        if (isVerified)
                          _buildStatusChip(
                            'موثق',
                            Colors.blueAccent,
                            Colors.blue.withOpacity(0.15),
                            Icons.check,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: widget.textSecondary,
                ),
                color: widget.inputFillColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'profile') {
                    _openUserProfile(userId);
                  }
                  if (value == 'verify')
                    _handleAction(userId, 'verify', isVerified);
                  if (value == 'ban') _handleAction(userId, 'ban', isBanned);
                  if (value == 'admin') _handleAction(userId, 'admin', isAdmin);
                },
                itemBuilder: (ctx) => [
                  _buildPopupItem(
                    'profile',
                    'عرض البروفايل',
                    Icons.person_outline,
                    false,
                  ),
                  _buildPopupItem(
                    'verify',
                    isVerified ? 'إلغاء التوثيق' : 'توثيق الحساب',
                    isVerified ? Icons.close : Icons.verified,
                    false,
                  ),
                  _buildPopupItem(
                    'ban',
                    isBanned ? 'فك الحظر' : 'حظر المستخدم',
                    isBanned ? Icons.check_circle : Icons.block,
                    !isBanned,
                  ),
                  _buildPopupItem(
                    'admin',
                    isAdmin ? 'إزالة مشرف' : 'ترقية لمشرف',
                    Icons.security,
                    false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    String label,
    Color textColor,
    Color bgColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    String text,
    IconData icon,
    bool isDestructive,
  ) {
    final color = isDestructive ? Colors.redAccent : widget.textPrimary;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. الإعدادات (داكن)
// ==========================================
class _AppControlTab extends StatefulWidget {
  final Color bgColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color inputFillColor;

  const _AppControlTab(
    this.bgColor,
    this.surfaceColor,
    this.textPrimary,
    this.textSecondary,
    this.inputFillColor,
  );

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
    try {
      final settings = await ApiService.fetchAppSettings();
      if (mounted) {
        setState(() {
          _versionController.text = settings['min_version'] ?? '1.0.0';
          _maintenance = settings['maintenance_mode'] ?? false;
          _msgController.text = settings['maintenance_message'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الإعدادات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadSettings();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم الحفظ بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final inputDecoration = InputDecoration(
      labelStyle: TextStyle(color: widget.textSecondary),
      hintStyle: TextStyle(color: widget.textSecondary.withOpacity(0.5)),
      filled: true,
      fillColor: widget.inputFillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('حالة التطبيق'),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.blueAccent),
              onPressed: _refresh,
              tooltip: 'تحديث الإعدادات',
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: Text(
                  'وضع الصيانة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.textPrimary,
                  ),
                ),
                subtitle: Text(
                  _maintenance ? 'التطبيق مغلق' : 'التطبيق يعمل',
                  style: TextStyle(
                    color: _maintenance ? Colors.redAccent : Colors.greenAccent,
                  ),
                ),
                value: _maintenance,
                activeColor: Colors.redAccent,
                onChanged: (v) => setState(() => _maintenance = v),
              ),
              Divider(height: 1, color: widget.textSecondary.withOpacity(0.2)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _msgController,
                  style: TextStyle(color: widget.textPrimary),
                  decoration: inputDecoration.copyWith(
                    labelText: 'رسالة الصيانة',
                    prefixIcon: Icon(
                      Icons.message_outlined,
                      color: widget.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        _buildSectionHeader('التحديثات'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الحد الأدنى للإصدار',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _versionController,
                style: TextStyle(color: widget.textPrimary),
                decoration: inputDecoration.copyWith(
                  hintText: '1.0.0',
                  prefixIcon: Icon(Icons.numbers, color: widget.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'حفظ الإعدادات',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 5),
      child: Text(
        title,
        style: TextStyle(
          color: widget.textSecondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ==========================================
// 4. مراقبة الشات (داكن)
// ==========================================
class _ChatMonitoringTab extends StatefulWidget {
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;

  const _ChatMonitoringTab(
    this.surfaceColor,
    this.textPrimary,
    this.textSecondary,
  );

  @override
  State<_ChatMonitoringTab> createState() => _ChatMonitoringTabState();
}

class _ChatMonitoringTabState extends State<_ChatMonitoringTab> {
  late Future<List<Map<String, dynamic>>> _chatsFuture;

  @override
  void initState() {
    super.initState();
    _chatsFuture = ApiService.fetchAllChats();
  }

  Future<void> _refreshChats() async {
    setState(() {
      _chatsFuture = ApiService.fetchAllChats();
    });
    await _chatsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshChats,
      backgroundColor: widget.surfaceColor,
      color: Colors.blue,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _chatsFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return Center(
              child: Text(
                'لا توجد محادثات',
                style: TextStyle(color: widget.textSecondary),
              ),
            );

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.length,
            itemBuilder: (ctx, index) {
              final chat = snapshot.data![index];
              return Card(
                elevation: 0,
                color: widget.surfaceColor,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                    child: const Icon(
                      Icons.chat_bubble,
                      color: Colors.blueAccent,
                    ),
                  ),
                  title: Text(
                    'محادثة #${chat['id'].toString().substring(0, 5)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    chat['lastMessage'] ?? '...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: widget.textSecondary),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: widget.textSecondary,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminChatMonitorScreen(
                          chatId: chat['id'],
                          chatData: chat,
                        ),
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

// ==========================================
// 5. البلاغات (داكن)
// ==========================================
class _ReportsAndArchiveTab extends StatefulWidget {
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;

  const _ReportsAndArchiveTab(
    this.surfaceColor,
    this.textPrimary,
    this.textSecondary,
  );

  @override
  State<_ReportsAndArchiveTab> createState() => _ReportsAndArchiveTabState();
}

class _ReportsAndArchiveTabState extends State<_ReportsAndArchiveTab> {
  late Future<List<Map<String, dynamic>>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = ApiService.fetchReports();
  }

  Future<void> _refreshReports() async {
    setState(() {
      _reportsFuture = ApiService.fetchReports();
    });
    await _reportsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportsFuture,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 60,
                  color: Colors.greenAccent.withOpacity(0.5),
                ),
                const SizedBox(height: 10),
                Text(
                  'لا توجد بلاغات',
                  style: TextStyle(color: widget.textSecondary),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshReports,
          backgroundColor: widget.surfaceColor,
          color: Colors.blue,
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.length,
            itemBuilder: (ctx, index) {
              final report = snapshot.data![index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: widget.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(color: Colors.redAccent, width: 4),
                  ),
                ),
                child: ListTile(
                  onTap: () async {
                    // الانتقال لصفحة التفاصيل وانتظار النتيجة (لتحديث القائمة إذا تم الحذف)
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ReportDetailsScreen(report: report),
                      ),
                    );

                    // إذا عاد بـ true (يعني تم حذف البلاغ أو تغييره)، قم بتحديث القائمة
                    if (result == true) {
                      await _refreshReports();
                    }
                  },
                  title: Text(
                    report['reason'] ?? 'سبب غير محدد',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    report['description'] ?? report['details'] ?? '',
                    style: TextStyle(color: widget.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

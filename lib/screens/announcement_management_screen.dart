import 'package:flutter/material.dart';
import 'package:aqar_app/services/api_service.dart';

class AnnouncementManagementScreen extends StatefulWidget {
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color inputFillColor;

  const AnnouncementManagementScreen({
    super.key,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.inputFillColor,
  });

  @override
  State<AnnouncementManagementScreen> createState() =>
      _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState
    extends State<AnnouncementManagementScreen> {
  final _announcementController = TextEditingController();
  final _announcementUrlController = TextEditingController();
  bool _announcementEnabled = false;
  bool _loading = true;
  bool _announcementViewsLoading = false;
  String? _announcementId;
  List<Map<String, dynamic>> _announcementViews = [];

  String _generateAnnouncementId() {
    return 'ann_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _announcementController.dispose();
    _announcementUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await ApiService.fetchAppSettings();
      if (mounted) {
        setState(() {
          _announcementEnabled = settings['announcement_enabled'] == true;
          _announcementController.text =
              settings['announcement_text']?.toString() ?? '';
          _announcementUrlController.text =
              settings['announcement_url']?.toString() ?? '';
          _announcementId = settings['announcement_id']?.toString();
          _loading = false;
        });
      }
      await _loadAnnouncementViews();
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

  Future<void> _loadAnnouncementViews() async {
    final announcementId = _announcementId;
    if (announcementId == null || announcementId.isEmpty) {
      if (mounted) {
        setState(() => _announcementViews = []);
      }
      return;
    }

    setState(() => _announcementViewsLoading = true);
    try {
      final views = await ApiService.fetchAnnouncementViews(announcementId);
      if (mounted) {
        setState(() {
          _announcementViews = views;
          _announcementViewsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _announcementViewsLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تحميل المشاهدات: $e')));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final announcementText = _announcementController.text.trim();
      if (_announcementEnabled && announcementText.isNotEmpty) {
        _announcementId ??= _generateAnnouncementId();
      }

      await ApiService.updateAppSettings({
        'announcement_enabled': _announcementEnabled,
        'announcement_text': announcementText,
        'announcement_url': _announcementUrlController.text,
        if (_announcementId != null) 'announcement_id': _announcementId,
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

  // ✅ حذف مشاهدة واحدة
  Future<void> _deleteView(String viewId, String username) async {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ جاري الحذف...'),
          backgroundColor: Colors.orange,
        ),
      );

      final success = await ApiService.deleteAnnouncementView(viewId);

      if (!mounted) return;

      if (success) {
        setState(() {
          _announcementViews.removeWhere((v) => v['id'] == viewId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حذف المشاهدة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        await _loadAnnouncementViews();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل حذف المشاهدة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ حذف جميع مشاهدات مستخدم معين
  Future<void> _deleteUserViews(String userId, String username) async {
    if (!mounted) return;

    try {
      final announcementId = _announcementId;
      if (announcementId == null || announcementId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ معرف الإعلان غير متوفر'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ جاري الحذف...'),
          backgroundColor: Colors.orange,
        ),
      );

      final (success, deletedCount) =
          await ApiService.deleteUserAnnouncementViews(userId, announcementId);

      if (!mounted) return;

      if (success) {
        setState(() {
          _announcementViews.removeWhere((v) => v['userId'] == userId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم حذف $deletedCount مشاهدة للمستخدم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        await _loadAnnouncementViews();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل حذف مشاهدات المستخدم'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ حذف جميع المشاهدات
  Future<void> _deleteAllViews() async {
    if (!mounted) return;

    try {
      final announcementId = _announcementId;
      if (announcementId == null || announcementId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ معرف الإعلان غير متوفر'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ جاري حذف جميع المشاهدات...'),
          backgroundColor: Colors.orange,
        ),
      );

      final (success, deletedCount) =
          await ApiService.deleteAllAnnouncementViews(announcementId);

      if (!mounted) return;

      if (success) {
        setState(() {
          _announcementViews = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم حذف $deletedCount مشاهدة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        await _loadAnnouncementViews();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل حذف المشاهدات'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ عرض حوار تأكيد حذف مشاهدة واحدة
  void _showDeleteViewConfirmation(String viewId, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.surfaceColor,
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تأكيد الحذف',
                style: TextStyle(color: widget.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد حقاً حذف مشاهدة المستخدم "$username"؟',
          style: TextStyle(color: widget.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: widget.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteView(viewId, username);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  // ✅ عرض حوار تأكيد حذف جميع مشاهدات المستخدم
  void _showDeleteUserViewsConfirmation(String userId, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.surfaceColor,
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تأكيد الحذف',
                style: TextStyle(color: widget.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد حقاً حذف جميع مشاهدات المستخدم "$username"؟',
          style: TextStyle(color: widget.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: widget.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUserViews(userId, username);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف الجميع'),
          ),
        ],
      ),
    );
  }

  // ✅ عرض حوار تأكيد حذف جميع المشاهدات
  void _showDeleteAllViewsConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.surfaceColor,
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '⚠️ تحذير',
                style: TextStyle(color: widget.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد حقاً حذف جميع مشاهدات الإعلان (${_announcementViews.length} مشاهدة)؟\n\nهذا الإجراء لا يمكن التراجع عنه!',
          style: TextStyle(color: widget.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: TextStyle(color: widget.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAllViews();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: widget.surfaceColor,
        appBar: AppBar(
          backgroundColor: widget.surfaceColor,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'إدارة الشريط الإخباري',
            style: TextStyle(
              color: widget.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final inputDecoration = InputDecoration(
      labelStyle: TextStyle(color: widget.textSecondary),
      hintStyle: TextStyle(color: widget.textSecondary.withValues(alpha: 0.5)),
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

    return Scaffold(
      backgroundColor: widget.surfaceColor,
      appBar: AppBar(
        backgroundColor: widget.surfaceColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'إدارة الشريط الإخباري',
          style: TextStyle(
            color: widget.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.blueAccent),
            onPressed: _refresh,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ========== الشريط الإخباري ==========
          _buildSectionHeader('الشريط الإخباري'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.inputFillColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'تفعيل الشريط',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _announcementEnabled ? 'ظاهر للمستخدمين' : 'مخفي حالياً',
                    style: TextStyle(
                      color: _announcementEnabled
                          ? Colors.greenAccent
                          : Colors.red,
                    ),
                  ),
                  value: _announcementEnabled,
                  activeThumbColor: Colors.greenAccent,
                  onChanged: (v) => setState(() => _announcementEnabled = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _announcementController,
                  style: TextStyle(color: widget.textPrimary),
                  maxLines: 3,
                  decoration: inputDecoration.copyWith(
                    labelText: 'نص الشريط الإخباري',
                    prefixIcon: Icon(
                      Icons.campaign_outlined,
                      color: widget.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _announcementUrlController,
                  style: TextStyle(color: widget.textPrimary),
                  decoration: inputDecoration.copyWith(
                    labelText: 'رابط اختياري',
                    hintText: 'https://example.com',
                    prefixIcon: Icon(Icons.link, color: widget.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'حفظ التغييرات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 30),

          // ========== مشاهدات الشريط ==========
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('مشاهدات الشريط'),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.blueAccent,
                ),
                onPressed: _loadAnnouncementViews,
                tooltip: 'تحديث المشاهدات',
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.inputFillColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _announcementViewsLoading
                ? const Center(child: CircularProgressIndicator())
                : _announcementViews.isEmpty
                ? Text(
                    'لا توجد مشاهدات حتى الآن',
                    style: TextStyle(color: widget.textSecondary),
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.visibility,
                                color: widget.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'الإجمالي: ${_announcementViews.length}',
                                style: TextStyle(
                                  color: widget.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (_announcementViews.isNotEmpty)
                            Tooltip(
                              message: 'حذف جميع المشاهدات',
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                iconSize: 18,
                                onPressed: _showDeleteAllViewsConfirmation,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._announcementViews.map((view) {
                        final username = view['username'] ?? 'مجهول';
                        final email = view['email'] ?? '';
                        final viewId = view['id'] ?? '';
                        final userId = view['userId'] ?? '';

                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.person_outline,
                            color: widget.textSecondary,
                          ),
                          title: Text(
                            username,
                            style: TextStyle(color: widget.textPrimary),
                          ),
                          subtitle: email.toString().isEmpty
                              ? null
                              : Text(
                                  email,
                                  style: TextStyle(color: widget.textSecondary),
                                ),
                          trailing: PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: widget.textSecondary,
                            ),
                            color: widget.inputFillColor,
                            onSelected: (value) {
                              if (value == 'delete_single') {
                                _showDeleteViewConfirmation(viewId, username);
                              } else if (value == 'delete_user') {
                                _showDeleteUserViewsConfirmation(
                                  userId,
                                  username,
                                );
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem<String>(
                                value: 'delete_single',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'حذف هذه المشاهدة',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete_user',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_sweep,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'حذف جميع مشاهدات المستخدم',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
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
          fontSize: 16,
        ),
      ),
    );
  }
}

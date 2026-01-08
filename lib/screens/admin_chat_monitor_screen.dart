import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:aqar_app/services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// شاشة مراقبة محادثة معينة - عرض جميع الرسائل مع المشاركين
class AdminChatMonitorScreen extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> chatData;

  const AdminChatMonitorScreen({
    super.key,
    required this.chatId,
    required this.chatData,
  });

  @override
  State<AdminChatMonitorScreen> createState() => _AdminChatMonitorScreenState();
}

class _AdminChatMonitorScreenState extends State<AdminChatMonitorScreen> {
  Map<String, dynamic>? _chatDetails;
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;
  String? _error;

  // ألوان التصميم الداكن
  final Color backgroundColor = const Color(0xFF111827);
  final Color surfaceColor = const Color(0xFF1F2937);
  final Color cardColor = const Color(0xFF374151);
  final Color textPrimary = const Color(0xFFF3F4F6);
  final Color textSecondary = const Color(0xFF9CA3AF);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color accentOrange = const Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _loadChatMessages();
  }

  Future<void> _loadChatMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('📥 [API] Fetching messages for chat: ${widget.chatId}');

      // ✅ استخدام fetchAdminChatMessages التي ترجع Map كامل
      final Map<String, dynamic>? data =
          await ApiService.fetchAdminChatMessages(widget.chatId);

      print('📊 [Chat Monitor] Data received from server:');
      print('Participants: ${data?['participants']}');
      print('Messages count: ${(data?['messages'] as List?)?.length ?? 0}');

      if (mounted) {
        setState(() {
          _chatDetails = data;
          // استخراج المشاركين من الاستجابة
          _participants =
              (data?['participants'] as List?)
                  ?.map((p) => p as Map<String, dynamic>)
                  .toList() ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ [Chat Monitor] Error loading messages: $e');
      if (mounted) {
        setState(() {
          _error = 'فشل تحميل الرسائل: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ تأكيد الحذف'),
        content: const Text(
          'هل أنت متأكد من حذف هذه المحادثة بالكامل؟\n'
          'سيتم حذف جميع الرسائل ولا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ApiService.deleteChat(widget.chatId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم حذف المحادثة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ فشل حذف المحادثة'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ الحصول على المشاركين من السيرفر أولاً، ثم من widget.chatData كنسخة احتياطية
    print(
      '👥 [Build] user1: ${_participants.isNotEmpty ? _participants[0] : null}',
    );
    print(
      '👥 [Build] user2: ${_participants.length > 1 ? _participants[1] : null}',
    );

    final user1 = _participants.isNotEmpty
        ? _participants[0]
        : (widget.chatData['user1'] as Map<String, dynamic>?);
    final user2 = _participants.length > 1
        ? _participants[1]
        : (widget.chatData['user2'] as Map<String, dynamic>?);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          '🔍 مراقبة المحادثة',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: accentBlue),
            onPressed: _loadChatMessages,
            tooltip: 'تحديث',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.redAccent,
            ),
            onPressed: _deleteChat,
            tooltip: 'حذف المحادثة',
          ),
        ],
      ),
      body: Column(
        children: [
          // معلومات المحادثة
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildUserInfo(user1, 'المستخدم الأول')),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentOrange.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_rounded,
                        color: accentOrange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buildUserInfo(user2, 'المستخدم الثاني')),
                  ],
                ),
                Divider(height: 24, color: textSecondary.withOpacity(0.2)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoChip(
                      Icons.chat,
                      'الرسائل: ${_chatDetails?['totalMessages'] ?? widget.chatData['messagesCount'] ?? 0}',
                    ),
                    if (widget.chatData['lastMessageTimestamp'] != null)
                      _buildInfoChip(
                        Icons.access_time,
                        'آخر رسالة: ${_formatTimestamp(widget.chatData['lastMessageTimestamp'])}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // قائمة الرسائل
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadChatMessages,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : _buildMessagesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(Map<String, dynamic>? user, String label) {
    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: user['profileImage'] != null
                      ? CachedNetworkImageProvider(user['profileImage'])
                      : null,
                  child: user['profileImage'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['username'] ?? 'مستخدم',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user['email'] ?? '',
                        style: TextStyle(fontSize: 10, color: textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (user['isOnline'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 6, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'متصل',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (user['isBanned'] == true)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, size: 10, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'محظور',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentBlue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentBlue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accentBlue),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    final messages = _chatDetails?['messages'] as List<dynamic>? ?? [];

    print('📋 [Messages List] Messages count: ${messages.length}');
    print(
      '📋 [Messages List] user1: ${_participants.isNotEmpty ? _participants[0] : null}',
    );
    print(
      '📋 [Messages List] user2: ${_participants.length > 1 ? _participants[1] : null}',
    );

    if (messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد رسائل في هذه المحادثة'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (ctx, index) {
        final message = messages[index] as Map<String, dynamic>;
        print(
          '📨 [Message $index] ${message['senderId']} - ${message['senderName']} - ${message['text']}',
        );

        final senderId = message['senderId'];

        // استخدام المشاركين من السيرفر أولاً
        final user1 = _participants.isNotEmpty
            ? _participants[0]
            : (widget.chatData['user1'] as Map<String, dynamic>?);
        final user2 = _participants.length > 1
            ? _participants[1]
            : (widget.chatData['user2'] as Map<String, dynamic>?);

        final isUser1 = senderId == user1?['id'];

        // ✅ استخدام senderName من السيرفر إن وُجد
        final senderName =
            message['senderName'] as String? ??
            (isUser1
                ? (user1?['username'] ?? 'مستخدم 1')
                : (user2?['username'] ?? 'مستخدم 2'));

        return Align(
          alignment: isUser1 ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isUser1
                      ? [
                          accentBlue.withOpacity(0.2),
                          accentBlue.withOpacity(0.1),
                        ]
                      : [cardColor, surfaceColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUser1
                      ? accentBlue.withOpacity(0.3)
                      : Colors.white.withOpacity(0.05),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ اسم المرسل من السيرفر
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isUser1 ? accentBlue : accentOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          senderName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isUser1 ? accentBlue : accentOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // نص الرسالة - دعم text و content
                    if ((message['text'] ?? message['content'])
                            ?.toString()
                            .isNotEmpty ==
                        true)
                      Text(
                        (message['text'] ?? message['content']).toString(),
                        style: TextStyle(
                          fontSize: 14,
                          color: textPrimary,
                          height: 1.4,
                        ),
                      ),
                    // الصور (إن وجدت) - دعم imageUrls و images
                    if ((message['imageUrls'] ?? message['images']) != null)
                      ..._buildMessageImages(
                        (message['imageUrls'] ?? message['images'])
                            as List<dynamic>,
                      ),
                    const SizedBox(height: 8),
                    // ✅ التوقيت - دعم timestamp و createdAt
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(
                            message['timestamp'] ?? message['createdAt'],
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMessageImages(List<dynamic> imageUrls) {
    return imageUrls.map((url) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: url.toString(),
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 150,
              color: Colors.grey.shade300,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              height: 150,
              color: Colors.grey.shade300,
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
      );
    }).toList();
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'غير معروف';

      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is Map && timestamp.containsKey('_seconds')) {
        // ✅ دعم Firestore Timestamp
        dateTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp['_seconds'] * 1000,
        );
      } else {
        return 'غير معروف';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return intl.DateFormat('HH:mm').format(dateTime);
      } else if (difference.inDays < 7) {
        return intl.DateFormat('EEEE HH:mm', 'ar').format(dateTime);
      } else {
        return intl.DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      }
    } catch (e) {
      return 'غير معروف';
    }
  }
}

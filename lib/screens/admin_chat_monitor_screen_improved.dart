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
      appBar: AppBar(
        title: const Text('🔍 مراقبة المحادثة'),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChatMessages,
            tooltip: 'تحديث',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: _deleteChat,
            tooltip: 'حذف المحادثة',
          ),
        ],
      ),
      body: Column(
        children: [
          // معلومات المحادثة
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildUserInfo(user1, 'المستخدم الأول')),
                    const SizedBox(width: 16),
                    const Icon(Icons.chat_bubble, color: Colors.orange),
                    const SizedBox(width: 16),
                    Expanded(child: _buildUserInfo(user2, 'المستخدم الثاني')),
                  ],
                ),
                const Divider(height: 24),
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user['email'] ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
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
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'متصل',
                      style: TextStyle(color: Colors.white, fontSize: 10),
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
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'محظور',
                      style: TextStyle(color: Colors.white, fontSize: 10),
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
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.blue.shade50,
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
            child: Card(
              color: isUser1 ? Colors.blue.shade50 : Colors.grey.shade100,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ اسم المرسل من السيرفر
                    Text(
                      senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isUser1
                            ? Colors.blue.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // نص الرسالة - دعم text و content
                    if ((message['text'] ?? message['content'])
                            ?.toString()
                            .isNotEmpty ==
                        true)
                      Text(
                        (message['text'] ?? message['content']).toString(),
                        style: const TextStyle(fontSize: 14),
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
                          Icons.access_time,
                          size: 10,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(
                            message['timestamp'] ?? message['createdAt'],
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
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

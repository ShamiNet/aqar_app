import 'dart:async';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;

class ChatMessagesScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String recipientName;

  const ChatMessagesScreen({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  State<ChatMessagesScreen> createState() => _ChatMessagesScreenState();
}

class _ChatMessagesScreenState extends State<ChatMessagesScreen> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  Timer? _pollTimer;
  String? _myId;

  // 🎨 الألوان (مطابقة لصفحة مراقبة المحادثة)
  final Color _primaryColor = const Color(0xFF2563EB); // لون الشريط العلوي
  final Color _backgroundColor = const Color(0xFFF3F4F6); // خلفية الصفحة

  @override
  void initState() {
    super.initState();
    // ✅ الاستماع للرسائل الجديدة فوراً
    WebSocketService.addListener(_onNewMessage);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _myId = prefs.getString('user_id');
    await _loadMessages();

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages();
    });
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await ApiService.fetchChatMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    setState(() {
      _messages.insert(0, {
        'text': text,
        'senderId': _myId ?? 'ME',
        'isMe': true,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    await ApiService.sendMessage(widget.chatId, text, widget.recipientId);
    _loadMessages();
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime date;
      if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else if (timestamp is int) {
        date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is Map) {
        if (timestamp.containsKey('_seconds')) {
          date = DateTime.fromMillisecondsSinceEpoch(
            timestamp['_seconds'] * 1000,
          );
        } else if (timestamp.containsKey('seconds')) {
          date = DateTime.fromMillisecondsSinceEpoch(
            timestamp['seconds'] * 1000,
          );
        } else {
          return '';
        }
      } else {
        return '';
      }

      return intl.DateFormat('hh:mm a', 'ar').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    // ✅ تنظيف الذاكرة
    WebSocketService.removeListener(_onNewMessage);
    super.dispose();
  }

  // ✅ دالة معالجة الرسالة القادمة
  void _onNewMessage(dynamic data) {
    if (data['type'] == 'chat' && data['chatId'] == widget.chatId) {
      // إذا كانت الرسالة لهذه المحادثة، أضفها للقائمة
      setState(() {
        _messages.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch.toString(), // ID مؤقت
          'text': data['text'] ?? '',
          'senderId': data['senderId'],
          'createdAt': DateTime.now().toIso8601String(), // وقت محلي
          'isMe': false, // لأنها قادمة من الطرف الآخر
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: Text(
                widget.recipientName.isNotEmpty ? widget.recipientName[0] : '?',
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.recipientName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMessages),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _primaryColor))
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, index) {
                      final msg = _messages[index];
                      final senderId = msg['senderId']?.toString();
                      final isMe =
                          msg['isMe'] == true ||
                          (_myId != null && senderId == _myId);
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // 🎨 بناء الفقاعة بنفس ستايل AdminChatMonitorScreen
  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final time = _formatTime(msg['createdAt']);
    // تحديد اسم المرسل ليظهر أعلى الرسالة
    final senderName = isMe ? 'أنا' : widget.recipientName;

    // الألوان - غامقة وتدريجية
    const accentBlue = Color(0xFF1E40AF);
    const accentOrange = Color(0xFFD97706);
    const textPrimary = Color(0xFFF3F4F6);
    const textSecondary = Color(0xFF9CA3AF);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75, // عرض نسبي
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isMe
                  ? [const Color(0xFF1E40AF), const Color(0xFF1E3A8A)]
                  : [const Color(0xFF374151), const Color(0xFF1F2937)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe
                  ? const Color(0xFF3B82F6).withOpacity(0.4)
                  : Colors.grey.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
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
                // 1. اسم المرسل مع نقطة ملونة
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFFFCD34D),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isMe
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFFFDE047),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // 2. نص الرسالة
                Text(
                  msg['text'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 8),

                // 3. التوقيت مع الأيقونة
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 11,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
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
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _sendMessage,
              borderRadius: BorderRadius.circular(50),
              child: CircleAvatar(
                backgroundColor: _primaryColor,
                radius: 24,
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

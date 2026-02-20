import 'dart:async';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:aqar_app/providers/chat_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aqar_app/screens/property_details_screen.dart';

class ChatMessagesScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String recipientName;
  final String? propertyId;
  final String? propertyTitle;
  final String? propertyImage;
  final String? propertyPrice;

  const ChatMessagesScreen({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
    this.propertyId,
    this.propertyTitle,
    this.propertyImage,
    this.propertyPrice,
  });

  @override
  State<ChatMessagesScreen> createState() => _ChatMessagesScreenState();
}

class _ChatMessagesScreenState extends State<ChatMessagesScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  Timer? _pollTimer;
  String? _myId;

  @override
  void initState() {
    super.initState();
    WebSocketService.addListener(_onNewMessage);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _myId = prefs.getString('user_id');
    await _loadMessages();
    await ApiService.markChatAsRead(widget.chatId);
    if (mounted) _updateGlobalUnreadCount();

    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadMessages();
    });
  }

  Future<void> _updateGlobalUnreadCount() async {
    try {
      final chats = await ApiService.fetchMyChats();
      int totalUnread = 0;
      for (var chat in chats) {
        totalUnread += (chat['unreadCount'] ?? 0) as int;
      }
      if (mounted)
        Provider.of<ChatProvider>(
          context,
          listen: false,
        ).setUnreadChatsCount(totalUnread);
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await ApiService.fetchChatMessages(widget.chatId);
      if (mounted)
        setState(() {
          _messages = msgs;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

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
        // معالجة Firestore Timestamp
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
    } catch (_) {
      return '';
    }
  }

  void _onNewMessage(dynamic data) {
    if (data['type'] == 'chat' && data['chatId'] == widget.chatId) {
      setState(() {
        _messages.insert(0, {
          'text': data['text'],
          'senderId': data['senderId'],
          'isMe': false,
          'createdAt':
              data['createdAt'] ??
              data['timestamp'] ??
              DateTime.now().toIso8601String(),
        });
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    WebSocketService.removeListener(_onNewMessage);
    _updateGlobalUnreadCount();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final appBarColor = isDark ? const Color(0xFF1E1E1E) : primaryColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: isDark
                  ? primaryColor.withOpacity(0.2)
                  : Colors.white,
              radius: 18,
              child: Text(
                widget.recipientName.isNotEmpty ? widget.recipientName[0] : '?',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.recipientName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: appBarColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (widget.propertyId != null)
            _buildPropertyCard(isDark, primaryColor),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, index) => _buildMessageBubble(
                      _messages[index],
                      isDark,
                      primaryColor,
                    ),
                  ),
          ),
          _buildInputArea(isDark, primaryColor),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isDark,
    Color primaryColor,
  ) {
    final senderId = msg['senderId']?.toString();
    final bool isMe =
        msg['isMe'] == true || (_myId != null && senderId == _myId);
    final time = _formatTime(msg['createdAt']);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isMe
                ? (isDark
                      ? [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)]
                      : [primaryColor, primaryColor.withBlue(200)])
                : (isDark
                      ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
                      : [Colors.white, Colors.grey.shade100]),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg['text'] ?? '',
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (widget.propertyId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PropertyDetailsScreen(propertyId: widget.propertyId!),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.propertyImage != null
                      ? CachedNetworkImage(
                          imageUrl: widget.propertyImage!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade300,
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade300,
                          child: Icon(
                            Icons.home,
                            color: Colors.grey.shade600,
                            size: 40,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.home_work, size: 16, color: primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'العقار المعروض',
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.propertyTitle ?? 'عقار للبيع',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (widget.propertyPrice != null)
                        Text(
                          widget.propertyPrice!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: primaryColor,
              child: IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

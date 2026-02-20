import 'dart:async';
import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/services/websocket_service.dart';
import 'package:aqar_app/providers/chat_provider.dart'; // ✅
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart'; // ✅

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _currentUserId;
  Timer? _pollTimer;
  bool _useWebSocket = true;

  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _loadCurrentUser().then((_) {
      _loadChats();
      if (_useWebSocket && _currentUserId != null) {
        _initWebSocket();
      } else {
        _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          _loadChatsInBackground();
        });
      }
    });

    _searchController.addListener(_filterChats);
  }

  void _initWebSocket() {
    WebSocketService.addListener(_onWebSocketData);
    if (_currentUserId != null) {
      WebSocketService.connect(_currentUserId!);
    }
  }

  void _onWebSocketData(dynamic data) {
    if (data['type'] == 'chats_update' || data['type'] == 'new_message') {
      _loadChatsInBackground();
    }
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredChats = List.from(_chats);
      } else {
        _filteredChats = _chats.where((chat) {
          final names = chat['participantNames'] ?? {};
          final lastMessage = (chat['lastMessage'] ?? '')
              .toString()
              .toLowerCase();
          final propertyTitle = (chat['propertyTitle'] ?? '')
              .toString()
              .toLowerCase();
          bool nameMatch = false;
          names.forEach((key, value) {
            if (key != _currentUserId &&
                value.toString().toLowerCase().contains(query)) {
              nameMatch = true;
            }
          });
          return nameMatch ||
              lastMessage.contains(query) ||
              propertyTitle.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('user_id');
    });
  }

  void _updateUnreadCount() {
    int totalUnread = 0;
    for (var chat in _chats) {
      totalUnread += (chat['unreadCount'] ?? 0) as int;
    }
    Provider.of<ChatProvider>(
      context,
      listen: false,
    ).setUnreadChatsCount(totalUnread);
  }

  Future<void> _loadChats() async {
    if (_chats.isEmpty) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      final chats = await ApiService.fetchMyChats();
      if (mounted) {
        setState(() {
          _chats = chats;
          _filterChats();
          _isLoading = false;
        });
        _updateUnreadCount();
        _animationController.forward();
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          if (_chats.isEmpty) _hasError = true;
        });
    }
  }

  Future<void> _loadChatsInBackground() async {
    try {
      final chats = await ApiService.fetchMyChats();
      if (mounted) {
        setState(() {
          _chats = chats;
          _filterChats();
        });
        _updateUnreadCount();
      }
    } catch (_) {}
  }

  String _formatChatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime messageTime;
      if (timestamp is int)
        messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      else if (timestamp is String)
        messageTime = DateTime.parse(timestamp);
      else
        return '';

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (DateTime(messageTime.year, messageTime.month, messageTime.day) ==
          today) {
        return intl.DateFormat('HH:mm').format(messageTime);
      }
      return intl.DateFormat('dd/MM').format(messageTime);
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WebSocketService.removeListener(_onWebSocketData);
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar(Color fillColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _searchController,
          textDirection: TextDirection.rtl,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'ابحث في المحادثات...',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isDark ? Colors.grey.shade500 : Colors.grey,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد محادثات نشطة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'فشل تحميل المحادثات',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          TextButton(
            onPressed: _loadChats,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(
    Map<String, dynamic> chatData,
    Color textColor,
    Color subTextColor,
    Color cardColor,
    bool isDark,
  ) {
    final chatId = chatData['id'] ?? 'unknown';
    final Map<String, dynamic> names = chatData['participantNames'] ?? {};
    String recipientName = 'مستخدم';
    String recipientId = '';

    names.forEach((key, value) {
      if (key != _currentUserId) {
        recipientId = key;
        recipientName = value.toString();
      }
    });

    final unreadCount = chatData['unreadCount'] ?? 0;
    final propertyImageUrl = chatData['propertyImageUrl'];
    final propertyId = chatData['propertyId'];
    final propertyTitle = chatData['propertyTitle'];
    final propertyPrice = chatData['propertyPrice'];
    final isOnline = chatData['isOnline'] ?? false;
    String timeString = _formatChatTime(chatData['lastMessageTime']);

    return InkWell(
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (ctx) => ChatMessagesScreen(
                  chatId: chatId,
                  recipientId: recipientId,
                  recipientName: recipientName,
                  propertyId: propertyId,
                  propertyTitle: propertyTitle,
                  propertyImage: propertyImageUrl,
                  propertyPrice: propertyPrice,
                ),
              ),
            )
            .then((_) => _loadChats());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: unreadCount > 0
            ? (isDark
                  ? Colors.blue.withOpacity(0.05)
                  : Colors.blue.withOpacity(0.02))
            : Colors.transparent,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade100,
                  backgroundImage: propertyImageUrl != null
                      ? CachedNetworkImageProvider(propertyImageUrl)
                      : null,
                  child: propertyImageUrl == null
                      ? Text(
                          recipientName.isNotEmpty ? recipientName[0] : '؟',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF121212)
                              : Colors.white,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        recipientName,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                      Text(
                        timeString,
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0
                              ? Theme.of(context).primaryColor
                              : subTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chatData['lastMessage'] ?? 'بدأ محادثة جديدة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: unreadCount > 0 ? textColor : subTextColor,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(
    Color textColor,
    Color subTextColor,
    Color cardColor,
    bool isDark,
  ) {
    if (_filteredChats.isEmpty) return _buildEmptyState(isDark);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _filteredChats.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        ),
        itemBuilder: (ctx, index) => _buildChatItem(
          _filteredChats[index],
          textColor,
          subTextColor,
          cardColor,
          isDark,
        ),
      ),
    );
  }

  Widget _buildLoginRequired(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 80,
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'يرجى تسجيل الدخول للوصول إلى المحادثات',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ متغيرات الألوان المتكيفة مع الثيم
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final searchFillColor = isDark
        ? Colors.grey.shade900
        : Colors.grey.shade100;

    return FutureBuilder<bool>(
      future: ApiService.isLoggedIn(),
      builder: (ctx, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!authSnapshot.hasData || !authSnapshot.data!)
          return _buildLoginRequired(isDark);

        return Column(
          children: [
            _buildSearchBar(searchFillColor, isDark),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadChats,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                    ? _buildErrorState()
                    : _buildChatList(
                        textColor,
                        subTextColor,
                        cardColor,
                        isDark,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

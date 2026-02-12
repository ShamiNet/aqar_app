import 'dart:async';
import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/services/websocket_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';

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
    debugPrint('🔥 [ChatsScreen] Initializing...');

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
      debugPrint('💬 [ChatsScreen] WebSocket notification received');
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
    debugPrint(' [ChatsScreen] Current user ID: $_currentUserId');
  }

  Future<void> _loadChats() async {
    if (_chats.isEmpty) {
      debugPrint('📥 [ChatsScreen] Fetching chats from server...');
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
          _hasError = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      debugPrint('❌ [ChatsScreen] Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_chats.isEmpty) {
            _hasError = true;
            _errorMessage = 'فشل تحميل المحادثات. الرجاء المحاولة مرة أخرى.';
          }
        });
      }
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
      }
    } catch (e) {
      debugPrint('⚠️ [ChatsScreen] Background update error: $e');
    }
  }

  String _formatChatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      DateTime messageTime;
      if (timestamp is int) {
        messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        messageTime = DateTime.parse(timestamp);
      } else {
        return '';
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final messageDate = DateTime(
        messageTime.year,
        messageTime.month,
        messageTime.day,
      );

      if (messageDate == today) {
        return intl.DateFormat('HH:mm').format(messageTime);
      } else if (messageDate == yesterday) {
        return 'أمس';
      } else if (now.difference(messageTime).inDays < 7) {
        return intl.DateFormat('EEEE', 'ar').format(messageTime);
      } else {
        return intl.DateFormat('dd/MM/yyyy').format(messageTime);
      }
    } catch (e) {
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'ابحث في المحادثات...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _filterChats();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد محادثات نشطة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تواصل مع أصحاب العقارات للبدء',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadChats,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chatData) {
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

    if (recipientId.isEmpty && names.isNotEmpty) {
      recipientId = _currentUserId ?? '';
      recipientName = 'أنا';
    }

    final lastMessage = chatData['lastMessage'] ?? '';
    final lastMessageTime = chatData['lastMessageTime'];
    final unreadCount = chatData['unreadCount'] ?? 0;
    final propertyImageUrl = chatData['propertyImageUrl'];
    final propertyTitle = chatData['propertyTitle'];
    final isOnline = chatData['isOnline'] ?? false;

    String timeString = _formatChatTime(lastMessageTime);

    return Dismissible(
      key: Key(chatId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف المحادثة'),
            content: const Text('هل أنت متأكد من حذف هذه المحادثة؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () {
                  ApiService.deleteChat(chatId);
                  Navigator.of(ctx).pop(true);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: unreadCount > 0
            ? Theme.of(context).primaryColor.withOpacity(0.05)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (ctx) => ChatMessagesScreen(
                      chatId: chatId,
                      recipientId: recipientId,
                      recipientName: recipientName,
                    ),
                  ),
                )
                .then((_) => _loadChats());
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[100],
                        backgroundImage: propertyImageUrl != null
                            ? CachedNetworkImageProvider(propertyImageUrl)
                            : null,
                        child: propertyImageUrl == null
                            ? Text(
                                recipientName.isNotEmpty
                                    ? recipientName[0]
                                    : '؟',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            : null,
                      ),
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
                            border: Border.all(color: Colors.white, width: 2),
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
                          Expanded(
                            child: Text(
                              recipientName,
                              style: TextStyle(
                                fontWeight: unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            timeString,
                            style: TextStyle(
                              fontSize: 12,
                              color: unreadCount > 0
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage.isNotEmpty
                                  ? lastMessage
                                  : 'بدأ محادثة جديدة',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: unreadCount > 0
                                    ? Colors.black87
                                    : Colors.grey[600],
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ApiService.isLoggedIn(),
      builder: (ctx, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!authSnapshot.hasData || !authSnapshot.data!) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'يرجى تسجيل الدخول للوصول إلى المحادثات',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // شريط البحث دائماً في الأعلى
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadChats,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                    ? _buildErrorState()
                    : _filteredChats.isEmpty
                    // هنا التعديل: نتحقق من حقل البحث بدلاً من المتغير
                    ? _searchController.text.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 80,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد نتائج للبحث',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildEmptyState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _filteredChats.length,
                          itemBuilder: (ctx, index) {
                            return _buildChatItem(_filteredChats[index]);
                          },
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

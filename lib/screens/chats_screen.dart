import 'dart:async';

import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:aqar_app/services/api_service.dart'; //  استخدام السيرفر
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  Future<List<Map<String, dynamic>>>? _chatsFuture;
  String? _currentUserId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    debugPrint(' [ChatsScreen] Initializing...');
    _loadCurrentUser();
    _loadChats();

    // Polling بسيط لتحديث قائمة المحادثات كل 5 ثوانٍ
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadChats();
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
    debugPrint(' [ChatsScreen] Fetching chats from server...');
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _chatsFuture = ApiService.fetchMyChats();
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ApiService.isLoggedIn(),
      builder: (ctx, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authSnapshot.hasData || !authSnapshot.data!) {
          return const Scaffold(
            body: Center(child: Text('يرجى تسجيل الدخول.')),
          );
        }

        return Scaffold(
          body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _chatsFuture,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                debugPrint(' [ChatsScreen] Error: ${snapshot.error}');
                return const Center(child: Text('حدث خطأ في جلب المحادثات.'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد محادثات نشطة.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              final chatDocs = snapshot.data!;
              debugPrint(' [ChatsScreen] Loaded ${chatDocs.length} chats.');

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: chatDocs.length,
                separatorBuilder: (ctx, index) => const SizedBox(height: 8),
                itemBuilder: (ctx, index) {
                  final chatData = chatDocs[index];
                  final chatId = chatData['id'] ?? 'unknown';

                  final Map<String, dynamic> names =
                      chatData['participantNames'] ?? {};
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
                  String timeString = '';

                  final propertyImageUrl = chatData['propertyImageUrl'];
                  final propertyTitle = chatData['propertyTitle'];

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        backgroundImage: propertyImageUrl != null
                            ? CachedNetworkImageProvider(propertyImageUrl)
                            : null,
                        child: propertyImageUrl == null
                            ? Text(
                                recipientName.isNotEmpty
                                    ? recipientName[0]
                                    : '?',
                              )
                            : null,
                      ),
                      title: Text(
                        recipientName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (propertyTitle != null)
                            Text(
                              propertyTitle,
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 12,
                              ),
                            ),
                          Text(
                            lastMessage.isNotEmpty ? lastMessage : 'صورة ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: Text(
                        timeString,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

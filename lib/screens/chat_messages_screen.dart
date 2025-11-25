import 'dart:async';
import 'package:aqar_app/screens/public_profile_screen.dart';
import 'package:aqar_app/widgets/full_screen_gallery.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  final _messageController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleTyping);
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleTyping);
    _messageController.dispose();
    _typingTimer?.cancel();
    if (_currentUser != null) {
      _updateTypingStatus(false);
    }
    super.dispose();
  }

  void _handleTyping() {
    if (_currentUser == null) return;
    if (!_isTyping) {
      _isTyping = true;
      _updateTypingStatus(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      _updateTypingStatus(false);
    });
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'typingStatus.${_currentUser!.uid}': isTyping});
    } catch (e) {
      // ignore
    }
  }

  // 🛡️ نظام الحماية وفلترة الرسائل 🛡️
  bool _validateMessage(String text) {
    // 1. منع أرقام الهواتف (سلسلة من 8 أرقام أو أكثر)
    // هذا النمط يكشف الأرقام حتى لو كان بينها مسافات أو فواصل
    final phoneRegex = RegExp(r'(\d[\s-]?){8,}');

    // 2. منع معرفات التواصل الاجتماعي والكلمات المحظورة
    final forbiddenWords = [
      'واتس',
      'whatsapp',
      'سناب',
      'snapchat',
      'انستا',
      'instagram',
      'تليجرام',
      'telegram',
      'رقمي',
      'اتصل بي',
      'هاتفي',
      'جوالي',
      '05',
      '+966',
      'gmail.com',
      '@',
    ];

    // التحقق من الأرقام
    if (phoneRegex.hasMatch(text)) {
      _showWarning(
        'يمنع إرسال أرقام الهواتف. الرجاء التواصل داخل التطبيق فقط حفاظاً على أمانك.',
      );
      return false;
    }

    // التحقق من الكلمات المحظورة
    for (String word in forbiddenWords) {
      if (text.toLowerCase().contains(word)) {
        _showWarning(
          'يمنع مشاركة حسابات التواصل الخارجي. الرجاء الالتزام بسياسة التطبيق.',
        );
        return false;
      }
    }

    return true;
  }

  void _showWarning(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.red),
            SizedBox(width: 8),
            Text('تنبيه أمني'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _currentUser == null) return;

    // 🛑 تشغيل الفلتر قبل الإرسال
    if (!_validateMessage(messageText)) return;

    _typingTimer?.cancel();
    _isTyping = false;
    _updateTypingStatus(false);
    _messageController.clear();

    try {
      final messageData = {
        'text': messageText,
        'createdAt': Timestamp.now(),
        'senderId': _currentUser!.uid,
        'isEdited': false, // حقل جديد لمعرفة هل تم التعديل
      };

      final batch = FirebaseFirestore.instance.batch();
      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, messageData);

      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId);
      batch.update(chatRef, {
        'lastMessage': messageText,
        'lastMessageTimestamp': Timestamp.now(),
        'lastSenderId': _currentUser!.uid,
        'participants': FieldValue.arrayUnion([
          widget.recipientId,
          _currentUser!.uid,
        ]),
      });

      await batch.commit();

      // إشعار
      String myName = _currentUser!.displayName ?? 'مستخدم';
      if (_currentUser!.displayName == null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .get();
          if (userDoc.exists) {
            myName = userDoc.data()?['username'] ?? 'مستخدم';
          }
        } catch (e) {
          /* ignore */
        }
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.recipientId,
        'title': 'رسالة جديدة من $myName',
        'body': messageText,
        'type': 'chat_message',
        'screen': 'chat',
        'chatId': widget.chatId,
        'recipientId': _currentUser!.uid,
        'recipientName': myName,
        'image': _currentUser!.photoURL,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  // 🗑️ حذف الرسالة
  void _deleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الرسالة'),
        content: const Text('هل أنت متأكد من حذف هذه الرسالة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .doc(messageId)
                  .delete();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ✏️ تعديل الرسالة
  void _editMessage(String messageId, String oldText) {
    final editController = TextEditingController(text: oldText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الرسالة'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != oldText) {
                // التحقق من النص المعدل أيضاً!
                if (!_validateMessage(newText)) return;

                Navigator.of(ctx).pop();
                await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .doc(messageId)
                    .update({'text': newText, 'isEdited': true});
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .get(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final img = data?['propertyImageUrl'];
                if (img != null) {
                  return CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(img),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublicProfileScreen(
                      userId: widget.recipientId,
                      userName: widget.recipientName,
                    ),
                  ),
                ),
                child: Text(
                  widget.recipientName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, messagesSnapshot) {
                if (messagesSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = messagesSnapshot.data?.docs ?? [];

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (ctx, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final messageId = messages[index].id;
                    final isMe = message['senderId'] == _currentUser?.uid;

                    return _MessageBubble(
                      message: message['text'],
                      isMe: isMe,
                      timestamp: message['createdAt'],
                      isEdited: message['isEdited'] ?? false,
                      onLongPress: isMe
                          ? () {
                              // إظهار قائمة الخيارات
                              showModalBottomSheet(
                                context: context,
                                builder: (ctx) => Wrap(
                                  children: [
                                    ListTile(
                                      leading: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      title: const Text('تعديل'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _editMessage(
                                          messageId,
                                          message['text'],
                                        );
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      title: const Text('حذف'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _deleteMessage(messageId);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          _MessageInput(controller: _messageController, onSend: _sendMessage),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final Timestamp? timestamp;
  final bool isEdited;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.timestamp,
    this.isEdited = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = timestamp != null
        ? intl.DateFormat.jm().format(timestamp!.toDate())
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress, // تفعيل الضغط المطول
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: isMe
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe
                  ? const Radius.circular(16)
                  : const Radius.circular(0),
              bottomRight: isMe
                  ? const Radius.circular(0)
                  : const Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(message, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEdited)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '(معدل)',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                  Text(
                    time,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInput({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالتك هنا...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(icon: const Icon(Icons.send), onPressed: onSend),
          ],
        ),
      ),
    );
  }
}

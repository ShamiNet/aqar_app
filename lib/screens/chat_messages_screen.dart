import 'dart:async';
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
    // Set typing status to false when leaving the screen
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

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _currentUser == null) {
      return;
    }

    // Stop the typing indicator immediately on send
    _typingTimer?.cancel();
    _isTyping = false;
    _updateTypingStatus(false);
    FocusScope.of(context).unfocus();
    // Clear the controller optimistically. We can restore the text on failure.
    _messageController.clear();

    try {
      final messageData = {
        'text': messageText,
        'createdAt': Timestamp.now(),
        'senderId': _currentUser!.uid,
      };

      // Use a batch write to ensure atomicity
      final batch = FirebaseFirestore.instance.batch();

      // 1. Add message to the messages subcollection
      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();
      batch.set(messageRef, messageData);

      // 2. Update the last message in the chat document
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId);
      batch.update(chatRef, {
        'lastMessage': messageText,
        'lastMessageTimestamp': Timestamp.now(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint(
        '[ChatMessagesScreen] _sendMessage: Error sending message: $e',
      );
      if (mounted) {
        _messageController.text = messageText; // Restore text
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل إرسال الرسالة. الرجاء المحاولة مرة أخرى.'),
          ),
        );
      }
    }
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'typingStatus.${_currentUser!.uid}': isTyping});
    } catch (e) {
      debugPrint(
        '[ChatMessagesScreen] _updateTypingStatus: Error updating status: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .snapshots(),
        builder: (context, chatDocSnapshot) {
          final chatData =
              chatDocSnapshot.data?.data() as Map<String, dynamic>?;
          final typingStatus =
              chatData?['typingStatus'] as Map<String, dynamic>? ?? {};
          final propertyImageUrl = chatData?['propertyImageUrl'] as String?;
          final isRecipientTyping = typingStatus[widget.recipientId] == true;

          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  if (propertyImageUrl != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: CachedNetworkImageProvider(
                        propertyImageUrl,
                      ),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    )
                  else
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: Icon(
                        Icons.house_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Text(widget.recipientName),
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
                      if (!messagesSnapshot.hasData ||
                          messagesSnapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text('لا توجد رسائل بعد. ابدأ المحادثة!'),
                        );
                      }
                      if (messagesSnapshot.hasError) {
                        return const Center(child: Text('حدث خطأ ما...'));
                      }

                      final messages = messagesSnapshot.data!.docs;

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: messages.length,
                        itemBuilder: (ctx, index) {
                          final message =
                              messages[index].data() as Map<String, dynamic>;
                          final isMe = message['senderId'] == _currentUser?.uid;

                          return _MessageBubble(
                            message: message['text'],
                            isMe: isMe,
                            timestamp: message['createdAt'],
                          );
                        },
                      );
                    },
                  ),
                ),
                if (isRecipientTyping)
                  _TypingIndicator(recipientName: widget.recipientName),
                _MessageInput(
                  controller: _messageController,
                  onSend: _sendMessage,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final Timestamp timestamp;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = intl.DateFormat.jm().format(timestamp.toDate());

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
            Text(
              time,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.recipientName});

  final String recipientName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Text(
            '$recipientName يكتب...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          // Optional: Add a typing animation like three dots
        ],
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
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                autocorrect: true,
                enableSuggestions: true,
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالتك هنا...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.send_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

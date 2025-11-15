import 'package:flutter/material.dart';

class ChatMessagesScreen extends StatefulWidget {
  const ChatMessagesScreen({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
  });

  final String chatId;
  final String recipientId;
  final String recipientName;

  @override
  State<ChatMessagesScreen> createState() => _ChatMessagesScreenState();
}

class _ChatMessagesScreenState extends State<ChatMessagesScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.recipientName)),
      body: const Center(child: Text('الرسائل ستظهر هنا قريبًا.')),
      // سنضيف حقل إدخال الرسائل لاحقًا
    );
  }
}

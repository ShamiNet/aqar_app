import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class AdminAllChatsScreen extends StatelessWidget {
  const AdminAllChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراقبة المحادثات (Admin)'),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب كل المحادثات بدون استثناء
        stream: FirebaseFirestore.instance
            .collection('chats')
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('لا توجد محادثات في النظام.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (ctx, index) => const Divider(),
            itemBuilder: (ctx, index) {
              final chatData = docs[index].data() as Map<String, dynamic>;
              final chatId = docs[index].id;

              // بيانات الأطراف
              final Map<String, dynamic> names =
                  chatData['participantNames'] ?? {};
              final namesString = names.values.join(
                ' ↔️ ',
              ); // عرض أسماء الطرفين

              final lastMessage = chatData['lastMessage'] ?? '';
              final timestamp = chatData['lastMessageTimestamp'] as Timestamp?;
              final timeString = timestamp != null
                  ? intl.DateFormat('dd/MM hh:mm a').format(timestamp.toDate())
                  : '';

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.security, color: Colors.white),
                ),
                title: Text(
                  namesString.isEmpty ? 'محادثة مجهولة' : namesString,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                ),
                subtitle: Text(
                  lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  timeString,
                  style: const TextStyle(fontSize: 10),
                ),
                onTap: () {
                  // الدخول للمحادثة بوضع المراقب
                  // نمرر أي ID لأنه مجرد عرض
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatMessagesScreen(
                        chatId: chatId,
                        recipientId: 'admin_monitor', // وهمي
                        recipientName: 'وضع المراقبة',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

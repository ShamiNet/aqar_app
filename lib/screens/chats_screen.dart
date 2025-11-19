import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart' as intl;

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('يرجى تسجيل الدخول لعرض المحادثات.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('المحادثات'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        // جلب المحادثات التي يكون المستخدم الحالي أحد المشاركين فيها
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ في جلب المحادثات.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                    'لا توجد محادثات نشطة بعد.',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final chatDocs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: chatDocs.length,
            separatorBuilder: (ctx, index) => const SizedBox(height: 8),
            itemBuilder: (ctx, index) {
              final chatData = chatDocs[index].data() as Map<String, dynamic>;
              final chatId = chatDocs[index].id;

              // تحديد الطرف الآخر في المحادثة
              final Map<String, dynamic> participantNames =
                  chatData['participantNames'] ?? {};

              String recipientName = 'مستخدم';
              String recipientId = '';

              // البحث عن ID واسم الشخص الذي ليس "أنا"
              participantNames.forEach((key, value) {
                if (key != currentUser.uid) {
                  recipientId = key;
                  recipientName = value.toString();
                }
              });

              // إذا لم نجد طرفاً آخر (مثلاً محادثة مع النفس للتجربة)، نستخدم البيانات الافتراضية
              if (recipientId.isEmpty && participantNames.isNotEmpty) {
                recipientId = currentUser.uid;
                recipientName = 'أنا';
              }

              final lastMessage = chatData['lastMessage'] ?? '';
              final Timestamp? timestamp = chatData['lastMessageTimestamp'];
              final timeString = timestamp != null
                  ? intl.DateFormat('dd/MM hh:mm a').format(timestamp.toDate())
                  : '';

              final propertyImageUrl = chatData['propertyImageUrl'] as String?;
              final propertyTitle = chatData['propertyTitle'] as String?;

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
                            recipientName.isNotEmpty ? recipientName[0] : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          recipientName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeString,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (propertyTitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.home_work_outlined,
                                size: 14,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  propertyTitle,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        lastMessage.isNotEmpty ? lastMessage : 'صورة 📷',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => ChatMessagesScreen(
                          chatId: chatId,
                          recipientId: recipientId,
                          recipientName: recipientName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

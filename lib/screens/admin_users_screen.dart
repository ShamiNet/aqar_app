import 'package:aqar_app/screens/public_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _searchQuery = '';
  final _currentUser = FirebaseAuth.instance.currentUser;

  // دالة الحظر/إلغاء الحظر
  Future<void> _toggleUserBan(
    String userId,
    bool currentBanStatus,
    String userName,
  ) async {
    final shouldBan = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentBanStatus ? 'إلغاء الحظر' : 'حظر المستخدم 🚫'),
        content: Text(
          currentBanStatus
              ? 'هل أنت متأكد من فك الحظر عن $userName؟'
              : 'هل أنت متأكد من حظر $userName؟ لن يتمكن من استخدام التطبيق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentBanStatus ? Colors.green : Colors.red,
            ),
            child: Text(currentBanStatus ? 'فك الحظر' : 'حظر'),
          ),
        ],
      ),
    );

    if (shouldBan == true) {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isBanned': !currentBanStatus,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentBanStatus ? 'تم فك الحظر' : 'تم حظر المستخدم بنجاح',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الإيميل...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا يوجد مستخدمين.'));
          }

          // تصفية المستخدمين حسب البحث
          final users = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['username'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();

          return ListView.builder(
            itemCount: users.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (ctx, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;

              // لا تظهر نفسك في القائمة (حماية من حظر النفس)
              if (userId == _currentUser?.uid) return const SizedBox.shrink();

              final isBanned = userData['isBanned'] == true;
              final userImage = userData['profileImageUrl'];
              final role = userData['role'] ?? 'user';

              return Card(
                color: isBanned ? Colors.red.shade50 : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userImage != null
                        ? CachedNetworkImageProvider(userImage)
                        : null,
                    child: userImage == null ? const Icon(Icons.person) : null,
                  ),
                  title: Row(
                    children: [
                      Text(
                        userData['username'] ?? 'مستخدم',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (role == 'admin')
                        const Padding(
                          padding: EdgeInsets.only(right: 5),
                          child: Icon(
                            Icons.verified_user,
                            color: Colors.blue,
                            size: 16,
                          ),
                        ),
                      if (isBanned)
                        const Padding(
                          padding: EdgeInsets.only(right: 5),
                          child: Chip(
                            label: Text(
                              'محظور',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(userData['email'] ?? '---'),
                  trailing: Switch(
                    value: isBanned,
                    activeColor: Colors.red,
                    onChanged: (_) => _toggleUserBan(
                      userId,
                      isBanned,
                      userData['username'] ?? 'المستخدم',
                    ),
                  ),
                  onTap: () {
                    // الذهاب لصفحة البروفايل لرؤية التفاصيل
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicProfileScreen(
                          userId: userId,
                          userName: userData['username'] ?? '',
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

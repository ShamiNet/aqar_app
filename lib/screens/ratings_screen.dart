import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class RatingsScreen extends StatelessWidget {
  final String targetUserId; // معرف البائع (صاحب البروفايل)
  final String targetUserName;

  const RatingsScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تقييمات $targetUserName'), centerTitle: true),
      body: Column(
        children: [
          _buildRatingSummary(context),
          const Divider(height: 1, thickness: 1),
          Expanded(child: _buildReviewsList(context)),
        ],
      ),
    );
  }

  Widget _buildRatingSummary(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final double score = (userData?['reputationScore'] ?? 0.0).toDouble();
        final int count = (userData?['reputationCount'] ?? 0).toInt();

        return Container(
          padding: const EdgeInsets.all(20),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    score.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text('من 5', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStarDisplay(score, 30),
                  const SizedBox(height: 8),
                  Text(
                    '$count تقييم ومراجعة',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'بناءً على تعاملات المستخدمين',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('reviews')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                const Text('لا توجد تقييمات بعد لهذا المستخدم.'),
              ],
            ),
          );
        }

        final reviews = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          separatorBuilder: (ctx, index) => const SizedBox(height: 16),
          itemBuilder: (ctx, index) {
            final reviewData = reviews[index].data() as Map<String, dynamic>;
            final reviewId = reviews[index].id; // نحتاج المعرف للإبلاغ
            return _ReviewItemCard(
              reviewData: reviewData,
              reviewId: reviewId,
              targetUserId: targetUserId, // لتحديد مسار التقييم بدقة
            );
          },
        );
      },
    );
  }

  Widget _buildStarDisplay(double rating, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        IconData icon;
        if (index < rating.floor()) {
          icon = Icons.star;
        } else if (index < rating && (rating - index) >= 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: Colors.amber, size: size);
      }),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  final Map<String, dynamic> reviewData;
  final String reviewId;
  final String targetUserId;

  // معرف الأدمن لاستقبال البلاغات
  static const String _adminId = 'QzX6w0qA8vflx5oGM3jW4GgW2BC2';

  const _ReviewItemCard({
    required this.reviewData,
    required this.reviewId,
    required this.targetUserId,
  });

  void _reportReview(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول للإبلاغ.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إبلاغ عن تعليق'),
        content: const Text(
          'هل هذا التعليق مسيء أو يخالف القوانين؟ سيتم إرسال بلاغ للإدارة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('إبلاغ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. إضافة البلاغ في مجموعة التقارير (للوحة التحكم)
        await FirebaseFirestore.instance.collection('reports').add({
          'type': 'review_report',
          'reason': 'تعليق مسيء',
          'details': reviewData['comment'] ?? 'لا يوجد نص',
          'targetId': targetUserId, // المستخدم المُقيَّم
          'reviewId': reviewId,
          'reporterId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 2. 🚀 [إشعار] إرسال تنبيه للأدمن
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': _adminId,
          'title': 'بلاغ جديد 🚨',
          'body': 'قام مستخدم بالإبلاغ عن تعليق مسيء في بروفايل أحد الأعضاء.',
          'type': 'report',
          'screen': 'admin_reports', // للتوجيه المستقبلي
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم استلام البلاغ، شكراً لك.')),
          );
        }
      } catch (e) {
        debugPrint('Error reporting review: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewerId = reviewData['reviewerId'];
    final rating = (reviewData['rating'] ?? 0.0).toDouble();
    final comment = reviewData['comment'] ?? '';
    final timestamp = (reviewData['timestamp'] as Timestamp?)?.toDate();
    final dateStr = timestamp != null
        ? intl.DateFormat('dd MMM yyyy').format(timestamp)
        : '';

    final currentUser = FirebaseAuth.instance.currentUser;
    final isMe = currentUser?.uid == reviewerId;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(reviewerId)
          .get(),
      builder: (context, snapshot) {
        String reviewerName = 'مستخدم';
        String? reviewerImage;

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          reviewerName = userData['username'] ?? 'مستخدم';
          reviewerImage = userData['profileImageUrl'];
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: reviewerImage != null
                          ? CachedNetworkImageProvider(reviewerImage)
                          : null,
                      child: reviewerImage == null
                          ? Text(
                              reviewerName.isNotEmpty ? reviewerName[0] : '?',
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reviewerName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (index) => Icon(
                                  index < rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // زر الإبلاغ (لا يظهر إذا كان التعليق لي)
                    if (!isMe)
                      IconButton(
                        icon: const Icon(
                          Icons.flag_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                        tooltip: 'إبلاغ عن التعليق',
                        onPressed: () => _reportReview(context),
                      ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(comment, style: const TextStyle(height: 1.4)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

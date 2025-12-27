import 'package:aqar_app/services/api_service.dart'; // ✅
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // تأكد من وجود المكتبة
import 'package:intl/intl.dart' as intl;

class RatingsScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const RatingsScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  late Future<Map<String, dynamic>> _summaryFuture;
  late Future<List<Map<String, dynamic>>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = ApiService.fetchUserRatingSummary(widget.targetUserId);
    _reviewsFuture = ApiService.fetchUserReviews(widget.targetUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تقييمات ${widget.targetUserName}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildRatingSummary(),
          const Divider(height: 1, thickness: 1),
          Expanded(child: _buildReviewsList()),
        ],
      ),
    );
  }

  Widget _buildRatingSummary() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();

        final data = snapshot.data!;
        final double score = (data['reputationScore'] ?? 0.0).toDouble();
        final int count = (data['reputationCount'] ?? 0).toInt();

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
                  RatingBarIndicator(
                    rating: score,
                    itemBuilder: (context, index) =>
                        const Icon(Icons.star, color: Colors.amber),
                    itemCount: 5,
                    itemSize: 24.0,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$count تقييم ومراجعة',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reviewsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('لا توجد تقييمات بعد.'));
        }

        final reviews = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          separatorBuilder: (ctx, index) => const SizedBox(height: 16),
          itemBuilder: (ctx, index) {
            return _ReviewItemCard(
              reviewData: reviews[index],
              targetUserId: widget.targetUserId,
            );
          },
        );
      },
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  final Map<String, dynamic> reviewData;
  final String targetUserId;

  const _ReviewItemCard({required this.reviewData, required this.targetUserId});

  @override
  Widget build(BuildContext context) {
    final rating = (reviewData['rating'] ?? 0.0).toDouble();
    final comment = reviewData['comment'] ?? '';
    // سيحتاج السيرفر لإرسال اسم المراجع وصورته مع التقييم
    final reviewerName = reviewData['reviewerName'] ?? 'مستخدم';
    final reviewerImage = reviewData['reviewerImage'];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: reviewerImage != null
                      ? CachedNetworkImageProvider(reviewerImage)
                      : null,
                  child: reviewerImage == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewerName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    RatingBarIndicator(
                      rating: rating,
                      itemBuilder: (context, index) =>
                          const Icon(Icons.star, color: Colors.amber),
                      itemCount: 5,
                      itemSize: 14.0,
                    ),
                  ],
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(comment),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// تأكد من إضافة intl في ملف pubspec.yaml لتنسيق التاريخ إذا أردت،
// أو سنستخدم تنسيقاً بسيطاً يدوياً لتجنب الأخطاء الآن.

class MyDealsScreen extends StatelessWidget {
  const MyDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('سجل الصفقات')),
        body: const Center(child: Text('يرجى تسجيل الدخول لعرض سجلاتك.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل الصفقات'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'طلباتي (شراء/إيجار)'),
              Tab(text: 'مبيعاتي (للمشترين)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // التبويب الأول: صفقات أنا فيها المشتري
            _DealsList(fieldName: 'buyerId', uid: user.uid),

            // التبويب الثاني: صفقات أنا فيها البائع
            _DealsList(fieldName: 'sellerId', uid: user.uid),
          ],
        ),
      ),
    );
  }
}

class _DealsList extends StatelessWidget {
  final String fieldName;
  final String uid;

  const _DealsList({required this.fieldName, required this.uid, super.key});

  @override
  Widget build(BuildContext context) {
    // فقط في تبويب المشتري، نقوم بالتحقق من وجود صفقات تحتاج لتقييم
    if (fieldName == 'buyerId') {
      _checkForPendingRatings(context);
    }

    return _buildStream(context);
  }

  // بناء الواجهة الرئيسية للويدجت
  Widget _buildStream(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deals')
          .where(fieldName, isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  fieldName == 'buyerId'
                      ? 'لم تقم بأي عمليات شراء أو استئجار بعد.'
                      : 'لم يتم بيع أو تأجير أي عقار لك بعد.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (ctx, index) {
            final dealData = docs[index].data() as Map<String, dynamic>;
            final propertyId = dealData['propertyId'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('properties')
                  .doc(propertyId)
                  .get(),
              builder: (ctx, propSnapshot) {
                if (!propSnapshot.hasData) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final propertyData = propSnapshot.data!.exists
                    ? propSnapshot.data!.data() as Map<String, dynamic>
                    : null;

                return _buildDealCard(
                  context,
                  dealData,
                  propertyData,
                  propertyId,
                  dealData['buyerId'], // <-- الوسيط المفقود
                  docs[index].id, // <-- معرّف الصفقة
                );
              },
            );
          },
        );
      },
    );
  }

  // --- دوال التقييم الجديدة ---
  Future<void> _checkForPendingRatings(BuildContext context) async {
    final query = await FirebaseFirestore.instance
        .collection('deals')
        .where('buyerId', isEqualTo: uid)
        .where('status', isEqualTo: 'confirmed')
        .where('isBuyerRated', isEqualTo: false)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final dealDoc = query.docs.first;
      final dealData = dealDoc.data();
      final sellerId = dealData['sellerId'];

      // جلب اسم البائع
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();
      final sellerName = sellerDoc.data()?['username'] ?? 'المعلن';

      // تأخير بسيط لإعطاء الواجهة فرصة للرسم
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          _showRatingPromptDialog(context, dealDoc.id, sellerId, sellerName);
        }
      });
    }
  }

  void _showRatingPromptDialog(
    BuildContext context,
    String dealId,
    String sellerId,
    String sellerName,
  ) {
    double selectedRating = 5.0;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('تقييم البائع: $sellerName'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('كيف كانت تجربتك مع هذا المعلن بعد إتمام الصفقة؟'),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (context, setStateSB) {
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return IconButton(
                              onPressed: () {
                                setStateSB(() {
                                  selectedRating = index + 1.0;
                                });
                              },
                              icon: Icon(
                                index < selectedRating
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 32,
                              ),
                            );
                          }),
                        ),
                        Text(
                          'التقييم: ${selectedRating.toInt()} من 5',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reviewController,
                  decoration: const InputDecoration(
                    labelText: 'اكتب تعليقك (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // وضع علامة على أنه تم تخطي التقييم
                FirebaseFirestore.instance
                    .collection('deals')
                    .doc(dealId)
                    .update({'isBuyerRated': true});
              },
              child: const Text('تخطي'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _submitUserRating(
                  context,
                  dealId,
                  sellerId,
                  selectedRating,
                  reviewController.text,
                );
              },
              child: const Text('إرسال التقييم'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitUserRating(
    BuildContext context,
    String dealId,
    String sellerId,
    double rating,
    String review,
  ) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) throw Exception("User does not exist!");

        final data = userSnapshot.data() as Map<String, dynamic>;
        double currentScore = (data['reputationScore'] ?? 0.0).toDouble();
        int currentCount = (data['reputationCount'] ?? 0).toInt();

        double newScore =
            ((currentScore * currentCount) + rating) / (currentCount + 1);
        int newCount = currentCount + 1;

        transaction.update(userRef, {
          'reputationScore': newScore,
          'reputationCount': newCount,
        });

        final reviewRef = userRef.collection('reviews').doc();
        transaction.set(reviewRef, {
          'reviewerId': currentUser.uid,
          'rating': rating,
          'comment': review,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      await FirebaseFirestore.instance.collection('deals').doc(dealId).update({
        'isBuyerRated': true,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال تقييمك بنجاح! شكراً لك.')),
        );
      }
    } catch (e) {
      debugPrint('Failed to submit rating: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إرسال التقييم، حاول مرة أخرى.')),
        );
      }
    }
  }

  // --- دوال التحكم بالصفقة (للبائع) ---
  Future<void> _confirmDeal(
    BuildContext context,
    String dealId,
    String propertyId,
    String dealType,
    String buyerId, // <-- إضافة buyerId
  ) async {
    try {
      // 1. أرشفة العقار أولاً
      final propDocRef = FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId);
      final propSnapshot = await propDocRef.get();

      if (propSnapshot.exists) {
        await FirebaseFirestore.instance.collection('archived_properties').add({
          ...propSnapshot.data()!,
          'originalId': propertyId,
          'archivedAt': FieldValue.serverTimestamp(),
          'archiveReason': dealType == 'إيجار' ? 'تم التأجير' : 'تم البيع',
        });
        final String propertyTitle = propSnapshot.data()?['title'] ?? 'عقار';
        // 2. حذف العقار من القائمة العامة
        await propDocRef.delete();
      }

      // 3. تحديث حالة الصفقة إلى "مؤكدة"
      await FirebaseFirestore.instance.collection('deals').doc(dealId).update({
        'status': 'confirmed',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد الصفقة وأرشفة العقار بنجاح.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $error')));
    }
  }

  void _rejectDeal(
    BuildContext context,
    String dealId,
    String buyerId,
    String propertyTitle, // العنوان لعرضه في الرسالة
    String propertyId, // معرّف العقار للإشعار
  ) {
    FirebaseFirestore.instance
        .collection('deals')
        .doc(dealId)
        .delete()
        .then((_) {
          debugPrint("✅ [Deals] تم حذف الصفقة بنجاح: $dealId");
          // إنشاء مستند إشعار للمشتري
          FirebaseFirestore.instance.collection('notifications').add({
            'userId': buyerId, // إرسال للمشتري
            'title': 'تم رفض طلبك',
            'body': 'للأسف، قام المالك برفض طلبك بخصوص "$propertyTitle".',
            'type': 'deal_rejected',
            'propertyId': propertyId, // <-- تم إصلاح المشكلة هنا
            'timestamp': FieldValue.serverTimestamp(),
          });

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض الطلب.'),
              backgroundColor: Colors.red,
            ),
          );
        })
        .catchError((error) {
          debugPrint("❌ [Deals] خطأ أثناء رفض الصفقة: $error");
        });
  }

  Widget _buildDealCard(
    BuildContext context,
    Map<String, dynamic> dealData,
    Map<String, dynamic>? propertyData,
    String propertyId,
    String buyerId, // <-- إضافة buyerId
    String dealId, // معرّف الصفقة
  ) {
    final dealType = dealData['dealType'] ?? 'عملية';
    final timestamp = (dealData['timestamp'] as Timestamp?)?.toDate();

    final title = propertyData != null
        ? propertyData['title']
        : 'عقار محذوف أو غير متاح';
    final imageUrls = propertyData != null
        ? (propertyData['imageUrls'] as List?)
        : [];
    final firstImage = (imageUrls != null && imageUrls.isNotEmpty)
        ? imageUrls.first
        : null;
    final price = propertyData != null ? propertyData['price'] : '---';

    // --- منطق الحالة الجديد ---
    final status =
        dealData['status'] ??
        'confirmed'; // الافتراضي مؤكد للتوافق مع الصفقات القديمة
    final isSellerView = fieldName == 'sellerId';
    final isPending = status == 'pending';

    String statusText = '';
    Color statusColor = Colors.grey;
    if (isPending) {
      statusText = isSellerView ? 'بانتظار موافقتك' : 'بانتظار موافقة البائع';
      statusColor = Colors.orange.shade800;
    } else if (status == 'confirmed') {
      statusText = 'صفقة مؤكدة';
      statusColor = Colors.green.shade800;
    }
    // --- نهاية منطق الحالة ---

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: propertyData != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PropertyDetailsScreen(propertyId: propertyId),
                  ),
                );
              }
            : null, // لا يمكن النقر إذا كان العقار محذوفاً
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // صورة العقار
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: firstImage != null
                      ? CachedNetworkImage(
                          imageUrl: firstImage,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Icon(Icons.image),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.broken_image),
                        )
                      : const Icon(Icons.home, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),

              // تفاصيل الصفقة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // شارة نوع الصفقة
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: dealType == 'إيجار'
                                ? Colors.orange.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            dealType,
                            style: TextStyle(
                              color: dealType == 'إيجار'
                                  ? Colors.orange.shade900
                                  : Colors.green.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // التاريخ
                        // --- عرض الحالة بدلاً من التاريخ في الأعلى ---
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      propertyData != null
                          ? '$price ${propertyData['currency'] ?? ''}'
                          : '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // --- إضافة أزرار التحكم للبائع ---
                    if (isSellerView && isPending) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _rejectDeal(
                              context,
                              dealId,
                              buyerId,
                              title,
                              propertyId,
                            ), // <-- تمرير propertyId هنا
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('رفض'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _confirmDeal(
                              context,
                              dealId,
                              propertyId,
                              dealType,
                              buyerId,
                            ),
                            child: Text(
                              dealType == 'إيجار'
                                  ? 'تأكيد الإيجار'
                                  : 'تأكيد البيع',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

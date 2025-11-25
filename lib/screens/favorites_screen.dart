import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('المفضلة')),
        body: const Center(child: Text('يرجى تسجيل الدخول لعرض مفضلتك.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('العقارات المفضلة')),
      body: StreamBuilder<QuerySnapshot>(
        // 1. جلب معرفات العقارات المفضلة من مجموعة المستخدم
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .orderBy('favoritedAt', descending: true)
            .snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ في جلب البيانات.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لم تقم بإضافة أي عقار للمفضلة بعد.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final favDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: favDocs.length,
            itemBuilder: (ctx, index) {
              // معرف العقار هو معرف المستند في المفضلة
              final propertyId = favDocs[index].id;

              // 2. جلب تفاصيل العقار الحقيقية لكل عنصر
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

                  // التحقق من أن العقار لا يزال موجوداً (لم يحذفه المالك)
                  if (!propSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                    // يمكننا هنا حذف المفضلة تلقائياً إذا أردنا، لكن إخفاءها يكفي الآن
                  }

                  final propertyData =
                      propSnapshot.data!.data() as Map<String, dynamic>;

                  return _buildFavoriteCard(context, propertyData, propertyId);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFavoriteCard(
    BuildContext context,
    Map<String, dynamic> data,
    String propertyId,
  ) {
    final title = data['title'] ?? 'بدون عنوان';
    final price = data['price'] ?? 0;
    final currency = data['currency'] ?? 'ر.س';
    final imageUrls = data['imageUrls'] as List<dynamic>? ?? [];
    final firstImage = imageUrls.isNotEmpty ? imageUrls.first : null;
    final addressCity = data['addressCity'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailsScreen(propertyId: propertyId),
            ),
          );
        },
        child: Column(
          children: [
            // صورة العقار
            SizedBox(
              height: 150,
              width: double.infinity,
              child: firstImage != null
                  ? CachedNetworkImage(
                      imageUrl: firstImage,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.image)),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.home,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
            ),
            // التفاصيل
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Icon(Icons.favorite, color: Colors.red[400], size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (addressCity.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          addressCity,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '$price $currency',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

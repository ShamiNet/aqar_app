import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/services/api_service.dart'; // ✅
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // ✅ جعلناها nullable لتفادي الأخطاء أثناء التحميل
  Future<List<Map<String, dynamic>>>? _favoritesFuture;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');

    if (mounted) {
      setState(() {
        if (uid != null) {
          _isLoggedIn = true;
          _favoritesFuture = ApiService.fetchFavorites(uid);
        } else {
          _isLoggedIn = false;
          _favoritesFuture = Future.value([]);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // عرض مؤشر تحميل حتى نتأكد من حالة الدخول
    if (_favoritesFuture == null) {
      return const Scaffold(
        // ✅ تم إصلاح الخطأ هنا (حذفنا الـ AppBar أثناء التحميل لمنع الوميض)
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('المفضلة')),
        body: const Center(child: Text('يرجى تسجيل الدخول لعرض مفضلتك.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('العقارات المفضلة')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _favoritesFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ في جلب البيانات.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

          final favorites = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: favorites.length,
            itemBuilder: (ctx, index) {
              final propertyData = favorites[index];
              return _buildFavoriteCard(context, propertyData);
            },
          );
        },
      ),
    );
  }

  Widget _buildFavoriteCard(BuildContext context, Map<String, dynamic> data) {
    final propertyId = data['id'] ?? 'unknown';
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

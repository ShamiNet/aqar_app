import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final VoidCallback? onTap;

  const PropertyCard({super.key, required this.property, this.onTap});

  @override
  Widget build(BuildContext context) {
    // 1. استخراج الصورة
    String? firstImageUrl;
    try {
      final rawList = property['images'] ?? property['imageUrls'];
      if (rawList is List && rawList.isNotEmpty) {
        firstImageUrl = rawList[0].toString();
      }
    } catch (e) {
      debugPrint('Error parsing image in card: $e');
    }

    // 2. استخراج البيانات
    final title = property['title']?.toString() ?? 'بدون عنوان';
    final priceRaw = property['price'] ?? 0;
    final price = priceRaw is num
        ? priceRaw
        : num.tryParse(priceRaw.toString()) ?? 0;
    final currency = property['currency']?.toString() ?? '\$';
    final address = property['address']?.toString() ?? '';
    final rooms =
        property['bedrooms']?.toString() ??
        property['rooms']?.toString() ??
        '-';
    final area = property['area']?.toString() ?? '-';

    final category = property['category']?.toString() ?? 'بيع';
    final isRent = category.contains('إيجار');

    return GestureDetector(
      onTap:
          onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PropertyDetailsScreen(
                  propertyId: (property['id'] ?? property['_id']).toString(),
                ),
              ),
            );
          },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12), // تقليل التدaduer
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼️ صورة العقار
            Stack(
              children: [
                SizedBox(
                  height:
                      150, // ✅ تم تقليل الارتفاع من 180 إلى 150 لمنع الـ Overflow
                  width: double.infinity,
                  child: firstImageUrl != null && firstImageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: firstImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.house,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                ),
                // شارة النوع
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isRent ? Colors.purple : Colors.blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                // السعر
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${price.toStringAsFixed(0)} $currency',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 📝 التفاصيل
            Padding(
              padding: const EdgeInsets.all(10.0), // تقليل الحشو الداخلي
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15, // تصغير الخط قليلاً
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (address.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  // أيقونات الخصائص
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFeature(Icons.bed, '$rooms غرف'),
                      _buildFeature(Icons.square_foot, '$area م²'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}

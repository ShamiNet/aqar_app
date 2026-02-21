import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aqar_app/config/cloudinary_config.dart';

class PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final VoidCallback? onTap;

  const PropertyCard({super.key, required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 1. استخراج الصورة وتحسينها سحابياً
    String? firstImageUrl;
    try {
      final rawList = property['images'] ?? property['imageUrls'];
      if (rawList is List && rawList.isNotEmpty) {
        firstImageUrl = rawList[0].toString();
      }
    } catch (e) {
      debugPrint('Error parsing image: $e');
    }

    String optimizedImageUrl = '';
    if (firstImageUrl != null && firstImageUrl.isNotEmpty) {
      optimizedImageUrl = CloudinaryConfig.getOptimizedImageUrl(
        firstImageUrl,
        width: 600,
      );
    }

    // 2. استخراج البيانات
    final title = property['title']?.toString() ?? 'بدون عنوان';
    final priceRaw = property['price'] ?? 0;
    final price = priceRaw is num
        ? priceRaw
        : num.tryParse(priceRaw.toString()) ?? 0;
    final currency = property['currency']?.toString() ?? '\$';
    final address = property['address']?.toString() ?? 'لا يوجد عنوان';
    final rooms =
        property['bedrooms']?.toString() ??
        property['rooms']?.toString() ??
        '-';
    final area = property['area']?.toString() ?? '-';
    final category = property['category']?.toString() ?? 'بيع';
    final isRent = category.contains('إيجار');
    final badgeStyle = _getCategoryBadgeStyle(context, category, isRent);

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
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 🖼️ القسم العلوي: الصورة
            // أضفنا Expanded هنا فقط لكي تأخذ الصورة المساحة المتبقية بمرونة
            // ==========================================
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // الصورة المحسنة
                  optimizedImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: optimizedImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),

                  // تدرج لوني خفيف أسفل الصورة
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // شارة النوع (بيع / إيجار)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: DecoratedBox(
                      decoration: badgeStyle.decoration,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(category, style: badgeStyle.textStyle),
                      ),
                    ),
                  ),

                  // السعر
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Text(
                      '${price.toStringAsFixed(0)} $currency',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black45,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // 📝 القسم السفلي: التفاصيل
            // قمنا بإزالة الـ Expanded من هنا لكي يأخذ هذا القسم مساحته الطبيعية التي يحتاجها فقط
            // ==========================================
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // ✅ هذا السطر يمنع الـ Overflow نهائياً
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // العنوان
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 6), // مسافة آمنة بدلاً من SpaceBetween
                  // العنوان والموقع
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.0),
                    child: Divider(height: 1, thickness: 0.5),
                  ),

                  // الخصائص السفلية (الغرف والمساحة)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFeatureIcon(Icons.king_bed_rounded, '$rooms غرف'),
                      _buildFeatureIcon(Icons.square_foot_rounded, '$area م²'),
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

  // ودجت فرعي لترتيب أيقونات الخصائص السفلية
  Widget _buildFeatureIcon(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  _CategoryBadgeStyle _getCategoryBadgeStyle(
    BuildContext context,
    String category,
    bool isRent,
  ) {
    final baseColor = isRent
        ? const Color(0xFF6A3CBC)
        : const Color(0xFF1C6FDB);
    final highlightColor = isRent
        ? const Color(0xFFB46BFF)
        : const Color(0xFF4FD0FF);
    final surface = Theme.of(context).colorScheme.surface;

    return _CategoryBadgeStyle(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [highlightColor, baseColor],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surface.withOpacity(0.25), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 0.2,
      ),
    );
  }

  // صورة بديلة
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.holiday_village_rounded,
              size: 40,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد صورة',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadgeStyle {
  final BoxDecoration decoration;
  final TextStyle textStyle;

  const _CategoryBadgeStyle({
    required this.decoration,
    required this.textStyle,
  });
}

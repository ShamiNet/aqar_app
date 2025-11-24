import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PropertyCard extends StatelessWidget {
  final QueryDocumentSnapshot property;
  final VoidCallback onTap;

  const PropertyCard({super.key, required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = property.data() as Map<String, dynamic>;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final String title = data['title'] ?? 'بدون عنوان';
    final String imageUrl =
        (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty)
        ? data['imageUrls'][0]
        : 'https://placehold.co/600x400/png?text=No+Image';

    final double price = double.tryParse(data['price'].toString()) ?? 0.0;
    final String currency = data['currency'] ?? 'ر.س';
    final String address = data['address'] ?? 'غير محدد';
    final int rooms = int.tryParse(data['rooms'].toString()) ?? 0;
    final int bathrooms = int.tryParse(data['bathrooms'].toString()) ?? 0;
    final double area = double.tryParse(data['area'].toString()) ?? 0.0;
    final String type = data['propertyType'] ?? '';

    Color badgeColor = _getBadgeColor(type, colorScheme);

    return GestureDetector(
      onTap: onTap,
      child:
          Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? theme.cardColor : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isDark
                      ? Border.all(color: colorScheme.outline.withOpacity(0.2))
                      : Border.all(color: Colors.grey.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.15),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- قسم الصورة ---
                    Flexible(
                      child: Stack(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: CircularProgressIndicator.adaptive(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 50,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (type.isNotEmpty)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: badgeColor.withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  type,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // --- قسم التفاصيل ---
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${price.toStringAsFixed(0)} $currency',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (address != 'غير محدد')
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: colorScheme.secondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(
                                        0.7,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 10),
                          Divider(
                            height: 1,
                            color: colorScheme.outlineVariant.withOpacity(0.3),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              if (rooms > 0)
                                _buildSpecItem(
                                  context,
                                  Icons.bed_outlined,
                                  '$rooms غرف',
                                ),
                              if (bathrooms > 0)
                                _buildSpecItem(
                                  context,
                                  Icons.bathtub_outlined,
                                  '$bathrooms حمام',
                                ),
                              if (area > 0)
                                _buildSpecItem(
                                  context,
                                  Icons.square_foot_outlined,
                                  '${area.toStringAsFixed(0)} م²',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.1, curve: Curves.easeOut),
    );
  }

  Color _getBadgeColor(String type, ColorScheme scheme) {
    final t = type.trim();
    if (t.contains('بيت')) return Colors.blue.shade600;
    if (t.contains('فيلا')) return Colors.purple.shade600;
    if (t.contains('بناية')) return Colors.indigo.shade600;
    if (t.contains('شقة')) return Colors.teal.shade600;
    if (t.contains('مكتب')) return Colors.blueGrey.shade600;
    if (t.contains('دكان') || t.contains('محل')) return Colors.orange.shade700;
    if (t.contains('ارض') || t.contains('أرض')) return Colors.brown.shade600;
    if (t.contains('مزرعة')) return Colors.green.shade600;
    return scheme.primary;
  }

  Widget _buildSpecItem(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.secondary.withOpacity(0.8)),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

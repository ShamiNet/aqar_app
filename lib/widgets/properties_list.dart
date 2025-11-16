import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PropertiesList extends StatelessWidget {
  const PropertiesList({super.key, required this.properties});

  final List<QueryDocumentSnapshot> properties;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: properties.length,
      itemBuilder: (ctx, index) {
        final property = properties[index].data() as Map<String, dynamic>;
        final propertyId = properties[index].id;
        final title = property['title'] ?? 'بدون عنوان';
        final price = property['price'] ?? 0.0;
        final currency = property['currency'] ?? 'ر.س';
        final imageUrls = property['imageUrls'] as List<dynamic>?;
        final String? category =
            property['category'] as String?; // 'بيع' أو 'إيجار'
        final bool isFeatured = property['isFeatured'] == true;
        final int discountPercent =
            (property['discountPercent'] as num?)?.toInt() ?? 0;

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => PropertyDetailsScreen(propertyId: propertyId),
              ),
            );
          },
          child:
              Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                    child: Stack(
                      children: [
                        // Image
                        if (imageUrls != null && imageUrls.isNotEmpty)
                          Image.network(
                            imageUrls.first,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder:
                                (
                                  BuildContext context,
                                  Widget child,
                                  ImageChunkEvent? loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object exception,
                                  StackTrace? stackTrace,
                                ) {
                                  return Container(
                                    height: 220,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                          )
                        else
                          Container(
                            height: 220,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.house,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        // Gradient Overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withAlpha((255 * 0.6).round()),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withAlpha((255 * 0.8).round()),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0, 0.2, 0.6, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Badges Row (Category, Discount, Featured)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (category != null)
                                _Badge(
                                  icon: category == 'بيع'
                                      ? Icons.sell_outlined
                                      : Icons.key,
                                  label: category,
                                  background: category == 'بيع'
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.errorContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                  foreground: category == 'بيع'
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onErrorContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                ),
                              if (discountPercent > 0)
                                _Badge(
                                  icon: Icons.local_offer_outlined,
                                  label: '-$discountPercent%',
                                  background: Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                                  foreground: Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                                ),
                              if (isFeatured)
                                _Badge(
                                  icon: Icons.star,
                                  label: 'مميز',
                                  background: Theme.of(
                                    context,
                                  ).colorScheme.tertiaryContainer,
                                  foreground: Theme.of(
                                    context,
                                  ).colorScheme.onTertiaryContainer,
                                ),
                            ],
                          ),
                        ),
                        // Text Content
                        Positioned(
                          bottom: 20,
                          right: 20,
                          left: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} $currency',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fade(duration: 500.ms)
                  .slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOut),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

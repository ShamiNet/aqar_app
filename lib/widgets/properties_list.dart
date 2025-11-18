import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/screens/filtered_properties_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        final String? propertyType = property['propertyType'] as String?;
        String title = property['title'] ?? '';
        if (title.trim().isEmpty) {
          title = propertyType ?? 'بدون عنوان';
        }
        final price = property['price'] ?? 0.0;
        final currency = property['currency'] ?? 'ر.س';
        final imageUrls = property['imageUrls'] as List<dynamic>?;
        final bool hasMultipleImages =
            imageUrls != null && imageUrls.length > 1;
        final String? category =
            property['category'] as String?; // 'بيع' أو 'إيجار'
        final bool isFeatured = property['isFeatured'] == true;
        final int discountPercent =
            (property['discountPercent'] as num?)?.toInt() ?? 0;
        final int rooms = (property['rooms'] as num?)?.toInt() ?? 0;
        final num area = (property['area'] as num?) ?? 0;
        final int? floor = (property['floor'] as num?)?.toInt();
        final String? subscriptionPeriod =
            property['subscriptionPeriod'] as String?;

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
                        imageUrls != null && imageUrls.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrls.first,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 220,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : Container(
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
                                _ClickableBadge(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (ctx) =>
                                            FilteredPropertiesScreen(
                                              filterTitle: 'عقارات $category',
                                              filterType: 'category',
                                              filterValue: category,
                                            ),
                                      ),
                                    );
                                  },
                                  child: _Badge(
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
                                ),
                              if (discountPercent > 0)
                                _ClickableBadge(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (ctx) =>
                                            const FilteredPropertiesScreen(
                                              filterTitle: 'عقارات عليها خصم',
                                              filterType: 'hasDiscount',
                                              filterValue: true,
                                            ),
                                      ),
                                    );
                                  },
                                  child: _Badge(
                                    icon: Icons.local_offer_outlined,
                                    label: '-$discountPercent%',
                                    background: Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer,
                                    foreground: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              if (isFeatured)
                                _ClickableBadge(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (ctx) =>
                                            const FilteredPropertiesScreen(
                                              filterTitle: 'عقارات مميزة',
                                              filterType: 'isFeatured',
                                              filterValue: true,
                                            ),
                                      ),
                                    );
                                  },
                                  child: _Badge(
                                    icon: Icons.star,
                                    label: 'مميز',
                                    background: Theme.of(
                                      context,
                                    ).colorScheme.tertiaryContainer,
                                    foreground: Theme.of(
                                      context,
                                    ).colorScheme.onTertiaryContainer,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Text Content + Info Chips within a fancy glass container
                        Positioned(
                          bottom: 16,
                          right: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.06),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.22),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // The price is already shown in the top-left bubble, so this can be removed to avoid redundancy.
                                // Text(
                                //   '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} $currency',
                                //   style: Theme.of(context).textTheme.titleMedium
                                //       ?.copyWith(
                                //         color: Theme.of(
                                //           context,
                                //         ).colorScheme.primary,
                                //         fontWeight: FontWeight.bold,
                                //       ),
                                // ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (rooms > 0)
                                      _InfoChip(
                                        icon: Icons.timer_outlined,
                                        label: '$subscriptionPeriod',
                                        accent: Colors.cyan,
                                      ),
                                    if (rooms > 0)
                                      _InfoChip(
                                        icon: Icons.meeting_room,
                                        label: '$rooms غرفة',
                                        accent: Colors.teal,
                                      ),
                                    if (area > 0)
                                      _InfoChip(
                                        icon: Icons.area_chart,
                                        label: '${area.toString()} م²',
                                        accent: Colors.orange,
                                      ),
                                    if (floor != null && propertyType != 'ارض')
                                      _InfoChip(
                                        icon: Icons.stairs,
                                        label: 'طابق $floor',
                                        accent: Colors.purple,
                                      ),
                                    if (hasMultipleImages)
                                      _InfoChip(
                                        icon: Icons.collections,
                                        label: '${imageUrls.length} صور',
                                        accent: Colors.blue,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // price bubble overlay (top-left)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.currency_exchange_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} $currency',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // featured ribbon
                        if (isFeatured)
                          Positioned(
                            bottom: 12,
                            right: -32,
                            child: Transform.rotate(
                              angle: -0.90, // -45 degrees
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 26,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade700,
                                      Colors.orange.shade800,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'مميز',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                  .animate()
                  .scaleXY(
                    begin: 0.98,
                    end: 1.0,
                    duration: 420.ms,
                    curve: Curves.easeOut,
                  )
                  .fade(duration: 500.ms)
                  .slideY(begin: 0.26, duration: 400.ms, curve: Curves.easeOut),
        );
      },
    );
  }
}

class _ClickableBadge extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ClickableBadge({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: child,
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
        gradient: LinearGradient(
          colors: [background, background.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.6),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.18), accent.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: accent.withOpacity(0.14), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

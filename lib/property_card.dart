import 'package:aqar_app/screens/filtered_properties_screen.dart';
import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final String propertyId;

  const PropertyCard({
    super.key,
    required this.property,
    required this.propertyId,
  });

  @override
  Widget build(BuildContext context) {
    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final asInt = int.tryParse(v);
        if (asInt != null) return asInt;
        final asDouble = double.tryParse(v);
        return asDouble?.toInt() ?? 0;
      }
      return 0;
    }

    num _toNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v;
      if (v is String) return num.tryParse(v) ?? 0;
      return 0;
    }

    final String? propertyType = property['propertyType'] as String?;
    String title = property['title'] ?? '';
    if (title.trim().isEmpty) {
      title = propertyType ?? 'بدون عنوان';
    }
    final num price = _toNum(property['price']);
    final currency = property['currency'] ?? 'ر.س';
    final imageUrls = property['imageUrls'] as List<dynamic>?;
    final String? category =
        property['category'] as String?; // 'بيع' أو 'إيجار'
    final int discountPercent = _toInt(property['discountPercent']);
    final int rooms = _toInt(property['rooms']);
    final num area = _toNum(property['area']);
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
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                        height: double.infinity,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Container(
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
                    alignment: WrapAlignment.end,
                    children: [
                      if (category != null)
                        _ClickableBadge(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => FilteredPropertiesScreen(
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
                                ? Theme.of(context).colorScheme.errorContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                            foreground: category == 'بيع'
                                ? Theme.of(context).colorScheme.onErrorContainer
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
                    ],
                  ),
                ),
                // Text Content + Info Chips
                Positioned(
                  bottom: 16,
                  right: 16,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (subscriptionPeriod != null)
                            _InfoChip(
                              icon: Icons.timer_outlined,
                              label: subscriptionPeriod,
                              accent: Colors.cyan,
                            ),
                          if (rooms > 0)
                            _InfoChip(
                              icon: Icons.meeting_room,
                              label: '$rooms غرف',
                              accent: Colors.teal,
                            ),
                          if (area > 0)
                            _InfoChip(
                              icon: Icons.area_chart,
                              label: '${area.toString()} م²',
                              accent: Colors.orange,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // price bubble overlay (top-left)
                Positioned(
                  top: 45,
                  left: 5,
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
                    child: Text(
                      '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} $currency',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .scaleXY(begin: 0.98, end: 1.0, duration: 420.ms, curve: Curves.easeOut)
        .fade(duration: 500.ms)
        .slideY(begin: 0.26, duration: 400.ms, curve: Curves.easeOut);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.18), accent.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: accent.withOpacity(0.12), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

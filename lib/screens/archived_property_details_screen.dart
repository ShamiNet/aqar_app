import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ArchivedPropertyDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> propertyData;

  const ArchivedPropertyDetailsScreen({super.key, required this.propertyData});

  @override
  Widget build(BuildContext context) {
    final title = propertyData['title'] ?? 'بدون عنوان';
    final priceRaw = propertyData['price'] ?? 0.0;
    num price = (priceRaw is num)
        ? priceRaw
        : (num.tryParse(priceRaw.toString()) ?? 0.0);
    final currency = propertyData['currency'] ?? 'ر.س';
    final description = propertyData['description'] ?? 'لا يوجد وصف.';
    final imageUrls = propertyData['imageUrls'] as List<dynamic>? ?? [];
    final category = propertyData['category'] ?? 'غير محدد';
    final rooms = propertyData['rooms'];
    final area = propertyData['area'] ?? 0.0;
    final location = propertyData['location'] as GeoPoint?;
    final archiveReason = propertyData['archiveReason'] ?? 'غير معروف';
    final archivedAt = propertyData['archivedAt'] as Timestamp?;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.secondaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- شريط معلومات الأرشفة --
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'هذا العقار مؤرشف (للقراءة فقط)',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'سبب الأرشفة: $archiveReason',
                    style: TextStyle(color: Colors.amber.shade800),
                  ),
                  if (archivedAt != null)
                    Text(
                      'تاريخ الأرشفة: ${archivedAt.toDate().day}/${archivedAt.toDate().month}/${archivedAt.toDate().year}',
                      style: TextStyle(
                        color: Colors.amber.shade700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),

            // -- الصور --
            if (imageUrls.isNotEmpty)
              SizedBox(
                height: 250,
                child: PageView.builder(
                  itemCount: imageUrls.length,
                  itemBuilder: (ctx, index) => CachedNetworkImage(
                    imageUrl: imageUrls[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image, size: 48),
                  ),
                ),
              )
            else
              Container(
                height: 250,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 64),
                ),
              ),

            // -- باقي التفاصيل --
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${price.toStringAsFixed(0)} $currency',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 32),
                  Text('الوصف', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(description),
                  const Divider(height: 32),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      Text('النوع: $category'),
                      if (rooms != null) Text('الغرف: $rooms'),
                      if (area > 0) Text('المساحة: $area م²'),
                    ],
                  ),
                  if (location != null) ...[
                    const Divider(height: 32),
                    Text(
                      'الموقع',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(location.latitude, location.longitude),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('location'),
                            position: LatLng(
                              location.latitude,
                              location.longitude,
                            ),
                          ),
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

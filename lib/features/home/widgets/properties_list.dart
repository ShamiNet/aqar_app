import 'package:aqar_app/features/properties/screens/property_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
        final imageUrls = property['imageUrls'] as List<dynamic>?;

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => PropertyDetailsScreen(propertyId: propertyId),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                        '${price.toStringAsFixed(2)} ر.س',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

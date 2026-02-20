import 'package:aqar_app/property_card.dart';
import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/services/api_service.dart'; // ✅
import 'package:aqar_app/widgets/properties_list_skeleton.dart';
import 'package:aqar_app/widgets/verified_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Future<Map<String, dynamic>?> _userProfileFuture;
  late Future<List<Map<String, dynamic>>> _userPropertiesFuture;

  @override
  void initState() {
    super.initState();
    _userProfileFuture = ApiService.fetchUserProfile(widget.userId);
    _userPropertiesFuture = ApiService.fetchMyProperties(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.userName)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. قسم معلومات المستخدم ---
            FutureBuilder<Map<String, dynamic>?>(
              future: _userProfileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final userData = snapshot.data;
                final username = userData?['username'] ?? widget.userName;
                final image = userData?['profileImageUrl'];
                final bio = userData?['bio'];
                final phone = userData?['phone'];
                final isVerified =
                    (userData?['isVerified'] == true) ||
                    (userData?['role'] == 'admin');

                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: image != null
                            ? CachedNetworkImageProvider(image)
                            : null,
                        child: image == null
                            ? Text(
                                username.isNotEmpty ? username[0] : '?',
                                style: const TextStyle(fontSize: 30),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            username,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 8),
                            const VerifiedBadge(size: 20),
                          ],
                        ],
                      ),
                      if (bio != null && bio.toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                      if (phone != null && phone.toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('tel:$phone');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.phone),
                          label: const Text('اتصال'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            // --- 2. قسم عقارات المستخدم ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'عقارات المعلن',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _userPropertiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 300,
                    child: PropertiesListSkeleton(),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text('لا توجد عقارات أخرى لهذا المعلن.'),
                    ),
                  );
                }
                return Column(
                  children: snapshot.data!.map((property) {
                    final propertyId = property['id'] ?? 'unknown';
                    return Container(
                      height: 280,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: PropertyCard(
                        property: property,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) =>
                                  PropertyDetailsScreen(propertyId: propertyId),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

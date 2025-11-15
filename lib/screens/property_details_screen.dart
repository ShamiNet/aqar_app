import 'package:aqar_app/screens/edit_property_screen.dart';
import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertyDetailsScreen extends StatefulWidget {
  const PropertyDetailsScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  late Future<DocumentSnapshot> _propertyFuture;
  bool _isOwner = false;
  bool _isFavorited = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _propertyFuture = FirebaseFirestore.instance
        .collection('properties')
        .doc(widget.propertyId)
        .get();
    _checkOwnership();
    _checkIfFavorited();
  }

  void _checkOwnership() async {
    if (_currentUser == null) return;
    final property = await _propertyFuture;
    if (!property.exists) return;
    final propertyUserId = (property.data() as Map<String, dynamic>)['userId'];
    setState(() {
      _isOwner = _currentUser!.uid == propertyUserId;
    });
  }

  void _checkIfFavorited() async {
    if (_currentUser == null) return;
    final favoriteDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('favorites')
        .doc(widget.propertyId)
        .get();
    setState(() {
      _isFavorited = favoriteDoc.exists;
    });
  }

  void _toggleFavorite() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تسجيل الدخول أولاً.')),
      );
      return;
    }

    final favoriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('favorites')
        .doc(widget.propertyId);

    setState(() {
      _isFavorited = !_isFavorited;
    });

    if (_isFavorited) {
      await favoriteRef.set({'favoritedAt': Timestamp.now()});
    } else {
      await favoriteRef.delete();
    }
  }

  void _deleteProperty() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا العقار؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (shouldDelete == null || !shouldDelete) {
      return;
    }

    try {
      final property = await _propertyFuture;
      final imageUrls =
          (property.data() as Map<String, dynamic>)['imageUrls']
              as List<dynamic>?;

      if (imageUrls != null) {
        for (final url in imageUrls) {
          await FirebaseStorage.instance.refFromURL(url).delete();
        }
      }

      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .delete();

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف العقار بنجاح.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحذف: ${e.toString()}')),
      );
    }
  }

  void _shareProperty(Map<String, dynamic> propertyData) {
    final title = propertyData['title'] ?? 'بدون عنوان';
    final description = propertyData['description'] ?? 'لا يوجد وصف.';
    final price = propertyData['price'] ?? 0.0;

    final shareText =
        '''
اطلع على هذا العقار: $title

السعر: ${price.toStringAsFixed(2)} ر.س

الوصف:
$description
''';
    Share.share(shareText);
  }

  void _startOrOpenChat(Map<String, dynamic> propertyData) async {
    final ownerId = propertyData['userId'];
    if (_currentUser == null || _currentUser!.uid == ownerId) {
      return;
    }

    final currentUser = _currentUser!;
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    DocumentSnapshot? existingChat;
    final potentialChats = chatQuery.docs.where((doc) {
      final participants = List<String>.from(doc['participants']);
      return participants.contains(ownerId);
    });
    if (potentialChats.isNotEmpty) existingChat = potentialChats.first;

    final chat = existingChat;
    if (chat != null) {
      final ownerData = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();
      final ownerName = ownerData.data()?['username'] ?? 'مستخدم';

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => ChatMessagesScreen(
            chatId: chat.id,
            recipientId: ownerId,
            recipientName: ownerName,
          ),
        ),
      );
    } else {
      final ownerData = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();
      final ownerName = ownerData.data()?['username'] ?? 'مستخدم';
      final currentUserData = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUserName = currentUserData.data()?['username'] ?? 'مستخدم';

      final newChatRef = await FirebaseFirestore.instance
          .collection('chats')
          .add({
            'participants': [currentUser.uid, ownerId],
            'participantNames': {
              currentUser.uid: currentUserName,
              ownerId: ownerName,
            },
            'lastMessage': '',
            'lastMessageTimestamp': Timestamp.now(),
          });

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => ChatMessagesScreen(
            chatId: newChatRef.id,
            recipientId: ownerId,
            recipientName: ownerName,
          ),
        ),
      );
    }
  }

  void _launchMapsUrl(double lat, double lon) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: _propertyFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('لم يتم العثور على العقار.'));
          }

          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ ما.'));
          }

          final property = snapshot.data!.data() as Map<String, dynamic>;
          final title = property['title'] ?? 'بدون عنوان';
          final price = property['price'] ?? 0.0;
          final description = property['description'] ?? 'لا يوجد وصف.';
          final imageUrls = property['imageUrls'] as List<dynamic>? ?? [];
          final category = property['category'] ?? 'غير محدد';
          final floor = property['floor'] ?? 0;
          final rooms = property['rooms'] ?? 0;
          final area = property['area'] ?? 0.0;
          final location = property['location'] as GeoPoint?;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: imageUrls.isNotEmpty
                      ? PageView.builder(
                          itemCount: imageUrls.length,
                          itemBuilder: (ctx, index) {
                            return Image.network(
                              imageUrls[index],
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
                                    return const Icon(
                                      Icons.broken_image,
                                      size: 48,
                                    );
                                  },
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.house,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                ),
                actions: [
                  IconButton(
                    onPressed: () => _shareProperty(property),
                    icon: const Icon(Icons.share),
                  ),
                  if (_currentUser != null)
                    IconButton(
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        _isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorited ? Colors.red : Colors.white,
                      ),
                    ),
                  if (_isOwner)
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => EditPropertyScreen(
                              propertyId: widget.propertyId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                    ),
                  if (_isOwner)
                    IconButton(
                      onPressed: _deleteProperty,
                      icon: const Icon(Icons.delete),
                    ),
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${price.toStringAsFixed(2)} ر.س',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _buildDetailItem(context, Icons.category, category),
                            _buildDetailItem(
                              context,
                              Icons.stairs,
                              'الطابق $floor',
                            ),
                            _buildDetailItem(
                              context,
                              Icons.meeting_room,
                              '$rooms غرف',
                            ),
                            _buildDetailItem(
                              context,
                              Icons.area_chart,
                              '$area م²',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'الوصف',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (location != null) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            'الموقع',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 200,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(
                                    location.latitude,
                                    location.longitude,
                                  ),
                                  zoom: 15,
                                ),
                                markers: {
                                  Marker(
                                    markerId: const MarkerId(
                                      'propertyLocation',
                                    ),
                                    position: LatLng(
                                      location.latitude,
                                      location.longitude,
                                    ),
                                  ),
                                },
                                scrollGesturesEnabled: false,
                                zoomGesturesEnabled: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => _launchMapsUrl(
                                location.latitude,
                                location.longitude,
                              ),
                              icon: const Icon(Icons.map),
                              label: const Text('فتح في الخرائط'),
                            ),
                          ),
                        ],
                        if (!_isOwner && _currentUser != null) ...[
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _startOrOpenChat(property),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('تواصل مع البائع'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

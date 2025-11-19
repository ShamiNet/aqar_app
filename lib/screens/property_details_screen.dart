import 'package:aqar_app/screens/edit_property_screen.dart';
import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
// تم إزالة مكتبة Firebase Storage لأننا نستخدم Cloudinary
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    debugPrint(
      '[PropertyDetailsScreen] initState: Initializing for property ID: ${widget.propertyId}',
    );
    _currentUser = FirebaseAuth.instance.currentUser;
    _propertyFuture = FirebaseFirestore.instance
        .collection('properties')
        .doc(widget.propertyId)
        .get();
    _checkOwnership();
    _checkIfFavorited();
  }

  void _checkOwnership() async {
    debugPrint('[PropertyDetailsScreen] _checkOwnership: Checking ownership.');
    if (_currentUser == null) return;
    final property = await _propertyFuture;
    if (!property.exists) return;
    final data = property.data();
    if (data != null &&
        data is Map<String, dynamic> &&
        data.containsKey('userId')) {
      final propertyUserId = data['userId'];
      setState(() {
        _isOwner = _currentUser!.uid == propertyUserId;
      });
    }
  }

  void _checkIfFavorited() async {
    debugPrint(
      '[PropertyDetailsScreen] _checkIfFavorited: Checking favorite status.',
    );
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
    debugPrint(
      '[PropertyDetailsScreen] _toggleFavorite: Toggling favorite status.',
    );
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
      FirebaseAnalytics.instance.logEvent(
        name: 'add_to_favorites',
        parameters: {'property_id': widget.propertyId},
      );
      debugPrint(
        '[PropertyDetailsScreen] _toggleFavorite: Property added to favorites.',
      );
    } else {
      await favoriteRef.delete();
      FirebaseAnalytics.instance.logEvent(
        name: 'remove_from_favorites',
        parameters: {'property_id': widget.propertyId},
      );
      debugPrint(
        '[PropertyDetailsScreen] _toggleFavorite: Property removed from favorites.',
      );
    }
  }

  void _deleteProperty() async {
    debugPrint('[PropertyDetailsScreen] _deleteProperty: Delete dialog shown.');
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (shouldDelete == null || !shouldDelete) {
      debugPrint(
        '[PropertyDetailsScreen] _deleteProperty: Deletion cancelled.',
      );
      return;
    }

    debugPrint('[PropertyDetailsScreen] _deleteProperty: Deletion confirmed.');
    try {
      // ملاحظة: تم إزالة كود حذف الصور لأن الروابط من Cloudinary
      // ومحاولة حذفها باستخدام Firebase SDK تسبب انهيار التطبيق.
      // سنكتفي بحذف وثيقة العقار من Firestore.

      debugPrint(
        '[PropertyDetailsScreen] _deleteProperty: Deleting document from Firestore.',
      );
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .delete();

      if (!mounted) return;
      debugPrint(
        '[PropertyDetailsScreen] _deleteProperty: Deletion successful. Navigating back.',
      );
      Navigator.of(context).pop(); // العودة للصفحة السابقة
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف العقار بنجاح.')));
    } catch (e) {
      debugPrint(
        '[PropertyDetailsScreen] _deleteProperty: An error occurred: $e',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحذف: ${e.toString()}')),
      );
    }
  }

  void _shareProperty(Map<String, dynamic> propertyData) {
    debugPrint('[PropertyDetailsScreen] _shareProperty: Sharing property.');
    final title = propertyData['title'] ?? 'بدون عنوان';
    final description = propertyData['description'] ?? 'لا يوجد وصف.';
    final price = propertyData['price'] ?? 0.0;
    final currency = propertyData['currency'] ?? 'ر.س';

    final shareText =
        '''
اطلع على هذا العقار: $title

السعر: ${price.toStringAsFixed(2)} $currency

الوصف:
$description
''';
    Share.share(shareText);
    FirebaseAnalytics.instance.logEvent(
      name: 'share',
      parameters: {'content_type': 'property', 'item_id': widget.propertyId},
    );
  }

  void _startOrOpenChat(Map<String, dynamic> propertyData) async {
    debugPrint(
      '[PropertyDetailsScreen] _startOrOpenChat: Initiating chat with owner.',
    );
    final ownerId = propertyData['userId'];
    // تأكد من تغيير معرف الأدمن هذا بمعرف حقيقي إذا لزم الأمر
    const adminId = 'QzX6w0qA8vflx5oGM3jW4GgW2BC2';

    if (_currentUser == null || _currentUser!.uid == ownerId) {
      return;
    }

    final currentUser = _currentUser!;

    final requiredParticipants = [currentUser.uid, ownerId, adminId];
    final uniqueParticipants = requiredParticipants.toSet().toList();

    // تحسين: البحث عن المحادثة بدقة أكبر
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('propertyId', isEqualTo: widget.propertyId)
        .where('participants', arrayContains: currentUser.uid)
        .get();

    DocumentSnapshot? existingChat;

    for (final doc in chatQuery.docs) {
      final participants = List<String>.from(doc['participants']);
      // نتأكد أن المالك موجود أيضاً في المحادثة
      if (participants.contains(ownerId)) {
        existingChat = doc;
        break;
      }
    }

    if (existingChat != null) {
      debugPrint(
        '[PropertyDetailsScreen] _startOrOpenChat: Existing chat found: ${existingChat.id}.',
      );

      // جلب اسم المالك لعرضه في المحادثة
      String ownerName = 'المعلن';
      try {
        final ownerData = await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .get();
        if (ownerData.exists) {
          ownerName = ownerData.data()?['username'] ?? 'المعلن';
        }
      } catch (e) {
        debugPrint('Error fetching owner name: $e');
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => ChatMessagesScreen(
            chatId: existingChat!.id,
            recipientId: ownerId,
            recipientName: ownerName,
          ),
        ),
      );
    } else {
      debugPrint(
        '[PropertyDetailsScreen] _startOrOpenChat: No existing chat. Creating new one.',
      );

      // جلب الأسماء لإنشاء المحادثة
      String ownerName = 'المعلن';
      String currentUserName = currentUser.displayName ?? 'مستخدم';
      String adminName = 'الإدارة';

      try {
        final ownerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .get();
        if (ownerDoc.exists)
          ownerName = ownerDoc.data()?['username'] ?? 'المعلن';

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists)
          currentUserName = userDoc.data()?['username'] ?? currentUserName;

        // (اختياري) جلب اسم الأدمن
      } catch (e) {
        debugPrint('Error fetching names: $e');
      }

      final imageUrls = propertyData['imageUrls'] as List<dynamic>? ?? [];
      final propertyImageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;

      final newChatRef = await FirebaseFirestore.instance
          .collection('chats')
          .add({
            'participants': uniqueParticipants,
            'participantNames': {
              currentUser.uid: currentUserName,
              ownerId: ownerName,
              if (![currentUser.uid, ownerId].contains(adminId))
                adminId: adminName,
            },
            'lastMessage': '',
            'lastMessageTimestamp': Timestamp.now(),
            'propertyId': widget.propertyId,
            'propertyTitle': propertyData['title'] ?? 'بدون عنوان',
            'propertyImageUrl': propertyImageUrl,
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
    debugPrint('[PropertyDetailsScreen] _launchMapsUrl: Opening maps app.');
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا يمكن فتح الخرائط.')));
    }
  }

  IconData _getIconForPropertyType(String? type) {
    switch (type) {
      case 'بيت':
        return Icons.house_rounded;
      case 'فيلا':
        return Icons.villa_rounded;
      case 'بناية':
        return Icons.apartment_rounded;
      case 'ارض':
        return Icons.landscape_rounded;
      case 'دكان':
        return Icons.store_rounded;
      default:
        return Icons.home_rounded;
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
          final priceRaw = property['price'] ?? 0.0;
          num price;
          if (priceRaw is num) {
            price = priceRaw;
          } else if (priceRaw is String) {
            price = num.tryParse(priceRaw) ?? 0.0;
          } else {
            price = 0.0;
          }
          final currency = property['currency'] ?? 'ر.س';
          final description = property['description'] ?? 'لا يوجد وصف.';
          final imageUrls = property['imageUrls'] as List<dynamic>? ?? [];
          final category = property['category'] ?? 'غير محدد';
          final floor = property['floor'];
          final rooms = property['rooms'];
          final area = property['area'] ?? 0.0;
          final String? propertyType = property['propertyType'] as String?;
          final location = property['location'] as GeoPoint?;
          final String? addressCountry = property['addressCountry'];
          final String? addressCity = property['addressCity'];
          final String? addressStreet = property['addressStreet'];
          final fullAddress = [
            addressStreet,
            addressCity,
            addressCountry,
          ].where((s) => s != null && s.isNotEmpty).join(', ');

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
                            return CachedNetworkImage(
                              imageUrl: imageUrls[index],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey,
                              ),
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
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (ctx) => EditPropertyScreen(
                                  propertyId: widget.propertyId,
                                ),
                              ),
                            )
                            .then((_) {
                              // تحديث الصفحة بعد العودة من التعديل
                              setState(() {
                                _propertyFuture = FirebaseFirestore.instance
                                    .collection('properties')
                                    .doc(widget.propertyId)
                                    .get();
                              });
                            });
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
                        // بطاقة العنوان والسعر
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primaryContainer,
                                Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.25),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  _getIconForPropertyType(propertyType),
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${price.toStringAsFixed(0)} $currency',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // بطاقات المعلومات
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildInfoCard(
                              context,
                              Icons.category_rounded,
                              'النوع',
                              category,
                              Colors.blue,
                            ),
                            if (floor != null && floor != 0)
                              _buildInfoCard(
                                context,
                                Icons.stairs,
                                'الطابق',
                                '$floor',
                                Colors.purple,
                              ),
                            if (rooms != null && rooms != 0)
                              _buildInfoCard(
                                context,
                                Icons.meeting_room,
                                'الغرف',
                                '$rooms',
                                Colors.teal,
                              ),
                            if (area > 0)
                              _buildInfoCard(
                                context,
                                Icons.area_chart,
                                'المساحة',
                                '$area م²',
                                Colors.orange,
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // الوصف
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.description_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'الوصف',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),

                        // الموقع
                        if (location != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.place_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'الموقع',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (fullAddress.isNotEmpty)
                                  Text(
                                    fullAddress,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: SizedBox(
                                    height: 200,
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
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.center,
                                  child: TextButton.icon(
                                    onPressed: () => _launchMapsUrl(
                                      location.latitude,
                                      location.longitude,
                                    ),
                                    icon: const Icon(Icons.map_rounded),
                                    label: const Text('فتح في الخرائط'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // زر التواصل
                        if (!_isOwner && _currentUser != null) ...[
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.85),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _startOrOpenChat(property),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.chat_bubble_outline,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'تواصل مع البائع',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
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

  Widget _buildInfoCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color accentColor,
  ) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:aqar_app/screens/edit_property_screen.dart';
import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:aqar_app/screens/public_profile_screen.dart';
import 'package:aqar_app/widgets/full_screen_gallery.dart';
import 'package:aqar_app/widgets/verified_badge.dart'; // <--- 1. استيراد الشارة
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

// استيراد الفيديو
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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

  // متغيرات الفيديو
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  // دالة تهيئة الفيديو
  Future<void> _initializeVideoPlayer(String videoUrl) async {
    if (_videoPlayerController != null) return;

    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
    );
    await _videoPlayerController!.initialize();

    setState(() {
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return const Center(
            child: Text(
              'فشل تحميل الفيديو',
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );
    });
  }

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

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _checkOwnership() async {
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
      FirebaseAnalytics.instance.logEvent(
        name: 'add_to_favorites',
        parameters: {'property_id': widget.propertyId},
      );
    } else {
      await favoriteRef.delete();
      FirebaseAnalytics.instance.logEvent(
        name: 'remove_from_favorites',
        parameters: {'property_id': widget.propertyId},
      );
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (shouldDelete == null || !shouldDelete) return;

    try {
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
    final priceRaw = propertyData['price'] ?? 0.0;
    num price = (priceRaw is num)
        ? priceRaw
        : (num.tryParse(priceRaw.toString()) ?? 0.0);
    final currency = propertyData['currency'] ?? 'ر.س';

    // 👇👇👇 التعديل هنا: استخدمنا https بدلاً من aqarapp 👇👇👇
    // هذا الرابط سيظهر باللون الأزرق في واتساب، والأندرويد سيلتقطه ويفتح تطبيقك
    final String deepLink = 'https://n4yo.com/property/${widget.propertyId}';

    const String storeLink =
        'https://play.google.com/store/apps/details?id=com.shami313.aqar_app';

    final shareText =
        '''
🏠 *فرصة عقارية مميزة في عقار بلص*

📌 *$title*
💰 *السعر:* ${price.toStringAsFixed(0)} $currency

📲 *لفتح العقار في التطبيق مباشرة:*
$deepLink

📥 *ليس لديك التطبيق؟ حمله من هنا:*
$storeLink
''';

    Share.share(shareText);

    FirebaseAnalytics.instance.logEvent(
      name: 'share',
      parameters: {'content_type': 'property', 'item_id': widget.propertyId},
    );
  }

  void _startOrOpenChat(Map<String, dynamic> propertyData) async {
    final ownerId = propertyData['userId'];
    const adminId = 'QzX6w0qA8vflx5oGM3jW4GgW2BC2';

    if (_currentUser == null || _currentUser!.uid == ownerId) return;

    final currentUser = _currentUser!;
    final requiredParticipants = [currentUser.uid, ownerId, adminId];
    final uniqueParticipants = requiredParticipants.toSet().toList();

    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('propertyId', isEqualTo: widget.propertyId)
        .where('participants', arrayContains: currentUser.uid)
        .get();

    DocumentSnapshot? existingChat;

    for (final doc in chatQuery.docs) {
      final participants = List<String>.from(doc['participants']);
      if (participants.contains(ownerId)) {
        existingChat = doc;
        break;
      }
    }

    if (existingChat != null) {
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
        /* ignore */
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
      } catch (e) {
        /* ignore */
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

  // --- 2. دالة جديدة لبناء بطاقة معلومات البائع ---
  Widget _buildSellerInfo(
    BuildContext context,
    String ownerId,
    Map<String, dynamic> propertyData,
  ) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final username = userData?['username'] ?? 'المعلن';
        final userImage = userData?['profileImageUrl'];
        final isVerified =
            (userData?['isVerified'] == true) || (userData?['role'] == 'admin');

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              // --- جعل الصورة والاسم قابلين للنقر ---
              Expanded(
                child: InkWell(
                  onTap: () {
                    // الانتقال للبروفايل العام
                    // تأكد من استيراد public_profile_screen.dart في الأعلى
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PublicProfileScreen(
                          userId: ownerId,
                          userName: username,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: userImage != null
                            ? CachedNetworkImageProvider(userImage)
                            : null,
                        child: userImage == null
                            ? Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isVerified) ...[
                                  const SizedBox(width: 6),
                                  const VerifiedBadge(size: 16),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'انقر لعرض الملف الشخصي',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!_isOwner)
                IconButton.filledTonal(
                  onPressed: () => _startOrOpenChat(propertyData),
                  icon: const Icon(Icons.chat_bubble_outline),
                  tooltip: 'مراسلة',
                ),
            ],
          ),
        );
      },
    );
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
          num price = (priceRaw is num)
              ? priceRaw
              : (num.tryParse(priceRaw.toString()) ?? 0.0);
          final currency = property['currency'] ?? 'ر.س';
          final description = property['description'] ?? 'لا يوجد وصف.';
          final imageUrls = property['imageUrls'] as List<dynamic>? ?? [];

          final videoUrl = property['videoUrl'] as String?;
          if (videoUrl != null && _chewieController == null) {
            _initializeVideoPlayer(videoUrl);
          }

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
              // --- شريط العنوان والصور ---
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: imageUrls.isNotEmpty
                      ? PageView.builder(
                          itemCount: imageUrls.length,
                          itemBuilder: (ctx, index) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenGallery(
                                      imageUrls: imageUrls,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: imageUrls[index],
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    bottom: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.fullscreen,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.house, size: 48),
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
                      onPressed: () => Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (ctx) => EditPropertyScreen(
                                propertyId: widget.propertyId,
                              ),
                            ),
                          )
                          .then(
                            (_) => setState(() {
                              _propertyFuture = FirebaseFirestore.instance
                                  .collection('properties')
                                  .doc(widget.propertyId)
                                  .get();
                            }),
                          ),
                      icon: const Icon(Icons.edit),
                    ),
                  if (_isOwner)
                    IconButton(
                      onPressed: _deleteProperty,
                      icon: const Icon(Icons.delete),
                    ),
                ],
              ),

              // --- محتوى الصفحة ---
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

                        // فيديو
                        if (videoUrl != null) ...[
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
                                      Icons.videocam_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'جولة فيديو',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 250,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: _chewieController != null
                                        ? Chewie(controller: _chewieController!)
                                        : const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

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

                        // --- 3. عرض بطاقة البائع الجديدة هنا ---
                        _buildSellerInfo(context, property['userId'], property),

                        // الموقع
                        if (location != null) ...[
                          const SizedBox(height: 10),
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

                        // زر التواصل السفلي الكبير (إبقاءه كخيار إضافي بارز)
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

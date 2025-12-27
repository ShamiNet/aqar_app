import 'package:aqar_app/screens/edit_property_screen.dart';
import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:aqar_app/screens/public_profile_screen.dart';
import 'package:aqar_app/widgets/full_screen_gallery.dart';
import 'package:aqar_app/widgets/verified_badge.dart';
import 'package:aqar_app/services/api_service.dart'; // ✅
import 'package:aqar_app/widgets/report_dialog.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PropertyDetailsScreen extends StatefulWidget {
  const PropertyDetailsScreen({super.key, required this.propertyId});
  final String propertyId;

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  late Future<Map<String, dynamic>?> _propertyFuture;
  bool _isOwner = false;
  bool _isFavorited = false;
  String? _currentUserId;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  String _dealStatus = 'none';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _propertyFuture = ApiService.fetchPropertyDetails(widget.propertyId);
    _checkIfFavorited();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('user_id');
    });
  }

  // التحقق من المفضلة (يمكن تحسينها بجلب القائمة مرة واحدة)
  Future<void> _checkIfFavorited() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');
    if (uid != null) {
      final favs = await ApiService.fetchFavorites(uid);
      if (mounted) {
        setState(() {
          _isFavorited = favs.any(
            (element) => element['id'] == widget.propertyId,
          );
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول')));
      return;
    }
    // تحديث واجهة فوري
    setState(() => _isFavorited = !_isFavorited);
    try {
      await ApiService.toggleFavorite(widget.propertyId);
    } catch (e) {
      // تراجع عند الخطأ
      setState(() => _isFavorited = !_isFavorited);
    }
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    if (_videoPlayerController != null) return;
    try {
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
          errorBuilder: (context, errorMessage) => const Center(
            child: Text(
              'فشل تحميل الفيديو',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      });
    } catch (e) {
      debugPrint('Video error: $e');
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _shareProperty(String title, num price, String currency) {
    Share.share(
      'فرصة عقارية مميزة: $title\nالسعر: $price $currency\nتطبيق عقار بلص',
    );
  }

  void _startOrOpenChat(String ownerId, String ownerName) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول')));
      return;
    }
    try {
      final chatId = await ApiService.startChat(widget.propertyId, ownerId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => ChatMessagesScreen(
            chatId: chatId,
            recipientId: ownerId,
            recipientName: ownerName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('فشل بدء المحادثة')));
    }
  }

  Future<void> _requestDeal(String type, String sellerId) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول')));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد طلب $type'),
        content: Text('هل أنت متأكد من إرسال طلب $type لهذا العقار؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _dealStatus = 'loading');
      try {
        await ApiService.submitDealRequest(widget.propertyId, sellerId, type);
        setState(() => _dealStatus = 'pending');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إرسال الطلب بنجاح!')));
      } catch (e) {
        setState(() => _dealStatus = 'none');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('فشل إرسال الطلب')));
      }
    }
  }

  void _showRatingDialog(String sellerId, String sellerName) {
    double rating = 5;
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تقييم $sellerName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RatingBar.builder(
              initialRating: 5,
              minRating: 1,
              itemBuilder: (context, _) =>
                  const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (r) => rating = r,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(hintText: 'تعليقك...'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.submitRating(
                  sellerId,
                  rating,
                  commentController.text,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('تم التقييم')));
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('فشل التقييم')));
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  void _launchMapsUrl(double lat, double lon) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _propertyFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('العقار غير موجود')),
            );
          }

          final property = snapshot.data!;
          final userId = property['userId'];
          _isOwner = _currentUserId == userId;

          final title = property['title'] ?? 'بدون عنوان';
          final priceRaw = property['price'] ?? 0;
          final price = priceRaw is num
              ? priceRaw
              : num.tryParse(priceRaw.toString()) ?? 0;
          final currency = property['currency'] ?? 'ر.س';
          final description = property['description'] ?? 'لا يوجد وصف متاح';
          final category = property['category'] ?? 'غير محدد';
          final rooms = property['rooms'];
          final area = property['area'];
          final floor = property['floor'];
          final imageUrls = property['imageUrls'] as List<dynamic>? ?? [];
          final videoUrl = property['videoUrl'];

          if (videoUrl != null && _chewieController == null) {
            _initializeVideoPlayer(videoUrl);
          }

          double? lat, lng;
          if (property['location'] is Map) {
            lat =
                (property['location']['_latitude'] ??
                        property['location']['latitude'])
                    ?.toDouble();
            lng =
                (property['location']['_longitude'] ??
                        property['location']['longitude'])
                    ?.toDouble();
          }

          final sellerInfo = property['sellerInfo'] as Map<String, dynamic>?;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: imageUrls.isNotEmpty
                      ? PageView.builder(
                          itemCount: imageUrls.length,
                          itemBuilder: (ctx, index) => GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenGallery(
                                  imageUrls: imageUrls,
                                  initialIndex: index,
                                ),
                              ),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: imageUrls[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.house, size: 64),
                        ),
                ),
                actions: [
                  _buildAppBarIcon(
                    icon: Icons.share,
                    onPressed: () => _shareProperty(title, price, currency),
                  ),

                  // زر المفضلة المفعل
                  if (!_isOwner && _currentUserId != null)
                    _buildAppBarIcon(
                      icon: _isFavorited
                          ? Icons.favorite
                          : Icons.favorite_border,
                      iconColor: _isFavorited ? Colors.red : Colors.black87,
                      onPressed: _toggleFavorite,
                    ),

                  if (_isOwner)
                    _buildAppBarIcon(
                      icon: Icons.edit,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EditPropertyScreen(propertyId: widget.propertyId),
                        ),
                      ),
                    ),
                  if (!_isOwner)
                    _buildAppBarIcon(
                      icon: Icons.flag,
                      iconColor: Colors.red,
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) =>
                            ReportDialog(propertyId: widget.propertyId),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${price.toStringAsFixed(0)} $currency',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ✅ عرض المواصفات (تم استغلال المتغيرات هنا)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildInfoCard(
                              Icons.category,
                              'النوع',
                              category,
                              Colors.blue,
                            ),
                            if (rooms != null)
                              _buildInfoCard(
                                Icons.bed,
                                'الغرف',
                                '$rooms',
                                Colors.teal,
                              ),
                            if (area != null)
                              _buildInfoCard(
                                Icons.square_foot,
                                'المساحة',
                                '$area م²',
                                Colors.orange,
                              ),
                            if (floor != null)
                              _buildInfoCard(
                                Icons.stairs,
                                'الطابق',
                                '$floor',
                                Colors.purple,
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        if (_chewieController != null) ...[
                          const Text(
                            'جولة فيديو',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 250,
                              color: Colors.black,
                              child: Chewie(controller: _chewieController!),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ✅ عرض الوصف (تم استغلال المتغير هنا)
                        const Text(
                          'الوصف',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: const TextStyle(height: 1.5, fontSize: 15),
                        ),
                        const SizedBox(height: 24),

                        if (sellerInfo != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundImage:
                                      sellerInfo['profileImageUrl'] != null
                                      ? CachedNetworkImageProvider(
                                          sellerInfo['profileImageUrl'],
                                        )
                                      : null,
                                  child: sellerInfo['profileImageUrl'] == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            sellerInfo['username'] ?? 'المعلن',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (sellerInfo['isVerified'] == true)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                right: 4,
                                              ),
                                              child: VerifiedBadge(size: 16),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        'التقييم: ${sellerInfo['reputationScore']?.toStringAsFixed(1) ?? "0.0"} ⭐',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_isOwner) ...[
                                  IconButton.filledTonal(
                                    onPressed: () => _startOrOpenChat(
                                      userId,
                                      sellerInfo['username'] ?? 'المعلن',
                                    ),
                                    icon: const Icon(Icons.chat_bubble_outline),
                                    tooltip: 'مراسلة',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    onPressed: () => _showRatingDialog(
                                      userId,
                                      sellerInfo['username'] ?? 'المعلن',
                                    ),
                                    icon: const Icon(Icons.star_outline),
                                    tooltip: 'تقييم',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),

                        if (!_isOwner && _currentUserId != null)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: _buildDealButton(category, userId),
                          ),

                        if (lat != null && lng != null) ...[
                          const SizedBox(height: 30),
                          const Text(
                            'الموقع',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 200,
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(lat, lng),
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('loc'),
                                  position: LatLng(lat, lng),
                                ),
                              },
                              liteModeEnabled: true,
                            ),
                          ),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => _launchMapsUrl(lat!, lng!),
                              icon: const Icon(Icons.map),
                              label: const Text('فتح في خرائط جوجل'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 40),
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

  Widget _buildAppBarIcon({
    required IconData icon,
    required VoidCallback onPressed,
    Color iconColor = Colors.black87,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDealButton(String category, String sellerId) {
    final isRent = category == 'إيجار';
    final text = isRent ? 'طلب استئجار' : 'طلب شراء';
    if (_dealStatus == 'loading')
      return const Center(child: CircularProgressIndicator());
    if (_dealStatus == 'pending')
      return ElevatedButton(
        onPressed: null,
        child: const Text('الطلب قيد المراجعة'),
      );
    return ElevatedButton.icon(
      onPressed: () => _requestDeal(isRent ? 'إيجار' : 'شراء', sellerId),
      icon: Icon(isRent ? Icons.vpn_key : Icons.shopping_bag),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: isRent ? Colors.purple : Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }
}

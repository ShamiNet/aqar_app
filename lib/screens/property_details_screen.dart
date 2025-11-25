import 'package:aqar_app/screens/edit_property_screen.dart';
import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:aqar_app/screens/public_profile_screen.dart';
import 'package:aqar_app/widgets/full_screen_gallery.dart';
import 'package:aqar_app/widgets/verified_badge.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aqar_app/widgets/report_dialog.dart';
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
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  String _dealStatus = 'loading';

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
    _checkDealStatus();
  }

  Future<void> _checkDealStatus() async {
    if (_currentUser == null) {
      setState(() => _dealStatus = 'none');
      return;
    }
    try {
      final dealQuery = await FirebaseFirestore.instance
          .collection('deals')
          .where('propertyId', isEqualTo: widget.propertyId)
          .where('buyerId', isEqualTo: _currentUser!.uid)
          .limit(1)
          .get();

      final newStatus = dealQuery.docs.isEmpty
          ? 'none'
          : dealQuery.docs.first['status'];
      setState(() => _dealStatus = newStatus);
    } catch (e) {
      setState(() => _dealStatus = 'none');
    }
  }

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
    } else {
      await favoriteRef.delete();
    }
  }

  Future<void> _archiveOrDeleteProperty(String reason, String title) async {
    // ... (نفس كود الأرشفة السابق)
    // للاختصار لم أغير فيه شيئاً
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          'هل أنت متأكد؟ سيتم نقل العقار إلى الأرشيف ولن يظهر في القوائم العامة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(title),
            style: ElevatedButton.styleFrom(
              backgroundColor: reason == 'حذف بواسطة المالك'
                  ? Colors.red
                  : null,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId);
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        await FirebaseFirestore.instance.collection('archived_properties').add({
          ...docSnapshot.data()!,
          'originalId': widget.propertyId,
          'archivedAt': FieldValue.serverTimestamp(),
          'archiveReason': reason,
        });
      }
      await docRef.delete();
      if (mounted) Navigator.of(context).pop('تم أرشفة العقار بنجاح.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحذف: ${e.toString()}')),
      );
    }
  }

  Future<void> _togglePauseProperty(bool isCurrentlyPaused) async {
    // ... (نفس كود الإيقاف المؤقت)
    final String actionText = isCurrentlyPaused ? 'إعادة تفعيل' : 'إيقاف مؤقت';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionText العقار'),
        content: Text(
          isCurrentlyPaused
              ? 'هل أنت متأكد من إعادة تفعيل العقار؟ سيظهر مجدداً في القوائم العامة.'
              : 'هل أنت متأكد من إيقاف العقار مؤقتاً؟ سيتم إخفاؤه من العرض العام.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionText),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .update({'isPaused': !isCurrentlyPaused});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم ${actionText} العقار بنجاح.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  void _showManagementBottomSheet() {
    // ... (نفس كود القائمة السفلية)
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              FutureBuilder<DocumentSnapshot>(
                future: _propertyFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final isPaused =
                      (snapshot.data!.data()
                          as Map<String, dynamic>)['isPaused'] ==
                      true;
                  return ListTile(
                    leading: Icon(
                      isPaused
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                      color: Colors.orange,
                    ),
                    title: Text(
                      isPaused ? 'إعادة تفعيل العرض' : 'إيقاف مؤقت للعرض',
                    ),
                    subtitle: Text(
                      isPaused
                          ? 'سيظهر العقار للجميع مرة أخرى'
                          : 'سيتم إخفاء العقار مؤقتاً',
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _togglePauseProperty(isPaused);
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.sell_outlined, color: Colors.green),
                title: const Text('تحديد كـ "تم البيع"'),
                subtitle: const Text('سيتم أرشفة العقار ونقله لسجلاتك'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _archiveOrDeleteProperty('تم البيع', 'تأكيد البيع');
                },
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined, color: Colors.blue),
                title: const Text('تحديد كـ "تم التأجير"'),
                subtitle: const Text('سيتم أرشفة العقار ونقله لسجلاتك'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _archiveOrDeleteProperty('تم التأجير', 'تأكيد التأجير');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'حذف العقار',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text('سيتم نقل العقار إلى الأرشيف أولاً'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _archiveOrDeleteProperty('حذف بواسطة المالك', 'تأكيد الحذف');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareProperty(Map<String, dynamic> propertyData) {
    final title = propertyData['title'] ?? 'بدون عنوان';
    final priceRaw = propertyData['price'] ?? 0.0;
    num price = (priceRaw is num)
        ? priceRaw
        : (num.tryParse(priceRaw.toString()) ?? 0.0);
    final currency = propertyData['currency'] ?? 'ر.س';

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
      // فتح شاشة المحادثة الموجودة
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
      // إنشاء محادثة جديدة + إشعار
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
      final propertyTitle = propertyData['title'] ?? 'بدون عنوان';

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
            'propertyTitle': propertyTitle,
            'propertyImageUrl': propertyImageUrl,
          });

      // 🚀 [إشعار] تنبيه المعلن ببدء محادثة جديدة
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': ownerId,
        'title': 'استفسار جديد 💬',
        'body': 'بدأ $currentUserName محادثة بخصوص عقارك: $propertyTitle',
        'propertyId': widget.propertyId,
        'type': 'new_chat',
        'timestamp': FieldValue.serverTimestamp(),
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
    // ... (نفس الكود)
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
    // ... (نفس الكود)
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

  Widget _buildAppBarIcon({
    required IconData icon,
    required VoidCallback onPressed,
    Color iconColor = Colors.black87,
    String? tooltip,
  }) {
    // ... (نفس الكود)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: iconColor, size: 22),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildSellerInfo(
    BuildContext context,
    String ownerId,
    Map<String, dynamic> propertyData,
  ) {
    // ... (نفس الكود)
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
              Expanded(
                child: InkWell(
                  onTap: () {
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

  Future<void> showDealConfirmationDialog(
    String type,
    String sellerId,
    String sellerName,
  ) async {
    // ... (نفس الكود)
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول أولاً للمتابعة.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تأكيد طلب $type'),
        content: Text(
          'هل تود تأكيد رغبتك في $type هذا العقار؟ سيتم تسجيل الطلب وإتاحة الفرصة لتقييم البائع بعد إتمام الاتفاق.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد وإتمام'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _recordDeal(type, sellerId, sellerName);
    }
  }

  Future<void> _recordDeal(
    String dealType,
    String sellerId,
    String sellerName,
  ) async {
    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .get();
    final currentUserName = currentUserDoc.data()?['username'] ?? 'مشتري جديد';

    // جلب عنوان العقار للإشعار
    final propertyTitle = (await _propertyFuture).get('title') ?? 'عقار';

    try {
      setState(() => _dealStatus = 'loading');

      await FirebaseFirestore.instance.collection('deals').add({
        'propertyId': widget.propertyId,
        'buyerId': _currentUser!.uid,
        'sellerId': sellerId,
        'buyerName': currentUserName,
        'dealType': dealType,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'isBuyerRated': false,
        'propertyTitle': propertyTitle,
      });

      // 🚀 [إشعار] إرسال تنبيه للبائع بوجود طلب جديد
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': sellerId,
        'title': 'طلب صفقة جديد ($dealType)',
        'body': 'لديك طلب $dealType جديد للعقار: $propertyTitle',
        'propertyId': widget.propertyId,
        'type': 'deal_request',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() => _dealStatus = 'pending');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلبك بنجاح! سيظهر في سجل صفقاتك بانتظار موافقة البائع.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error recording deal: $e');
      setState(() => _dealStatus = 'none');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء التسجيل: $e')));
    }
  }

  // ... (showRatingPromptDialog نفس الكود)
  void showRatingPromptDialog(String sellerId, String sellerName) {
    double selectedRating = 5.0;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تقييم البائع: $sellerName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('كيف كانت تجربتك مع هذا المعلن؟'),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setStateSB) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          onPressed: () {
                            setStateSB(() {
                              selectedRating = index + 1.0;
                            });
                          },
                          icon: Icon(
                            index < selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    Text(
                      'التقييم: ${selectedRating.toInt()} من 5',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reviewController,
              decoration: const InputDecoration(
                labelText: 'اكتب تعليقك (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('تخطي'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _submitUserRating(
                sellerId,
                selectedRating,
                reviewController.text,
              );
            },
            child: const Text('إرسال التقييم'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitUserRating(
    String sellerId,
    double rating,
    String review,
  ) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) throw Exception("User does not exist!");

        final data = userSnapshot.data() as Map<String, dynamic>;
        double currentScore = (data['reputationScore'] ?? 0.0).toDouble();
        int currentCount = (data['reputationCount'] ?? 0).toInt();

        double newScore =
            ((currentScore * currentCount) + rating) / (currentCount + 1);
        int newCount = currentCount + 1;

        transaction.update(userRef, {
          'reputationScore': newScore,
          'reputationCount': newCount,
        });

        final reviewRef = userRef.collection('reviews').doc();
        transaction.set(reviewRef, {
          'reviewerId': _currentUser!.uid,
          'rating': rating,
          'comment': review,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      // 🚀 [إشعار] تنبيه البائع بأنه حصل على تقييم
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': sellerId,
        'title': 'تقييم جديد ⭐',
        'body': 'حصلت على تقييم جديد بقيمة ${rating.toInt()}/5',
        'propertyId': widget.propertyId,
        'type': 'new_rating',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال تقييمك بنجاح! شكراً لك.')),
      );
    } catch (e) {
      debugPrint('Failed to submit rating: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إرسال التقييم، حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (نفس كود بناء الواجهة تماماً، لم يتغير)
    // سأختصر هنا لعدم الإطالة، انسخ الـ build كما كان في ملفك الأصلي
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
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildAppBarIcon(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
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
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.fullscreen,
                                        color: Colors.white,
                                        size: 20,
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
                  _buildAppBarIcon(
                    icon: Icons.share,
                    onPressed: () => _shareProperty(property),
                    tooltip: 'مشاركة',
                  ),
                  if (_currentUser != null)
                    _buildAppBarIcon(
                      icon: _isFavorited
                          ? Icons.favorite
                          : Icons.favorite_border,
                      iconColor: _isFavorited ? Colors.red : Colors.black87,
                      onPressed: _toggleFavorite,
                      tooltip: 'المفضلة',
                    ),
                  if (!_isOwner)
                    _buildAppBarIcon(
                      icon: Icons.flag_outlined,
                      iconColor: Colors.red.shade700,
                      tooltip: 'إبلاغ',
                      onPressed: () {
                        if (_currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('يجب تسجيل الدخول للإبلاغ.'),
                            ),
                          );
                          return;
                        }
                        showDialog(
                          context: context,
                          builder: (ctx) =>
                              ReportDialog(propertyId: widget.propertyId),
                        );
                      },
                    ),
                  if (_isOwner) ...[
                    _buildAppBarIcon(
                      icon: Icons.edit,
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
                              setState(() {
                                _propertyFuture = FirebaseFirestore.instance
                                    .collection('properties')
                                    .doc(widget.propertyId)
                                    .get();
                              });
                            });
                      },
                      tooltip: 'تعديل',
                    ),
                    _buildAppBarIcon(
                      icon: Icons.settings_outlined,
                      onPressed: _showManagementBottomSheet,
                      tooltip: 'إدارة العقار',
                    ),
                  ],
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
                        _buildSellerInfo(context, property['userId'], property),
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
                        if (!_isOwner && _currentUser != null) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 56,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(context).colorScheme.primary
                                              .withOpacity(0.85),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.35),
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
                                                'مراسلة',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  height: 56,
                                  child: _buildDealButton(category, property),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 30),
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

  // (نفس دوال المساعدة للزر والأيقونات)
  Widget _buildDealButton(String category, Map<String, dynamic> property) {
    final dealType = category == 'إيجار' ? 'إيجار' : 'شراء';
    final buttonText = category == 'إيجار' ? 'استئجار' : 'شراء';
    final buttonIcon = category == 'إيجار'
        ? Icons.vpn_key
        : Icons.monetization_on;

    switch (_dealStatus) {
      case 'loading':
        return const ElevatedButton(
          onPressed: null,
          style: ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(Colors.grey),
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.white,
            ),
          ),
        );
      case 'pending':
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_top_rounded, size: 20),
          label: const Text('الطلب معلق', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: Colors.orange.shade700,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      case 'confirmed':
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle_rounded, size: 20),
          label: const Text('تمت الموافقة', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: Colors.teal,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      case 'none':
      default:
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
          onPressed: () => showDealConfirmationDialog(
            dealType,
            property['userId'],
            'المعلن',
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(buttonIcon, size: 20),
              const SizedBox(height: 4),
              Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
    }
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

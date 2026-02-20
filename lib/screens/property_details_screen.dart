import 'package:aqar_app/screens/chats_screen.dart';
import 'package:aqar_app/screens/chat_messages_screen.dart';
import 'package:aqar_app/screens/edit_property_screen.dart';
import 'package:aqar_app/screens/edit_history_screen.dart';
import 'package:aqar_app/screens/report_property_screen.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:aqar_app/providers/user_provider.dart';
import 'package:aqar_app/widgets/property_image_gallery.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final String propertyId;

  const PropertyDetailsScreen({super.key, required this.propertyId});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  Map<String, dynamic>? _property;
  bool _isLoading = true;
  String? _currentUserId;
  bool _isOwner = false;
  bool _isAdmin = false;
  bool _isFavorite = false;

  Set<Marker> _markers = {};
  LatLng? _propertyLocation;

  @override
  void initState() {
    super.initState();
    _isAdmin = Provider.of<UserProvider>(context, listen: false).isAdmin;
    _initData();
  }

  Future<void> _initData() async {
    try {
      await ApiService.incrementPropertyViews(widget.propertyId);
    } catch (e) {
      debugPrint('View increment failed: $e');
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      final data = await ApiService.fetchPropertyDetails(widget.propertyId);

      if (mounted) {
        setState(() {
          _property = data;
          _currentUserId = userId;

          if (data != null) {
            _isOwner = userId != null && data['ownerId'] == userId;

            if (data['latitude'] != null && data['longitude'] != null) {
              final lat = double.tryParse(data['latitude'].toString());
              final lng = double.tryParse(data['longitude'].toString());

              if (lat != null && lng != null && lat != 0 && lng != 0) {
                _propertyLocation = LatLng(lat, lng);
                _markers.add(
                  Marker(
                    markerId: const MarkerId('propertyLocation'),
                    position: _propertyLocation!,
                    infoWindow: InfoWindow(
                      title: data['title'] ?? 'موقع العقار',
                    ),
                  ),
                );
              }
            }
          }
          _isLoading = false;
        });

        if (_currentUserId != null) {
          _checkFavoriteStatus();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkFavoriteStatus() async {
    try {
      final favs = await ApiService.fetchFavorites(_currentUserId!);
      if (mounted) {
        setState(() {
          _isFavorite = favs.any(
            (f) => (f['id'] ?? f['_id']).toString() == widget.propertyId,
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول لإضافة العقار للمفضلة')),
      );
      return;
    }

    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      await ApiService.toggleFavorite(widget.propertyId);
    } catch (e) {
      setState(() {
        _isFavorite = !_isFavorite;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء تحديث المفضلة')),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    var phone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMapApp() async {
    if (_propertyLocation == null) return;
    final lat = _propertyLocation!.latitude;
    final lng = _propertyLocation!.longitude;
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      final appleMapsUrl = Uri.parse('https://maps.apple.com/?q=$lat,$lng');
      if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _startChat() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول لبدء المحادثة')),
      );
      return;
    }
    try {
      final chatId = await ApiService.startChat(
        widget.propertyId,
        _property!['ownerId'],
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatMessagesScreen(
            chatId: chatId,
            recipientId: _property!['ownerId'],
            recipientName: _property!['sellerInfo']?['username'] ?? 'المعلن',
            propertyId: widget.propertyId,
            propertyTitle: _property!['title'],
            propertyImage: (_property!['images'] as List?)?.isNotEmpty == true
                ? _property!['images'][0]
                : null,
            propertyPrice: '${_property!['price']} ر.س',
          ),
        ),
      );
    } catch (e) {
      if (mounted)
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ChatsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_property == null)
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('عذراً، لم يتم العثور على العقار')),
      );

    // ✅ متغيرات الثيم (الألوان تتغير تلقائياً حسب الوضع الفاتح أو الليلي)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final containerBgColor = isDark
        ? Colors.grey.shade900
        : Colors.grey.shade50;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final iconBgColor = isDark
        ? Colors.black.withOpacity(0.5)
        : Colors.white.withOpacity(0.9);

    final canEdit = _isOwner || _isAdmin;

    final images =
        (_property!['images'] ?? _property!['imageUrls'] ?? []) as List;
    final title = _property!['title'] ?? 'بدون عنوان';
    final price = _property!['price'] ?? 0;
    final currency = _property!['currency'] ?? 'ر.س';
    final description = _property!['description'] ?? '';
    final address = _property!['address'] ?? '';
    final views = _property!['views'] ?? 0;
    final isEdited = _property!['isEdited'] ?? false;
    final editHistory = _property!['editHistory'] ?? [];

    final bedrooms = _property!['bedrooms'] ?? _property!['rooms'] ?? 0;
    final bathrooms = _property!['bathrooms'] ?? 0;
    final area = _property!['area'] ?? 0;
    final floor = _property!['floor'];
    final livingRooms = _property!['livingRooms'];
    final streetWidth = _property!['streetWidth'];
    final age = _property!['age'];

    final featuresList = <Widget>[];
    if (_property!['isFurnished'] == true)
      featuresList.add(_buildFeatureChip(Icons.chair, 'مؤثث', isDark));
    if (_property!['hasKitchen'] == true)
      featuresList.add(_buildFeatureChip(Icons.kitchen, 'مطبخ', isDark));
    if (_property!['hasAnnex'] == true)
      featuresList.add(_buildFeatureChip(Icons.home_work, 'ملحق', isDark));
    if (_property!['hasCarEntrance'] == true)
      featuresList.add(_buildFeatureChip(Icons.garage, 'مدخل سيارة', isDark));
    if (_property!['hasElevator'] == true)
      featuresList.add(_buildFeatureChip(Icons.elevator, 'مصعد', isDark));
    if (_property!['hasPool'] == true)
      featuresList.add(_buildFeatureChip(Icons.pool, 'مسبح', isDark));
    if (_property!['features'] is List) {
      for (var f in _property!['features']) {
        featuresList.add(
          _buildFeatureChip(Icons.check_circle_outline, f.toString(), isDark),
        );
      }
    }

    final sellerInfo = _property!['sellerInfo'] ?? {};
    final sellerName = sellerInfo['username'] ?? 'مستخدم';
    final sellerPhone = sellerInfo['phone'];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            actions: [
              // زر المفضلة
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite
                        ? Colors.red
                        : (isDark ? Colors.white : Colors.grey[700]),
                    size: 28,
                  ),
                  onPressed: _toggleFavorite,
                ),
              ),
              // زر المشاركة
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.share,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                    size: 28,
                  ),
                  onPressed: () => Share.share(
                    'شاهد هذا العقار المميز: $title \n بسعر $price $currency',
                  ),
                ),
              ),
              // زر التعديل
              if (canEdit)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: isDark ? Colors.orange[400] : Colors.orange[700],
                      size: 28,
                    ),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) =>
                              EditPropertyScreen(propertyId: widget.propertyId),
                        ),
                      );
                      _loadData();
                    },
                  ),
                ),
              // زر الإبلاغ
              if (!canEdit)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.flag,
                      color: isDark ? Colors.red[400] : Colors.red[600],
                      size: 28,
                    ),
                    tooltip: 'إبلاغ عن مخالفة',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => ReportPropertyScreen(
                            propertyId: widget.propertyId,
                            propertyTitle: title,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: images.isNotEmpty
                  ? PropertyImageGallery(
                      imageUrls: (images).cast<String>().toList(),
                      propertyTitle: title,
                    )
                  : Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: isDark ? Colors.grey[600] : Colors.grey,
                      ),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // العنوان والسعر
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                        ),
                      ),
                      Text(
                        '$price $currency',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // العنوان والمشاهدات
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: subTextColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(color: subTextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: subTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$views مشاهدة',
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                      if (isEdited) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditHistoryScreen(editHistory: editHistory),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.history_edu,
                                  size: 12,
                                  color: isDark
                                      ? Colors.orange[300]
                                      : Colors.orange.shade800,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'مُعدّل',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.orange[300]
                                        : Colors.orange.shade800,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // مواصفات العقار (الغرف والمساحة)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: containerBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSpecItem(
                              Icons.bed_outlined,
                              '$bedrooms غرف',
                              textColor,
                            ),
                            _buildSpecItem(
                              Icons.bathtub_outlined,
                              '$bathrooms حمام',
                              textColor,
                            ),
                            _buildSpecItem(
                              Icons.square_foot,
                              '$area م²',
                              textColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(color: borderColor),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            if (livingRooms != null &&
                                int.tryParse(livingRooms.toString()) != 0)
                              _buildSpecItem(
                                Icons.chair_outlined,
                                '$livingRooms صالات',
                                textColor,
                              ),
                            if (age != null &&
                                int.tryParse(age.toString()) != 0)
                              _buildSpecItem(
                                Icons.history,
                                'عمر $age سنة',
                                textColor,
                              ),
                            if (streetWidth != null &&
                                double.tryParse(streetWidth.toString()) != 0)
                              _buildSpecItem(
                                Icons.add_road,
                                'شارع $streetWidth م',
                                textColor,
                              ),
                            if (floor != null)
                              _buildSpecItem(
                                Icons.layers_outlined,
                                'طابق $floor',
                                textColor,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // المميزات الإضافية (رقاقات)
                  if (featuresList.isNotEmpty) ...[
                    Text(
                      'المميزات والخدمات',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: featuresList),
                    const SizedBox(height: 24),
                  ],

                  // التفاصيل النصية
                  Text(
                    'تفاصيل العقار',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: textColor,
                    ),
                  ),

                  // الخريطة
                  if (_propertyLocation != null) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الموقع على الخريطة',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                        ),
                        TextButton.icon(
                          onPressed: _openMapApp,
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('فتح في الخرائط'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _propertyLocation!,
                            zoom: 14,
                          ),
                          markers: _markers,
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          onTap: (_) => _openMapApp(),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  // كارت المعلن
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: containerBgColor,
                          backgroundImage: sellerInfo['profileImageUrl'] != null
                              ? NetworkImage(sellerInfo['profileImageUrl'])
                              : null,
                          child: sellerInfo['profileImageUrl'] == null
                              ? Icon(Icons.person, color: subTextColor)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sellerName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'المعلن',
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (!_isOwner) ...[
                          IconButton(
                            onPressed: () => _startChat(),
                            icon: const Icon(Icons.chat_bubble_outline),
                            color: Theme.of(context).primaryColor,
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                            ),
                          ),
                          if (sellerPhone != null)
                            IconButton(
                              onPressed: () => _makePhoneCall(sellerPhone),
                              icon: const Icon(Icons.phone),
                              color: Colors.green,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green.withOpacity(0.1),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: (!_isOwner)
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor, // يعتمد على الثيم الأساسي للشاشة
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: sellerPhone != null
                          ? () => _openWhatsApp(sellerPhone)
                          : null,
                      icon: const Icon(Icons.chat),
                      label: const Text('تواصل واتساب'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _startChat(),
                      icon: const Icon(Icons.send),
                      label: const Text('مراسلة الآن'),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // ✅ دالة المواصفات أصبحت تقبل لون النص
  Widget _buildSpecItem(IconData icon, String text, Color textColor) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // ✅ دالة المميزات (الرقاقات) أصبحت تتفاعل مع الثيم الليلي
  Widget _buildFeatureChip(IconData icon, String label, bool isDark) {
    return Chip(
      avatar: Icon(
        icon,
        size: 18,
        color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
      ),
      label: Text(label),
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
      side: BorderSide(
        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        color: isDark ? Colors.white : Colors.grey.shade800,
        fontSize: 12,
      ),
    );
  }
}

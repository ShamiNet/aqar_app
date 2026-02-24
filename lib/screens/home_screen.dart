import 'package:aqar_app/horizontal_properties_section.dart';
import 'package:aqar_app/property_card.dart';
import 'package:aqar_app/screens/filtered_properties_screen.dart';
import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aqar_app/config/app_constants.dart';
import 'package:aqar_app/providers/properties_refresh_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  late final PropertiesRefreshProvider _refreshProvider;
  late final VoidCallback _refreshListener;

  // ✅ 1. فصلنا القوائم كمتغيرات حالة (State) لكي لا يتم حسابها مع كل إعادة رسم (يحسن الأداء جداً)
  List<Map<String, dynamic>> _featuredProperties = [];
  List<Map<String, dynamic>> _saleProperties = [];
  List<Map<String, dynamic>> _rentProperties = [];
  List<Map<String, dynamic>> _houses = [];
  List<Map<String, dynamic>> _villas = [];
  List<Map<String, dynamic>> _lands = [];
  List<Map<String, dynamic>> _buildings = [];
  List<Map<String, dynamic>> _shops = [];
  List<Map<String, dynamic>> _discounted = [];
  List<Map<String, dynamic>> _topViewed = [];
  List<Map<String, dynamic>> _newProperties = [];
  String _announcementText = '';
  String _announcementUrl = '';
  String? _announcementId;
  bool _announcementEnabled = false;
  bool _announcementViewRecorded = false;

  @override
  void initState() {
    super.initState();
    _refreshProvider = Provider.of<PropertiesRefreshProvider>(
      context,
      listen: false,
    );
    _refreshListener = () {
      _fetchData();
    };
    _refreshProvider.addListener(_refreshListener);
    SharedPreferences.getInstance().then((prefs) {
      debugPrint('USER_ID: ${prefs.getString(AppConstants.prefUserId)}');
    });
    _fetchData();
  }

  @override
  void dispose() {
    _refreshProvider.removeListener(_refreshListener);
    super.dispose();
  }

  // ✅ 2. دالة مخصصة لجلب البيانات (مبدأ المسؤولية الواحدة: جلب البيانات فقط)
  Future<void> _fetchData() async {
    try {
      final properties = await ApiService.fetchProperties(limit: 150);
      final settings = await ApiService.fetchAppSettings();
      final nextAnnouncementId = settings['announcement_id']?.toString();
      if (mounted) {
        final previousAnnouncementId = _announcementId;
        _categorizeProperties(
          properties,
        ); // تصنيف البيانات فور وصولها مرة واحدة
        setState(() {
          _announcementText = (settings['announcement_text'] ?? '').toString();
          _announcementUrl = (settings['announcement_url'] ?? '').toString();
          _announcementEnabled = settings['announcement_enabled'] == true;
          _announcementId = nextAnnouncementId;
          if (previousAnnouncementId != nextAnnouncementId) {
            _announcementViewRecorded = false;
          }
          _isLoading = false;
          _errorMessage = null;
        });
        _recordAnnouncementViewIfNeeded();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'فشل الاتصال بالسيرفر. تأكد من تشغيله.';
        });
      }
    }
  }

  // ✅ 3. دالة مخصصة لفرز البيانات وتصنيفها (تم إخراجها من دالة الـ build)
  void _categorizeProperties(List<Map<String, dynamic>> allProperties) {
    List<Map<String, dynamic>> filterBy(
      bool Function(Map<String, dynamic>) test,
    ) {
      return allProperties.where(test).take(10).toList();
    }

    _featuredProperties = filterBy((p) => p['isFeatured'] == true);
    _saleProperties = filterBy((p) => p['category'] == 'بيع');
    _rentProperties = filterBy((p) => p['category'] == 'إيجار');
    _houses = filterBy((p) => p['propertyType'] == 'بيت');
    _villas = filterBy((p) => p['propertyType'] == 'فيلا');
    _lands = filterBy((p) => p['propertyType'] == 'ارض');
    _buildings = filterBy((p) => p['propertyType'] == 'بناية');
    _shops = filterBy((p) => p['propertyType'] == 'دكان');
    _discounted = filterBy((p) => _parseInt(p['discountPercent']) > 0);

    final mostViewedList = List<Map<String, dynamic>>.from(allProperties);
    mostViewedList.sort(
      (a, b) => ((b['views'] ?? 0) as num).compareTo((a['views'] ?? 0) as num),
    );
    _topViewed = mostViewedList
        .where((p) => (p['views'] ?? 0) > 0)
        .take(10)
        .toList();

    final newestList = List<Map<String, dynamic>>.from(allProperties);
    newestList.sort(
      (a, b) => _getPropertyCreatedAt(b).compareTo(_getPropertyCreatedAt(a)),
    );
    _newProperties = newestList.take(10).toList();
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  DateTime _getPropertyCreatedAt(Map<String, dynamic> property) {
    final raw =
        property['createdAt'] ??
        property['created_at'] ??
        property['timestamp'] ??
        property['publishedAt'];
    return _parsePropertyDate(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _parsePropertyDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      if (value.toString().length > 10) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
    }
    if (value is Map) {
      if (value.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(value['_seconds'] * 1000);
      }
      if (value.containsKey('seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(value['seconds'] * 1000);
      }
    }
    return null;
  }

  // ✅ 4. دالة مساعدة لبناء الأقسام (تمنع تكرار الكود وتجعل الـ build قصيراً)
  Widget _buildSection(
    String title,
    List<Map<String, dynamic>> properties,
    String filterType,
    dynamic filterValue,
  ) {
    if (properties.isEmpty) return const SizedBox.shrink();
    return HorizontalPropertiesSection(
      title: title,
      properties: properties,
      filterType: filterType,
      filterValue: filterValue,
    );
  }

  // ✅ 5. دالة مساعدة لبناء واجهة الخطأ
  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                Text(_errorMessage!),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _fetchData();
                  },
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordAnnouncementViewIfNeeded() async {
    if (_announcementViewRecorded) return;
    if (!_announcementEnabled || _announcementText.trim().isEmpty) return;
    final announcementId = _announcementId;
    if (announcementId == null || announcementId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'announcement_viewed_$announcementId';
    if (prefs.getBool(key) == true) {
      _announcementViewRecorded = true;
      return;
    }

    final success = await ApiService.recordAnnouncementView(announcementId);
    if (success) {
      await prefs.setBool(key, true);
      _announcementViewRecorded = true;
    }
  }

  // ✅ 6. دالة الـ build أصبحت مجرد "خريطة" للعرض بدلاً من مكان لحساب البيانات!
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return _buildErrorState();

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade100,
                  Colors.blue.shade300,
                  Colors.grey.shade200,
                ],
              ),
      ),
      child: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_announcementEnabled && _announcementText.trim().isNotEmpty)
                _AnnouncementMarquee(
                  text: _announcementText.trim(),
                  url: _announcementUrl.trim().isEmpty
                      ? null
                      : _announcementUrl.trim(),
                ),
              if (_featuredProperties.isNotEmpty)
                _FeaturedPropertiesCarousel(properties: _featuredProperties),

              if (_newProperties.isNotEmpty)
                _NewPropertiesCarousel(properties: _newProperties),

              _buildSection('عقارات للبيع', _saleProperties, 'category', 'بيع'),
              _buildSection(
                'عقارات للإيجار',
                _rentProperties,
                'category',
                'إيجار',
              ),
              if (_rentProperties.isNotEmpty)
                _RentPropertiesCarousel(properties: _rentProperties),
              _buildSection('الأكثر مشاهدة 🔥', _topViewed, 'views', 'high'),
              _buildSection('بيوت', _houses, 'propertyType', 'بيت'),
              _buildSection('فلل', _villas, 'propertyType', 'فيلا'),
              _buildSection('أراضي', _lands, 'propertyType', 'ارض'),
              _buildSection('بنايات', _buildings, 'propertyType', 'بناية'),
              _buildSection('دكاكين', _shops, 'propertyType', 'دكان'),
              _buildSection('عقارات بخصم', _discounted, 'hasDiscount', true),

              const SizedBox(height: 55),
            ],
          ),
        ),
      ),
    );
  }
}

// كلاس الكاروسيل يبقى كما هو لأنه يمثل Widget منفصلة ومرتبة أصلاً
class _FeaturedPropertiesCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> properties;

  const _FeaturedPropertiesCarousel({required this.properties});

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FeaturedTitlePill(title: 'عقارات مميزة'),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const FilteredPropertiesScreen(
                        filterTitle: 'عقارات مميزة',
                        filterType: 'isFeatured',
                        filterValue: true,
                      ),
                    ),
                  );
                },
                child: const Text('عرض الكل'),
              ),
            ],
          ),
        ),
        CarouselSlider.builder(
          itemCount: properties.length,
          itemBuilder: (context, index, realIndex) {
            final doc = properties[index];
            final propertyId = doc['id'] ?? 'unknown';

            return SizedBox(
              width: MediaQuery.of(context).size.width,
              child: PropertyCard(
                property: doc,
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
          },
          options: CarouselOptions(
            height: 240,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 2),
            autoPlayAnimationDuration: const Duration(milliseconds: 1200),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            viewportFraction: 0.88,
            aspectRatio: 16 / 9,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _RentPropertiesCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> properties;

  const _RentPropertiesCarousel({required this.properties});

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FeaturedTitlePill(title: 'عقارات للإيجار'),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const FilteredPropertiesScreen(
                        filterTitle: 'عقارات للإيجار',
                        filterType: 'category',
                        filterValue: 'إيجار',
                      ),
                    ),
                  );
                },
                child: const Text('عرض الكل'),
              ),
            ],
          ),
        ),
        CarouselSlider.builder(
          itemCount: properties.length,
          itemBuilder: (context, index, realIndex) {
            final doc = properties[index];
            final propertyId = doc['id'] ?? 'unknown';

            return SizedBox(
              width: MediaQuery.of(context).size.width,
              child: PropertyCard(
                property: doc,
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
          },
          options: CarouselOptions(
            height: 240,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 3),
            autoPlayAnimationDuration: const Duration(milliseconds: 1200),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            viewportFraction: 0.88,
            aspectRatio: 16 / 9,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _NewPropertiesCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> properties;

  const _NewPropertiesCarousel({required this.properties});

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FeaturedTitlePill(title: 'عقارات جديدة'),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const FilteredPropertiesScreen(
                        filterTitle: 'عقارات جديدة',
                        filterType: 'newest',
                        filterValue: null,
                      ),
                    ),
                  );
                },
                child: const Text('عرض الكل'),
              ),
            ],
          ),
        ),
        CarouselSlider.builder(
          itemCount: properties.length,
          itemBuilder: (context, index, realIndex) {
            final doc = properties[index];
            final propertyId = doc['id'] ?? 'unknown';

            return SizedBox(
              width: MediaQuery.of(context).size.width,
              child: PropertyCard(
                property: doc,
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
          },
          options: CarouselOptions(
            height: 240,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 3),
            autoPlayAnimationDuration: const Duration(milliseconds: 1200),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            viewportFraction: 0.88,
            aspectRatio: 16 / 9,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _FeaturedTitlePill extends StatelessWidget {
  final String title;

  const _FeaturedTitlePill({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? const LinearGradient(colors: [Color(0xFF7EC9FF), Color(0xFF4A79FF)])
        : const LinearGradient(colors: [Color(0xFF0D2B5B), Color(0xFF2B7BFF)]);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _AnnouncementMarquee extends StatefulWidget {
  final String text;
  final String? url;

  const _AnnouncementMarquee({required this.text, this.url});

  @override
  State<_AnnouncementMarquee> createState() => _AnnouncementMarqueeState();
}

class _AnnouncementMarqueeState extends State<_AnnouncementMarquee>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  TextStyle _textStyle(BuildContext context) {
    return const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 14,
    );
  }

  Future<void> _handleTap() async {
    final url = widget.url;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [
        Color.fromARGB(255, 205, 184, 0),
        Color.fromARGB(255, 205, 123, 0),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GestureDetector(
        onTap: _handleTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.campaign,
                          color: Colors.white.withValues(alpha: 0.95),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _fadeAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _fadeAnimation.value,
                                child: child,
                              );
                            },
                            child: Text(
                              widget.text,
                              style: _textStyle(context),
                              textDirection: TextDirection.rtl,
                              softWrap: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedBuilder(
                          animation: _fadeAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _fadeAnimation.value,
                              child: child,
                            );
                          },
                          child: Icon(
                            Icons.touch_app_outlined,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

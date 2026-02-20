import 'package:aqar_app/horizontal_properties_section.dart';
import 'package:aqar_app/property_card.dart';
import 'package:aqar_app/screens/filtered_properties_screen.dart';
import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _errorMessage;

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

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // ✅ 2. دالة مخصصة لجلب البيانات (مبدأ المسؤولية الواحدة: جلب البيانات فقط)
  Future<void> _fetchData() async {
    try {
      final properties = await ApiService.fetchProperties(limit: 150);
      if (mounted) {
        _categorizeProperties(
          properties,
        ); // تصنيف البيانات فور وصولها مرة واحدة
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
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
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
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
              if (_featuredProperties.isNotEmpty)
                _FeaturedPropertiesCarousel(properties: _featuredProperties),

              _buildSection('عقارات للبيع', _saleProperties, 'category', 'بيع'),
              _buildSection(
                'عقارات للإيجار',
                _rentProperties,
                'category',
                'إيجار',
              ),
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
              Text(
                'عقارات مميزة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? null
                      : Colors.white,
                ),
              ),
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

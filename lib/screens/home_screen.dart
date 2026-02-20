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
  List<Map<String, dynamic>> _allProperties = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // لا نعرض مؤشر التحميل عند التحديث بالسحب للحفاظ على سلاسة التجربة
      // setState(() => _isLoading = true);

      final properties = await ApiService.fetchProperties();
      if (mounted) {
        setState(() {
          _allProperties = properties;
          _isLoading = false;
          _errorMessage = null; // تصفير الخطأ عند النجاح
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

  List<Map<String, dynamic>> _filterBy(
    bool Function(Map<String, dynamic>) test,
  ) {
    return _allProperties.where(test).take(10).toList();
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      // جعلنا واجهة الخطأ قابلة للسحب أيضاً لإعادة المحاولة
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

    final featuredProperties = _filterBy((p) => p['isFeatured'] == true);
    final saleProperties = _filterBy((p) => p['category'] == 'بيع');
    final rentProperties = _filterBy((p) => p['category'] == 'إيجار');
    final houses = _filterBy((p) => p['propertyType'] == 'بيت');
    final villas = _filterBy((p) => p['propertyType'] == 'فيلا');
    final lands = _filterBy((p) => p['propertyType'] == 'ارض');
    final buildings = _filterBy((p) => p['propertyType'] == 'بناية');
    final shops = _filterBy((p) => p['propertyType'] == 'دكان');
    final discounted = _filterBy((p) => _parseInt(p['discountPercent']) > 0);
    // ✅ استخراج العقارات الأكثر مشاهدة
    final mostViewedList = List<Map<String, dynamic>>.from(_allProperties);
    mostViewedList.sort((a, b) {
      final viewsA = (a['views'] ?? 0) as num;
      final viewsB = (b['views'] ?? 0) as num;
      return viewsB.compareTo(viewsA);
    });
    // نأخذ أعلى 10 عقارات مشاهدة (بشرط أن يكون لها مشاهدات أكبر من 0)
    final topViewed = mostViewedList
        .where((p) => (p['views'] ?? 0) > 0)
        .take(10)
        .toList();
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
      // ✅ هنا تمت إضافة RefreshIndicator
      child: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // مهم جداً لعمل السحب
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (featuredProperties.isNotEmpty)
                _FeaturedPropertiesCarousel(properties: featuredProperties),

              HorizontalPropertiesSection(
                title: 'عقارات للبيع',
                properties: saleProperties,
                filterType: 'category',
                filterValue: 'بيع',
              ),

              HorizontalPropertiesSection(
                title: 'عقارات للإيجار',
                properties: rentProperties,
                filterType: 'category',
                filterValue: 'إيجار',
              ),

              HorizontalPropertiesSection(
                title: 'بيوت',
                properties: houses,
                filterType: 'propertyType',
                filterValue: 'بيت',
              ),

              HorizontalPropertiesSection(
                title: 'فلل',
                properties: villas,
                filterType: 'propertyType',
                filterValue: 'فيلا',
              ),

              if (lands.isNotEmpty)
                HorizontalPropertiesSection(
                  title: 'أراضي',
                  properties: lands,
                  filterType: 'propertyType',
                  filterValue: 'ارض',
                ),

              HorizontalPropertiesSection(
                title: 'بنايات',
                properties: buildings,
                filterType: 'propertyType',
                filterValue: 'بناية',
              ),

              if (shops.isNotEmpty)
                HorizontalPropertiesSection(
                  title: 'دكاكين',
                  properties: shops,
                  filterType: 'propertyType',
                  filterValue: 'دكان',
                ),

              HorizontalPropertiesSection(
                title: 'عقارات بخصم',
                properties: discounted,
                filterType: 'hasDiscount',
                filterValue: true,
              ),
              // ✅ قسم العقارات الأكثر مشاهدة
              if (topViewed.isNotEmpty)
                HorizontalPropertiesSection(
                  title: 'الأكثر مشاهدة 🔥',
                  properties: topViewed,
                  filterType: 'views', // لا تهم هنا لأننا نرسل القائمة جاهزة
                  filterValue: 'high',
                ),

              const SizedBox(height: 55),
            ],
          ),
        ),
      ),
    );
  }
}

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

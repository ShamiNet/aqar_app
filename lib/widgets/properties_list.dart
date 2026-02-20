import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/property_card.dart';
import 'package:flutter/material.dart';

class PropertiesList extends StatefulWidget {
  final List<Map<String, dynamic>> properties;
  final Future<void> Function()? onLoadMore; // ✅ دالة جلب المزيد من العقارات
  final bool hasMore; // ✅ هل يوجد المزيد لجلبه؟

  const PropertiesList({
    super.key,
    required this.properties,
    this.onLoadMore,
    this.hasMore = false,
  });

  @override
  State<PropertiesList> createState() => _PropertiesListState();
}

class _PropertiesListState extends State<PropertiesList> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    // ✅ مراقبة حركة التمرير
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // ✅ إذا وصلنا لقبل نهاية القائمة بـ 200 بكسل، نطلب الصفحة التالية بذكاء
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!widget.hasMore || _isLoadingMore || widget.onLoadMore == null)
        return;

      setState(() => _isLoadingMore = true);
      widget.onLoadMore!().then((_) {
        if (mounted) setState(() => _isLoadingMore = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController, // ✅ ربط المتحكم بالقائمة
      padding: const EdgeInsets.all(8),
      // زيادة العدد بمقدار 1 لعرض مؤشر التحميل في الأسفل إذا كان هناك المزيد
      itemCount: widget.properties.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (ctx, index) {
        // ✅ إذا وصلنا لنهاية القائمة نعرض مؤشر التحميل الدائري
        if (index == widget.properties.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final property = widget.properties[index];
        final propertyId = property['id'] ?? 'unknown';

        return SizedBox(
          height: 280,
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
      },
    );
  }
}

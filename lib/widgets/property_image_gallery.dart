import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:photo_view/photo_view.dart';

class PropertyImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final String propertyTitle;

  const PropertyImageGallery({
    Key? key,
    required this.imageUrls,
    this.propertyTitle = 'صور العقار',
  }) : super(key: key);

  @override
  State<PropertyImageGallery> createState() => _PropertyImageGalleryState();
}

class _PropertyImageGalleryState extends State<PropertyImageGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    print('🎬 [DEBUG] PropertyImageGallery بناء الـ Widget');
    print('📊 [DEBUG] عدد الصور: ${widget.imageUrls.length}');

    if (widget.imageUrls.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
              const SizedBox(height: 10),
              Text(
                'لا توجد صور متاحة',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // العرض الرئيسي للصور
        CarouselSlider(
          options: CarouselOptions(
            height: 300,
            viewportFraction: 1.0,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              print('🔄 [DEBUG] تغيير الصفحة إلى: ${index + 1}');
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          items: widget.imageUrls.map((imageUrl) {
            return GestureDetector(
              onTap: () {
                print('🖼️ [DEBUG] تم النقر على الصورة: $imageUrl');
                print(
                  '📸 [DEBUG] رقم الصورة الحالية: ${widget.imageUrls.indexOf(imageUrl) + 1} من ${widget.imageUrls.length}',
                );
                _showFullScreenGallery(imageUrl);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ExtendedImage.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    cache: true,
                    clearMemoryCacheIfFailed: true,
                    loadStateChanged: (ExtendedImageState state) {
                      switch (state.extendedImageLoadState) {
                        case LoadState.loading:
                          return _buildLoadingShimmer();
                        case LoadState.completed:
                          return null;
                        case LoadState.failed:
                          return _buildErrorWidget();
                      }
                    },
                    handleLoadingProgress: true,
                    mode: ExtendedImageMode.gesture,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // عداد الصور والنقاط للتنقل (موضوع فوق الـ Carousel)
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // عداد الصور
              Container(
                margin: const EdgeInsets.only(left: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.imageUrls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // نقاط التنقل
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == index ? 12 : 8,
                    height: _currentIndex == index ? 12 : 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.blue
                          : Colors.grey[300],
                    ),
                  ),
                ),
              ),

              // زر فتح المعرض كاملاً
              GestureDetector(
                onTap: () {
                  print('📐 [DEBUG] فتح المعرض بملء الشاشة');
                  _showFullScreenGallery(widget.imageUrls[_currentIndex]);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
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
        ),
      ],
    );
  }

  // عرض الصور بملء الشاشة
  void _showFullScreenGallery(String initialImage) {
    print('🎬 [DEBUG] بدء فتح معرض الصور بملء الشاشة');
    print('📷 [DEBUG] الصورة المختارة: $initialImage');
    int initialIdx = widget.imageUrls.indexOf(initialImage);
    print('📊 [DEBUG] الفهرس الأولي: $initialIdx');
    print('✅ [DEBUG] إجمالي الصور: ${widget.imageUrls.length}');

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) {
              print('🔧 [DEBUG] بناء صفحة المعرض الجديدة...');
              return _FullScreenGallery(
                imageUrls: widget.imageUrls,
                initialIndex: initialIdx,
              );
            },
          ),
        )
        .then((value) {
          print('👈 [DEBUG] تم الرجوع من معرض الصور بملء الشاشة');
        });
  }

  // ويدجت التحميل
  Widget _buildLoadingShimmer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ),
    );
  }

  // ويدجت الخطأ
  Widget _buildErrorWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 40, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text('فشل تحميل الصورة', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

// ويدجت المعرض على ملء الشاشة
class _FullScreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenGallery({required this.imageUrls, this.initialIndex = 0});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    print('🚀 [DEBUG] تم تهيئة _FullScreenGallery');
    print('📍 [DEBUG] الفهرس الأولي: ${widget.initialIndex}');
    print('📚 [DEBUG] عدد الصور في المعرض: ${widget.imageUrls.length}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              print('🔄 [DEBUG] تم التنقل إلى الصورة رقم: ${index + 1}');
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              print(
                '🖼️ [DEBUG] بناء صورة رقم: ${index + 1} - ${widget.imageUrls[index]}',
              );
              return PhotoView(
                imageProvider: NetworkImage(widget.imageUrls[index]),
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 2,
                initialScale: PhotoViewComputedScale.contained,
                basePosition: Alignment.center,
                loadingBuilder: (context, event) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'خطأ في تحميل الصورة',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          // أزرار الملاحة
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                if (_currentIndex > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Container(
                width: 50,
                color: Colors.transparent,
                child: _currentIndex > 0
                    ? const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 32,
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                if (_currentIndex < widget.imageUrls.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Container(
                width: 50,
                color: Colors.transparent,
                child: _currentIndex < widget.imageUrls.length - 1
                    ? const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 32,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

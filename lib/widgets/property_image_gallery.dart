import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:photo_view/photo_view.dart';

class PropertyImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final String propertyTitle;

  const PropertyImageGallery({
    super.key,
    required this.imageUrls,
    this.propertyTitle = 'صور العقار',
  });

  @override
  State<PropertyImageGallery> createState() => _PropertyImageGalleryState();
}

class _PropertyImageGalleryState extends State<PropertyImageGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    developer.log('PropertyImageGallery build', name: 'PropertyImageGallery');
    developer.log(
      'Images count: ${widget.imageUrls.length}',
      name: 'PropertyImageGallery',
    );

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
              developer.log(
                'Page changed to: ${index + 1}',
                name: 'PropertyImageGallery',
              );
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          items: widget.imageUrls.map((imageUrl) {
            return GestureDetector(
              onTap: () {
                developer.log(
                  'Image tapped: $imageUrl',
                  name: 'PropertyImageGallery',
                );
                developer.log(
                  'Current image index: ${widget.imageUrls.indexOf(imageUrl) + 1} of ${widget.imageUrls.length}',
                  name: 'PropertyImageGallery',
                );
                _showFullScreenGallery(imageUrl);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
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
                  developer.log(
                    'Open full screen gallery',
                    name: 'PropertyImageGallery',
                  );
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
    developer.log('Opening full screen gallery', name: 'PropertyImageGallery');
    developer.log(
      'Selected image: $initialImage',
      name: 'PropertyImageGallery',
    );
    int initialIdx = widget.imageUrls.indexOf(initialImage);
    developer.log('Initial index: $initialIdx', name: 'PropertyImageGallery');
    developer.log(
      'Total images: ${widget.imageUrls.length}',
      name: 'PropertyImageGallery',
    );

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) {
              developer.log(
                'Building full screen gallery page',
                name: 'PropertyImageGallery',
              );
              return _FullScreenGallery(
                imageUrls: widget.imageUrls,
                initialIndex: initialIdx,
              );
            },
          ),
        )
        .then((value) {
          developer.log(
            'Returned from full screen gallery',
            name: 'PropertyImageGallery',
          );
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
    developer.log('FullScreenGallery initialized', name: '_FullScreenGallery');
    developer.log(
      'Initial index: ${widget.initialIndex}',
      name: '_FullScreenGallery',
    );
    developer.log(
      'Gallery images count: ${widget.imageUrls.length}',
      name: '_FullScreenGallery',
    );
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
              developer.log(
                'Navigated to image: ${index + 1}',
                name: '_FullScreenGallery',
              );
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              developer.log(
                'Building image: ${index + 1} - ${widget.imageUrls[index]}',
                name: '_FullScreenGallery',
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

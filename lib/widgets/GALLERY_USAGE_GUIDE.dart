// ملف للتوثيق السريعة - كيفية استخدام PropertyImageGallery

/*
═══════════════════════════════════════════════════════════════════════════
                      دليل استخدام معرض الصور للعقارات
═══════════════════════════════════════════════════════════════════════════

## الميزات الرئيسية:

✅ عرض الصور بشكل جميل مع تأثيرات
✅ تمرير سلس بين الصور (Carousel)
✅ معاينة ملء الشاشة مع إمكانية التكبير والتصغير
✅ مؤشرات البحث والعد (Pagination indicators)
✅ تحميل الصور من الويب بكفاءة
✅ عرض حالات التحميل والخطأ بشكل جميل
✅ دعم الصور المتعددة

═══════════════════════════════════════════════════════════════════════════
*/

// طريقة الاستخدام الأساسية:

/*
import 'package:flutter/material.dart';
import 'package:aqar_app/widgets/property_image_gallery.dart';

class PropertyDetailsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<String> propertyImages = [
      'https://example.com/image1.jpg',
      'https://example.com/image2.jpg',
      'https://example.com/image3.jpg',
    ];

    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل العقار')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // استخدام معرض الصور
            PropertyImageGallery(
              imageUrls: propertyImages,
              propertyTitle: 'فيلا حديثة في الرياض',
            ),
            
            // باقي تفاصيل العقار
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('السعر: 850,000 ريال'),
                  Text('المساحة: 250 متر مربع'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/

// مثال متقدم - مع الحصول على الصور من Firestore:

/*
class PropertyDetailsPage extends StatelessWidget {
  final String propertyId;

  const PropertyDetailsPage({required this.propertyId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final propertyData = snapshot.data!.data() as Map<String, dynamic>;
        final imageUrls = List<String>.from(propertyData['images'] ?? []);

        return Scaffold(
          appBar: AppBar(
            title: Text(propertyData['title'] ?? 'تفاصيل العقار'),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                PropertyImageGallery(
                  imageUrls: imageUrls,
                  propertyTitle: propertyData['title'],
                ),
                // باقي التفاصيل...
              ],
            ),
          ),
        );
      },
    );
  }
}
*/

// المعاملات (Parameters):
// 
// - imageUrls (مطلوب): قائمة روابط الصور
//   final List<String> imageUrls = ['url1', 'url2', 'url3'];
//
// - propertyTitle (اختياري): عنوان العقار
//   default: 'صور العقار'

/// ═══════════════════════════════════════════════════════════════════════════
/// تخصيص الألوان والأنماط
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// العناصر التي يمكن تخصيصها:
/// - لون الأزرار الزرقاء > يمكن تغييره من 'Colors.blue' إلى أي لون آخر
/// - حجم الصور (300 في الـ Carousel)
/// - نصف قطر الأركان (BorderRadius)
/// - الظلال (BoxShadow)
/// 
/// للتخصيص:
/// 1. قم بنسخ الـ Widget إلى مشروعك
/// 2. اضبط الألوان حسب تصميم التطبيق الخاص بك
/// 3. عدّل الأحجام والاسافات حسب احتياجاتك

/*
═══════════════════════════════════════════════════════════════════════════
✨ تم إضافة مكتبة extended_image بنجاح! ✨
═══════════════════════════════════════════════════════════════════════════
الحزم المستخدمة:
  ✓ extended_image     - لعرض الصور بكفاءة عالية
  ✓ carousel_slider    - للتمرير بين الصور
  ✓ photo_view         - معاينة الصور مع التكبير

الملف الرئيسي:
  📁 lib/widgets/property_image_gallery.dart

الاستخدام:
  import 'package:aqar_app/widgets/property_image_gallery.dart';
  
  PropertyImageGallery(
    imageUrls: ['url1', 'url2', 'url3'],
    propertyTitle: 'اسم العقار',
  )

═══════════════════════════════════════════════════════════════════════════
*/

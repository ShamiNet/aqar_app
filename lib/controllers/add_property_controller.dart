import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:aqar_app/services/api_service.dart';

// ✅ كلاس التحكم المسؤول عن منطق إضافة العقار
class AddPropertyController extends ChangeNotifier {
  // 📝 أدوات التحكم بالنصوص
  final titleController = TextEditingController();
  final priceController = TextEditingController();
  final areaController = TextEditingController();
  final descriptionController = TextEditingController();
  final addressController = TextEditingController();
  final bedroomsController = TextEditingController();
  final bathroomsController = TextEditingController();
  final livingRoomsController = TextEditingController();
  final streetWidthController = TextEditingController();
  final ageController = TextEditingController();

  // 🎛️ المتغيرات (State)
  String selectedType = 'بيت';
  String selectedCategory = 'بيع';
  bool isFurnished = false;
  bool hasKitchen = false;
  bool hasAnnex = false;
  bool hasCarEntrance = false;
  bool hasElevator = false;
  bool hasPool = false;

  bool isLoading = false;
  List<File> selectedImages = [];
  File? selectedVideo;
  VideoPlayerController? videoPlayerController;
  final ImagePicker _picker = ImagePicker();

  // 📍 متغيرات الموقع
  double? latitude;
  double? longitude;

  // دالة لتحديث الموقع المستلم من الخريطة
  void setLocation(double lat, double lng) {
    latitude = lat;
    longitude = lng;
    notifyListeners();
  }

  // 🧹 تنظيف الذاكرة عند الخروج
  @override
  void dispose() {
    titleController.dispose();
    priceController.dispose();
    areaController.dispose();
    descriptionController.dispose();
    addressController.dispose();
    bedroomsController.dispose();
    bathroomsController.dispose();
    livingRoomsController.dispose();
    streetWidthController.dispose();
    ageController.dispose();
    videoPlayerController?.dispose();
    super.dispose();
  }

  // 📸 اختيار الصور
  Future<void> pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        selectedImages.addAll(pickedFiles.map((e) => File(e.path)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ [Controller] خطأ في اختيار الصور: $e');
    }
  }

  // 🎥 اختيار الفيديو
  Future<void> pickVideo() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );

      if (pickedFile != null) {
        selectedVideo = File(pickedFile.path);
        videoPlayerController = VideoPlayerController.file(selectedVideo!)
          ..initialize().then((_) {
            notifyListeners();
          });
      }
    } catch (e) {
      debugPrint('❌ [Controller] خطأ في اختيار الفيديو: $e');
    }
  }

  // 🗑️ حذف صورة
  void removeImage(int index) {
    if (index >= 0 && index < selectedImages.length) {
      selectedImages.removeAt(index);
      notifyListeners();
    }
  }

  // 🗑️ حذف الفيديو
  void removeVideo() {
    selectedVideo = null;
    videoPlayerController?.dispose();
    videoPlayerController = null;
    notifyListeners();
  }

  // 🚀 رفع البيانات (العملية الرئيسية مع الضغط)
  Future<bool> submitProperty(BuildContext context) async {
    // 1. التحقق من المدخلات
    if (!_validateInputs(context)) return false;

    // 2. التحقق من الموقع
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد موقع العقار على الخريطة'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    isLoading = true;
    notifyListeners();

    try {
      // 3. تحويل الخيارات إلى قائمة نصوص (للعرض فقط)
      List<String> featuresList = [];
      if (isFurnished) featuresList.add('مؤثثة');
      if (hasKitchen) featuresList.add('مطبخ');
      if (hasAnnex) featuresList.add('ملحق');
      if (hasCarEntrance) featuresList.add('مدخل سيارة');
      if (hasElevator) featuresList.add('مصعد');
      if (hasPool) featuresList.add('مسبح');

      // 4. الاستدعاء الصحيح لـ ApiService مع تمرير الصور (التي سيتم ضغطها هناك)
      final success = await ApiService.addProperty(
        title: titleController.text,
        price: priceController.text,
        description: descriptionController.text,
        address: addressController.text,
        latitude: latitude!,
        longitude: longitude!,
        category: selectedCategory,
        propertyType: selectedType,
        bedrooms: bedroomsController.text,
        bathrooms: bathroomsController.text,
        area: areaController.text,
        features: featuresList,
        images:
            selectedImages, // ✅ هذه الصور سيتم ضغطها قبل الرفع في ApiService -> CloudinaryConfig
        video: selectedVideo,
        livingRooms: livingRoomsController.text,
        streetWidth: streetWidthController.text,
        age: ageController.text,
        isFurnished: isFurnished,
        hasKitchen: hasKitchen,
        hasAnnex: hasAnnex,
        hasCarEntrance: hasCarEntrance,
        hasElevator: hasElevator,
        hasPool: hasPool,
      );

      isLoading = false;
      notifyListeners();

      if (success) {
        resetForm();
        return true;
      } else {
        throw Exception('فشل الحفظ في السيرفر');
      }
    } catch (e) {
      debugPrint('💥 [Controller] خطأ أثناء رفع العقار: $e');
      isLoading = false;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل إضافة العقار: ${e.toString().replaceAll("Exception:", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // ✅ التحقق من المدخلات
  bool _validateInputs(BuildContext context) {
    if (titleController.text.isEmpty ||
        priceController.text.isEmpty ||
        areaController.text.isEmpty ||
        addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تعبئة الحقول الأساسية المطلوبة'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }
    if (selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إضافة صورة واحدة على الأقل'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }
    return true;
  }

  void setType(String? val) {
    if (val != null) {
      selectedType = val;
      notifyListeners();
    }
  }

  void setCategory(String? val) {
    if (val != null) {
      selectedCategory = val;
      notifyListeners();
    }
  }

  void toggleFurnished(bool? val) {
    isFurnished = val ?? false;
    notifyListeners();
  }

  void toggleKitchen(bool? val) {
    hasKitchen = val ?? false;
    notifyListeners();
  }

  void toggleAnnex(bool? val) {
    hasAnnex = val ?? false;
    notifyListeners();
  }

  void toggleCarEntrance(bool? val) {
    hasCarEntrance = val ?? false;
    notifyListeners();
  }

  void toggleElevator(bool? val) {
    hasElevator = val ?? false;
    notifyListeners();
  }

  void togglePool(bool? val) {
    hasPool = val ?? false;
    notifyListeners();
  }

  // 🔄 مسح جميع الحقول
  void resetForm() {
    debugPrint('🔄 [Controller] Resetting form');
    titleController.clear();
    priceController.clear();
    areaController.clear();
    descriptionController.clear();
    addressController.clear();
    bedroomsController.clear();
    bathroomsController.clear();
    livingRoomsController.clear();
    streetWidthController.clear();
    ageController.clear();

    selectedType = 'بيت';
    selectedCategory = 'بيع';
    isFurnished = false;
    hasKitchen = false;
    hasAnnex = false;
    hasCarEntrance = false;
    hasElevator = false;
    hasPool = false;

    selectedImages.clear();
    removeVideo();

    latitude = null;
    longitude = null;

    notifyListeners();
    debugPrint('✅ [Controller] Form reset completed');
  }
}

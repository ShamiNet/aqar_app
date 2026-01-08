import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/config/cloudinary_config.dart';

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
  String selectedType = 'شقة'; // القيمة الافتراضية
  String selectedCategory = 'بيع';
  bool isFurnished = false;
  bool hasKitchen = false;
  bool hasAnnex = false;
  bool hasCarEntrance = false;
  bool hasElevator = false;
  bool hasPool = false; // إضافة المسبح كخيار شائع

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
        notifyListeners(); // 🔔 تحديث الواجهة
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
            notifyListeners(); // 🔔 تحديث الواجهة عند جاهزية الفيديو
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

  // 🚀 رفع البيانات (العملية الرئيسية)
  Future<bool> submitProperty(BuildContext context) async {
    if (!_validateInputs(context)) return false;

    isLoading = true;
    notifyListeners();

    try {
      // 1. رفع الصور
      List<String> imageUrls = [];
      if (selectedImages.isNotEmpty) {
        imageUrls = await CloudinaryConfig.uploadImages(selectedImages);
      }

      // 2. رفع الفيديو (إن وجد)
      String? videoUrl;
      if (selectedVideo != null) {
        videoUrl = await CloudinaryConfig.uploadVideo(selectedVideo!);
      }

      // 3. جلب بيانات المستخدم
      final user = await ApiService.getCurrentUser();
      final userId = user?['id'] ?? user?['uid'];

      if (userId == null) {
        throw Exception('المستخدم غير مسجل دخول');
      }

      // 4. تجهيز كائن البيانات (Data Object)
      final propertyData = {
        'title': titleController.text,
        'price': double.tryParse(priceController.text) ?? 0.0,
        'area': double.tryParse(areaController.text) ?? 0.0,
        'description': descriptionController.text,
        'address': addressController.text,
        'type': selectedType,
        'category': selectedCategory,
        'bedrooms': int.tryParse(bedroomsController.text) ?? 0,
        'bathrooms': int.tryParse(bathroomsController.text) ?? 0,
        'livingRooms': int.tryParse(livingRoomsController.text) ?? 0,
        'streetWidth': double.tryParse(streetWidthController.text) ?? 0.0,
        'age': int.tryParse(ageController.text) ?? 0,
        'isFurnished': isFurnished,
        'hasKitchen': hasKitchen,
        'hasAnnex': hasAnnex,
        'hasCarEntrance': hasCarEntrance,
        'hasElevator': hasElevator,
        'hasPool': hasPool,
        'images': imageUrls,
        'videoUrl': videoUrl,
        'userId': userId,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'pending', // بانتظار الموافقة
      };

      // 5. إرسال للسيرفر
      await ApiService.addProperty(propertyData);

      isLoading = false;
      notifyListeners();
      return true; // ✅ نجاح
    } catch (e) {
      debugPrint('💥 [Controller] خطأ أثناء رفع العقار: $e');
      isLoading = false;
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إضافة العقار: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false; // ❌ فشل
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

  // دوال مساعدة لتحديث القيم المنطقية (checkboxes/switches)
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
}

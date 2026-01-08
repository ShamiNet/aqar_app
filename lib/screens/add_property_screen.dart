import 'dart:io';
import 'package:aqar_app/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:aqar_app/controllers/add_property_controller.dart'; // ✅ استيراد الكنترولر
import 'package:video_player/video_player.dart';
import 'package:aqar_app/screens/map_screen.dart'; // لاستدعاء الشاشة
import 'package:google_maps_flutter/google_maps_flutter.dart'; // للتعرف على LatLng

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  // ✅ تعريف الكنترولر
  late final AddPropertyController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AddPropertyController();
    // 🔔 الاستماع للتغييرات لإعادة بناء الواجهة
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // ✅ تنظيف الذاكرة تلقائياً
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // الألوان من الثيم الحالي
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عقار جديد')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📸 قسم الصور والفيديو
                _buildMediaSection(colorScheme),

                const SizedBox(height: 20),

                // 📝 الحقول النصية
                _buildTextField(
                  'عنوان الإعلان *',
                  _controller.titleController,
                  icon: Icons.title,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        'السعر (ر.س) *',
                        _controller.priceController,
                        isNumber: true,
                        icon: Icons.attach_money,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        'المساحة (م²) *',
                        _controller.areaController,
                        isNumber: true,
                        icon: Icons.square_foot,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 🎛️ القوائم المنسدلة (النوع والفئة)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _controller.selectedType,
                        decoration: InputDecoration(
                          labelText: 'نوع العقار',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: ['شقة', 'فيلا', 'أرض', 'عمارة', 'استراحة']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: _controller.setType,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _controller.selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'الفئة',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: ['بيع', 'إيجار', 'استثمار']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: _controller.setCategory,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                _buildTextField(
                  'العنوان بالتفصيل *',
                  _controller.addressController,
                  icon: Icons.location_on,
                ),

                const SizedBox(height: 10),

                // 🗺️ زر تحديد الموقع
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.map_rounded,
                      color: _controller.latitude != null
                          ? Colors.green
                          : Colors.grey,
                    ),
                    title: Text(
                      _controller.latitude != null
                          ? 'تم تحديد الموقع بنجاح ✅'
                          : 'تحديد الموقع على الخريطة',
                      style: TextStyle(
                        color: _controller.latitude != null
                            ? Colors.green
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: _controller.latitude != null
                        ? Text(
                            '${_controller.latitude}, ${_controller.longitude}',
                          )
                        : const Text('اضغط لفتح الخريطة وتثبيت الدبوس'),
                    onTap: () async {
                      // ✅ فتح الخريطة وانتظار النتيجة
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => MapScreen(
                            // نمرر الموقع الحالي إذا كان محدداً مسبقاً ليظهر على الخريطة
                            initialLat: _controller.latitude,
                            initialLong: _controller.longitude,
                          ),
                        ),
                      );

                      // ✅ استلام النتيجة وتحديث الكنترولر
                      if (result != null && result is LatLng) {
                        _controller.setLocation(
                          result.latitude,
                          result.longitude,
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  'الوصف',
                  _controller.descriptionController,
                  maxLines: 3,
                  icon: Icons.description,
                ),

                const SizedBox(height: 20),
                const Text(
                  'التفاصيل الإضافية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),

                // 🔢 حقول الأرقام (غرف، حمامات...)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildSmallNumberField(
                      'غرف النوم',
                      _controller.bedroomsController,
                    ),
                    _buildSmallNumberField(
                      'دورات المياه',
                      _controller.bathroomsController,
                    ),
                    _buildSmallNumberField(
                      'الصالات',
                      _controller.livingRoomsController,
                    ),
                    _buildSmallNumberField(
                      'عرض الشارع',
                      _controller.streetWidthController,
                    ),
                    _buildSmallNumberField(
                      'عمر العقار',
                      _controller.ageController,
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),

                // ✅ الميزات (Checkboxes)
                Wrap(
                  spacing: 10,
                  children: [
                    _buildCheckbox(
                      'مؤثثة',
                      _controller.isFurnished,
                      _controller.toggleFurnished,
                    ),
                    _buildCheckbox(
                      'مطبخ',
                      _controller.hasKitchen,
                      _controller.toggleKitchen,
                    ),
                    _buildCheckbox(
                      'ملحق',
                      _controller.hasAnnex,
                      _controller.toggleAnnex,
                    ),
                    _buildCheckbox(
                      'مدخل سيارة',
                      _controller.hasCarEntrance,
                      _controller.toggleCarEntrance,
                    ),
                    _buildCheckbox(
                      'مصعد',
                      _controller.hasElevator,
                      _controller.toggleElevator,
                    ),
                    _buildCheckbox(
                      'مسبح',
                      _controller.hasPool,
                      _controller.togglePool,
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // 🔘 زر الحفظ
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _controller.isLoading
                        ? null
                        : () async {
                            final success = await _controller.submitProperty(
                              context,
                            );
                            if (success && mounted) {
                              Navigator.pop(
                                context,
                                'تمت إضافة العقار بنجاح!',
                              ); // العودة للرئيسية مع رسالة نجاح
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _controller.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'نشر الإعلان الآن',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // 🛡️ طبقة التحميل (Loading Overlay)
          if (_controller.isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      'جاري رفع الصور والبيانات...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🧱 ودجت اختيار الصور والفيديو
  Widget _buildMediaSection(ColorScheme colorScheme) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // زر إضافة صورة
              GestureDetector(
                onTap: _controller.pickImages,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline,
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: colorScheme.primary),
                      const Text('صور', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // زر إضافة فيديو
              GestureDetector(
                onTap: _controller.pickVideo,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outline),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, color: colorScheme.secondary),
                      const Text('فيديو', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // عرض الصور المختارة
              ..._controller.selectedImages.asMap().entries.map((entry) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(entry.value),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _controller.removeImage(entry.key),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.red,
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),

        // عرض الفيديو المختار (مصغر)
        if (_controller.selectedVideo != null &&
            _controller.videoPlayerController != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio:
                      _controller.videoPlayerController!.value.aspectRatio,
                  child: VideoPlayer(_controller.videoPlayerController!),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 30),
                  onPressed: _controller.removeVideo,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 🧱 ودجت الحقول النصية
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    int maxLines = 1,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  // 🧱 ودجت الأرقام الصغيرة
  Widget _buildSmallNumberField(
    String label,
    TextEditingController controller,
  ) {
    return SizedBox(
      width: 100,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // 🧱 ودجت الاختيار
  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }
}

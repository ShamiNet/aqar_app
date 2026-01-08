import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;
  final Color? iconColor; // ✅ 1. إضافة المتغير

  const VerifiedBadge({
    super.key,
    this.size = 16,
    this.iconColor, // ✅ 2. إضافته للمنشئ (Constructor)
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'حساب موثوق',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        // ✅ 3. استخدامه هنا (مع قيمة افتراضية الأبيض)
        child: Icon(Icons.check, color: iconColor ?? Colors.white, size: size),
      ),
    );
  }
}

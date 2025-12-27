import 'package:flutter/material.dart';
import 'auth_gate.dart';

class MaintenanceScreen extends StatelessWidget {
  final String message;
  const MaintenanceScreen({super.key, this.message = ''});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.build, size: 72, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'وضع الصيانة',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  message.isNotEmpty
                      ? message
                      : 'التطبيق قيد الصيانة حالياً. الرجاء المحاولة لاحقاً.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // إعادة تحميل الشاشة لمحاولة الخروج من وضع الصيانة
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// يمكن لاحقاً إضافة سلوك مخصص هنا إذا لزم

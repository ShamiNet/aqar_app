import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/widgets/properties_list.dart';
import 'package:aqar_app/widgets/properties_list_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyPropertiesScreen extends StatefulWidget {
  const MyPropertiesScreen({super.key});

  @override
  State<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends State<MyPropertiesScreen> {
  // ✅ جعلناها nullable لتفادي خطأ LateInitializationError
  Future<List<Map<String, dynamic>>>? _myPropertiesFuture;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  // ✅ استخدام SharedPreferences بدلاً من FirebaseAuth
  Future<void> _loadProperties() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');

    if (mounted) {
      setState(() {
        if (uid != null) {
          _myPropertiesFuture = ApiService.fetchMyProperties(uid);
        } else {
          _myPropertiesFuture = Future.value([]);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_myPropertiesFuture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('عقاراتي')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _myPropertiesFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PropertiesListSkeleton();
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لم تقم بإضافة أي عقارات بعد.'));
          }

          return PropertiesList(properties: snapshot.data!);
        },
      ),
    );
  }
}

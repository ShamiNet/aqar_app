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
  Future<List<Map<String, dynamic>>>? _myPropertiesFuture;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

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

  // دالة للتحديث عند السحب
  Future<void> _onRefresh() async {
    await _loadProperties();
  }

  @override
  Widget build(BuildContext context) {
    if (_myPropertiesFuture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('عقاراتي')),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _myPropertiesFuture,
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const PropertiesListSkeleton();
            }
            if (snapshot.hasError) {
              // جعل رسالة الخطأ قابلة للسحب
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(child: Text('حدث خطأ: ${snapshot.error}')),
                ],
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // جعل الرسالة الفارغة قابلة للسحب
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  const Center(child: Text('لم تقم بإضافة أي عقارات بعد.')),
                ],
              );
            }

            return PropertiesList(properties: snapshot.data!);
          },
        ),
      ),
    );
  }
}

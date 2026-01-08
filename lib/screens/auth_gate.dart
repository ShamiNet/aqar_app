import 'package:aqar_app/screens/login_screen.dart';
import 'package:aqar_app/screens/tabs_screen.dart';
import 'package:aqar_app/screens/maintenance_screen.dart';
import 'package:aqar_app/screens/update_required_screen.dart';
import 'package:aqar_app/services/api_service.dart'; // ✅ الخدمة الجديدة
import 'package:flutter/material.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _maintenanceMode = false;
  String _maintenanceMessage = '';
  bool _isAdmin = false;
  bool _updateRequired = false;
  String _requiredVersion = '';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _startMaintenanceCheckTimer(); // ✅ فحص دوري كل 5 ثوانٍ
  }

  // فحص حالة تسجيل الدخول محلياً من SharedPreferences + التحقق من الحظر
  Future<void> _checkLoginStatus() async {
    debugPrint('\n🛡️ [AuthGate] Checking login status...');

    // ✅ نتحقق هل التوكن محفوظ في الذاكرة؟
    final isLoggedIn = await ApiService.isLoggedIn();
    debugPrint('🛡️ [AuthGate] Is user logged in? $isLoggedIn');

    bool isAuthenticated = isLoggedIn;

    // ✅ التحقق من حالة الحظر إذا كان المستخدم مسجل دخول
    if (isLoggedIn) {
      final currentUser = await ApiService.getCurrentUser();
      if (currentUser != null && currentUser['isBanned'] == true) {
        debugPrint('🚫 [AuthGate] User is banned! Logging out...');
        // تسجيل الخروج إذا كان المستخدم محظوراً
        await ApiService.logout();
        isAuthenticated = false;

        // عرض رسالة للمستخدم
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حظر حسابك من قبل الإدارة'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      // حفظ حالة كونه مديراً
      if (currentUser != null) {
        _isAdmin = currentUser['isAdmin'] == true;
      }
    }

    // ✅ التحقق من وضع الصيانة من السيرفر
    try {
      final settings = await ApiService.fetchAppSettings();
      print('🔧 [AuthGate] جاري فحص الإعدادات: $settings');
      final oldMaintenance = _maintenanceMode;
      _maintenanceMode = settings['maintenance_mode'] == true;
      _maintenanceMessage = (settings['maintenance_message'] ?? '').toString();
      print(
        '🛠️ [AuthGate] Maintenance mode changed from: $oldMaintenance to: $_maintenanceMode',
      );
      print(
        '🛠️ [AuthGate] Raw maintenance_mode value: ${settings['maintenance_mode']}',
      );
      print(
        '🛠️ [AuthGate] maintenance_mode type: ${settings['maintenance_mode'].runtimeType}',
      );
      debugPrint('🛠️ [AuthGate] Maintenance mode: $_maintenanceMode');
    } catch (e) {
      print('❌ [AuthGate] Exception in settings: $e');
      debugPrint('⚠️ [AuthGate] Failed to fetch app settings: $e');
    }

    if (mounted) {
      setState(() {
        _isAuthenticated = isAuthenticated;
        _isLoading = false;
      });
    }
  }

  // ✅ فحص دوري لحالة الصيانة كل 30 ثانية
  void _startMaintenanceCheckTimer() {
    debugPrint('🛠️ [AuthGate-Timer] بدء الفحص الدوري للصيانة كل 30 ثانية');
    Future.delayed(const Duration(seconds: 30), () async {
      debugPrint('🛠️ [AuthGate-Timer] ⏰ تشغيل فحص دوري... mounted=$mounted');
      if (mounted) {
        await _checkMaintenanceOnly();
        _startMaintenanceCheckTimer(); // استدعاء نفسها مرة أخرى
      }
    });
  }

  // فحص الصيانة فقط دون تغيير حالة المصادقة
  Future<void> _checkMaintenanceOnly() async {
    debugPrint('🛠️ [AuthGate-Check] جلب إعدادات التطبيق من السيرفر...');
    try {
      final settings = await ApiService.fetchAppSettings();
      debugPrint('🛠️ [AuthGate-Check] الإعدادات المُسترجعة: $settings');

      final newMaintenanceMode = settings['maintenance_mode'] == true;
      final newMaintenanceMessage = (settings['maintenance_message'] ?? '')
          .toString();

      // ✅ التحقق من الإصدار المطلوب
      final minVersion = settings['min_version'] ?? '1.0.0';
      final updateRequired = ApiService.isUpdateRequired(minVersion);

      print(
        '📱 [Version Check] Current: ${ApiService.currentAppVersion}, Required: $minVersion',
      );
      print('🔄 [Version Check] Update Required: $updateRequired');

      debugPrint(
        '🛠️ [AuthGate-Check] وضع الصيانة الجديد: $newMaintenanceMode',
      );
      debugPrint('🛠️ [AuthGate-Check] رسالة الصيانة: $newMaintenanceMessage');
      debugPrint(
        '🛠️ [AuthGate-Check] الحالة القديمة: maintenance=$_maintenanceMode, isAdmin=$_isAdmin',
      );

      // إذا تغيرت حالة الصيانة أو الإصدار → أعد بناء الواجهة
      if (_maintenanceMode != newMaintenanceMode ||
          _maintenanceMessage != newMaintenanceMessage ||
          _updateRequired != updateRequired) {
        debugPrint('✅ [AuthGate-Check] تغييرات مكتشفة! تحديث الواجهة...');
        if (mounted) {
          setState(() {
            _maintenanceMode = newMaintenanceMode;
            _maintenanceMessage = newMaintenanceMessage;
            _updateRequired = updateRequired;
            _requiredVersion = minVersion;
          });
          debugPrint('🛠️ [AuthGate-Check] ✅ تم تحديث الواجهة بنجاح!');
        } else {
          debugPrint('🛠️ [AuthGate-Check] ❌ mounted=false، لم يتم التحديث');
        }
      } else {
        debugPrint('🛠️ [AuthGate-Check] ⚪ لا توجد تغييرات في الصيانة');
      }
    } catch (e) {
      debugPrint('⚠️ [AuthGate-Check] ❌ خطأ في فحص الصيانة: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '🛠️ [AuthGate-Build] بناء الواجهة: loading=$_isLoading, maintenance=$_maintenanceMode, admin=$_isAdmin, authenticated=$_isAuthenticated',
    );

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ✅ التحقق من الإصدار المطلوب أولاً
    if (_updateRequired) {
      print('🔴 [AuthGate-Build] عرض شاشة التحديث الإجباري');
      return UpdateRequiredScreen(
        currentVersion: ApiService.currentAppVersion,
        requiredVersion: _requiredVersion,
      );
    }

    // إذا كان وضع الصيانة مفعلاً والمستخدم ليس مديراً → نعرض شاشة الصيانة
    print(
      '🔍 [AuthGate-Build] Maintenance check: mode=$_maintenanceMode, isAdmin=$_isAdmin',
    );
    if (_maintenanceMode && !_isAdmin) {
      print('⚠️ [AuthGate-Build] عرض شاشة الصيانة لأن المستخدم ليس مدير');
      debugPrint('🛠️ [AuthGate-Build] ✅ عرض شاشة الصيانة');
      return MaintenanceScreen(message: _maintenanceMessage);
    }

    if (_isAuthenticated) {
      debugPrint('🛠️ [AuthGate-Build] ✅ عرض التطبيق الرئيسي');
      return const TabsScreen();
    } else {
      debugPrint('🛠️ [AuthGate-Build] ✅ عرض صفحة تسجيل الدخول');
      return const LoginScreen();
    }
  }
}

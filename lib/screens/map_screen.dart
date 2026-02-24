import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLong;

  const MapScreen({super.key, this.initialLat, this.initialLong});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentMapCenter;
  MapType _mapType = MapType.normal;

  // إحداثيات افتراضية (يمكن تغييرها إلى وسط مدينتك المستهدفة)
  static const LatLng _defaultLocation = LatLng(35.9293, 36.6331); // حلب

  @override
  void initState() {
    super.initState();
    // إذا تم تمرير موقع سابق، نجعله المركز الأولي
    if (widget.initialLat != null && widget.initialLong != null) {
      _currentMapCenter = LatLng(widget.initialLat!, widget.initialLong!);
    } else {
      _currentMapCenter = _defaultLocation;
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. التحقق من تفعيل خدمة الموقع
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تفعيل خدمة الموقع (GPS)')),
        );
      }
      return;
    }

    // 2. التحقق من الصلاحيات
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفض صلاحية الوصول للموقع')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'الصلاحيات مرفوضة نهائياً، يرجى تفعيلها من الإعدادات',
            ),
          ),
        );
      }
      return;
    }

    // 3. جلب الموقع والتحريك
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newLoc = LatLng(position.latitude, position.longitude);

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLoc, 15));

      setState(() {
        _currentMapCenter = newLoc;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حدد موقع العقار'),
        centerTitle: true,
        actions: [
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.layers_outlined),
            onSelected: (value) {
              setState(() {
                _mapType = value;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: MapType.normal,
                child: Text('الخريطة الحالية'),
              ),
              PopupMenuItem(value: MapType.hybrid, child: Text('هايبرد')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentMapCenter ?? _defaultLocation,
              zoom: 14,
            ),
            mapType: _mapType,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMove: (position) {
              _currentMapCenter = position.target;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // سنستخدم زرنا المخصص
            zoomControlsEnabled: false,
          ),

          // 📍 دبوس التحديد (ثابت في المنتصف)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: 35.0,
              ), // رفع الدبوس قليلاً ليكون رأس الدبوس هو المركز
              child: Icon(Icons.location_on, size: 50, color: Colors.red),
            ),
          ),

          // 🎯 زر موقعي
          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'my_loc_btn',
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          // ✅ زر التأكيد
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                if (_currentMapCenter != null) {
                  // إرجاع الإحداثيات للشاشة السابقة
                  Navigator.of(context).pop(_currentMapCenter);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
              ),
              child: const Text(
                'تأكيد هذا الموقع',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

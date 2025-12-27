import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/services/api_service.dart'; // ✅ المصدر الوحيد للبيانات
import 'package:aqar_app/screens/map_legend_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:aqar_app/firebase_options.dart';

// مفتاح API (اختياري)
const kDirectionsKey = String.fromEnvironment(
  'GOOGLE_MAPS_DIRECTIONS_API_KEY',
  defaultValue: 'AIzaSyAwiq4OSjCBXuMqms4e_JRJYjKMQOhrukQ',
);

class PropertiesMapScreen extends StatefulWidget {
  const PropertiesMapScreen({super.key});

  @override
  State<PropertiesMapScreen> createState() => _PropertiesMapScreenState();
}

class _PropertiesMapScreenState extends State<PropertiesMapScreen> {
  static const LatLng _initialPosition = LatLng(35.9333, 36.6333);
  Position? _currentUserPosition;
  final Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;
  MarkerId? _selectedMarkerId;

  // ✅ التغيير: نستخدم قائمة Maps فقط
  List<Map<String, dynamic>> _properties = [];
  final Set<Marker> _markers = {};
  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchProperties(); // ✅ جلب البيانات من السيرفر مرة واحدة
  }

  Future<void> _fetchProperties() async {
    try {
      final properties = await ApiService.fetchProperties();
      if (mounted) {
        setState(() {
          _properties = properties;
          _isLoading = false;
        });
        _buildMarkersWithCustomIcons();
      }
    } catch (e) {
      debugPrint('Error fetching properties for map: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<BitmapDescriptor> _createMarkerBitmap(
    IconData iconData,
    Color color,
  ) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0;
    final Paint circlePaint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, circlePaint);
    TextPainter textPainter = TextPainter(textDirection: TextDirection.rtl);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.6,
        fontFamily: iconData.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );
    final img = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentUserPosition = position;
      });
      _animateToUserLocation();
    }
  }

  void _animateToUserLocation() {
    if (_mapController != null && _currentUserPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentUserPosition!.latitude,
              _currentUserPosition!.longitude,
            ),
            zoom: 12,
          ),
        ),
      );
    }
  }

  Future<void> _drawRoute(LatLng propertyPosition) async {
    if (_currentUserPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم تحديد موقعك الحالي.')),
      );
      return;
    }

    final polylinePoints = PolylinePoints();
    List<LatLng> polyPoints = [];

    try {
      final apiKey = kDirectionsKey.isNotEmpty
          ? kDirectionsKey
          : DefaultFirebaseOptions.currentPlatform.apiKey;
      final result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(
            _currentUserPosition!.latitude,
            _currentUserPosition!.longitude,
          ),
          destination: PointLatLng(
            propertyPosition.latitude,
            propertyPosition.longitude,
          ),
          mode: TravelMode.driving,
        ),
        googleApiKey: apiKey,
      );
      polyPoints = result.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    } catch (e) {
      debugPrint('Error drawing route: $e');
    }

    if (mounted) {
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: polyPoints.isNotEmpty
                ? polyPoints
                : [
                    LatLng(
                      _currentUserPosition!.latitude,
                      _currentUserPosition!.longitude,
                    ),
                    propertyPosition,
                  ],
            color: Colors.blue,
            width: 5,
          ),
        );
      });
    }
  }

  void _onMarkerTapped(MarkerId markerId, LatLng propertyPosition) {
    String? distanceText;
    if (_currentUserPosition != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        _currentUserPosition!.latitude,
        _currentUserPosition!.longitude,
        propertyPosition.latitude,
        propertyPosition.longitude,
      );
      distanceText = '${(distanceInMeters / 1000).toStringAsFixed(2)} كم';
    }

    // ✅ البحث في القائمة الجديدة (Maps)
    final propertyData = _properties.firstWhere(
      (p) => (p['id'] ?? '') == markerId.value,
      orElse: () => {},
    );

    if (propertyData.isEmpty) return;

    final title = propertyData['title'] ?? 'عقار';
    final price = propertyData['price'];
    final currency = propertyData['currency'] ?? '';
    final category = propertyData['category'] ?? '';
    final String priceStr = price != null ? '$price $currency' : '';

    setState(() {
      _selectedMarkerId = markerId;
      _polylines.clear();
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (priceStr.isNotEmpty)
              Text(
                'السعر: $priceStr',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (category.isNotEmpty) Text('النوع: $category'),
            if (distanceText != null) Text('المسافة: $distanceText'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _drawRoute(propertyPosition);
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('المسار'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PropertyDetailsScreen(
                            propertyId: propertyData['id'],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info),
                    label: const Text('التفاصيل'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _initialPosition,
            zoom: 6,
          ),
          onMapCreated: (c) {
            _mapController = c;
            _animateToUserLocation();
          },
          onTap: (_) => setState(() {
            _polylines.clear();
            _selectedMarkerId = null;
          }),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        ),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
        Positioned(
          top: 16,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'map_legend',
            mini: true,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapLegendScreen()),
            ),
            child: const Icon(Icons.info_outline),
          ),
        ),
      ],
    );
  }

  // ✅ بناء العلامات بناءً على البيانات القادمة من السيرفر
  Future<void> _buildMarkersWithCustomIcons() async {
    _markers.clear();
    for (var data in _properties) {
      final location = data['location'];

      double? lat, lng;
      // السيرفر يرسل الموقع كـ Map {_latitude, _longitude}
      if (location is Map) {
        lat = (location['_latitude'] ?? location['latitude'])?.toDouble();
        lng = (location['_longitude'] ?? location['longitude'])?.toDouble();
      }

      if (lat != null && lng != null) {
        final propertyPosition = LatLng(lat, lng);
        final markerId = MarkerId(data['id']);
        final type = data['propertyType'];
        final category = data['category'];

        final iconKey = '${type}_$category';
        if (!_markerIcons.containsKey(iconKey)) {
          _markerIcons[iconKey] = await _createMarkerBitmap(
            getIconForPropertyType(type),
            getColorForCategory(category),
          );
        }

        _markers.add(
          Marker(
            markerId: markerId,
            position: propertyPosition,
            icon: _markerIcons[iconKey]!,
            infoWindow: InfoWindow(title: data['title'] ?? 'عقار'),
            onTap: () => _onMarkerTapped(markerId, propertyPosition),
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }
}

// دوال مساعدة للأيقونات والألوان
IconData getIconForPropertyType(String? type) {
  switch (type) {
    case 'بيت':
      return Icons.house_rounded;
    case 'فيلا':
      return Icons.villa_rounded;
    case 'بناية':
      return Icons.apartment_rounded;
    case 'ارض':
      return Icons.landscape_rounded;
    case 'دكان':
      return Icons.store_rounded;
    default:
      return Icons.location_pin;
  }
}

Color getColorForCategory(String? category) {
  switch (category) {
    case 'بيع':
      return Colors.red.shade700;
    case 'إيجار':
      return Colors.blue.shade700;
    default:
      return Colors.purple;
  }
}

import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/services/api_service.dart';
import 'package:aqar_app/screens/map_legend_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

// مفتاح API (اختياري)
const kDirectionsKey = String.fromEnvironment(
  'GOOGLE_MAPS_DIRECTIONS_API_KEY',
  defaultValue: 'AIzaSyAwLH04MSJUTEHldU740RghRCJKUnpInyI',
  // defaultValue: 'AIzaSyAwiq4OSjCBXuMqms4e_JRJYjKMQOhrukQ',
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

  List<Map<String, dynamic>> _properties = [];
  final Set<Marker> _markers = {};
  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _fetchProperties();
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

    List<LatLng> polyPoints = [];

    try {
      // المحاولة الأولى: استخدام Google Directions API وفك التشفير
      polyPoints = await _getRouteUsingDirectionsAPI(propertyPosition);

      if (polyPoints.isEmpty) {
        debugPrint(
          '⚠️ [Route] Directions API returned empty, trying PolylinePoints...',
        );
        polyPoints = await _getRouteUsingPolylinePoints(propertyPosition);
      }
    } catch (e) {
      debugPrint('❌ [Route] Both methods failed: $e');
      _showRouteError('خطأ في رسم المسار');
    }

    if (mounted) {
      setState(() {
        _polylines.clear();

        // إذا كان لدينا نقاط، استخدمها، وإلا رسم خط مستقيم كحل بديل أخير
        final finalPoints = polyPoints.isNotEmpty
            ? polyPoints
            : [
                LatLng(
                  _currentUserPosition!.latitude,
                  _currentUserPosition!.longitude,
                ),
                propertyPosition,
              ];

        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: finalPoints,
            color: Theme.of(
              context,
            ).primaryColor, // استخدم لون التطبيق الأساسي لجمالية أفضل
            width: 5,
            geodesic: true,
            jointType: JointType.round, // زوايا دائرية للمسار ليظهر بشكل أنعم
          ),
        );

        debugPrint('✅ [Route] Rendering ${finalPoints.length} points on map');
      });
    }
  }

  // ✅ التعديل الجذري هنا للحصول على مسار دقيق يحاكي انحناءات الشارع
  // ✅ دالة التتبع الأولى باستخدام Directions API
  Future<List<LatLng>> _getRouteUsingDirectionsAPI(LatLng destination) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${_currentUserPosition!.latitude},${_currentUserPosition!.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&key=$kDirectionsKey'
          '&mode=driving';

      debugPrint(
        '\n================= 🚀 START DIRECTIONS API DEBUG 🚀 =================',
      );
      debugPrint(
        '🌐 [DirectionsAPI] URL: $url',
      ); // سيطبع الرابط مع المفتاح للتحقق منه

      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              debugPrint('⏱️ [DirectionsAPI] انتهى وقت الطلب (Timeout)!');
              throw Exception('Directions API timeout');
            },
          );

      debugPrint('📡 [DirectionsAPI] HTTP Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = convert.jsonDecode(response.body);
        debugPrint('📝 [DirectionsAPI] JSON Status: ${json['status']}');

        if (json['status'] == 'OK' && json['routes'].isNotEmpty) {
          final route = json['routes'][0];
          final encodedPolyline = route['overview_polyline']['points'];
          PolylinePoints polylinePoints = PolylinePoints();
          List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(
            encodedPolyline,
          );
          List<LatLng> polyPoints = decodedPoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();

          debugPrint(
            '✅ [DirectionsAPI] تم بنجاح! عدد النقاط: ${polyPoints.length}',
          );
          debugPrint(
            '================= 🏁 END DIRECTIONS API DEBUG 🏁 =================\n',
          );
          return polyPoints;
        } else {
          debugPrint(
            '⚠️ [DirectionsAPI] لم يتم العثور على مسار، الحالة: ${json['status']}',
          );
          debugPrint(
            '🛑 [DirectionsAPI] رسالة الخطأ من جوجل: ${json['error_message']}',
          );
        }
      } else {
        debugPrint(
          '❌ [DirectionsAPI] فشل الاتصال! كود الخطأ HTTP: ${response.statusCode}',
        );
        debugPrint('📦 [DirectionsAPI] محتوى الرد: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('💥 [DirectionsAPI] حدث استثناء (Exception): $e');
      debugPrint('💥 [DirectionsAPI] مسار الخطأ: $stackTrace');
    }
    debugPrint(
      '================= 🏁 END DIRECTIONS API DEBUG 🏁 =================\n',
    );
    return [];
  }

  // ✅ دالة التتبع الثانية باستخدام PolylinePoints
  Future<List<LatLng>> _getRouteUsingPolylinePoints(LatLng destination) async {
    try {
      debugPrint(
        '\n================= 🚀 START POLYLINE POINTS DEBUG 🚀 =================',
      );
      final polylinePoints = PolylinePoints();

      final result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(
            _currentUserPosition!.latitude,
            _currentUserPosition!.longitude,
          ),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
        googleApiKey: kDirectionsKey,
      );

      debugPrint('📡 [PolylinePoints] حالة الرد: ${result.status}');
      if (result.errorMessage != null && result.errorMessage!.isNotEmpty) {
        debugPrint(
          '🛑 [PolylinePoints] رسالة الخطأ من جوجل: ${result.errorMessage}',
        );
      }

      if (result.points.isNotEmpty) {
        debugPrint(
          '✅ [PolylinePoints] تم بنجاح! عدد النقاط: ${result.points.length}',
        );
        debugPrint(
          '================= 🏁 END POLYLINE POINTS DEBUG 🏁 =================\n',
        );
        return result.points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
      } else {
        debugPrint(
          '⚠️ [PolylinePoints] القائمة فارغة، لم يتم توليد أي نقاط للمسار.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('💥 [PolylinePoints] حدث استثناء (Exception): $e');
      debugPrint('💥 [PolylinePoints] مسار الخطأ: $stackTrace');
    }
    debugPrint(
      '================= 🏁 END POLYLINE POINTS DEBUG 🏁 =================\n',
    );
    return [];
  }

  void _showRouteError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
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

  Future<void> _buildMarkersWithCustomIcons() async {
    _markers.clear();
    for (var data in _properties) {
      final location = data['location'];

      double? lat, lng;
      if (location is Map) {
        lat = (location['_latitude'] ?? location['latitude'])?.toDouble();
        lng = (location['_longitude'] ?? location['longitude'])?.toDouble();
      }

      if (lat != null && lng != null) {
        final propertyPosition = LatLng(lat, lng);
        final markerId = MarkerId(data['id']);

        String? type = data['propertyType'];
        if (type == null || type.isEmpty) {
          final title = (data['title'] ?? '').toString().toLowerCase();
          if (title.contains('فيلا')) {
            type = 'فيلا';
          } else if (title.contains('بناية') || title.contains('عمارة')) {
            type = 'بناية';
          } else if (title.contains('ارض') || title.contains('أرض')) {
            type = 'ارض';
          } else if (title.contains('دكان') || title.contains('محل')) {
            type = 'دكان';
          } else {
            type = 'بيت';
          }
        }

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

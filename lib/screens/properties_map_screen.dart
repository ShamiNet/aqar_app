import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:aqar_app/firebase_options.dart';
import 'package:aqar_app/screens/map_legend_screen.dart';

// Google Directions API key
// Method 1: Use dart-define (recommended, secure):
//   flutter run --dart-define-from-file=dart_defines.json
// Method 2: Hardcoded (simple but less secure):
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
  // الإحداثيات الأولية لوسط الخريطة (إدلب، سوريا)
  static const LatLng _initialPosition = LatLng(35.9333, 36.6333);
  Position? _currentUserPosition;
  final Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;
  MarkerId? _selectedMarkerId;
  StreamSubscription<QuerySnapshot>? _propertiesSubscription;
  final Set<Marker> _markers = {};
  List<QueryDocumentSnapshot> _propertyDocs = [];
  final Map<String, BitmapDescriptor> _markerIcons = {};

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[MapScreen] initState: Initializing screen and fetching user location.',
    );
    _determinePosition();
    _listenToProperties();
  }

  @override
  void dispose() {
    debugPrint('[MapScreen] dispose: Cancelling properties subscription.');
    _propertiesSubscription?.cancel();
    super.dispose();
  }

  void _listenToProperties() {
    _propertiesSubscription = FirebaseFirestore.instance
        .collection('properties')
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint(
              '[MapScreen] _listenToProperties: Received ${snapshot.docs.length} documents.',
            );
            if (mounted) {
              setState(() {
                _propertyDocs = snapshot.docs;
                _buildMarkersWithCustomIcons();
              });
            }
          },
          onError: (error) {
            debugPrint(
              '[MapScreen] _listenToProperties: Error fetching properties: $error',
            );
          },
        );
  }

  Future<BitmapDescriptor> _createMarkerBitmap(
    IconData iconData,
    Color color,
  ) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0; // حجم الأيقونة

    // رسم الدائرة الخارجية
    final Paint circlePaint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, circlePaint);

    // رسم أيقونة بداخل الدائرة
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
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint(
        '[MapScreen] _determinePosition: Location services are disabled.',
      );
      // خدمات الموقع معطلة
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      debugPrint(
        '[MapScreen] _determinePosition: Location permission is denied, requesting permission.',
      );
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint(
          '[MapScreen] _determinePosition: Location permission was denied by user.',
        );
        // تم رفض الأذونات
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        '[MapScreen] _determinePosition: Location permission is permanently denied.',
      );
      // تم رفض الأذونات بشكل دائم
      return;
    }

    debugPrint('[MapScreen] _determinePosition: Fetching current position.');
    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentUserPosition = position;
        debugPrint(
          '[MapScreen] _determinePosition: User position found: Lat: ${position.latitude}, Lng: ${position.longitude}',
        );
      });
      _animateToUserLocation();
    }
  }

  void _animateToUserLocation() {
    if (_mapController == null || _currentUserPosition == null) return;

    debugPrint(
      '[MapScreen] _animateToUserLocation: Animating camera to user location.',
    );
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

  Future<void> _drawRoute(LatLng propertyPosition) async {
    if (_currentUserPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم تحديد موقعك الحالي بعد.')),
      );
      return;
    }

    final polylinePoints = PolylinePoints();
    List<LatLng> polyPoints = [];

    try {
      final apiKey = (kDirectionsKey.isNotEmpty)
          ? kDirectionsKey
          : DefaultFirebaseOptions.currentPlatform.apiKey;
      if (kDirectionsKey.isNotEmpty) {
        debugPrint('[MapScreen] Using dart-define Directions API key.');
      } else {
        debugPrint(
          '[MapScreen] GOOGLE_MAPS_DIRECTIONS_API_KEY missing; falling back to Firebase apiKey.',
        );
      }
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
      debugPrint('[MapScreen] _drawRoute: Directions API failed: $e');
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

      // Animate camera to fit the route
      final bounds = _boundsFromLatLngList(_polylines.first.points);
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 64),
      );
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;
    for (final latLng in list) {
      if (minLat == null || latLng.latitude < minLat) minLat = latLng.latitude;
      if (maxLat == null || latLng.latitude > maxLat) maxLat = latLng.latitude;
      if (minLng == null || latLng.longitude < minLng)
        minLng = latLng.longitude;
      if (maxLng == null || latLng.longitude > maxLng)
        maxLng = latLng.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  void _onMarkerTapped(MarkerId markerId, LatLng propertyPosition) {
    // حساب المسافة إذا كان موقع المستخدم متاحاً
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

    // البحث عن بيانات العقار
    final propertyDoc = _propertyDocs.firstWhere(
      (doc) => doc.id == markerId.value,
      orElse: () => throw Exception('Property not found'),
    );
    final data = propertyDoc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'عقار غير مسمى';
    final price = data['price'];
    final currency = data['currency'] ?? '';
    final category = data['category'] ?? '';
    String priceStr = '';
    if (price is num) {
      priceStr = '${price.toStringAsFixed(0)} $currency';
    }

    // إخفاء أي مسارات قديمة
    setState(() {
      _selectedMarkerId = markerId;
      _polylines.clear();
    });

    // عرض BottomSheet جميلة بالمعلومات والخيارات
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.95),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // مقبض السحب
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),

            // بطاقة العنوان مع خلفية ملونة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.home_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // بطاقات المعلومات
            if (priceStr.isNotEmpty)
              _buildInfoCard(
                context,
                Icons.payments_rounded,
                'السعر',
                priceStr,
                Colors.green,
              ),
            if (category.isNotEmpty)
              _buildInfoCard(
                context,
                Icons.category_rounded,
                'النوع',
                category,
                Colors.blue,
              ),
            if (distanceText != null)
              _buildInfoCard(
                context,
                Icons.location_on_rounded,
                'المسافة',
                distanceText,
                Colors.orange,
              ),

            const SizedBox(height: 24),

            // الأزرار بتصميم جذاب
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _drawRoute(propertyPosition);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'رسم المسار',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.secondary,
                          Theme.of(
                            context,
                          ).colorScheme.secondary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => PropertyDetailsScreen(
                                propertyId: propertyDoc.id,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_rounded,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'التفاصيل',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color accentColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: accentColor),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
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
          onMapCreated: (controller) {
            debugPrint(
              '[MapScreen] onMapCreated: GoogleMapController is ready.',
            );
            _mapController = controller;
            _animateToUserLocation();
          },
          onTap: (_) {
            // إخفاء الخط عند النقر على الخريطة
            setState(() {
              debugPrint(
                '[MapScreen] onMapTap: Map tapped, clearing polylines.',
              );
              _polylines.clear();
              if (_selectedMarkerId != null && _mapController != null) {
                // Rebuild markers to reset the snippet before hiding
                final idToHide = _selectedMarkerId!;
                _selectedMarkerId =
                    null; // Important to set this before rebuild
                _buildMarkersWithCustomIcons();
                _mapController!.hideMarkerInfoWindow(idToHide);
              }
              _selectedMarkerId = null;
            });
          },
          markers: _markers,
          polylines: _polylines,
          mapType: MapType.normal,
          myLocationButtonEnabled: true,
          myLocationEnabled: true, // يعرض النقطة الزرقاء لموقع المستخدم
          trafficEnabled: true,
        ),
        Positioned(
          top: 16,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'map_legend_fab', // لتجنب التعارض مع أزرار أخرى
            mini: true,
            tooltip: 'دليل الخريطة',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const MapLegendScreen()),
              );
            },
            child: const Icon(Icons.info_outline),
          ),
        ),
      ],
    );
  }

  Future<void> _buildMarkersWithCustomIcons() async {
    _markers.clear();
    for (var doc in _propertyDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final location = data['location'];
      final propertyType = data['propertyType'] as String?;
      final category = data['category'] as String?;

      if (location is GeoPoint) {
        final propertyPosition = LatLng(location.latitude, location.longitude);
        final markerId = MarkerId(doc.id);

        final iconData = getIconForPropertyType(propertyType);
        final color = getColorForCategory(category);
        final iconKey = '${propertyType}_${category}';

        if (!_markerIcons.containsKey(iconKey)) {
          _markerIcons[iconKey] = await _createMarkerBitmap(iconData, color);
        }

        _markers.add(
          Marker(
            markerId: markerId,
            position: propertyPosition,
            icon: _markerIcons[iconKey] ?? BitmapDescriptor.defaultMarker,
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

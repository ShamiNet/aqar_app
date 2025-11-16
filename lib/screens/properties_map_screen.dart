import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:aqar_app/firebase_options.dart';

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
  // الإحداثيات الأولية لوسط الخريطة (مثلاً: الرياض)
  static const LatLng _initialPosition = LatLng(24.7136, 46.6753);
  Position? _currentUserPosition;
  final Set<Polyline> _polylines = {};
  String? _distance;
  GoogleMapController? _mapController;
  MarkerId? _selectedMarkerId;
  StreamSubscription<QuerySnapshot>? _propertiesSubscription;
  final Set<Marker> _markers = {};
  List<QueryDocumentSnapshot> _propertyDocs = [];

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
                _buildMarkers();
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
          zoom: 14,
        ),
      ),
    );
  }

  Future<void> _onMarkerTapped(
    LatLng propertyPosition,
    MarkerId markerId,
  ) async {
    if (_currentUserPosition == null) return;

    debugPrint('[MapScreen] _onMarkerTapped: Marker ${markerId.value} tapped.');
    debugPrint(
      '[MapScreen] _onMarkerTapped: User Position: ${_currentUserPosition!.latitude}, ${_currentUserPosition!.longitude}',
    );
    debugPrint(
      '[MapScreen] _onMarkerTapped: Property Position: ${propertyPosition.latitude}, ${propertyPosition.longitude}',
    );

    final distanceInMeters = Geolocator.distanceBetween(
      _currentUserPosition!.latitude,
      _currentUserPosition!.longitude,
      propertyPosition.latitude,
      propertyPosition.longitude,
    );

    debugPrint(
      '[MapScreen] _onMarkerTapped: Calculated distance: $distanceInMeters meters.',
    );

    // Get polyline points before setState (guard errors and fall back)
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
      debugPrint(
        '[MapScreen] _onMarkerTapped: Directions status: ${result.status}, points: ${polyPoints.length}',
      );
    } catch (e) {
      debugPrint('[MapScreen] _onMarkerTapped: Directions failed: $e');
    }

    setState(() {
      _selectedMarkerId = markerId;
      _distance = '${(distanceInMeters / 1000).toStringAsFixed(2)} كم';
      debugPrint(
        '[MapScreen] _onMarkerTapped: Updating state with distance: $_distance. Rebuilding markers.',
      );

      // Rebuild markers to update the InfoWindow snippet
      _buildMarkers();

      _polylines.clear();
      if (polyPoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: polyPoints,
            color: Colors.blue,
            width: 5,
          ),
        );
        debugPrint(
          '[MapScreen] _onMarkerTapped: Polyline with ${polyPoints.length} points added.',
        );
      } else {
        // Fallback: draw straight line if Directions API fails
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route_fallback'),
            points: [
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
        debugPrint(
          '[MapScreen] _onMarkerTapped: Directions empty, added fallback straight polyline.',
        );
      }
    });

    // بعد تحديث الحالة، نطلب من الخريطة إعادة عرض نافذة المعلومات للعلامة المحددة
    // هذا يضمن ظهور المسافة المحدثة
    if (_mapController != null) {
      await _mapController!.showMarkerInfoWindow(markerId);
    }
    debugPrint('[MapScreen] _onMarkerTapped: showMarkerInfoWindow called.');

    // Fit camera to show entire route
    if (_mapController != null) {
      final allPoints = _polylines.isNotEmpty
          ? _polylines.first.points
          : [
              LatLng(
                _currentUserPosition!.latitude,
                _currentUserPosition!.longitude,
              ),
              propertyPosition,
            ];
      double minLat = allPoints.first.latitude;
      double maxLat = allPoints.first.latitude;
      double minLng = allPoints.first.longitude;
      double maxLng = allPoints.first.longitude;
      for (final p in allPoints) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 64),
      );
      debugPrint(
        '[MapScreen] _onMarkerTapped: Camera animated to route bounds.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: _initialPosition,
        zoom: 6,
      ),
      onMapCreated: (controller) {
        debugPrint('[MapScreen] onMapCreated: GoogleMapController is ready.');
        _mapController = controller;
        _animateToUserLocation();
      },
      onTap: (_) {
        // إخفاء الخط عند النقر على الخريطة
        setState(() {
          debugPrint('[MapScreen] onMapTap: Map tapped, clearing polylines.');
          _polylines.clear();
          if (_selectedMarkerId != null && _mapController != null) {
            // Rebuild markers to reset the snippet before hiding
            final idToHide = _selectedMarkerId!;
            _selectedMarkerId = null;
            _buildMarkers();
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
    );
  }

  void _buildMarkers() {
    _markers.clear();
    for (var doc in _propertyDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final location = data['location'];

      if (location is GeoPoint) {
        final propertyPosition = LatLng(location.latitude, location.longitude);
        final markerId = MarkerId(doc.id);

        _markers.add(
          Marker(
            markerId: markerId,
            position: propertyPosition,
            onTap: () => _onMarkerTapped(propertyPosition, markerId),
            infoWindow: InfoWindow(
              title: data['title'] ?? 'عقار غير مسمى',
              snippet: () {
                final price = data['price'];
                final currency = data['currency'] ?? '';
                final category = data['category'] ?? '';
                String priceStr = '';
                if (price is num) {
                  priceStr = '${price.toStringAsFixed(0)} $currency';
                }
                if (_selectedMarkerId == markerId && _distance != null) {
                  return 'المسافة: $_distance • $priceStr • $category';
                }
                return '$priceStr • $category';
              }(),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => PropertyDetailsScreen(propertyId: doc.id),
                  ),
                );
              },
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueViolet,
            ),
          ),
        );
      }
    }
  }
}

import 'package:aqar_app/screens/property_details_screen.dart';
import 'package:aqar_app/services/api_service.dart'; // ✅
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Future<List<Map<String, dynamic>>>? _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');
    if (uid != null) {
      setState(() {
        _favoritesFuture = ApiService.fetchFavorites(uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_favoritesFuture == null)
      return const Scaffold(
        body: Center(child: Text('سجل الدخول لترى المفضلة')),
      );

    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _favoritesFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return const Center(child: Text('المفضلة فارغة.'));

          return ListView.builder(
            itemCount: snapshot.data!.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (ctx, index) {
              final property = snapshot.data![index];
              return Card(
                child: ListTile(
                  leading:
                      property['imageUrls'] != null &&
                          (property['imageUrls'] as List).isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: property['imageUrls'][0],
                          width: 50,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.image),
                  title: Text(property['title'] ?? ''),
                  subtitle: Text(
                    '${property['price']} ${property['currency']}',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropertyDetailsScreen(
                        propertyId: property['id'] ?? '',
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

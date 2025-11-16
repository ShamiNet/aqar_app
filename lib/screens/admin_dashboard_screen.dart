import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<Map<String, int>> _statsFuture;

  Future<Map<String, int>> _fetchStats() async {
    final usersCountFuture = FirebaseFirestore.instance
        .collection('users')
        .count()
        .get();
    final propertiesCountFuture = FirebaseFirestore.instance
        .collection('properties')
        .count()
        .get();

    final results = await Future.wait([
      usersCountFuture,
      propertiesCountFuture,
    ]);

    return {
      'users': results[0].count ?? 0,
      'properties': results[1].count ?? 0,
    };
  }

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة تحكم المدير')),
      body: FutureBuilder<Map<String, int>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ في جلب الإحصائيات.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('لا توجد بيانات.'));
          }

          final stats = snapshot.data!;
          final userCount = stats['users'] ?? 0;
          final propertyCount = stats['properties'] ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                // Re-fetch the stats and update the future
                // This will cause the FutureBuilder to re-run with the new future
                _statsFuture = _fetchStats();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildStatCard(
                  context,
                  icon: Icons.person_outline,
                  label: 'إجمالي المستخدمين',
                  value: userCount.toString(),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  context,
                  icon: Icons.home_work_outlined,
                  label: 'إجمالي العقارات',
                  value: propertyCount.toString(),
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

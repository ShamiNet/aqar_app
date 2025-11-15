import 'package:flutter/material.dart';

class PropertyCardSkeleton extends StatelessWidget {
  const PropertyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      child: Stack(
        children: [
          // Image placeholder
          Container(
            height: 220,
            width: double.infinity,
            color: Colors.black, // Shimmer base color
          ),
          // Text placeholders
          Positioned(
            bottom: 20,
            right: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 200, height: 22, color: Colors.black),
                const SizedBox(height: 8),
                Container(width: 100, height: 18, color: Colors.black),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

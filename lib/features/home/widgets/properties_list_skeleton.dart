import 'package:aqar_app/features/home/widgets/property_card_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class PropertiesListSkeleton extends StatelessWidget {
  const PropertiesListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: 5, // Display 5 skeleton cards
        itemBuilder: (ctx, index) {
          return const PropertyCardSkeleton();
        },
      ),
    );
  }
}

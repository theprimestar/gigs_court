import 'package:flutter/material.dart';
import '../models/provider_card_data.dart';

class ProviderCardNearby extends StatelessWidget {
  final ProviderCardData provider;
  final VoidCallback onTap;

  const ProviderCardNearby({
    super.key,
    required this.provider,
    required this.onTap,
  });

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatServices() {
    final services = provider.services.take(2).join(', ');
    if (provider.services.length > 2) return '$services...';
    return services;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: provider.photoUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(provider.photoUrl),
                  fit: BoxFit.cover,
                )
              : null,
          color: const Color(0xFF1A1F71),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (provider.isActive)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          provider.fullName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 11, color: Color(0xFFFFD700)),
                      const SizedBox(width: 2),
                      Text(
                        '${provider.rating.toStringAsFixed(1)} (${provider.reviewCount})',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatServices(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDistance(provider.distanceMeters)} • ${provider.gigCountThisMonth} gigs',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
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

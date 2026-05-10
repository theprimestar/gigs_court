import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/provider_card_data.dart';
import 'firestore_profile_service.dart';

class PaginatedProviders {
  final List<ProviderCardData> providers;
  final double? nextCursorDistance;
  final String? nextCursorId;

  const PaginatedProviders({
    required this.providers,
    this.nextCursorDistance,
    this.nextCursorId,
  });
}

class HomeService {
  final _supabase = Supabase.instance.client;
  final _profileService = FirestoreProfileService();

  Future<PaginatedProviders> getTrendingProviders({
    required double viewerLat,
    required double viewerLng,
    int limit = 10,
    double? cursorDistance,
    String? cursorId,
  }) async {
    final supabaseResponse = await _supabase.rpc('get_nearby_profiles', params: {
      'viewer_lat': viewerLat,
      'viewer_lng': viewerLng,
      'max_distance_meters': 999999999,
      'p_limit': 30,
      'p_cursor_distance': cursorDistance,
      'p_cursor_id': cursorId,
    });

    if (supabaseResponse == null) return const PaginatedProviders(providers: []);

    final nearbyData = List<Map<String, dynamic>>.from(supabaseResponse);
    final uids = nearbyData.map((d) => d['id'] as String).toList();
    if (uids.isEmpty) return const PaginatedProviders(providers: []);

    final firestoreData = await _profileService.readProfiles(uids);

    final allProviders = <ProviderCardData>[];

    for (final uid in uids) {
      final profile = firestoreData[uid];
      if (profile == null) continue;

      final gigCount7Days = (profile['gigCount7Days'] as int?) ?? 0;
      final gigCount30Days = (profile['gigCount30Days'] as int?) ?? 0;
      final reviewCount = (profile['reviewCount'] as int?) ?? 0;

      if (gigCount7Days < 1) continue;
      if (reviewCount < 1) continue;

      final isActive = gigCount7Days >= 1 || gigCount30Days >= 3;

      allProviders.add(ProviderCardData(
        uid: uid,
        fullName: profile['fullName'] as String? ?? '',
        photoUrl: profile['photoUrl'] as String? ?? '',
        rating: (profile['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: reviewCount,
        services: List<String>.from(profile['services'] ?? []),
        distanceMeters: nearbyData.firstWhere((d) => d['id'] == uid)['distance_meters'] ?? 0.0,
        gigCountThisMonth: gigCount30Days,
        gigCountTotal: (profile['gigCount'] as int?) ?? 0,
        dateJoined: _profileService.formatDate(profile['createdAt'] as Timestamp?),
        workspaceAddress: nearbyData.firstWhere((d) => d['id'] == uid)['workspace_address'] as String? ?? '',
        isActive: isActive,
      ));
    }

    allProviders.sort((a, b) {
      final velocityA = (firestoreData[a.uid]?['gigCount7Days'] as int?) ?? 0;
      final velocityB = (firestoreData[b.uid]?['gigCount7Days'] as int?) ?? 0;
      if (velocityB != velocityA) return velocityB.compareTo(velocityA);
      if (b.rating != a.rating) return b.rating.compareTo(a.rating);
      return b.gigCountTotal.compareTo(a.gigCountTotal);
    });

    final paged = allProviders.take(limit).toList();

    double? nextDistance;
    String? nextId;
    if (paged.isNotEmpty && allProviders.length > limit) {
      final last = paged.last;
      nextDistance = last.distanceMeters;
      nextId = last.uid;
    }

    return PaginatedProviders(
      providers: paged,
      nextCursorDistance: nextDistance,
      nextCursorId: nextId,
    );
  }

  Future<PaginatedProviders> getNearbyProviders({
    required double viewerLat,
    required double viewerLng,
    int limit = 10,
    double? cursorDistance,
    String? cursorId,
  }) async {
    final supabaseResponse = await _supabase.rpc('get_nearby_profiles', params: {
      'viewer_lat': viewerLat,
      'viewer_lng': viewerLng,
      'max_distance_meters': 999999999,
      'p_limit': limit,
      'p_cursor_distance': cursorDistance,
      'p_cursor_id': cursorId,
    });

    if (supabaseResponse == null) return const PaginatedProviders(providers: []);

    final nearbyData = List<Map<String, dynamic>>.from(supabaseResponse);
    final uids = nearbyData.map((d) => d['id'] as String).toList();
    if (uids.isEmpty) return const PaginatedProviders(providers: []);

    final firestoreData = await _profileService.readProfiles(uids);

    final providers = <ProviderCardData>[];

    for (final data in nearbyData) {
      final uid = data['id'] as String;
      final profile = firestoreData[uid];
      if (profile == null) continue;

      final gigCount7Days = (profile['gigCount7Days'] as int?) ?? 0;
      final gigCount30Days = (profile['gigCount30Days'] as int?) ?? 0;
      final isActive = gigCount7Days >= 1 || gigCount30Days >= 3;

      providers.add(ProviderCardData(
        uid: uid,
        fullName: profile['fullName'] as String? ?? '',
        photoUrl: profile['photoUrl'] as String? ?? '',
        rating: (profile['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (profile['reviewCount'] as int?) ?? 0,
        services: List<String>.from(profile['services'] ?? []),
        distanceMeters: data['distance_meters'] ?? 0.0,
        gigCountThisMonth: gigCount30Days,
        gigCountTotal: (profile['gigCount'] as int?) ?? 0,
        dateJoined: _profileService.formatDate(profile['createdAt'] as Timestamp?),
        workspaceAddress: data['workspace_address'] as String? ?? '',
        isActive: isActive,
      ));
    }

    providers.sort((a, b) {
      if (a.distanceMeters != b.distanceMeters) {
        return a.distanceMeters.compareTo(b.distanceMeters);
      }
      if (a.isActive != b.isActive) return b.isActive ? 1 : -1;
      if (b.rating != a.rating) return b.rating.compareTo(a.rating);
      return b.gigCountTotal.compareTo(a.gigCountTotal);
    });

    double? nextDistance;
    String? nextId;
    if (providers.isNotEmpty) {
      final last = providers.last;
      nextDistance = last.distanceMeters;
      nextId = last.uid;
    }

    return PaginatedProviders(
      providers: providers,
      nextCursorDistance: nextDistance,
      nextCursorId: nextId,
    );
  }
}

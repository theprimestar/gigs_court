import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/provider_card_data.dart';
import 'firestore_profile_service.dart';
import 'home_service.dart';

class SearchService {
  final _supabase = Supabase.instance.client;
  final _firestore = FirebaseFirestore.instance;
  final _profileService = FirestoreProfileService();

  Future<List<String>> getPopularServices() async {
    final doc = await _firestore.collection('metadata').doc('service_counts').get();
    if (!doc.exists) return [];

    final data = doc.data() as Map<String, dynamic>;
    final counts = <String, int>{};
    data.forEach((key, value) {
      counts[key] = (value as num).toInt();
    });

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(10).map((e) => e.key).toList();
  }

  Future<PaginatedProviders> searchProviders({
    required double viewerLat,
    required double viewerLng,
    required String serviceSlug,
    required double maxDistanceMeters,
    int limit = 10,
    double? cursorDistance,
    String? cursorId,
  }) async {
    final supabaseResponse = await _supabase.rpc('search_providers', params: {
      'viewer_lat': viewerLat,
      'viewer_lng': viewerLng,
      'service_slug': serviceSlug,
      'max_distance_meters': maxDistanceMeters,
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

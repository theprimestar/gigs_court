import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/provider_card_data.dart';

class HomeService {
  final _supabase = Supabase.instance.client;
  final _firestore = FirebaseFirestore.instance;

  Future<List<ProviderCardData>> getTrendingProviders({
    required double viewerLat,
    required double viewerLng,
    int limit = 10,
    String? cursorDistance,
    String? cursorId,
  }) async {
    final supabaseResponse = await _supabase.rpc('get_nearby_profiles', params: {
      'viewer_lat': viewerLat,
      'viewer_lng': viewerLng,
      'max_distance_meters': 999999999,
      'p_limit': 50,
      'p_cursor_distance': cursorDistance,
      'p_cursor_id': cursorId,
    });

    if (supabaseResponse == null) return [];

    final nearbyData = List<Map<String, dynamic>>.from(supabaseResponse);
    final uids = nearbyData.map((d) => d['id'] as String).toList();
    if (uids.isEmpty) return [];

    final firestoreData = await _readProfiles(uids);

    final providers = <ProviderCardData>[];

    for (final uid in uids) {
      final profile = firestoreData[uid];
      if (profile == null) continue;

      final gigCount7Days = (profile['gigCount7Days'] as int?) ?? 0;
      final gigCount30Days = (profile['gigCount30Days'] as int?) ?? 0;
      final reviewCount = (profile['reviewCount'] as int?) ?? 0;

      // Trending filter: must have at least 1 gig in 7 days and 1 review
      if (gigCount7Days < 1) continue;
      if (reviewCount < 1) continue;

      final isActive = gigCount7Days >= 1 || gigCount30Days >= 3;

      providers.add(ProviderCardData(
        uid: uid,
        fullName: profile['fullName'] as String? ?? '',
        photoUrl: profile['photoUrl'] as String? ?? '',
        rating: (profile['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: reviewCount,
        services: List<String>.from(profile['services'] ?? []),
        distanceMeters: nearbyData.firstWhere((d) => d['id'] == uid)['distance_meters'] ?? 0.0,
        gigCountThisMonth: gigCount30Days,
        gigCountTotal: (profile['gigCount'] as int?) ?? 0,
        dateJoined: _formatDate(profile['createdAt'] as Timestamp?),
        workspaceAddress: nearbyData.firstWhere((d) => d['id'] == uid)['workspace_address'] as String? ?? '',
        isActive: isActive,
      ));
    }

    // Sort: 7-day velocity DESC → rating DESC → total gigs DESC
    providers.sort((a, b) {
      final velocityA = (firestoreData[a.uid]?['gigCount7Days'] as int?) ?? 0;
      final velocityB = (firestoreData[b.uid]?['gigCount7Days'] as int?) ?? 0;
      if (velocityB != velocityA) return velocityB.compareTo(velocityA);
      if (b.rating != a.rating) return b.rating.compareTo(a.rating);
      return b.gigCountTotal.compareTo(a.gigCountTotal);
    });

    return providers.take(limit).toList();
  }

  Future<List<ProviderCardData>> getNearbyProviders({
    required double viewerLat,
    required double viewerLng,
    int limit = 10,
    String? cursorDistance,
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

    if (supabaseResponse == null) return [];

    final nearbyData = List<Map<String, dynamic>>.from(supabaseResponse);
    final uids = nearbyData.map((d) => d['id'] as String).toList();
    if (uids.isEmpty) return [];

    final firestoreData = await _readProfiles(uids);

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
        dateJoined: _formatDate(profile['createdAt'] as Timestamp?),
        workspaceAddress: data['workspace_address'] as String? ?? '',
        isActive: isActive,
      ));
    }

    // Sort: Distance ASC → activity badge → rating DESC → gig count DESC
    providers.sort((a, b) {
      if (a.distanceMeters != b.distanceMeters) {
        return a.distanceMeters.compareTo(b.distanceMeters);
      }
      if (a.isActive != b.isActive) return b.isActive ? 1 : -1;
      if (b.rating != a.rating) return b.rating.compareTo(a.rating);
      return b.gigCountTotal.compareTo(a.gigCountTotal);
    });

    return providers;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<Map<String, Map<String, dynamic>>> _readProfiles(List<String> uids) async {
    final result = <String, Map<String, dynamic>>{};
    final chunks = <List<String>>[];
    for (var i = 0; i < uids.length; i += 30) {
      chunks.add(uids.sublist(i, i + 30 > uids.length ? uids.length : i + 30));
    }
    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection('profiles')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        result[doc.id] = doc.data();
      }
    }
    return result;
  }
}

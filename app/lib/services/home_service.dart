import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/provider_card_data.dart';

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
  final _firestore = FirebaseFirestore.instance;

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

    final firestoreData = await _readProfiles(uids);

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
        dateJoined: _formatDate(profile['createdAt'] as Timestamp?),
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
        result[doc.id] = doc.data() as Map<String, dynamic>;
      }
    }

    await _recalculateStaleCounters(result);

    return result;
  }

  Future<void> _recalculateStaleCounters(Map<String, Map<String, dynamic>> profiles) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final staleUids = <String>[];

    for (final entry in profiles.entries) {
      final lastReset = entry.value['lastCountReset'] as Timestamp?;
      if (lastReset == null || lastReset.toDate().isBefore(today)) {
        staleUids.add(entry.key);
      }
    }

    if (staleUids.isEmpty) return;

    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final batch = _firestore.batch();
    final chunks = <List<String>>[];
    for (var i = 0; i < staleUids.length; i += 30) {
      chunks.add(staleUids.sublist(i, i + 30 > staleUids.length ? staleUids.length : i + 30));
    }

    for (final chunk in chunks) {
      final gigsSnapshot = await _firestore
          .collection('gigs')
          .where('provider_id', whereIn: chunk)
          .where('status', isEqualTo: 'completed')
          .where('completed_at', isGreaterThan: thirtyDaysAgo)
          .get();

      final counts7 = <String, int>{};
      final counts30 = <String, int>{};

      for (final doc in gigsSnapshot.docs) {
        final data = doc.data();
        final pid = data['provider_id'] as String;
        final completedAt = (data['completed_at'] as Timestamp).toDate();

        if (completedAt.isAfter(sevenDaysAgo)) {
          counts7[pid] = (counts7[pid] ?? 0) + 1;
        }
        if (completedAt.isAfter(thirtyDaysAgo)) {
          counts30[pid] = (counts30[pid] ?? 0) + 1;
        }
      }

      for (final uid in chunk) {
        final count7 = counts7[uid] ?? 0;
        final count30 = counts30[uid] ?? 0;

        batch.update(_firestore.collection('profiles').doc(uid), {
          'gigCount7Days': count7,
          'gigCount30Days': count30,
          'lastCountReset': FieldValue.serverTimestamp(),
        });

        if (profiles.containsKey(uid)) {
          profiles[uid]!['gigCount7Days'] = count7;
          profiles[uid]!['gigCount30Days'] = count30;
        }
      }
    }

    await batch.commit();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreProfileService {
  final _firestore = FirebaseFirestore.instance;

  Future<Map<String, Map<String, dynamic>>> readProfiles(List<String> uids) async {
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

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> createProfile({
    required String fullName,
    required String photoUrl,
    required String photoFileId,
    required String phone,
    required String bio,
    required List<String> services,
  }) async {
    final uid = _auth.currentUser!.uid;

    await _firestore.collection('profiles').doc(uid).set({
      'fullName': fullName,
      'photoUrl': photoUrl,
      'photoFileId': photoFileId,
      'phone': phone,
      'bio': bio,
      'services': services,
      'credits': 5,
      'gigCount': 0,
      'gigCount30Days': 0,
      'gigCount7Days': 0,
      'lastCountReset': FieldValue.serverTimestamp(),
      'rating': 0.0,
      'reviewCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final String? voiceUrl;
  final DateTime createdAt;
  final MessageStatus status;
  final Map<String, bool> readBy;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.imageUrl,
    this.voiceUrl,
    required this.createdAt,
    required this.status,
    required this.readBy,
  });
}

enum MessageStatus { sending, sent, read, viewed, played }

class ChatConversation {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhoto;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String? gigStatus;

  ChatConversation({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhoto,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.gigStatus,
  });
}

class ChatService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Stream<List<ChatConversation>> getConversations() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final conversations = <ChatConversation>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants']);
        final otherUid = participants.firstWhere((p) => p != currentUid);

        // Fetch other user's profile
        final userDoc = await _firestore.collection('profiles').doc(otherUid).get();
        final userName = userDoc.data()?['fullName'] as String? ?? 'Unknown';
        final userPhoto = userDoc.data()?['photoUrl'] as String? ?? '';

        conversations.add(ChatConversation(
          chatId: doc.id,
          otherUserId: otherUid,
          otherUserName: userName,
          otherUserPhoto: userPhoto,
          lastMessage: data['lastMessage'] as String?,
          lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
          unreadCount: (data['unreadCount_$currentUid'] as int?) ?? 0,
          gigStatus: data['gigStatus'] as String?,
        ));
      }

      return conversations;
    });
  }

  Stream<List<ChatMessage>> getMessages(String otherUid) {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return Stream.value([]);

    final chatId = _getChatId(currentUid, otherUid);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        return ChatMessage(
          id: doc.id,
          senderId: data['senderId'] as String,
          text: data['text'] as String?,
          imageUrl: data['imageUrl'] as String?,
          voiceUrl: data['voiceUrl'] as String?,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          status: _parseStatus(data['status'] as String?),
          readBy: Map<String, bool>.from(data['readBy'] ?? {}),
        );
      }).toList();

      return messages.reversed.toList();
    });
  }

  Future<List<ChatMessage>> getOlderMessages(String otherUid, DateTime before) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return [];

    final chatId = _getChatId(currentUid, otherUid);

    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfter(before)
        .limit(20)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return ChatMessage(
        id: doc.id,
        senderId: data['senderId'] as String,
        text: data['text'] as String?,
        imageUrl: data['imageUrl'] as String?,
        voiceUrl: data['voiceUrl'] as String?,
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        status: _parseStatus(data['status'] as String?),
        readBy: Map<String, bool>.from(data['readBy'] ?? {}),
      );
    }).toList().reversed.toList();
  }

  Future<void> sendTextMessage(String otherUid, String text) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    final chatId = _getChatId(currentUid, otherUid);
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'senderId': currentUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sent',
      'readBy': {currentUid: true},
    });

    await _firestore.collection('chats').doc(chatId).set({
      'participants': [currentUid, otherUid],
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount_$otherUid': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> sendImageMessage(String otherUid, String imageUrl) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    final chatId = _getChatId(currentUid, otherUid);
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'senderId': currentUid,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sent',
      'readBy': {currentUid: true},
    });

    await _firestore.collection('chats').doc(chatId).set({
      'participants': [currentUid, otherUid],
      'lastMessage': '📷 Image',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount_$otherUid': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> markAsRead(String otherUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    final chatId = _getChatId(currentUid, otherUid);

    // Reset unread count
    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount_$currentUid': 0,
    });

    // Mark all unread messages as read
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('readBy.$currentUid', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.update(doc.reference, {
        'readBy.$currentUid': true,
        'status': 'read',
      });
    }
    await batch.commit();
  }

  Future<Map<String, dynamic>?> getGig(String otherUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return null;

    final chatId = _getChatId(currentUid, otherUid);

    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('gigs')
        .where('status', whereIn: ['pending', 'active'])
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data();
  }

  Future<void> registerGig(String otherUid, String service) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) throw Exception('Not authenticated');

    final chatId = _getChatId(currentUid, otherUid);
    final gigRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('gigs')
        .doc();

    await gigRef.set({
      'provider_id': currentUid,
      'client_id': otherUid,
      'service': service,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });

    // Also create in global gigs collection
    await _firestore.collection('gigs').doc(gigRef.id).set({
      'provider_id': currentUid,
      'client_id': otherUid,
      'service': service,
      'status': 'pending',
      'completed_at': null,
      'created_at': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('chats').doc(chatId).update({
      'gigStatus': 'pending',
    });
  }

  Future<void> cancelGig(String otherUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    final chatId = _getChatId(currentUid, otherUid);

    final gigSnapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('gigs')
        .where('status', whereIn: ['pending', 'active'])
        .limit(1)
        .get();

    if (gigSnapshot.docs.isEmpty) return;

    final gigId = gigSnapshot.docs.first.id;

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('gigs')
        .doc(gigId)
        .update({'status': 'canceled'});

    await _firestore.collection('gigs').doc(gigId).update({
      'status': 'canceled',
    });

    await _firestore.collection('chats').doc(chatId).update({
      'gigStatus': null,
    });
  }

  Future<void> submitReview(String otherUid, int rating, String? reviewText) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    final chatId = _getChatId(currentUid, otherUid);

    final gigSnapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('gigs')
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (gigSnapshot.docs.isEmpty) return;

    final gig = gigSnapshot.docs.first;
    final gigData = gig.data();
    final providerUid = gigData['provider_id'] as String;
    final gigId = gig.id;

    // Update gig
    await gig.reference.update({
      'status': 'completed',
      'completed_at': FieldValue.serverTimestamp(),
      'review': {'rating': rating, 'text': reviewText ?? ''},
    });

    await _firestore.collection('gigs').doc(gigId).update({
      'status': 'completed',
      'completed_at': FieldValue.serverTimestamp(),
      'review': {'rating': rating, 'text': reviewText ?? ''},
    });

    // Update provider stats
    final providerRef = _firestore.collection('profiles').doc(providerUid);
    final providerDoc = await providerRef.get();
    final providerData = providerDoc.data()!;
    final currentRating = (providerData['rating'] as num?)?.toDouble() ?? 0.0;
    final currentReviewCount = (providerData['reviewCount'] as int?) ?? 0;
    final currentGigCount = (providerData['gigCount'] as int?) ?? 0;

    // Check if this client already reviewed this provider
    final previousReviews = await _firestore
        .collection('reviews')
        .where('provider_id', isEqualTo: providerUid)
        .where('client_id', isEqualTo: currentUid)
        .limit(1)
        .get();

    if (previousReviews.docs.isEmpty) {
      // New review
      await providerRef.update({
        'rating': currentRating + rating,
        'reviewCount': currentReviewCount + 1,
        'gigCount': currentGigCount + 1,
        'gigCount30Days': FieldValue.increment(1),
        'gigCount7Days': FieldValue.increment(1),
        'credits': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Overwrite existing review
      final oldReview = previousReviews.docs.first.data();
      final oldRating = (oldReview['rating'] as num?)?.toInt() ?? 0;
      await providerRef.update({
        'rating': currentRating - oldRating + rating,
        'gigCount': currentGigCount + 1,
        'gigCount30Days': FieldValue.increment(1),
        'gigCount7Days': FieldValue.increment(1),
        'credits': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Save review document (overwrite if exists)
    if (previousReviews.docs.isEmpty) {
      await _firestore.collection('reviews').add({
        'provider_id': providerUid,
        'client_id': currentUid,
        'rating': rating,
        'text': reviewText ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });
    } else {
      await previousReviews.docs.first.reference.update({
        'rating': rating,
        'text': reviewText ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });
    }

    await _firestore.collection('chats').doc(chatId).update({
      'gigStatus': null,
    });
  }

  Future<List<Map<String, dynamic>>> getRecentChats14Days() async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return [];

    final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));

    final snapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .where('lastMessageTime', isGreaterThan: fourteenDaysAgo)
        .orderBy('lastMessageTime', descending: true)
        .limit(10)
        .get();

    final results = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants']);
      final otherUid = participants.firstWhere((p) => p != currentUid);

      final userDoc = await _firestore.collection('profiles').doc(otherUid).get();
      results.add({
        'uid': otherUid,
        'name': userDoc.data()?['fullName'] ?? 'Unknown',
        'photoUrl': userDoc.data()?['photoUrl'] ?? '',
      });
    }

    return results;
  }

  MessageStatus _parseStatus(String? status) {
    switch (status) {
      case 'read':
        return MessageStatus.read;
      case 'viewed':
        return MessageStatus.viewed;
      case 'played':
        return MessageStatus.played;
      case 'sent':
        return MessageStatus.sent;
      default:
        return MessageStatus.sending;
    }
  }
}

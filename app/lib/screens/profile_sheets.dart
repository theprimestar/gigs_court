import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import '../services/credit_service.dart';
import '../services/chat_service.dart';
import '../widgets/loading_dots.dart';

// ─── CREDITS SHEET ──────────────────────────────

class CreditsSheet extends StatelessWidget {
  final int credits;
  const CreditsSheet({super.key, required this.credits});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Credits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text('$credits credits remaining', style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.6))),
          const SizedBox(height: 20),
          Text('Buy Credits', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 4),
          Text('Credits allow clients to rate and review your work.', style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5)), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ...CreditService.packages.map((pkg) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () { Navigator.pop(context); _startPayment(context, pkg['amount'] as int, pkg['credits'] as int); },
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1A1F71), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: const BorderSide(color: Color(0xFF1A1F71))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(pkg['label'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), Text(pkg['price'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))]),
              ),
            ),
          )),
        ],
      ),
    );
  }

  void _startPayment(BuildContext context, int amount, int credits) async {
    final service = CreditService();
    final reference = await service.initializePayment(amount, credits);
    if (reference == null) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to initialize payment')));
      return;
    }
    final charge = Charge()
      ..reference = reference
      ..amount = amount * 100
      ..currency = 'NGN'
      ..email = FirebaseAuth.instance.currentUser?.email ?? '';
    try {
      final response = await PaystackPlugin().checkout(context, charge: charge);
      if (response.status == 'success') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment received! Credits will be added shortly.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment cancelled')));
    }
  }
}

// ─── REVIEWS SHEET ──────────────────────────────

class ReviewsSheet extends StatefulWidget {
  final String userId;
  const ReviewsSheet({super.key, required this.userId});
  @override
  State<ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends State<ReviewsSheet> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadReviews(); }

  Future<void> _loadReviews() async {
    final snapshot = await _firestore.collection('reviews').where('provider_id', isEqualTo: widget.userId).orderBy('created_at', descending: true).limit(20).get();
    final reviews = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final clientDoc = await _firestore.collection('profiles').doc(data['client_id']).get();
      reviews.add({...data, 'client_name': clientDoc.data()?['fullName'] ?? 'Unknown'});
    }
    if (mounted) setState(() { _reviews = reviews; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading ? const Center(child: LoadingDots(color: Color(0xFF1A1F71))) : _reviews.isEmpty ? Center(child: Text('No reviews yet', style: TextStyle(color: textColor.withValues(alpha: 0.5)))) : ListView.separated(
              itemCount: _reviews.length, separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final review = _reviews[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [...List.generate(5, (i) => Icon(i < (review['rating'] as int?)! ? Icons.star : Icons.star_outline, size: 14, color: const Color(0xFFFFD700))), const SizedBox(width: 8), Text(review['client_name'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor))]),
                    if (review['text'] != null && (review['text'] as String).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(review['text'] as String, style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.7)))),
                    Text(_formatDate(review['created_at']), style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic ts) { if (ts == null) return ''; final date = (ts as Timestamp).toDate(); return '${date.day}/${date.month}/${date.year}'; }
}

// ─── GIG HISTORY SHEET ──────────────────────────

class GigHistorySheet extends StatefulWidget {
  final String userId;
  const GigHistorySheet({super.key, required this.userId});
  @override
  State<GigHistorySheet> createState() => _GigHistorySheetState();
}

class _GigHistorySheetState extends State<GigHistorySheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _providerGigs = [];
  List<Map<String, dynamic>> _clientGigs = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); _loadGigs(); }

  Future<void> _loadGigs() async {
    final allGigs = await _firestore.collection('gigs').where('provider_id', isEqualTo: widget.userId).orderBy('created_at', descending: true).limit(30).get();
    _providerGigs = allGigs.docs.map((d) => d.data()).toList();
    final clientGigsSnap = await _firestore.collection('gigs').where('client_id', isEqualTo: widget.userId).orderBy('created_at', descending: true).limit(30).get();
    _clientGigs = clientGigsSnap.docs.map((d) => d.data()).toList();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Gig History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 12),
          TabBar(controller: _tabController, labelColor: const Color(0xFF1A1F71), unselectedLabelColor: textColor.withValues(alpha: 0.5), indicatorColor: const Color(0xFF1A1F71), tabs: const [Tab(text: 'As Provider'), Tab(text: 'As Client')]),
          Expanded(
            child: _isLoading ? const Center(child: LoadingDots(color: Color(0xFF1A1F71))) : TabBarView(
              controller: _tabController,
              children: [_buildGigList(_providerGigs, textColor), _buildGigList(_clientGigs, textColor)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGigList(List<Map<String, dynamic>> gigs, Color textColor) {
    if (gigs.isEmpty) return Center(child: Text('No gigs', style: TextStyle(color: textColor.withValues(alpha: 0.5))));
    return ListView.separated(
      itemCount: gigs.length, separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final gig = gigs[index];
        final status = gig['status'] as String? ?? 'unknown';
        final service = gig['service'] as String? ?? '';
        final review = gig['review'] as Map<String, dynamic>?;
        return ListTile(
          title: Text(service, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
          subtitle: Text(status == 'completed' ? 'Completed' : status == 'canceled' ? 'Canceled' : 'Pending', style: TextStyle(fontSize: 12, color: status == 'completed' ? Colors.green : status == 'canceled' ? Colors.red : Colors.orange)),
          trailing: review != null ? Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star, size: 14, color: const Color(0xFFFFD700)), const SizedBox(width: 2), Text('${review['rating']}', style: const TextStyle(fontSize: 13))]) : null,
        );
      },
    );
  }
}

// ─── REGISTER GIG SHEET ─────────────────────────

class RegisterGigSheet extends StatefulWidget {
  const RegisterGigSheet({super.key});
  @override
  State<RegisterGigSheet> createState() => _RegisterGigSheetState();
}

class _RegisterGigSheetState extends State<RegisterGigSheet> {
  final _chatService = ChatService();
  List<Map<String, dynamic>> _recentChats = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadRecentChats(); }

  Future<void> _loadRecentChats() async {
    final chats = await _chatService.getRecentChats14Days();
    if (mounted) setState(() { _recentChats = chats; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Register a Gig', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text('People you chatted with recently', style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5))),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading ? const Center(child: LoadingDots(color: Color(0xFF1A1F71))) : _recentChats.isEmpty ? Center(child: Text('No recent chats', style: TextStyle(color: textColor.withValues(alpha: 0.5)))) : ListView.separated(
              itemCount: _recentChats.length, separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final chat = _recentChats[index];
                return ListTile(
                  leading: CircleAvatar(backgroundImage: chat['photoUrl'] != null && (chat['photoUrl'] as String).isNotEmpty ? NetworkImage(chat['photoUrl'] as String) : null, backgroundColor: const Color(0xFF1A1F71)),
                  title: Text(chat['name'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                  onTap: () { Navigator.pop(context); context.push('/chat/${chat['uid']}'); },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../services/credit_service.dart';
import '../services/chat_service.dart';
import '../services/imagekit_service.dart';
import '../services/firestore_profile_service.dart';
import '../widgets/loading_dots.dart';

// ─── EDIT PROFILE SHEET ──────────────────────────

class EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfileSheet({super.key, required this.profile});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile['fullName'] ?? '');
    _bioController = TextEditingController(text: widget.profile['bio'] ?? '');
    _phoneController = TextEditingController(text: widget.profile['phone'] ?? '');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('profiles').doc(uid).update({
      'fullName': _nameController.text.trim(),
      'bio': _bioController.text.trim(),
      'phone': _phoneController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Edit Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            style: TextStyle(fontSize: 14, color: textColor),
            decoration: InputDecoration(
              labelText: 'Full Name / Business Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLines: 2,
            style: TextStyle(fontSize: 14, color: textColor),
            decoration: InputDecoration(
              labelText: 'Bio',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(fontSize: 14, color: textColor),
            decoration: InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1F71),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _saving
                  ? const LoadingDots(color: Colors.white)
                  : const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

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
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
          Text('Credits allow clients to rate and review your work.',
              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5)), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ...CreditService.packages.map((pkg) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _startPayment(context, pkg['amount'] as int, pkg['credits'] as int);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1F71),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFF1A1F71)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(pkg['label'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(pkg['price'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _startPayment(BuildContext context, int amount, int credits) async {
    final service = CreditService();
    final reference = await service.initializePayment(amount, credits);

    if (reference == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize payment')),
        );
      }
      return;
    }

    final charge = Charge()
      ..reference = reference
      ..amount = (amount * 100).toString()
      ..currency = 'NGN'
      ..email = FirebaseAuth.instance.currentUser?.email ?? '';

    try {
      final response = await PaystackPlugin().checkout(context, charge: charge);

      if (response.status == 'success') {
        final verified = await service.verifyAndUpdateCredits(reference, credits);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(verified ? 'Credits added!' : 'Payment received. Refreshing...')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment cancelled')),
        );
      }
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
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('provider_id', isEqualTo: widget.userId)
        .orderBy('created_at', descending: true)
        .limit(20)
        .get();

    final reviews = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final clientDoc = await _firestore.collection('profiles').doc(data['client_id']).get();
      reviews.add({
        ...data,
        'client_name': clientDoc.data()?['fullName'] ?? 'Unknown',
      });
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
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingDots(color: Color(0xFF1A1F71)))
                : _reviews.isEmpty
                    ? Center(child: Text('No reviews yet', style: TextStyle(color: textColor.withValues(alpha: 0.5))))
                    : ListView.separated(
                        itemCount: _reviews.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final review = _reviews[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ...List.generate(5, (i) => Icon(
                                      i < (review['rating'] as int?)! ? Icons.star : Icons.star_outline,
                                      size: 14, color: const Color(0xFFFFD700),
                                    )),
                                    const SizedBox(width: 8),
                                    Text(review['client_name'] ?? '',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                                  ],
                                ),
                                if (review['text'] != null && (review['text'] as String).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(review['text'] as String,
                                        style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.7))),
                                  ),
                                Text(_formatDate(review['created_at']),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    final date = (ts as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year}';
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
  void initState() {
    super.initState();
    _loadRecentChats();
  }

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
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Register a Gig', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text('People you chatted with recently', style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5))),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingDots(color: Color(0xFF1A1F71)))
                : _recentChats.isEmpty
                    ? Center(child: Text('No recent chats', style: TextStyle(color: textColor.withValues(alpha: 0.5))))
                    : ListView.separated(
                        itemCount: _recentChats.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final chat = _recentChats[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: chat['photoUrl'] != null && (chat['photoUrl'] as String).isNotEmpty
                                  ? NetworkImage(chat['photoUrl'] as String)
                                  : null,
                              backgroundColor: const Color(0xFF1A1F71),
                            ),
                            title: Text(chat['name'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/chat/${chat['uid']}');
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── SETTINGS SHEET ─────────────────────────────

class SettingsSheet extends StatefulWidget {
  final Map<String, dynamic> profile;

  const SettingsSheet({super.key, required this.profile});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late bool _showPhone;

  @override
  void initState() {
    super.initState();
    _showPhone = widget.profile['showPhone'] != false;
  }

  Future<void> _togglePhone() async {
    setState(() => _showPhone = !_showPhone);
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('profiles').doc(uid).update({'showPhone': _showPhone});
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This will permanently remove your profile, photos, and all personal information. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await ImageKitService.deleteAllUserFiles(uid);
      final supabaseUrl = 'https://paohowngwtpffbdxxije.supabase.co';
      final supabaseKey = 'sb_publishable_sBrBW0vl1scg2ACsErDfag_IgIJj50Q';
      // Delete from Supabase
      await Supabase.instance.client.from('profiles').delete().eq('id', uid);
      // Delete from Firestore
      await _firestore.collection('profiles').doc(uid).delete();
      // Delete auth
      await _auth.currentUser?.delete();

      if (mounted) {
        context.go('/onboarding');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Privacy
                  _SectionTitle(title: 'Privacy', textColor: textColor),
                  SwitchListTile(
                    title: Text('Show phone number', style: TextStyle(fontSize: 14, color: textColor)),
                    subtitle: Text('Visible on your profile', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    value: _showPhone,
                    onChanged: (_) => _togglePhone(),
                    activeColor: const Color(0xFF1A1F71),
                  ),

                  // Account
                  _SectionTitle(title: 'Account', textColor: textColor),
                  ListTile(
                    title: Text('Log Out', style: TextStyle(fontSize: 14, color: textColor)),
                    leading: const Icon(Icons.logout, size: 20),
                    onTap: () async {
                      await _auth.signOut();
                      if (context.mounted) context.go('/onboarding');
                    },
                  ),
                  ListTile(
                    title: const Text('Delete Account', style: TextStyle(fontSize: 14, color: Colors.red)),
                    leading: const Icon(Icons.delete_forever, size: 20, color: Colors.red),
                    onTap: _deleteAccount,
                  ),

                  // About
                  _SectionTitle(title: 'About', textColor: textColor),
                  ListTile(
                    title: Text('App Version', style: TextStyle(fontSize: 14, color: textColor)),
                    trailing: Text('1.0.0', style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color textColor;

  const _SectionTitle({required this.title, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.5), letterSpacing: 0.5)),
    );
  }
}

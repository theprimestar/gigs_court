import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
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

    if (mounted) Navigator.pop(context, true);
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
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Edit Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          TextField(controller: _nameController, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(labelText: 'Full Name / Business Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: _bioController, maxLines: 2, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(labelText: 'Bio', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: _phoneController, keyboardType: TextInputType.phone, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F71), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: _saving ? const LoadingDots(color: Colors.white) : const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
    final charge = Charge()..reference = reference..amount = (amount * 100).toString()..currency = 'NGN'..email = FirebaseAuth.instance.currentUser?.email ?? '';
    try {
      final response = await PaystackPlugin().checkout(context, charge: charge);
      if (response.status == 'success') {
        final verified = await service.verifyAndUpdateCredits(reference, credits);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(verified ? 'Credits added!' : 'Payment received. Refreshing...')));
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
  void initState() {
    super.initState();
    _loadReviews();
  }

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
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGigs();
  }

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
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF1A1F71),
            unselectedLabelColor: textColor.withValues(alpha: 0.5),
            indicatorColor: const Color(0xFF1A1F71),
            tabs: const [Tab(text: 'As Provider'), Tab(text: 'As Client')],
          ),
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

// ─── WORK PHOTOS SECTION ────────────────────────

class WorkPhotosSection extends StatefulWidget {
  final String userId;
  const WorkPhotosSection({super.key, required this.userId});
  @override
  State<WorkPhotosSection> createState() => _WorkPhotosSectionState();
}

class _WorkPhotosSectionState extends State<WorkPhotosSection> {
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadPhotos(); }

  Future<void> _loadPhotos() async {
    final doc = await _firestore.collection('profiles').doc(widget.userId).get();
    final photos = List<Map<String, dynamic>>.from(doc.data()?['workPhotos'] ?? []);
    if (mounted) setState(() { _photos = photos; _isLoading = false; });
  }

  Future<void> _addPhotos() async {
    if (_photos.length >= 15) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 15 photos. Delete some to add more.')));
      return;
    }
    final files = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1080);
    if (files.isEmpty) return;

    for (final file in files) {
      if (_photos.length >= 15) break;
      final result = await ImageKitService.uploadPhoto(File(file.path), widget.userId, folder: '/work_photos/${widget.userId}');
      if (result != null) {
        _photos.add({'url': result.url, 'fileId': result.fileId});
      }
    }

    await _firestore.collection('profiles').doc(widget.userId).update({'workPhotos': _photos});
    if (mounted) setState(() {});
  }

  Future<void> _deletePhoto(int index) async {
    final photo = _photos[index];
    await ImageKitService.deletePhoto(photo['fileId'] as String);
    _photos.removeAt(index);
    await _firestore.collection('profiles').doc(widget.userId).update({'workPhotos': _photos});
    if (mounted) setState(() {});
  }

  void _viewPhoto(int index) {
    showDialog(
      context: context,
      builder: (ctx) => Stack(
        children: [
          GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(color: Colors.black.withValues(alpha: 0.95), child: Center(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(_photos[index]['url'] as String, fit: BoxFit.contain))))),
          Positioned(top: 40, left: 16, child: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white, size: 28), onPressed: () { _deletePhoto(index); Navigator.pop(ctx); })),
          Positioned(top: 40, right: 16, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(ctx))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: GestureDetector(
            onTap: _addPhotos,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF1A1F71).withValues(alpha: 0.5))), child: const Text('+ Add Photos', style: TextStyle(fontSize: 13, color: Color(0xFF1A1F71), fontWeight: FontWeight.w500))),
          ),
        ),
        if (_photos.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [const Icon(Icons.photo_library_outlined, size: 40, color: Color(0xFF6B7280)), const SizedBox(height: 12), Text('Add photos so clients can see your work.\nThis helps them trust you.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey))]),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
              itemCount: _photos.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _viewPhoto(index),
                onLongPress: () => _deletePhoto(index),
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_photos[index]['url'] as String, fit: BoxFit.cover)),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── SERVICES EDIT SHEET ────────────────────────

class ServicesEditSheet extends StatefulWidget {
  final String userId;
  final List<String> currentServices;
  const ServicesEditSheet({super.key, required this.userId, required this.currentServices});
  @override
  State<ServicesEditSheet> createState() => _ServicesEditSheetState();
}

class _ServicesEditSheetState extends State<ServicesEditSheet> {
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  late List<String> _selectedServices;
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _filteredServices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedServices = List.from(widget.currentServices);
    _loadServices();
  }

  Future<void> _loadServices() async {
    final supabase = Supabase.instance.client;
    final response = await supabase.from('services').select('name, category').eq('is_active', true).order('name');
    if (mounted) setState(() { _allServices = List<Map<String, dynamic>>.from(response); _filteredServices = List.from(_allServices); _isLoading = false; });
  }

  void _addService(String service) {
    if (!_selectedServices.contains(service)) setState(() => _selectedServices.add(service));
  }

  void _removeService(String service) => setState(() => _selectedServices.remove(service));

  Future<void> _save() async {
    await _firestore.collection('profiles').doc(widget.userId).update({'services': _selectedServices, 'updatedAt': FieldValue.serverTimestamp()});
    final supabase = Supabase.instance.client;
    await supabase.from('profiles').update({'services': _selectedServices}).eq('id', widget.userId);
    if (mounted) Navigator.pop(context, _selectedServices);
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Edit Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (q) => setState(() => _filteredServices = _allServices.where((s) => (s['name'] as String).toLowerCase().contains(q.toLowerCase())).toList()),
            decoration: InputDecoration(hintText: 'Search services...', prefixIcon: const Icon(Icons.search, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), isDense: true),
          ),
          const SizedBox(height: 8),
          if (_selectedServices.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: _selectedServices.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 13)), deleteIcon: const Icon(Icons.close, size: 16), onDeleted: () => _removeService(s), backgroundColor: const Color(0xFF1A1F71).withValues(alpha: 0.1), labelStyle: TextStyle(color: textColor))).toList()),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading ? const Center(child: LoadingDots(color: Color(0xFF1A1F71))) : ListView(
              children: _filteredServices.where((s) => !_selectedServices.contains(s['name'])).map((s) => ListTile(title: Text(s['name'] as String, style: TextStyle(fontSize: 14, color: textColor)), dense: true, onTap: () => _addService(s['name'] as String))).toList(),
            ),
          ),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F71), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
        ],
      ),
    );
  }
}

// ─── WORKSPACE EDIT SHEET ───────────────────────

class WorkspaceEditSheet extends StatefulWidget {
  final String userId;
  final String currentAddress;
  const WorkspaceEditSheet({super.key, required this.userId, required this.currentAddress});
  @override
  State<WorkspaceEditSheet> createState() => _WorkspaceEditSheetState();
}

class _WorkspaceEditSheetState extends State<WorkspaceEditSheet> {
  late TextEditingController _addressController;
  final _firestore = FirebaseFirestore.instance;
  bool _saving = false;

  @override
  void initState() { super.initState(); _addressController = TextEditingController(text: widget.currentAddress); }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _firestore.collection('profiles').doc(widget.userId).update({'workspaceAddress': _addressController.text.trim(), 'updatedAt': FieldValue.serverTimestamp()});
    final supabase = Supabase.instance.client;
    await supabase.from('profiles').update({'workspace_address': _addressController.text.trim()}).eq('id', widget.userId);
    if (mounted) Navigator.pop(context, _addressController.text.trim());
  }

  @override
  void dispose() { _addressController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Edit Workspace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 12),
          TextField(controller: _addressController, maxLines: 2, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(labelText: 'Workspace Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F71), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: _saving ? const LoadingDots(color: Colors.white) : const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
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
  void initState() { super.initState(); _showPhone = widget.profile['showPhone'] != false; }

  Future<void> _togglePhone() async {
    setState(() => _showPhone = !_showPhone);
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _firestore.collection('profiles').doc(uid).update({'showPhone': _showPhone});
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Delete Account'), content: const Text('This will permanently remove your profile, photos, and all personal information. This cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete My Account'))]));
    if (confirmed != true) return;
    try {
      final uid = _auth.currentUser?.uid; if (uid == null) return;
      await ImageKitService.deleteAllUserFiles(uid);
      await Supabase.instance.client.from('profiles').delete().eq('id', uid);
      await _firestore.collection('profiles').doc(uid).delete();
      await _auth.currentUser?.delete();
      if (mounted) context.go('/onboarding');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete account: $e')));
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
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
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
                  _SectionTitle(title: 'Privacy', textColor: textColor),
                  SwitchListTile(title: Text('Show phone number', style: TextStyle(fontSize: 14, color: textColor)), subtitle: Text('Visible on your profile', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))), value: _showPhone, onChanged: (_) => _togglePhone(), activeColor: const Color(0xFF1A1F71)),
                  _SectionTitle(title: 'Account', textColor: textColor),
                  ListTile(title: Text('Log Out', style: TextStyle(fontSize: 14, color: textColor)), leading: const Icon(Icons.logout, size: 20), onTap: () async { await _auth.signOut(); if (context.mounted) context.go('/onboarding'); }),
                  ListTile(title: const Text('Delete Account', style: TextStyle(fontSize: 14, color: Colors.red)), leading: const Icon(Icons.delete_forever, size: 20, color: Colors.red), onTap: _deleteAccount),
                  _SectionTitle(title: 'About', textColor: textColor),
                  ListTile(title: Text('App Version', style: TextStyle(fontSize: 14, color: textColor)), trailing: Text('1.0.0', style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5)))),
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
  final String title; final Color textColor;
  const _SectionTitle({required this.title, required this.textColor});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 4), child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.5), letterSpacing: 0.5)));
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/loading_dots.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  // Dashboard
  int _totalUsers = 0;
  int _activeToday = 0;
  int _totalGigs = 0;
  int _completedGigs = 0;
  int _pendingGigs = 0;
  int _cancelledGigs = 0;
  double _totalRevenue = 0;
  bool _isLoading = true;

  // Revenue period
  String _revenuePeriod = 'day';
  double _periodRevenue = 0;

  // User search
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  String? _giftUserId;
  String _giftAmount = '';

  // Services
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _serviceRequests = [];
  String _newServiceName = '';
  String _newServiceCategory = '';

  // Revenue
  List<Map<String, dynamic>> _purchases = [];

  // Top providers
  List<Map<String, dynamic>> _topProviders = [];

  // Issues
  List<Map<String, dynamic>> _issues = [];
  String? _resolvingIssueId;
  String _customResponse = '';

  static const _presetResponses = [
    {'label': 'Payment Verified', 'text': "We've verified your payment and your credits have been updated."},
    {'label': 'Account Fixed', 'text': "We've checked your account and everything looks good."},
    {'label': 'Bug Noted', 'text': "Thank you for reporting this. Our team is investigating."},
    {'label': 'Noted', 'text': "Thank you for reaching out. We've noted your feedback."},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadStats(),
      _loadServices(),
      _loadServiceRequests(),
      _loadPurchases(),
      _loadTopProviders(),
      _loadIssues(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    try {
      final profiles = await _firestore.collection('profiles').count().get();
      _totalUsers = profiles.count ?? 0;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final activeSnap = await _firestore.collection('profiles').where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart)).count().get();
      _activeToday = activeSnap.count ?? 0;

      final gigsSnap = await _firestore.collection('gigs').count().get();
      _totalGigs = gigsSnap.count ?? 0;

      final completedSnap = await _firestore.collection('gigs').where('status', isEqualTo: 'completed').count().get();
      _completedGigs = completedSnap.count ?? 0;

      final pendingSnap = await _firestore.collection('gigs').where('status', isEqualTo: 'pending').count().get();
      _pendingGigs = pendingSnap.count ?? 0;

      final cancelledSnap = await _firestore.collection('gigs').where('status', isEqualTo: 'canceled').count().get();
      _cancelledGigs = cancelledSnap.count ?? 0;

      final purchasesSnap = await _firestore.collection('credit_purchases').get();
      int total = 0;
      for (final doc in purchasesSnap.docs) {
        total += (doc.data()['amount_paid'] as num?)?.toInt() ?? 0;
      }
      _totalRevenue = total / 100.0;
    } catch (_) {}
  }

  Future<void> _loadServices() async {
    final data = await _supabase.from('services').select('*').order('category').order('name');
    _services = List<Map<String, dynamic>>.from(data);
  }

  Future<void> _loadServiceRequests() async {
    final data = await _supabase.from('service_suggestions').select('*').order('created_at', ascending: false).limit(50);
    _serviceRequests = List<Map<String, dynamic>>.from(data);
  }

  Future<void> _loadPurchases() async {
    final snap = await _firestore.collection('credit_purchases').orderBy('created_at', descending: true).limit(50).get();
    _purchases = snap.docs.map((d) => d.data()).toList();
  }

  Future<void> _loadTopProviders() async {
    final snap = await _firestore.collection('profiles').orderBy('gigCount', descending: true).limit(20).get();
    _topProviders = snap.docs.map((d) => d.data()).toList();
  }

  Future<void> _loadIssues() async {
    final snap = await _firestore.collection('reported_issues').orderBy('created_at', descending: true).limit(50).get();
    _issues = snap.docs.map((d) => { 'id': d.id, ...d.data() }).toList();
  }

  void _handleResolveIssue(String id, String? responseText) async {
    final update = <String, dynamic>{'status': 'resolved'};
    if (responseText != null && responseText.isNotEmpty) update['response_text'] = responseText;
    await _firestore.collection('reported_issues').doc(id).update(update);
    setState(() { _resolvingIssueId = null; _customResponse = ''; });
    _loadIssues();
  }

  void _handleSearchUsers() async {
    if (_searchController.text.trim().isEmpty) return;
    setState(() => _searching = true);
    final q = _searchController.text.trim().toLowerCase();
    final snap = await _firestore.collection('profiles').where('fullName', isGreaterThanOrEqualTo: q).where('fullName', isLessThanOrEqualTo: '$q\uf8ff').limit(20).get();
    _searchResults = snap.docs.map((d) => d.data()).toList();
    setState(() => _searching = false);
  }

  void _handleGiftCredits() async {
    if (_giftUserId == null || _giftAmount.isEmpty) return;
    final amount = int.tryParse(_giftAmount);
    if (amount == null || amount < 1) return;
    await _firestore.collection('profiles').doc(_giftUserId).update({'credits': FieldValue.increment(amount)});
    await _firestore.collection('credit_purchases').add({
      'user_id': _giftUserId,
      'credits_purchased': amount,
      'amount_paid': 0,
      'paystack_reference': 'admin_gift_${DateTime.now().millisecondsSinceEpoch}',
      'status': 'completed',
      'created_at': FieldValue.serverTimestamp(),
    });
    setState(() { _giftUserId = null; _giftAmount = ''; });
  }

  void _handleAddService() async {
    if (_newServiceName.isEmpty || _newServiceCategory.isEmpty) return;
    final slug = _newServiceName.toLowerCase().replaceAll(' ', '-');
    await _supabase.from('services').insert({
      'name': _newServiceName,
      'slug': slug,
      'category': _newServiceCategory,
      'is_active': true,
    });
    setState(() { _newServiceName = ''; _newServiceCategory = ''; });
    _loadServices();
  }

  void _handleToggleService(String id, bool current) async {
    await _supabase.from('services').update({'is_active': !current}).eq('id', id);
    _loadServices();
  }

  void _handleDeleteService(String id) async {
    await _supabase.from('services').delete().eq('id', id);
    _loadServices();
  }

  void _handleApproveRequest(String id) async {
    await _supabase.from('service_suggestions').update({'status': 'approved'}).eq('id', id);
    _loadServiceRequests();
  }

  void _handleRejectRequest(String id) async {
    await _supabase.from('service_suggestions').update({'status': 'rejected'}).eq('id', id);
    _loadServiceRequests();
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    final date = (ts is Timestamp) ? ts.toDate() : DateTime.parse(ts.toString());
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryColor = const Color(0xFF6B7280);

    if (_isLoading) return const Scaffold(body: Center(child: LoadingDots(color: Color(0xFF1A1F71))));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Admin Panel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                Text('GigsCourt', style: TextStyle(fontSize: 13, color: secondaryColor)),
              ]),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF1A1F71),
              unselectedLabelColor: textColor.withValues(alpha: 0.5),
              indicatorColor: const Color(0xFF1A1F71),
              tabs: const [
                Tab(text: 'Dashboard'),
                Tab(text: 'Users'),
                Tab(text: 'Services'),
                Tab(text: 'Revenue'),
                Tab(text: 'Providers'),
                Tab(text: 'Issues'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboard(textColor, secondaryColor),
                  _buildUsers(textColor, secondaryColor, isDark),
                  _buildServices(textColor, secondaryColor, isDark),
                  _buildRevenue(textColor, secondaryColor),
                  _buildProviders(textColor, secondaryColor),
                  _buildIssues(textColor, secondaryColor, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(Color textColor, Color secondary) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _StatCard(label: 'Total Users', value: '$_totalUsers', color: const Color(0xFF1A1F71)),
        _StatCard(label: 'Active Today', value: '$_activeToday', color: Colors.green),
        _StatCard(label: 'Total Gigs', value: '$_totalGigs', color: Colors.orange),
        _StatCard(label: 'Revenue', value: '₦${_totalRevenue.toStringAsFixed(0)}', color: const Color(0xFF1A1F71)),
      ]),
      const SizedBox(height: 20),
      Text('Gig Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
      const SizedBox(height: 8),
      Row(children: [
        _GigChip(label: '$_completedGigs Completed', color: Colors.green),
        const SizedBox(width: 8),
        _GigChip(label: '$_pendingGigs Pending', color: Colors.orange),
        const SizedBox(width: 8),
        _GigChip(label: '$_cancelledGigs Cancelled', color: Colors.red),
      ]),
    ]),
  );

  Widget _buildUsers(Color textColor, Color secondary, bool isDark) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: TextField(controller: _searchController, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(hintText: 'Search by name...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), isDense: true))),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _searching ? null : _handleSearchUsers, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F71), foregroundColor: Colors.white), child: _searching ? const LoadingDots(color: Colors.white) : const Text('Search')),
      ]),
      const SizedBox(height: 16),
      ..._searchResults.map((user) => ListTile(
        title: Text(user['fullName'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
        subtitle: Text('${user['gigCount'] ?? 0} gigs • ${user['credits'] ?? 0} credits', style: TextStyle(fontSize: 12, color: secondary)),
        trailing: TextButton(
          onPressed: () => setState(() => _giftUserId = _giftUserId == user['uid'] ? null : user['uid'] as String?),
          child: const Text('Gift'),
        ),
      )),
      if (_giftUserId != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            SizedBox(width: 100, child: TextField(decoration: const InputDecoration(hintText: 'Credits', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => _giftAmount = v)),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _handleGiftCredits, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('Send')),
          ]),
        ),
    ]),
  );

  Widget _buildServices(Color textColor, Color secondary, bool isDark) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Add Service', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Name', border: OutlineInputBorder()), onChanged: (v) => _newServiceName = v)),
        const SizedBox(width: 8),
        Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Category', border: OutlineInputBorder()), onChanged: (v) => _newServiceCategory = v)),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _handleAddService, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F71), foregroundColor: Colors.white), child: const Text('Add')),
      ]),
      const SizedBox(height: 20),
      Text('Service Catalog', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
      const SizedBox(height: 8),
      ..._services.map((s) => ListTile(
        title: Text(s['name'] ?? '', style: TextStyle(fontSize: 14, color: textColor)),
        subtitle: Text(s['category'] ?? '', style: TextStyle(fontSize: 12, color: secondary)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: Icon(s['is_active'] == true ? Icons.toggle_on : Icons.toggle_off, color: s['is_active'] == true ? Colors.green : Colors.grey), onPressed: () => _handleToggleService(s['id'], s['is_active'] == true)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _handleDeleteService(s['id'])),
        ]),
      )),
      const SizedBox(height: 20),
      Text('Service Requests', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
      ..._serviceRequests.map((sr) => ListTile(
        title: Text(sr['name'] ?? sr['requested_name'] ?? '', style: TextStyle(fontSize: 14, color: textColor)),
        subtitle: Text(sr['status'] ?? 'pending', style: TextStyle(fontSize: 12, color: secondary)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (sr['status'] == 'pending') ...[
            TextButton(onPressed: () => _handleApproveRequest(sr['id']), child: const Text('Approve')),
            TextButton(onPressed: () => _handleRejectRequest(sr['id']), child: const Text('Reject', style: TextStyle(color: Colors.red))),
          ],
        ]),
      )),
    ]),
  );

  Widget _buildRevenue(Color textColor, Color secondary) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Credit Purchases', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
      const SizedBox(height: 12),
      ..._purchases.map((p) => ListTile(
        title: Text('${p['credits_purchased']} credits', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
        subtitle: Text('₦${((p['amount_paid'] as num?)?.toInt() ?? 0) / 100}', style: TextStyle(fontSize: 12, color: secondary)),
        trailing: Text(_formatDate(p['created_at']), style: TextStyle(fontSize: 11, color: secondary)),
      )),
      if (_purchases.isEmpty) Center(child: Text('No purchases yet', style: TextStyle(color: secondary))),
    ]),
  );

  Widget _buildProviders(Color textColor, Color secondary) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Top Providers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
      const SizedBox(height: 12),
      ..._topProviders.asMap().entries.map((e) => ListTile(
        leading: Text('#${e.key + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1F71))),
        title: Text(e.value['fullName'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
        trailing: Text('${e.value['gigCount'] ?? 0} gigs', style: TextStyle(fontSize: 13, color: secondary)),
      )),
      if (_topProviders.isEmpty) Center(child: Text('No providers yet', style: TextStyle(color: secondary))),
    ]),
  );

  Widget _buildIssues(Color textColor, Color secondary, bool isDark) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Reported Issues', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
      const SizedBox(height: 12),
      ..._issues.map((issue) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(issue['issue_type'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: (issue['status'] == 'resolved' ? Colors.green : Colors.orange).withValues(alpha: 0.15)), child: Text(issue['status'] == 'resolved' ? 'Resolved' : 'Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: issue['status'] == 'resolved' ? Colors.green : Colors.orange))),
          ]),
          if (issue['description'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(issue['description'] as String, style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.7)))),
          if (issue['response_text'] != null && issue['status'] == 'resolved') Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: Colors.green, width: 3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Response:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)), const SizedBox(height: 4), Text(issue['response_text'] as String, style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.7)))])),
          if (issue['status'] == 'pending' && _resolvingIssueId != issue['id']) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => _resolvingIssueId = issue['id'] as String), child: const Text('Resolve'))),
          ],
          if (_resolvingIssueId == issue['id']) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _presetResponses.map((p) => InkWell(
              onTap: () => _handleResolveIssue(issue['id'] as String, p['text'] as String),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: secondary.withValues(alpha: 0.3))), child: Text(p['label'] as String, style: const TextStyle(fontSize: 11))),
            )).toList()),
            const SizedBox(height: 8),
            TextField(maxLines: 2, decoration: const InputDecoration(hintText: 'Or type custom response...', border: OutlineInputBorder()), onChanged: (v) => _customResponse = v),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => setState(() { _resolvingIssueId = null; _customResponse = ''; }), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: () => _handleResolveIssue(issue['id'] as String, _customResponse), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F71), foregroundColor: Colors.white), child: const Text('Submit')),
            ]),
          ],
        ]),
      )),
      if (_issues.isEmpty) Center(child: Text('No reported issues', style: TextStyle(color: secondary))),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7))),
    ]),
  );
}

class _GigChip extends StatelessWidget {
  final String label;
  final Color color;
  const _GigChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
  );
}

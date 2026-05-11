import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/credit_service.dart';
import '../services/imagekit_service.dart';
import '../widgets/loading_dots.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onProfileUpdated;

  const SettingsScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late bool _showPhone;
  late bool _pushEnabled;
  late bool _emailEnabled;

  @override
  void initState() {
    super.initState();
    _showPhone = widget.profile['showPhone'] != false;
    _pushEnabled = widget.profile['pushEnabled'] != false;
    _emailEnabled = widget.profile['emailEnabled'] == true;
  }

  Future<void> _togglePhone() async {
    setState(() => _showPhone = !_showPhone);
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _firestore.collection('profiles').doc(uid).update({'showPhone': _showPhone});
  }

  Future<void> _togglePush() async {
    setState(() => _pushEnabled = !_pushEnabled);
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _firestore.collection('profiles').doc(uid).update({'pushEnabled': _pushEnabled});
  }

  Future<void> _toggleEmail() async {
    setState(() => _emailEnabled = !_emailEnabled);
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _firestore.collection('profiles').doc(uid).update({'emailEnabled': _emailEnabled});
  }

  void _showCreditsSheet() {
    final credits = widget.profile['credits'] as int? ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreditsSheetContent(credits: credits),
    );
  }

  void _showCreditHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreditHistorySheet(),
    );
  }

  void _showContactSupport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactSupportSheet(),
    );
  }

  void _showTermsPrivacy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TermsPrivacySheet(),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This will permanently remove your profile, photos, and all personal information. You can sign up again with the same email, but you will not receive new free credits. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete My Account')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

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
    final credits = widget.profile['credits'] as int? ?? 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _SectionHeader(title: 'Privacy', textColor: textColor),
                  _ToggleRow(
                    title: 'Show phone number to clients',
                    subtitle: 'Your phone number will be visible on your profile',
                    value: _showPhone,
                    onChanged: (_) => _togglePhone(),
                    icon: Icons.phone_android,
                    textColor: textColor,
                  ),
                  _SectionHeader(title: 'Notifications', textColor: textColor),
                  _ToggleRow(
                    title: 'Push Notifications',
                    subtitle: 'Receive notifications about gigs and messages',
                    value: _pushEnabled,
                    onChanged: (_) => _togglePush(),
                    icon: Icons.notifications_outlined,
                    textColor: textColor,
                  ),
                  _ToggleRow(
                    title: 'Email Notifications',
                    subtitle: 'Receive email updates about your account',
                    value: _emailEnabled,
                    onChanged: (_) => _toggleEmail(),
                    icon: Icons.email_outlined,
                    textColor: textColor,
                  ),
                  _SectionHeader(title: 'Credits', textColor: textColor),
                  _TapRow(title: 'My Credits', subtitle: '$credits credits remaining', icon: Icons.monetization_on_outlined, onTap: _showCreditsSheet, textColor: textColor),
                  _TapRow(title: 'Buy Credits', subtitle: 'Credits allow clients to rate and review your work', icon: Icons.add_circle_outline, onTap: _showCreditsSheet, textColor: textColor),
                  _TapRow(title: 'Credit History', icon: Icons.history, onTap: _showCreditHistory, textColor: textColor),
                  _SectionHeader(title: 'Support', textColor: textColor),
                  _TapRow(title: 'Contact Support', subtitle: 'Get help or report an issue', icon: Icons.support_outlined, onTap: _showContactSupport, textColor: textColor),
                  _SectionHeader(title: 'Legal', textColor: textColor),
                  _TapRow(title: 'Terms & Privacy', icon: Icons.description_outlined, onTap: _showTermsPrivacy, textColor: textColor),
                  _SectionHeader(title: 'About', textColor: textColor),
                  _InfoRow(title: 'App Version', value: '1.0.0', textColor: textColor),
                  _SectionHeader(title: 'Account', textColor: textColor),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async { await _auth.signOut(); if (context.mounted) context.go('/onboarding'); },
                      style: OutlinedButton.styleFrom(foregroundColor: textColor, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), side: BorderSide(color: textColor.withValues(alpha: 0.3))),
                      child: const Text('Log Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _deleteAccount,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), side: const BorderSide(color: Colors.red)),
                      child: const Text('Delete Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color textColor;
  const _SectionHeader({required this.title, required this.textColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 4),
    child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.5), letterSpacing: 0.5)),
  );
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final Color textColor;
  const _ToggleRow({required this.title, required this.subtitle, required this.value, required this.onChanged, required this.icon, required this.textColor});

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: Icon(icon, size: 20, color: textColor.withValues(alpha: 0.6)),
    title: Text(title, style: TextStyle(fontSize: 14, color: textColor)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
    value: value, onChanged: onChanged, activeColor: const Color(0xFF1A1F71),
  );
}

class _TapRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color textColor;
  const _TapRow({required this.title, this.subtitle, required this.icon, required this.onTap, required this.textColor});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 20, color: textColor.withValues(alpha: 0.6)),
    title: Text(title, style: TextStyle(fontSize: 14, color: textColor)),
    subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))) : null,
    trailing: Icon(Icons.chevron_right, size: 20, color: textColor.withValues(alpha: 0.3)),
    onTap: onTap,
  );
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;
  final Color textColor;
  const _InfoRow({required this.title, required this.value, required this.textColor});

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title, style: TextStyle(fontSize: 14, color: textColor)),
    trailing: Text(value, style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5))),
  );
}

class _CreditsSheetContent extends StatelessWidget {
  final int credits;
  const _CreditsSheetContent({required this.credits});

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
          Text('Credits allow clients to rate and review your work. Credits are used to receive reviews and boost your reputation.', style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5)), textAlign: TextAlign.center),
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
      ..amount = (amount * 100).toString()
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

class _CreditHistorySheet extends StatefulWidget {
  @override
  State<_CreditHistorySheet> createState() => _CreditHistorySheetState();
}

class _CreditHistorySheetState extends State<_CreditHistorySheet> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _purchases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await _firestore.collection('credit_purchases').where('user_id', isEqualTo: uid).orderBy('created_at', descending: true).limit(30).get();
    if (mounted) setState(() { _purchases = snapshot.docs.map((d) => d.data()).toList(); _isLoading = false; });
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    final date = (ts as Timestamp).toDate();
    return '${date.day} ${_month(date.month)} ${date.year}';
  }

  String _month(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];

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
          Text('Credit History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading ? const Center(child: LoadingDots(color: Color(0xFF1A1F71))) : _purchases.isEmpty ? Center(child: Text('No purchases yet', style: TextStyle(color: textColor.withValues(alpha: 0.5)))) : ListView.separated(
              itemCount: _purchases.length, separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final p = _purchases[index];
                return ListTile(
                  title: Text('${p['credits_purchased']} credits', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                  subtitle: Text('₦${((p['amount_paid'] as num?)?.toInt() ?? 0) / 100}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  trailing: Text(_formatDate(p['created_at']), style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactSupportSheet extends StatefulWidget {
  @override
  State<_ContactSupportSheet> createState() => _ContactSupportSheetState();
}

class _ContactSupportSheetState extends State<_ContactSupportSheet> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  List<Map<String, dynamic>> _tickets = [];
  bool _submitting = false;
  bool _submitted = false;
  bool _loadingTickets = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await _firestore.collection('reported_issues').where('reported_by', isEqualTo: uid).orderBy('created_at', descending: true).get();
    if (mounted) setState(() { _tickets = snapshot.docs.map((d) => d.data()).toList(); _loadingTickets = false; });
  }

  Future<void> _submitTicket() async {
    if (_subjectController.text.trim().isEmpty || _messageController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('reported_issues').add({
      'reported_by': uid,
      'issue_type': _subjectController.text.trim(),
      'description': _messageController.text.trim(),
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
    _subjectController.clear();
    _messageController.clear();
    setState(() { _submitted = true; _submitting = false; });
    _loadTickets();
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    final date = (ts as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() { _subjectController.dispose(); _messageController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Contact Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text("We're here to help. Submit a ticket and we'll respond promptly.", style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5)), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (_submitted)
            Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Text('✓ Ticket submitted successfully. We\'ll review it shortly.', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w500))),
          TextField(controller: _subjectController, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(labelText: 'Subject', hintText: 'e.g. Payment issue, Bug report...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 8),
          TextField(controller: _messageController, maxLines: 4, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(labelText: 'Message', hintText: 'Describe your issue in detail...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _submitting ? null : _submitTicket, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F71), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: _submitting ? const LoadingDots(color: Colors.white) : const Text('Submit Ticket', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
          const SizedBox(height: 20),
          Text('My Tickets', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingTickets ? const Center(child: LoadingDots(color: Color(0xFF1A1F71))) : _tickets.isEmpty ? Center(child: Text('No tickets yet', style: TextStyle(color: textColor.withValues(alpha: 0.5)))) : ListView.separated(
              itemCount: _tickets.length, separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final t = _tickets[index];
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(t['issue_type'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: (t['status'] == 'resolved' ? Colors.green : Colors.orange).withValues(alpha: 0.15)), child: Text(t['status'] == 'resolved' ? 'Resolved' : 'Pending', style: TextStyle(fontSize: 11, color: t['status'] == 'resolved' ? Colors.green : Colors.orange, fontWeight: FontWeight.w600))),
                  ]),
                  if (t['description'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(t['description'] as String, style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.7)))),
                  Text(_formatDate(t['created_at']), style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  if (t['status'] == 'resolved' && t['response_text'] != null) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: Colors.green, width: 3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Response from GigsCourt:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)), const SizedBox(height: 4), Text(t['response_text'] as String, style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.7)))])),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsPrivacySheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Terms & Privacy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Terms of Service', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 4),
                Text('Last updated: 2026', style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.4))),
                const SizedBox(height: 12),
                _termSection('1. Acceptance of Terms', 'By using GigsCourt, you agree to these terms. If you do not agree, please do not use the app.', textColor),
                _termSection('2. Description of Service', 'GigsCourt is a location-based marketplace that connects service providers with clients in their area. Users can browse providers, chat, register completed gigs, and leave reviews.', textColor),
                _termSection('3. User Accounts', 'You are responsible for maintaining the confidentiality of your account. You may delete your account at any time from Settings. If you sign up again with the same email, you will start fresh with a new profile.', textColor),
                _termSection('4. Credits and Payments', 'Credits are used to register gigs and receive reviews. All credit purchases are final. Credits have no cash value and cannot be redeemed for money. GigsCourt reserves the right to modify credit pricing.', textColor),
                _termSection('5. User Conduct', 'Users agree not to misuse the platform, harass other users, post false reviews, manipulate the rating system, or use the app for any illegal purpose. Violation may result in account suspension.', textColor),
                _termSection('6. Limitation of Liability', 'GigsCourt is a platform for connecting users and is not a party to any agreement between providers and clients. We do not guarantee the quality of services or the accuracy of user profiles.', textColor),
                _termSection('7. Contact', 'For questions about these terms, contact us at theprimestarventures@gmail.com.', textColor),
                const SizedBox(height: 24),
                Text('Privacy Policy', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 4),
                Text('Last updated: 2026', style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.4))),
                const SizedBox(height: 12),
                _termSection('1. Information We Collect', 'We collect your name, phone number, email, profile picture, services, and workspace location. We also collect messages and gig history.', textColor),
                _termSection('2. How We Use Your Information', 'Your profile is visible to other users to facilitate connections. Your phone number is visible only if you choose to show it. Your email is never publicly displayed.', textColor),
                _termSection('3. Data Sharing', 'We do not sell your personal information. We share data only as necessary to provide the service.', textColor),
                _termSection('4. Data Retention', 'We retain your information as long as your account exists. If you delete your account, your profile is removed. Messages and gig history may be retained for the integrity of other users\' records.', textColor),
                _termSection('5. Contact', 'For privacy inquiries, contact us at theprimestarventures@gmail.com.', textColor),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _termSection(String title, String body, Color textColor) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
      const SizedBox(height: 2),
      Text(body, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6), height: 1.5)),
    ]),
  );
}

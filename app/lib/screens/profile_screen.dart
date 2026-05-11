import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../widgets/loading_dots.dart';
import 'profile_sheets.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scrollController = ScrollController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _showCollapsedHeader = false;

  bool get _isOwnProfile =>
      widget.userId == null || widget.userId == _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadProfile();
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 120;
    if (show != _showCollapsedHeader) {
      setState(() => _showCollapsedHeader = show);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final uid = widget.userId ?? _auth.currentUser?.uid;
      if (uid == null) return;

      final doc = await _firestore.collection('profiles').doc(uid).get();
      if (mounted && doc.exists) {
        setState(() {
          _profile = doc.data();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _refreshProfile() async {
    await _loadProfile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: LoadingDots(color: Color(0xFF1A1F71))),
      );
    }

    if (_profile == null) {
      return Scaffold(
        body: Center(
          child: Text('Profile not found', style: TextStyle(color: textColor)),
        ),
      );
    }

    final name = _profile!['fullName'] as String? ?? '';
    final photoUrl = _profile!['photoUrl'] as String? ?? '';
    final bio = _profile!['bio'] as String? ?? '';
    final services = List<String>.from(_profile!['services'] ?? []);
    final gigCount = _profile!['gigCount'] as int? ?? 0;
    final gigCount30Days = _profile!['gigCount30Days'] as int? ?? 0;
    final rating = (_profile!['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = _profile!['reviewCount'] as int? ?? 0;
    final credits = _profile!['credits'] as int? ?? 0;
    final createdAt = _profile!['createdAt'];
    final workspaceAddress = _profile!['workspaceAddress'] as String? ?? '';
    final phone = _profile!['phone'] as String? ?? '';
    final showPhone = _profile!['showPhone'] != false;
    final displayRating = reviewCount > 0 ? rating / reviewCount : 0.0;
    final uid = widget.userId ?? _auth.currentUser?.uid ?? '';

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileHeaderDelegate(
                name: name,
                photoUrl: photoUrl,
                isOwnProfile: _isOwnProfile,
                showCollapsed: _showCollapsedHeader,
                textColor: textColor,
                isDark: isDark,
                onMenuTap: () {
                  if (_profile != null) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => SettingsScreen(
                        profile: _profile!,
                        onProfileUpdated: _refreshProfile,
                      ),
                    );
                  }
                },
                onBackTap: () => context.pop(),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: photoUrl.isNotEmpty
                            ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                            : null,
                        color: const Color(0xFF1A1F71),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            icon: Icons.work_outline,
                            value: gigCount.toString(),
                            label: 'Gigs',
                            textColor: textColor,
                            onTap: _isOwnProfile
                                ? () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => GigHistorySheet(userId: uid),
                                    );
                                  }
                                : null,
                          ),
                          _StatItem(
                            icon: Icons.star_outline,
                            value: displayRating.toStringAsFixed(1),
                            label: 'Rating',
                            textColor: textColor,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => ReviewsSheet(userId: uid),
                              );
                            },
                          ),
                          if (_isOwnProfile)
                            _StatItem(
                              icon: Icons.monetization_on_outlined,
                              value: credits.toString(),
                              label: 'Credits',
                              textColor: textColor,
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => CreditsSheet(credits: credits),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                        Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(bio, style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.7))),
                    ],
                    const SizedBox(height: 8),
                    Text('$gigCount30Days gigs this month', style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.6))),
                    if (workspaceAddress.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _isOwnProfile
                            ? () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => WorkspaceEditSheet(
                                    userId: uid,
                                    currentAddress: workspaceAddress,
                                    onProfileUpdated: _refreshProfile,
                                  ),
                                );
                              }
                            : null,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(workspaceAddress, style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.6)))),
                          ],
                        ),
                      ),
                    ],
                    if (services.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _isOwnProfile
                            ? () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => ServicesEditSheet(
                                    userId: uid,
                                    currentServices: services,
                                    onProfileUpdated: _refreshProfile,
                                  ),
                                );
                              }
                            : null,
                        child: Text(services.join(', '), style: TextStyle(fontSize: 13, color: _isOwnProfile ? const Color(0xFF1A1F71) : textColor.withValues(alpha: 0.6))),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text('Joined ${_formatDate(createdAt)}', style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.45))),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isOwnProfile
                            ? () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => EditProfileSheet(
                                    profile: _profile!,
                                    onProfileUpdated: _refreshProfile,
                                  ),
                                );
                              }
                            : () => context.push('/chat/$uid'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1F71),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text(
                          _isOwnProfile ? 'Edit Profile' : 'Message',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isOwnProfile
                            ? () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => const RegisterGigSheet(),
                                );
                              }
                            : () {
                                if (showPhone && phone.isNotEmpty) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Contact'),
                                      content: Text(phone),
                                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Phone number is private')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isOwnProfile ? const Color(0xFF4A0E17) : const Color(0xFF1A1F71),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text(
                          _isOwnProfile ? 'Register Gig' : 'Contact Now',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isOwnProfile)
              SliverToBoxAdapter(
                child: WorkPhotosSection(userId: uid),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color textColor;
  final VoidCallback? onTap;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 3),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String name;
  final String photoUrl;
  final bool isOwnProfile;
  final bool showCollapsed;
  final Color textColor;
  final bool isDark;
  final VoidCallback onMenuTap;
  final VoidCallback onBackTap;

  _ProfileHeaderDelegate({
    required this.name,
    required this.photoUrl,
    required this.isOwnProfile,
    required this.showCollapsed,
    required this.textColor,
    required this.isDark,
    required this.onMenuTap,
    required this.onBackTap,
  });

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  bool shouldRebuild(covariant _ProfileHeaderDelegate oldDelegate) {
    return showCollapsed != oldDelegate.showCollapsed || name != oldDelegate.name;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (!isOwnProfile)
            IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: onBackTap,
            ),
          if (isOwnProfile) const Spacer(),
          if (showCollapsed) ...[
            if (photoUrl.isNotEmpty)
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover),
                ),
              ),
            Text(
              name,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Spacer(),
          if (isOwnProfile)
            IconButton(
              icon: Icon(Icons.menu, color: textColor),
              onPressed: onMenuTap,
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/provider_card_data.dart';
import '../services/home_service.dart';
import '../widgets/provider_card_trending.dart';
import '../widgets/provider_card_nearby.dart';
import '../widgets/loading_dots.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _homeService = HomeService();
  final _scrollController = ScrollController();
  final _firestore = FirebaseFirestore.instance;

  List<ProviderCardData> _trendingProviders = [];
  List<ProviderCardData> _nearbyProviders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _showScrollToTop = false;
  bool _usingFallbackLocation = false;

  double _viewerLat = 9.082;
  double _viewerLng = 8.6753;
  double? _lastFetchLat;
  double? _lastFetchLng;
  String? _lastCursorDistance;
  String? _lastCursorId;
  bool _hasMore = true;

  final List<StreamSubscription> _listeners = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCachedData();
  }

  void _showErrorDialog(String title, dynamic error, dynamic stackTrace) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(stackTrace.toString(), style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('home_cache');
      final lastLat = prefs.getDouble('home_lat');
      final lastLng = prefs.getDouble('home_lng');

      if (cachedJson != null && lastLat != null && lastLng != null) {
        final cachedData = jsonDecode(cachedJson) as Map<String, dynamic>;
        setState(() {
          _trendingProviders = _parseProvidersFromCache(cachedData['trending'] as List?);
          _nearbyProviders = _parseProvidersFromCache(cachedData['nearby'] as List?);
          _lastFetchLat = lastLat;
          _lastFetchLng = lastLng;
          _isLoading = false;
        });
        _attachListeners();
      }
    } catch (e, stack) {
      _showErrorDialog('Cache Error', e, stack);
    }

    _fetchFreshData();
  }

  List<ProviderCardData> _parseProvidersFromCache(List? list) {
    if (list == null) return [];
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return ProviderCardData(
        uid: map['uid'] ?? '',
        fullName: map['fullName'] ?? '',
        photoUrl: map['photoUrl'] ?? '',
        rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: map['reviewCount'] ?? 0,
        services: List<String>.from(map['services'] ?? []),
        distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
        gigCountThisMonth: map['gigCountThisMonth'] ?? 0,
        gigCountTotal: map['gigCountTotal'] ?? 0,
        dateJoined: map['dateJoined'] ?? '',
        workspaceAddress: map['workspaceAddress'] ?? '',
        isActive: map['isActive'] ?? false,
      );
    }).toList();
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchFreshData() async {
    try {
      final position = await _getCurrentPosition();

      double newLat;
      double newLng;

      if (position != null) {
        newLat = position.latitude;
        newLng = position.longitude;
        _usingFallbackLocation = false;
      } else {
        newLat = 9.082;
        newLng = 8.6753;
        _usingFallbackLocation = true;
      }

      if (_lastFetchLat != null && _lastFetchLng != null && _nearbyProviders.isNotEmpty && !_usingFallbackLocation) {
        final distance = _calculateDistance(_lastFetchLat!, _lastFetchLng!, newLat, newLng);
        if (distance < 100) {
          if (mounted) {
            _viewerLat = newLat;
            _viewerLng = newLng;
            setState(() => _isLoading = false);
            _attachListeners();
          }
          return;
        }
      }

      if (mounted) {
        _viewerLat = newLat;
        _viewerLng = newLng;
      }

      final trending = await _homeService.getTrendingProviders(
        viewerLat: _viewerLat,
        viewerLng: _viewerLng,
      );

      final nearby = await _homeService.getNearbyProviders(
        viewerLat: _viewerLat,
        viewerLng: _viewerLng,
      );

      if (mounted) {
        setState(() {
          _trendingProviders = trending;
          _nearbyProviders = nearby;
          _isLoading = false;
          _lastFetchLat = newLat;
          _lastFetchLng = newLng;
          if (nearby.isNotEmpty) {
            _lastCursorDistance = nearby.last.distanceMeters.toString();
            _lastCursorId = nearby.last.uid;
          }
        });

        _cacheData();
        _attachListeners();
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Home Error', e, stack);
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  Future<void> _cacheData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('home_cache', jsonEncode({
        'trending': _trendingProviders.map((p) => {
          'uid': p.uid, 'fullName': p.fullName, 'photoUrl': p.photoUrl,
          'rating': p.rating, 'reviewCount': p.reviewCount,
          'services': p.services, 'distanceMeters': p.distanceMeters,
          'gigCountThisMonth': p.gigCountThisMonth, 'gigCountTotal': p.gigCountTotal,
          'dateJoined': p.dateJoined, 'workspaceAddress': p.workspaceAddress,
          'isActive': p.isActive,
        }).toList(),
        'nearby': _nearbyProviders.map((p) => {
          'uid': p.uid, 'fullName': p.fullName, 'photoUrl': p.photoUrl,
          'rating': p.rating, 'reviewCount': p.reviewCount,
          'services': p.services, 'distanceMeters': p.distanceMeters,
          'gigCountThisMonth': p.gigCountThisMonth, 'gigCountTotal': p.gigCountTotal,
          'dateJoined': p.dateJoined, 'workspaceAddress': p.workspaceAddress,
          'isActive': p.isActive,
        }).toList(),
      }));
      await prefs.setDouble('home_lat', _viewerLat);
      await prefs.setDouble('home_lng', _viewerLng);
    } catch (e, stack) {
      _showErrorDialog('Cache Error', e, stack);
    }
  }

  void _attachListeners() {
    for (final sub in _listeners) {
      sub.cancel();
    }
    _listeners.clear();

    final allUids = <String>{};
    for (final p in _trendingProviders) allUids.add(p.uid);
    for (final p in _nearbyProviders) allUids.add(p.uid);

    if (allUids.isEmpty) return;

    final uidList = allUids.toList();
    final chunks = <List<String>>[];
    for (var i = 0; i < uidList.length; i += 30) {
      chunks.add(uidList.sublist(i, i + 30 > uidList.length ? uidList.length : i + 30));
    }

    for (final chunk in chunks) {
      final sub = _firestore
          .collection('profiles')
          .where(FieldPath.documentId, whereIn: chunk)
          .snapshots()
          .listen((snapshot) {
        _updateProvidersFromSnapshot(snapshot);
      }, onError: (e, stack) {
        _showErrorDialog('Listener Error', e, stack);
      });
      _listeners.add(sub);
    }
  }

  void _updateProvidersFromSnapshot(QuerySnapshot snapshot) {
    if (!mounted) return;

    final updatedData = <String, Map<String, dynamic>>{};
    for (final doc in snapshot.docs) {
      updatedData[doc.id] = doc.data() as Map<String, dynamic>;
    }

    if (updatedData.isEmpty) return;

    setState(() {
      _trendingProviders = _trendingProviders.map((p) {
        if (updatedData.containsKey(p.uid)) {
          return _mergeProviderData(p, updatedData[p.uid]!);
        }
        return p;
      }).toList();

      _nearbyProviders = _nearbyProviders.map((p) {
        if (updatedData.containsKey(p.uid)) {
          return _mergeProviderData(p, updatedData[p.uid]!);
        }
        return p;
      }).toList();
    });

    _cacheData();
  }

  ProviderCardData _mergeProviderData(ProviderCardData old, Map<String, dynamic> newData) {
    final gigCount7Days = (newData['gigCount7Days'] as int?) ?? 0;
    final gigCount30Days = (newData['gigCount30Days'] as int?) ?? 0;

    return ProviderCardData(
      uid: old.uid,
      fullName: newData['fullName'] as String? ?? old.fullName,
      photoUrl: newData['photoUrl'] as String? ?? old.photoUrl,
      rating: (newData['rating'] as num?)?.toDouble() ?? old.rating,
      reviewCount: (newData['reviewCount'] as int?) ?? old.reviewCount,
      services: List<String>.from(newData['services'] ?? old.services),
      distanceMeters: old.distanceMeters,
      gigCountThisMonth: gigCount30Days,
      gigCountTotal: (newData['gigCount'] as int?) ?? old.gigCountTotal,
      dateJoined: old.dateJoined,
      workspaceAddress: old.workspaceAddress,
      isActive: gigCount7Days >= 1 || gigCount30Days >= 3,
    );
  }

  Future<void> _loadMoreNearby() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final more = await _homeService.getNearbyProviders(
        viewerLat: _viewerLat,
        viewerLng: _viewerLng,
        cursorDistance: _lastCursorDistance,
        cursorId: _lastCursorId,
      );

      if (mounted) {
        setState(() {
          if (more.isEmpty) {
            _hasMore = false;
          } else {
            _nearbyProviders.addAll(more);
            _lastCursorDistance = more.last.distanceMeters.toString();
            _lastCursorId = more.last.uid;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        _showErrorDialog('Load More Error', e, stack);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels > 200 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (_scrollController.position.pixels <= 200 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMoreNearby();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  void _showProviderBottomSheet(ProviderCardData provider) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProviderBottomSheet(provider: provider),
    );
  }

  @override
  void dispose() {
    for (final sub in _listeners) {
      sub.cancel();
    }
    _listeners.clear();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: LoadingDots(color: Color(0xFF1A1F71)))
            : RefreshIndicator(
                onRefresh: _fetchFreshData,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Gigs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                                Text('Court', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                              ],
                            ),
                            IconButton(
                              icon: Icon(Icons.notifications_outlined, color: textColor),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_usingFallbackLocation)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_off, size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Location unavailable. Showing providers from default location.',
                                  style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                            const SizedBox(height: 4),
                            Text(
                              'Top performers this week near you',
                              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.55)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 108,
                        child: _trendingProviders.isEmpty
                            ? Center(
                                child: Text('No trending providers yet', style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5))),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                itemCount: _trendingProviders.length,
                                itemBuilder: (context, index) {
                                  return ProviderCardTrending(
                                    provider: _trendingProviders[index],
                                    onTap: () => _showProviderBottomSheet(_trendingProviders[index]),
                                  );
                                },
                              ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                        child: Text('Nearby Providers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      sliver: _nearbyProviders.isEmpty
                          ? SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Text('No providers nearby yet', style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5))),
                                ),
                              ),
                            )
                          : SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.72,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return ProviderCardNearby(
                                    provider: _nearbyProviders[index],
                                    onTap: () => _showProviderBottomSheet(_nearbyProviders[index]),
                                  );
                                },
                                childCount: _nearbyProviders.length,
                              ),
                            ),
                    ),
                    if (_isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: LoadingDots(color: Color(0xFF1A1F71))),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              onPressed: _scrollToTop,
              backgroundColor: const Color(0xFF1A1F71),
              child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
            )
          : null,
    );
  }
}

class _ProviderBottomSheet extends StatelessWidget {
  final ProviderCardData provider;

  const _ProviderBottomSheet({required this.provider});

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

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
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: provider.photoUrl.isNotEmpty
                  ? DecorationImage(image: NetworkImage(provider.photoUrl), fit: BoxFit.cover)
                  : null,
              color: const Color(0xFF1A1F71),
            ),
          ),
          const SizedBox(height: 12),
          Text(provider.fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(icon: Icons.star, color: const Color(0xFFFFD700), value: '${provider.rating.toStringAsFixed(1)} (${provider.reviewCount})', label: 'Rating', textColor: textColor),
              _StatItem(icon: Icons.work_outline, value: '${provider.gigCountThisMonth}', label: 'This month', textColor: textColor),
              _StatItem(icon: Icons.check_circle_outline, value: '${provider.gigCountTotal}', label: 'Total gigs', textColor: textColor),
            ],
          ),
          const SizedBox(height: 12),
          Text('Joined ${provider.dateJoined}', style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5))),
          const SizedBox(height: 12),
          Text(_formatDistance(provider.distanceMeters), style: TextStyle(fontSize: 14, color: textColor)),
          const SizedBox(height: 6),
          if (provider.workspaceAddress.isNotEmpty)
            Text(provider.workspaceAddress, style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.65)), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.message_outlined, size: 18),
                  label: const Text('Message', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1F71),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('View Profile', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1F71),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    side: const BorderSide(color: Color(0xFF1A1F71)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color textColor;
  final Color? color;

  const _StatItem({required this.icon, required this.value, required this.label, required this.textColor, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? textColor.withValues(alpha: 0.7)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
        Text(label, style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5))),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../models/provider_card_data.dart';
import '../services/search_service.dart';
import '../widgets/loading_dots.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchService = SearchService();
  final _searchController = TextEditingController();
  final _mapController = MapController();

  List<String> _popularServices = [];
  List<ProviderCardData> _providers = [];
  bool _isLoading = false;
  bool _isMapView = true;
  bool _hasSearched = false;
  String? _selectedService;
  double _radiusKm = 10;
  double _viewerLat = 9.082;
  double _viewerLng = 8.6753;

  double? _lastCursorDistance;
  String? _lastCursorId;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _loadPopularServices();
  }

  Future<void> _getLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _viewerLat = position.latitude;
          _viewerLng = position.longitude;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPopularServices() async {
    final services = await _searchService.getPopularServices();
    if (mounted) {
      setState(() => _popularServices = services);
    }
  }

  Future<void> _search(String service) async {
    setState(() {
      _selectedService = service;
      _isLoading = true;
      _hasSearched = true;
      _providers = [];
      _lastCursorDistance = null;
      _lastCursorId = null;
      _hasMore = true;
    });

    try {
      final result = await _searchService.searchProviders(
        viewerLat: _viewerLat,
        viewerLng: _viewerLng,
        serviceSlug: service.toLowerCase().replaceAll(' ', '-'),
        maxDistanceMeters: _radiusKm * 1000,
      );

      if (mounted) {
        setState(() {
          _providers = result.providers;
          _isLoading = false;
          _lastCursorDistance = result.nextCursorDistance;
          _lastCursorId = result.nextCursorId;
          _hasMore = result.nextCursorId != null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_viewerLat, _viewerLng),
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.gigscourt.gigscourt',
                ),
                if (_providers.isNotEmpty)
                  MarkerLayer(
                    markers: _providers.map((p) {
                      return Marker(
                        point: LatLng(_viewerLat, _viewerLng),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _showProviderBottomSheet(p),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: p.isActive ? Colors.green : Colors.white,
                                width: p.isActive ? 3 : 2,
                              ),
                              image: p.photoUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(p.photoUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: const Color(0xFF1A1F71),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),

            if (!_hasSearched)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Search for a service above or pick from popular services to find providers near you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            if (_hasSearched && _providers.isEmpty && !_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off, size: 48, color: Colors.white70),
                          const SizedBox(height: 16),
                          Text(
                            'No providers offer $_selectedService in this area.\nYou could be the first!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (_isLoading)
              const Positioned.fill(
                child: Center(child: LoadingDots(color: Color(0xFF1A1F71))),
              ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212).withValues(alpha: 0.95) : const Color(0xFFF5F5F5).withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search services...',
                        hintStyle: const TextStyle(fontSize: 14),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _hasSearched = false;
                                    _providers = [];
                                    _selectedService = null;
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _search(value.trim());
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text('1 km', style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6))),
                        Expanded(
                          child: Slider(
                            value: _radiusKm,
                            min: 1,
                            max: 20,
                            divisions: 19,
                            activeColor: const Color(0xFF1A1F71),
                            onChanged: (value) {
                              setState(() => _radiusKm = value);
                            },
                          ),
                        ),
                        Text('20 km', style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F71).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_radiusKm.toInt()} km',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A1F71)),
                          ),
                        ),
                      ],
                    ),

                    if (_popularServices.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _popularServices.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final service = _popularServices[index];
                            return GestureDetector(
                              onTap: () => _search(service),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1F71).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF1A1F71).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  service,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1A1F71), fontWeight: FontWeight.w500),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isMapView = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _isMapView ? const Color(0xFF1A1F71) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isMapView ? const Color(0xFF1A1F71) : textColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.map, size: 16, color: _isMapView ? Colors.white : textColor),
                                  const SizedBox(width: 6),
                                  Text('Map', style: TextStyle(fontSize: 13, color: _isMapView ? Colors.white : textColor)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isMapView = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isMapView ? const Color(0xFF1A1F71) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: !_isMapView ? const Color(0xFF1A1F71) : textColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.list, size: 16, color: !_isMapView ? Colors.white : textColor),
                                  const SizedBox(width: 6),
                                  Text('List', style: TextStyle(fontSize: 13, color: !_isMapView ? Colors.white : textColor)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (!_isMapView && _providers.isNotEmpty)
              Positioned(
                top: 280,
                left: 0,
                right: 0,
                bottom: 0,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  itemCount: _providers.length,
                  itemBuilder: (context, index) {
                    final provider = _providers[index];
                    return _SearchCard(
                      provider: provider,
                      onTap: () => _showProviderBottomSheet(provider),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final ProviderCardData provider;
  final VoidCallback onTap;

  const _SearchCard({required this.provider, required this.onTap});

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatServices() {
    final services = provider.services.take(2).join(', ');
    if (provider.services.length > 2) return '$services...';
    return services;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 85,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        decoration: BoxDecoration(
          image: provider.photoUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(provider.photoUrl),
                  fit: BoxFit.cover,
                )
              : null,
          color: const Color(0xFF1A1F71),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (provider.isActive)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          provider.fullName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 11, color: Color(0xFFFFD700)),
                      const SizedBox(width: 2),
                      Text(
                        '${provider.rating.toStringAsFixed(1)} (${provider.reviewCount})',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatServices(),
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDistance(provider.distanceMeters)} • ${provider.gigCountThisMonth} gigs this month',
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/profile/${provider.uid}');
                  },
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/geocoding_service.dart';
import '../widgets/loading_dots.dart';

class SetupStepWorkspace extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;

  const SetupStepWorkspace({
    super.key,
    required this.initialData,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<SetupStepWorkspace> createState() => _SetupStepWorkspaceState();
}

class _SetupStepWorkspaceState extends State<SetupStepWorkspace> {
  final _addressController = TextEditingController();
  late MapController _mapController;
  LatLng _center = const LatLng(9.082, 8.6753);
  bool _isLoading = true;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getInitialLocation();
  }

  Future<void> _getInitialLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _center = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
        _mapController.move(_center, 16);
        _resolveAddress();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resolveAddress() async {
    setState(() => _isResolving = true);
    final address = await GeocodingService.getAddress(
      _center.latitude,
      _center.longitude,
    );
    if (mounted) {
      _addressController.text = address;
      setState(() => _isResolving = false);
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMove) {
      setState(() {
        _center = event.camera.center;
      });
    }
    if (event is MapEventMoveEnd) {
      _resolveAddress();
    }
  }

  void _submit() {
    HapticFeedback.heavyImpact();

    widget.onNext({
      'workspaceLat': _center.latitude,
      'workspaceLng': _center.longitude,
      'workspaceAddress': _addressController.text.trim().isEmpty
          ? 'Custom location'
          : _addressController.text.trim(),
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _mapController.dispose();
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
            : Column(
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: LinearProgressIndicator(
                      value: 1.0,
                      backgroundColor: textColor.withValues(alpha: 0.1),
                      color: const Color(0xFF1A1F71),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set Your Workspace',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Set your workspace address — this helps clients find you nearby.',
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Drag the map to center the pin on your workspace.',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _center,
                            initialZoom: 16.0,
                            onMapEvent: _onMapEvent,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.gigscourt.gigscourt',
                            ),
                          ],
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 40,
                                color: const Color(0xFF1A1F71),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF1A1F71),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 18, color: Color(0xFF1A1F71)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _addressController,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Describe your workspace',
                                  hintStyle: const TextStyle(fontSize: 13),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  isDense: true,
                                  suffixIcon: _isResolving
                                      ? const Padding(
                                          padding: EdgeInsets.all(10),
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to edit — describe your workspace in your own words',
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 6, 28, 24),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: widget.onBack,
                          child: Text('Back',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: textColor.withValues(alpha: 0.6))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A1F71),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            child: const Text('Complete Setup',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ),
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

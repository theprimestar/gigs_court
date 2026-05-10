import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/services_service.dart';
import '../widgets/loading_dots.dart';

class SetupStepServices extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onNext;
  final VoidCallback onBack;

  const SetupStepServices({
    super.key,
    required this.initialData,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<SetupStepServices> createState() => _SetupStepServicesState();
}

class _SetupStepServicesState extends State<SetupStepServices> {
  final _searchController = TextEditingController();
  final _suggestController = TextEditingController();
  final _servicesService = ServicesService();
  final _firestore = FirebaseFirestore.instance;
  List<String> _selectedServices = [];
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _filteredServices = [];
  String? _error;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSuggesting = false;

  @override
  void initState() {
    super.initState();
    _selectedServices =
        List<String>.from(widget.initialData['services'] ?? []);
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final services = await _servicesService.fetchServices();
      if (mounted) {
        setState(() {
          _allServices = services;
          _filteredServices = List.from(_allServices);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredServices = List.from(_allServices);
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _servicesService.searchServices(query);
      if (mounted) {
        setState(() {
          _filteredServices = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      final filtered = _allServices
          .where((s) =>
              s['name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
      if (mounted) {
        setState(() {
          _filteredServices = filtered;
          _isSearching = false;
        });
      }
    }
  }

  void _addService(String service) {
    HapticFeedback.lightImpact();
    if (!_selectedServices.contains(service)) {
      setState(() {
        _selectedServices.add(service);
        _searchController.clear();
        _filteredServices = List.from(_allServices);
        _error = null;
      });
      _updateServiceCount(service, 1);
    }
  }

  void _removeService(String service) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedServices.remove(service);
    });
    _updateServiceCount(service, -1);
  }

  void _updateServiceCount(String service, int increment) {
    final slug = service.toLowerCase().replaceAll(' ', '-');
    _firestore.collection('metadata').doc('service_counts').set(
      {slug: FieldValue.increment(increment)},
      SetOptions(merge: true),
    );
  }

  Future<void> _suggestService() async {
    final text = _suggestController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSuggesting = true);

    try {
      await _servicesService.suggestService(text);
      _addService(text);
      _suggestController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service suggested! It will appear on your profile.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to suggest service. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSuggesting = false);
    }
  }

  void _submit() {
    HapticFeedback.mediumImpact();

    if (_selectedServices.isEmpty) {
      setState(() => _error = 'Select at least one service to be discoverable');
      return;
    }

    widget.onNext({'services': _selectedServices});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _suggestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: 0.66,
                backgroundColor: textColor.withValues(alpha: 0.1),
                color: const Color(0xFF1A1F71),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: _isLoading
                    ? const Center(child: LoadingDots(color: Color(0xFF1A1F71)))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Services You Offer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add the services you offer — this helps clients who need your services find you.',
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _searchController,
                              onChanged: _onSearch,
                              decoration: InputDecoration(
                                hintText: 'Search services...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: _isSearching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_selectedServices.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _selectedServices.map((service) {
                                  return Chip(
                                    label: Text(service, style: const TextStyle(fontSize: 13)),
                                    deleteIcon: const Icon(Icons.close, size: 16),
                                    onDeleted: () => _removeService(service),
                                    backgroundColor: const Color(0xFF1A1F71)
                                        .withValues(alpha: 0.1),
                                    labelStyle: TextStyle(color: textColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                          color: const Color(0xFF1A1F71)
                                              .withValues(alpha: 0.3)),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            if (_selectedServices.isNotEmpty)
                              const SizedBox(height: 12),
                            ...(_filteredServices
                                .where((s) => !_selectedServices
                                    .contains(s['name'] as String))
                                .map((service) => ListTile(
                                      title: Text(service['name'] as String, style: const TextStyle(fontSize: 14)),
                                      subtitle: Text(
                                        service['category'] as String,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: textColor.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      onTap: () =>
                                          _addService(service['name'] as String),
                                    ))),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ),
                            const SizedBox(height: 20),
                            Text(
                              "Can't find the service you offer? Type it here.",
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _suggestController,
                                    decoration: InputDecoration(
                                      hintText: 'Type a new service...',
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      isDense: true,
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _isSuggesting ? null : _suggestService,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A1F71),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isSuggesting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Suggest', style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select at least 1 service to be discoverable',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
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
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1F71),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Next',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _servicesService = ServicesService();
  List<String> _selectedServices = [];
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _filteredServices = [];
  String? _error;
  bool _isLoading = true;
  bool _isSearching = false;

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
    }
  }

  void _removeService(String service) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedServices.remove(service);
    });
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
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _searchController,
                              onChanged: _onSearch,
                              decoration: InputDecoration(
                                hintText: 'Search services...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _isSearching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_selectedServices.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedServices.map((service) {
                                  return Chip(
                                    label: Text(service),
                                    deleteIcon:
                                        const Icon(Icons.close, size: 18),
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
                                  );
                                }).toList(),
                              ),
                            if (_selectedServices.isNotEmpty)
                              const SizedBox(height: 16),
                            ...(_filteredServices
                                .where((s) => !_selectedServices
                                    .contains(s['name'] as String))
                                .map((service) => ListTile(
                                      title: Text(service['name'] as String),
                                      subtitle: Text(
                                        service['category'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textColor.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      dense: true,
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
                                      color: Colors.red, fontSize: 13),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              'Select at least 1 service to be discoverable',
                              style: TextStyle(
                                fontSize: 13,
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
                          style:
                              TextStyle(color: textColor.withValues(alpha: 0.6))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1F71),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Next',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600)),
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

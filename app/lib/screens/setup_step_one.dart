import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../widgets/loading_dots.dart';

class SetupStepOne extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onNext;

  const SetupStepOne({
    super.key,
    required this.initialData,
    required this.onNext,
  });

  @override
  State<SetupStepOne> createState() => _SetupStepOneState();
}

class _SetupStepOneState extends State<SetupStepOne> {
  final _nameController = TextEditingController(text: '');
  final _phoneController = TextEditingController(text: '');
  final _bioController = TextEditingController(text: '');
  final _formKey = GlobalKey<FormState>();
  String? _photoPath;
  String? _nameError;
  String? _photoError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialData['fullName'] ?? '';
    _phoneController.text = widget.initialData['phone'] ?? '';
    _bioController.text = widget.initialData['bio'] ?? '';
    _photoPath = widget.initialData['photoPath'];
  }

  void _pickPhoto() async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1A1A2E) : Colors.white;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              if (_photoPath != null && _photoPath!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outlined, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
            ],
          ),
        );
      },
    );

    if (result == 'remove') {
      setState(() {
        _photoPath = null;
        _photoError = null;
      });
    } else if (result == 'gallery') {
      // Will implement image picker
      setState(() {
        _photoPath = 'picked'; // Placeholder until image_picker package is added
        _photoError = null;
      });
    }
  }

  void _submit() {
    HapticFeedback.mediumImpact();

    setState(() {
      _nameError = null;
      _photoError = null;
    });

    final name = _nameController.text.trim();
    bool valid = true;

    if (name.isEmpty) {
      setState(() => _nameError = 'Full name or business name is required');
      valid = false;
    }
    if (_photoPath == null || _photoPath!.isEmpty) {
      setState(() => _photoError = 'Profile photo is required');
      valid = false;
    }
    if (!valid) return;

    widget.onNext({
      'fullName': name,
      'photoPath': _photoPath ?? '',
      'phone': _phoneController.text.trim(),
      'bio': _bioController.text.trim(),
    });
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
                value: 0.33,
                backgroundColor: textColor.withValues(alpha: 0.1),
                color: const Color(0xFF1A1F71),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Photo picker
                        GestureDetector(
                          onTap: _pickPhoto,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF1A1F71).withValues(alpha: 0.1),
                                ),
                                child: _photoPath != null && _photoPath!.isNotEmpty
                                    ? const Icon(Icons.person, size: 60, color: Color(0xFF1A1F71))
                                    : const Icon(Icons.add_a_photo_outlined, size: 40, color: Color(0xFF1A1F71)),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF4A0E17),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_photoError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _photoError!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        const SizedBox(height: 32),

                        // Name
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name / Business Name *',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            errorText: _nameError,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number (optional)',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bio
                        TextField(
                          controller: _bioController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Bio (optional)',
                            prefixIcon: const Icon(Icons.edit_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Complete your profile to be discoverable to clients near you',
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
              ),
              // Button
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1F71),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const LoadingDots()
                        : const Text('Next', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

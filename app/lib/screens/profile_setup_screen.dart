import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'setup_step_one.dart';
import 'setup_step_services.dart';
import 'setup_step_workspace.dart';
import '../services/imagekit_service.dart';
import '../services/firestore_service.dart';
import '../widgets/loading_dots.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _currentStep = 0;
  bool _isSaving = false;

  final _profileData = <String, dynamic>{
    'fullName': '',
    'photoPath': '',
    'phone': '',
    'bio': '',
    'services': <String>[],
    'workspaceLat': 0.0,
    'workspaceLng': 0.0,
    'workspaceAddress': '',
  };

  final _firestoreService = FirestoreService();
  final _supabase = Supabase.instance.client;

  void _onNext(Map<String, dynamic> data) {
    _profileData.addAll(data);
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _completeSetup();
    }
  }

  void _onBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _completeSetup() async {
    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      // 1. Upload photo to ImageKit
      String photoUrl = '';
      final photoPath = _profileData['photoPath'] as String;
      if (photoPath.isNotEmpty) {
        final uploadedUrl = await ImageKitService.uploadPhoto(
          File(photoPath),
          uid,
        );
        if (uploadedUrl != null) {
          photoUrl = uploadedUrl;
        }
      }

      // 2. Save to Firestore
      await _firestoreService.createProfile(
        fullName: _profileData['fullName'] as String,
        photoUrl: photoUrl,
        phone: _profileData['phone'] as String,
        bio: _profileData['bio'] as String,
        services: List<String>.from(_profileData['services'] as List),
      );

      // 3. Save to Supabase
      await _supabase.rpc('create_profile', params: {
        'p_id': uid,
        'p_full_name': _profileData['fullName'] as String,
        'p_workspace_lat': _profileData['workspaceLat'] as double,
        'p_workspace_lng': _profileData['workspaceLng'] as double,
        'p_workspace_address': _profileData['workspaceAddress'] as String,
        'p_services': List<String>.from(_profileData['services'] as List),
      });

      if (mounted) {
        context.go('/home');
      }
    } catch (e, stackTrace) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Setup Error'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    stackTrace.toString(),
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _currentStep,
              children: [
                SetupStepOne(
                  initialData: _profileData,
                  onNext: _onNext,
                ),
                SetupStepServices(
                  initialData: _profileData,
                  onNext: _onNext,
                  onBack: _onBack,
                ),
                SetupStepWorkspace(
                  initialData: _profileData,
                  onNext: _onNext,
                  onBack: _onBack,
                ),
              ],
            ),
            if (_isSaving)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LoadingDots(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Setting up your profile...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

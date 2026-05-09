import 'package:flutter/material.dart';
import 'setup_step_one.dart';
import 'setup_step_services.dart';
import 'setup_step_workspace.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _currentStep = 0;

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

  void _onNext(Map<String, dynamic> data) {
    _profileData.addAll(data);
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      // Complete — will save to Firestore + Supabase
      _completeSetup();
    }
  }

  void _onBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _completeSetup() async {
    // Will integrate Firebase + Supabase in the next iteration
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
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
      ),
    );
  }
}

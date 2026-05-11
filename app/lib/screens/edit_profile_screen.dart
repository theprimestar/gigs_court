import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/imagekit_service.dart';
import '../widgets/loading_dots.dart';

// ─── EDIT PROFILE SHEET ──────────────────────────

class EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onProfileUpdated;

  const EditProfileSheet({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile['fullName'] ?? '');
    _bioController = TextEditingController(text: widget.profile['bio'] ?? '');
    _phoneController = TextEditingController(text: widget.profile['phone'] ?? '');
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Take Photo'), onTap: () => Navigator.pop(ctx, 'camera')),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(ctx, 'gallery')),
          ]),
        );
      },
    );

    if (source == null) return;
    final file = await _picker.pickImage(source: source == 'camera' ? ImageSource.camera : ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (file == null) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Delete old photo if exists
    final oldFileId = widget.profile['photoFileId'] as String?;
    if (oldFileId != null && oldFileId.isNotEmpty) {
      await ImageKitService.deletePhoto(oldFileId);
    }

    final result = await ImageKitService.uploadPhoto(File(file.path), uid);
    if (result != null) {
      await _firestore.collection('profiles').doc(uid).update({
        'photoUrl': result.url,
        'photoFileId': result.fileId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      widget.onProfileUpdated();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('profiles').doc(uid).update({
      'fullName': _nameController.text.trim(),
      'bio': _bioController.text.trim(),
      'phone': _phoneController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    widget.onProfileUpdated();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Edit Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          // Photo
          GestureDetector(
            onTap: _changePhoto,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: (widget.profile['photoUrl'] as String?).isNotEmpty == true
                    ? DecorationImage(image: NetworkImage(widget.profile['photoUrl'] as String), fit: BoxFit.cover)
                    : null,
                color: const Color(0xFF1A1F71),
              ),
              child: const Align(alignment: Alignment.bottomRight, child: Icon(Icons.camera_alt, size: 18, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _nameController, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(labelText: 'Full Name / Business Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: _bioController, maxLines: 2, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(labelText: 'Bio', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: _phoneController, keyboardType: TextInputType.phone, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F71), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: _saving ? const LoadingDots(color: Colors.white) : const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SERVICES EDIT SHEET ────────────────────────

class ServicesEditSheet extends StatefulWidget {
  final String userId;
  final List<String> currentServices;
  final VoidCallback onProfileUpdated;

  const ServicesEditSheet({
    super.key,
    required this.userId,
    required this.currentServices,
    required this.onProfileUpdated,
  });

  @override
  State<ServicesEditSheet> createState() => _ServicesEditSheetState();
}

class _ServicesEditSheetState extends State<ServicesEditSheet> {
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  late List<String> _selectedServices;
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _filteredServices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedServices = List.from(widget.currentServices);
    _loadServices();
  }

  Future<void> _loadServices() async {
    final supabase = Supabase.instance.client;
    final response = await supabase.from('services').select('name, category').eq('is_active', true).order('name');
    if (mounted) setState(() { _allServices = List<Map<String, dynamic>>.from(response); _filteredServices = List.from(_allServices); _isLoading = false; });
  }

  void _addService(String service) {
    if (!_selectedServices.contains(service)) setState(() => _selectedServices.add(service));
  }

  void _removeService(String service) => setState(() => _selectedServices.remove(service));

  Future<void> _save() async {
    await _firestore.collection('profiles').doc(widget.userId).update({'services': _selectedServices, 'updatedAt': FieldValue.serverTimestamp()});
    final supabase = Supabase.instance.client;
    await supabase.from('profiles').update({'services': _selectedServices}).eq('id', widget.userId);
    widget.onProfileUpdated();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Edit Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (q) => setState(() => _filteredServices = _allServices.where((s) => (s['name'] as String).toLowerCase().contains(q.toLowerCase())).toList()),
            decoration: InputDecoration(hintText: 'Search services...', prefixIcon: const Icon(Icons.search, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), isDense: true),
          ),
          const SizedBox(height: 8),
          if (_selectedServices.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: _selectedServices.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 13)), deleteIcon: const Icon(Icons.close, size: 16), onDeleted: () => _removeService(s), backgroundColor: const Color(0xFF1A1F71).withValues(alpha: 0.1), labelStyle: TextStyle(color: textColor))).toList()),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading ? const Center(child: LoadingDots(color: Color(0xFF1A1F71))) : ListView(
              children: _filteredServices.where((s) => !_selectedServices.contains(s['name'])).map((s) => ListTile(title: Text(s['name'] as String, style: TextStyle(fontSize: 14, color: textColor)), dense: true, onTap: () => _addService(s['name'] as String))).toList(),
            ),
          ),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F71), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
        ],
      ),
    );
  }
}

// ─── WORKSPACE EDIT SHEET ───────────────────────

class WorkspaceEditSheet extends StatefulWidget {
  final String userId;
  final String currentAddress;
  final VoidCallback onProfileUpdated;

  const WorkspaceEditSheet({
    super.key,
    required this.userId,
    required this.currentAddress,
    required this.onProfileUpdated,
  });

  @override
  State<WorkspaceEditSheet> createState() => _WorkspaceEditSheetState();
}

class _WorkspaceEditSheetState extends State<WorkspaceEditSheet> {
  late TextEditingController _addressController;
  final _firestore = FirebaseFirestore.instance;
  bool _saving = false;

  @override
  void initState() { super.initState(); _addressController = TextEditingController(text: widget.currentAddress); }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _firestore.collection('profiles').doc(widget.userId).update({'workspaceAddress': _addressController.text.trim(), 'updatedAt': FieldValue.serverTimestamp()});
    final supabase = Supabase.instance.client;
    await supabase.from('profiles').update({'workspace_address': _addressController.text.trim()}).eq('id', widget.userId);
    widget.onProfileUpdated();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() { _addressController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Edit Workspace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 12),
          TextField(controller: _addressController, maxLines: 2, style: TextStyle(fontSize: 14, color: textColor), decoration: InputDecoration(labelText: 'Workspace Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1F71), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: _saving ? const LoadingDots(color: Colors.white) : const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
        ],
      ),
    );
  }
}

// ─── WORK PHOTOS SECTION ────────────────────────

class WorkPhotosSection extends StatefulWidget {
  final String userId;
  const WorkPhotosSection({super.key, required this.userId});
  @override
  State<WorkPhotosSection> createState() => _WorkPhotosSectionState();
}

class _WorkPhotosSectionState extends State<WorkPhotosSection> {
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _photos = [];

  @override
  void initState() { super.initState(); _loadPhotos(); }

  Future<void> _loadPhotos() async {
    final doc = await _firestore.collection('profiles').doc(widget.userId).get();
    final photos = List<Map<String, dynamic>>.from(doc.data()?['workPhotos'] ?? []);
    if (mounted) setState(() => _photos = photos);
  }

  Future<void> _addPhotos() async {
    if (_photos.length >= 15) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 15 photos. Delete some to add more.')));
      return;
    }
    final files = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1080);
    if (files.isEmpty) return;

    for (final file in files) {
      if (_photos.length >= 15) break;
      final result = await ImageKitService.uploadPhoto(File(file.path), widget.userId, folder: '/work_photos/${widget.userId}');
      if (result != null) _photos.add({'url': result.url, 'fileId': result.fileId});
    }

    await _firestore.collection('profiles').doc(widget.userId).update({'workPhotos': _photos});
    if (mounted) setState(() {});
  }

  Future<void> _deletePhoto(int index) async {
    final photo = _photos[index];
    await ImageKitService.deletePhoto(photo['fileId'] as String);
    _photos.removeAt(index);
    await _firestore.collection('profiles').doc(widget.userId).update({'workPhotos': _photos});
    if (mounted) setState(() {});
  }

  void _viewPhoto(int index) {
    showDialog(
      context: context,
      builder: (ctx) => Stack(
        children: [
          GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(color: Colors.black.withValues(alpha: 0.95), child: Center(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(_photos[index]['url'] as String, fit: BoxFit.contain))))),
          Positioned(top: 40, left: 16, child: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white, size: 28), onPressed: () { _deletePhoto(index); Navigator.pop(ctx); })),
          Positioned(top: 40, right: 16, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(ctx))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: GestureDetector(
            onTap: _addPhotos,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF1A1F71).withValues(alpha: 0.5))), child: const Text('+ Add Photos', style: TextStyle(fontSize: 13, color: Color(0xFF1A1F71), fontWeight: FontWeight.w500))),
          ),
        ),
        if (_photos.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [const Icon(Icons.photo_library_outlined, size: 40, color: Color(0xFF6B7280)), const SizedBox(height: 12), Text('Add photos so clients can see your work.\nThis helps them trust you.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey))]),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
              itemCount: _photos.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _viewPhoto(index),
                onLongPress: () => _deletePhoto(index),
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_photos[index]['url'] as String, fit: BoxFit.cover)),
              ),
            ),
          ),
      ],
    );
  }
}

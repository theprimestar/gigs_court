import 'package:supabase_flutter/supabase_flutter.dart';

class ServicesService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchServices() async {
    final response = await _supabase
        .from('services')
        .select('name, category')
        .eq('is_active', true)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> searchServices(String query) async {
    final response = await _supabase
        .from('services')
        .select('name, category')
        .eq('is_active', true)
        .ilike('name', '%$query%')
        .order('name', ascending: true)
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> suggestService(String name) async {
    await _supabase.from('service_suggestions').insert({
      'name': name,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}

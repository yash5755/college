import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend_config.dart';

Future<void> initializeSupabase() async {
  await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
}

SupabaseClient get supabase => Supabase.instance.client;



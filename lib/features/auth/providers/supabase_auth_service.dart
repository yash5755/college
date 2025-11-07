import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';

class SupabaseAuthRepository {
  final SupabaseClient _client;
  SupabaseAuthRepository(this._client);

  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String email, String password, {Map<String, dynamic>? data}) {
    return _client.auth.signUp(email: email, password: password, data: data);
  }

  Future<void> signOut() => _client.auth.signOut();
}

final supabaseAuthRepositoryProvider = Provider<SupabaseAuthRepository>((ref) {
  return SupabaseAuthRepository(supabase);
});



import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';

abstract class IAuthFacade {
  Future<void> signIn(String email, String password);
  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    String? displayName,
    String? department,
    String? usn,
    int? year,
    String? profilePic,
  });
  Future<void> signOut();
}

class SupabaseAuthFacade implements IAuthFacade {
  SupabaseAuthFacade(this._client);
  final SupabaseClient _client;

  @override
  Future<void> signIn(String email, String password) async {
    _ensureDomain(email);
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      final errorMsg = e.message.toLowerCase();
      
      // Check if it's an email confirmation issue
      if (errorMsg.contains('email not confirmed') ||
          errorMsg.contains('email_not_confirmed') ||
          errorMsg.contains('confirmation')) {
        throw AuthException(
          'Please check your email and confirm your account before signing in.\n'
          'If you just signed up, check your inbox (including spam) for the confirmation email.'
        );
      }
      
      // If it's invalid credentials, provide helpful message
      // Note: Supabase returns "invalid_credentials" for both wrong password AND unconfirmed email
      if (errorMsg.contains('invalid_credentials') || errorMsg.contains('invalid login')) {
        throw AuthException(
          'Invalid email or password.\n'
          'If you just signed up, please check your email and confirm your account first.\n'
          'Otherwise, please verify your email and password are correct.'
        );
      }
      
      rethrow;
    } catch (e) {
      // Re-throw AuthException as-is, wrap others
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException('Login failed: ${e.toString()}');
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    String? displayName,
    String? department,
    String? usn,
    int? year,
    String? profilePic,
  }) async {
    _ensureDomain(email);
    
    // Prepare metadata to pass to signUp
    // This will be available in the trigger via new.raw_user_meta_data
    final userMetadata = <String, dynamic>{
      'role': role,
      if (displayName != null && displayName.isNotEmpty) 'display_name': displayName,
      if (department != null && department.isNotEmpty) 'department': department,
      if (year != null) 'year': year,
      if (profilePic != null && profilePic.isNotEmpty) 'profile_pic': profilePic,
      if (usn != null && usn.isNotEmpty) 'usn': usn,
    };
    
    final resp = await _client.auth.signUp(
      email: email,
      password: password,
      data: userMetadata,
    );
    final user = resp.user;
    if (user == null) {
      throw AuthException('Sign up failed - no user returned');
    }
    
    // Check if email confirmation is required
    // If session is null, user needs to confirm email first
    if (resp.session == null) {
      // Email confirmation is required - trigger will create profile with metadata
      // User will need to confirm email and then log in
      // The profile will be created by the trigger with the metadata we passed
      return; // Exit early - user needs to confirm email
    }
    
    // User is authenticated (email confirmation disabled or already confirmed)
    // Wait a moment for the trigger to create the profile
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Prepare profile data
    final profileData = <String, dynamic>{
      'id': user.id,
      'email': email,
      'role': role,
      if (displayName != null && displayName.isNotEmpty) 'name': displayName,
      if (department != null && department.isNotEmpty) 'department': department,
      if (year != null) 'year': year,
      if (profilePic != null && profilePic.isNotEmpty) 'profile_pic': profilePic,
      if (usn != null && usn.isNotEmpty) 'usn': usn,
    };
    
    // Try to update first (in case trigger created the profile)
    try {
      final updateResult = await _client
          .from('profiles')
          .update(profileData)
          .eq('id', user.id)
          .select()
          .maybeSingle();
      
      // If update didn't affect any rows, profile doesn't exist - insert it
      if (updateResult == null) {
        await _client.from('profiles').insert(profileData);
      }
    } catch (e) {
      // If update fails, try insert
      try {
        await _client.from('profiles').insert(profileData);
      } catch (insertError) {
        // Both failed - throw detailed error
        throw AuthException(
          'Failed to create profile: ${insertError.toString()}\n'
          'Original error: ${e.toString()}'
        );
      }
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  void _ensureDomain(String email) {
    final domain = email.split('@').last.toLowerCase();
    if (domain != 'vvce.ac.in') {
      throw AuthException('Use your @vvce.ac.in email');
    }
  }
}

final authFacadeProvider = Provider<IAuthFacade>((ref) {
  return SupabaseAuthFacade(supabase);
});

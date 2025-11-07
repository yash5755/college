import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../user/models/user_model.dart';
import '../../../core/backend_config.dart';
import '../../../core/supabase_client.dart';
import 'auth_facade.dart';

final supabaseAuthStateProvider = StreamProvider((ref) {
  if (!kUseSupabase) return const Stream.empty();
  return supabase.auth.onAuthStateChange.map((e) => e.session?.user);
});

final authStateChangesProvider = StreamProvider.autoDispose<dynamic>((ref) {
  return ref.watch(supabaseAuthStateProvider.stream);
});

final currentUserDocProvider = StreamProvider<AppUser?>((ref) {
  // Rebuild this provider whenever auth state changes so we re-subscribe
  // to the correct user's profile stream immediately after sign-in/sign-out.
  final auth = ref.watch(supabaseAuthStateProvider);
  final userId = auth.asData?.value?.id;
  if (userId == null) return const Stream<AppUser?>.empty();
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((rows) {
    if (rows.isEmpty) return null;
    final data = rows.first;
    return AppUser(
      uid: data['id'] as String,
      email: (data['email'] as String?) ?? '',
      role: (data['role'] as String?) ?? AppRoles.student,
      displayName: data['name'] as String?,
      department: data['department'] as String?,
      photoUrl: data['profile_pic'] as String?,
      usn: data['usn'] as String?,
      phone: data['phone'] as String?,
      approved: (data['approved'] as bool?) ?? true,
    );
  });
});

// Fast one-time fetch to avoid waiting for realtime stream handshake on first login
final currentUserDocOnceProvider = FutureProvider<AppUser?>((ref) async {
  final auth = ref.watch(supabaseAuthStateProvider);
  final userId = auth.asData?.value?.id;
  if (userId == null) return null;
  final data = await supabase
      .from('profiles')
      .select()
      .eq('id', userId)
      .maybeSingle();
  if (data == null) return null;
  return AppUser(
    uid: data['id'] as String,
    email: (data['email'] as String?) ?? '',
    role: (data['role'] as String?) ?? AppRoles.student,
    displayName: data['name'] as String?,
    department: data['department'] as String?,
    photoUrl: data['profile_pic'] as String?,
    usn: data['usn'] as String?,
    phone: data['phone'] as String?,
    approved: (data['approved'] as bool?) ?? true,
  );
});

final authRepositoryProvider = Provider<IAuthFacade>((ref) {
  return SupabaseAuthFacade(supabase);
});


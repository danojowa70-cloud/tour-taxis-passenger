import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

// Current user provider
final currentUserProvider = StateProvider<User?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.currentUser;
});

// User authentication stream provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange;
});

// User profile provider
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  
  if (user == null) return null;
  
  try {
    // First try to get from passengers table
    final passenger = await supabase
        .from('passengers')
        .select()
        .eq('auth_user_id', user.id)
        .maybeSingle();
    
    if (passenger != null) {
      return {
        'id': passenger['id'],
        'name': passenger['name'],
        'email': passenger['email'] ?? user.email,
        'phone': passenger['phone'],
        'avatar_url': passenger['avatar_url'],
        'created_at': passenger['created_at'],
      };
    }
    
    // Fallback to user metadata
    return {
      'id': user.id,
      'name': user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? 'User',
      'email': user.email,
      'phone': user.phone,
      'avatar_url': user.userMetadata?['avatar_url'],
      'created_at': user.createdAt,
    };
  } catch (e) {
    // Return basic info from auth
    return {
      'id': user.id,
      'name': user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? 'User',
      'email': user.email,
      'phone': user.phone,
      'avatar_url': user.userMetadata?['avatar_url'],
      'created_at': user.createdAt,
    };
  }
});

// Greeting provider based on time of day
final greetingProvider = Provider<String>((ref) {
  final hour = DateTime.now().hour;
  
  if (hour < 12) {
    return 'Good morning';
  } else if (hour < 17) {
    return 'Good afternoon';
  } else {
    return 'Good evening';
  }
});

// User display name provider
final userDisplayNameProvider = Provider<String>((ref) {
  final userProfile = ref.watch(userProfileProvider);
  
  return userProfile.when(
    data: (profile) => profile?['name'] ?? 'User',
    loading: () => 'Loading...',
    error: (_, __) => 'User',
  );
});

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AuthService(supabase);
});

class AuthService {
  final SupabaseClient _client;
  
  AuthService(this._client);
  
  User? get currentUser => _client.auth.currentUser;
  
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? avatarUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    
    // Update auth metadata
    final updates = <String, dynamic>{};
    if (name != null) updates['full_name'] = name;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    
    if (updates.isNotEmpty) {
      await _client.auth.updateUser(
        UserAttributes(data: updates),
      );
    }
    
    // Update passengers table
    try {
      await _client.from('passengers').upsert({
        'auth_user_id': user.id,
        'email': user.email,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }, onConflict: 'auth_user_id');
    } catch (e) {
      // Silently handle error - profile update in passengers table is optional
    }
  }
}
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import 'supabase_service.dart';

class AuthService {
  SupabaseClient get _supabase => SupabaseService().client;

  Future<void> _ready() => SupabaseService().initialize();

  Future<void> signInAnonymously() async {
    try {
      await _ready();
      final response = await _supabase.auth.signInAnonymously();
      final userId = response.user?.id;
      if (userId == null) {
        throw Exception('Anonymous sign-in failed: no user returned.');
      }
      await _ensureProfileExists(userId);
    } catch (e) {
      throw Exception('Anonymous sign-in failed: ${e.toString()}');
    }
  }

  Future<void> _ensureProfileExists(String userId, {int attempt = 0}) async {
    try {
      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('profiles').insert({
          'id': userId,
          'subscription_status': 'free',
          'subscription_expiry': null,
        });
      }
    } catch (e) {
      debugPrint('AuthService: profile creation failed (attempt $attempt): $e');
      if (attempt < 1) {
        await _ensureProfileExists(userId, attempt: attempt + 1);
        return;
      }
      throw Exception('Failed to create user profile: ${e.toString()}');
    }
  }

  Future<void> retryProfileCreation() async {
    final userId = getCurrentUser()?.id;
    if (userId == null) return;
    await _ensureProfileExists(userId);
  }

  Future<void> signOut() async {
    try {
      await _ready();
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  User? getCurrentUser() {
    if (!SupabaseService().isInitialized) return null;
    return _supabase.auth.currentUser;
  }

  Stream<AuthState> get authStateChanges {
    if (!SupabaseService().isInitialized) {
      return const Stream<AuthState>.empty();
    }
    return _supabase.auth.onAuthStateChange;
  }

  Future<Profile?> fetchProfile() async {
    try {
      await _ready();
      final user = getCurrentUser();
      if (user == null) return null;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return Profile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load profile: ${e.toString()}');
    }
  }
}
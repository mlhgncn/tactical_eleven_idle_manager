import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

class AuthService implements AuthRepository {
  AuthService({SupabaseClient? supabase}) : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<dynamic> signIn(String email, String password) {
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<dynamic> signUp(String email, String password) {
    return _supabase.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() {
    return _supabase.auth.signOut();
  }

  String? get currentUserId => _supabase.auth.currentUser?.id;
}

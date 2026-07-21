import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

class AuthService implements AuthRepository {
  AuthService({SupabaseClient? supabase}) : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<dynamic> signIn(String email, String password) {
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<dynamic> signUp(String email, String password, {String? username, String? referralCode}) {
    final data = <String, dynamic>{
      if (username != null && username.isNotEmpty) 'username': username,
      if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
    };
    return _supabase.auth.signUp(
      email: email,
      password: password,
      data: data.isEmpty ? null : data,
    );
  }

  Future<dynamic> signInAnonymously() {
    return _supabase.auth.signInAnonymously();
  }

  Future<void> signOut() {
    return _supabase.auth.signOut();
  }

  Future<void> updateEmail(String newEmail) async {
    await _supabase.auth.updateUser(UserAttributes(email: newEmail));
  }

  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  // Setting email+password together is what turns an anonymous auth.users
  // row into a real one - same UUID throughout, so the club/players/profile
  // already tied to that id carry straight over. Supabase sends a
  // confirmation email; the account is fully claimed once it's confirmed.
  Future<void> claimAccount(String email, String password) async {
    await _supabase.auth.updateUser(UserAttributes(email: email, password: password));
  }

  String? get currentUserId => _supabase.auth.currentUser?.id;
  String? get currentUserEmail => _supabase.auth.currentUser?.email;
  bool get isAnonymous => _supabase.auth.currentUser?.isAnonymous ?? false;
}

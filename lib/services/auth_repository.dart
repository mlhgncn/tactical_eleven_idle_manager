abstract class AuthRepository {
  Future<dynamic> signIn(String email, String password);
  Future<dynamic> signUp(String email, String password, {String? username, String? referralCode});
  Future<dynamic> signInAnonymously();
  Future<void> signOut();
  Future<void> updateEmail(String newEmail);
  Future<void> updatePassword(String newPassword);
  /// Upgrades the current anonymous session to a permanent email/password
  /// account in one call - keeps the same auth.uid() (and therefore the
  /// same club/players/progress), just attaches real credentials to it.
  Future<void> claimAccount(String email, String password);
  String? get currentUserId;
  String? get currentUserEmail;
  bool get isAnonymous;
}

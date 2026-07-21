abstract class AuthRepository {
  Future<dynamic> signIn(String email, String password);
  Future<dynamic> signUp(String email, String password, {String? username, String? referralCode});
  Future<void> signOut();
  Future<void> updateEmail(String newEmail);
  Future<void> updatePassword(String newPassword);
  String? get currentUserId;
  String? get currentUserEmail;
}

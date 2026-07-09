abstract class AuthRepository {
  Future<dynamic> signIn(String email, String password);
  Future<dynamic> signUp(String email, String password);
  Future<void> signOut();
  Future<void> updateEmail(String newEmail);
  Future<void> updatePassword(String newPassword);
  String? get currentUserId;
  String? get currentUserEmail;
}

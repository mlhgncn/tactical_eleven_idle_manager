abstract class AuthRepository {
  Future<dynamic> signIn(String email, String password);
  Future<dynamic> signUp(String email, String password);
  Future<void> signOut();
  String? get currentUserId;
}

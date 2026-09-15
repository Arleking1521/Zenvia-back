import '../models/parent_account.dart';

abstract class AuthRepository {
  Future<bool> isLoggedIn();

  Future<void> login({
    required String email,
    required String password,
  });

  Future<void> register({
    required String parentName,
    required String email,
    required String password,
    required String passwordConfirm,
  });

  Future<ParentAccount> getParent();

  Future<ParentAccount> updateParentName(String firstName);

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  });

  Future<void> logout();
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

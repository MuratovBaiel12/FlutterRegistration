class AuthSession {
  AuthSession._();

  static int? _accountId;
  static String? _email;

  static int? get accountId => _accountId;
  static String? get email => _email;
  static bool get isAuthorized => _accountId != null && _accountId! > 0;

  static void set({
    required int accountId,
    String? email,
  }) {
    _accountId = accountId;
    _email = (email ?? '').trim().isEmpty ? null : email!.trim();
  }

  static void clear() {
    _accountId = null;
    _email = null;
  }

  static int requireAccountId() {
    final value = _accountId;
    if (value == null || value <= 0) {
      throw StateError('User session is not initialized');
    }
    return value;
  }
}

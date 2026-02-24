import 'api_connect.dart';

class AuthActionResult {
  final bool success;
  final String message;
  final Map<String, dynamic> raw;

  const AuthActionResult({
    required this.success,
    required this.message,
    required this.raw,
  });
}

class AuthService {
  AuthService({ApiConnect? apiConnect})
      : _apiConnect = apiConnect ?? ApiConnect();

  final ApiConnect _apiConnect;

  // Под этот путь будет отправляться регистрация.
  // Измените путь, если PHP файл лежит в другом каталоге.
  static const String registerEndpoint = '/register.php';
  static const String loginEndpoint = '/login.php';

  Future<AuthActionResult> register({
    required String email,
    required String password,
  }) async {
    final response = await _apiConnect.postForm(
      registerEndpoint,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    return _buildActionResult(
      response,
      successFallback: 'Регистрация выполнена',
      errorFallback: 'Не удалось зарегистрироваться',
    );
  }

  Future<AuthActionResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiConnect.postForm(
      loginEndpoint,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    return _buildActionResult(
      response,
      successFallback: 'Вход выполнен',
      errorFallback: 'Не удалось войти',
    );
  }

  AuthActionResult _buildActionResult(
    Map<String, dynamic> response, {
    required String successFallback,
    required String errorFallback,
  }) {
    final success = _readBool(response['success']) ||
        _readBool(response['ok']) ||
        (response['status']?.toString().toLowerCase() == 'success');

    return AuthActionResult(
      success: success,
      message: response['message']?.toString() ??
          (success ? successFallback : errorFallback),
      raw: response,
    );
  }

  void dispose() {
    _apiConnect.dispose();
  }

  bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'ok';
  }
}

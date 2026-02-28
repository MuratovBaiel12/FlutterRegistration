import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }
    return 'HTTP $statusCode: $message';
  }
}

class ApiConnect {
  ApiConnect({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Укажите папку, где лежат PHP endpoints (НЕ файл db.php).
  // Пример: https://example.com/api
  static const String baseUrl = 'https://films.pladzuma.com/api';

  Uri buildUri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Future<Map<String, dynamic>> postForm(
    String path, {
    required Map<String, String> body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final response = await _client
        .post(
          buildUri(path),
          headers: const {
            'Accept': 'application/json',
          },
          body: body,
        )
        .timeout(timeout);

    final responseText = utf8.decode(response.bodyBytes);

    final looksLikeInfinityFreeAntiBot =
        responseText.contains('/aes.js') && responseText.contains('__test=');
    if (looksLikeInfinityFreeAntiBot) {
      throw ApiException(
        'Хостинг вернул anti-bot страницу вместо JSON. '
        'InfinityFree часто блокирует запросы из Flutter desktop/mobile. '
        'Нужен другой хостинг или proxy для API.',
        statusCode: response.statusCode,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(responseText);
    } catch (_) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw const ApiException('Сервер вернул не JSON');
      }
      throw ApiException(
        responseText.isEmpty ? 'Ошибка сервера' : responseText,
        statusCode: response.statusCode,
      );
    }

    final map = decoded is Map
        ? decoded.map((key, value) => MapEntry(key.toString(), value))
        : null;

    if (map == null) {
      throw const ApiException('Некорректный формат ответа сервера');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        map['message']?.toString() ?? 'Ошибка сервера',
        statusCode: response.statusCode,
      );
    }

    return map;
  }

  void dispose() {
    _client.close();
  }
}

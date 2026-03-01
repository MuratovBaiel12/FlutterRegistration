import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../services/api_connect.dart';
import '../models/movie_model.dart';

class MovieRemoteDataSource {
  MovieRemoteDataSource({
    ApiConnect? apiConnect,
    http.Client? client,
  })  : _apiConnect = apiConnect ?? ApiConnect(),
        _client = client ?? http.Client();

  static const String marksEndpoint = '/marks.php';
  static const String uploadImageEndpoint = '/upload_image.php';
  static const String imageBaseUrl = 'https://films.pladzuma.com/img';

  final ApiConnect _apiConnect;
  final http.Client _client;

  Future<List<MovieModel>> fetchMovies({
    required int accountId,
  }) async {
    final response = await _apiConnect.postForm(
      marksEndpoint,
      body: {
        'action': 'list',
        'account_id': accountId.toString(),
      },
    );

    final itemsRaw = response['items'];
    if (itemsRaw is! List) {
      return const <MovieModel>[];
    }

    final models = <MovieModel>[];
    for (final item in itemsRaw) {
      final itemMap = _readMap(item);
      if (itemMap == null) {
        continue;
      }

      final model = _movieFromResponse(
        itemMap,
        fallback: MovieModel(
          id: _optionalString(itemMap['id']) ?? '',
          title: _optionalString(itemMap['title']) ?? '',
          description: _optionalString(itemMap['description']) ?? '',
          notes: _optionalString(itemMap['notes']),
          tags: _parseTags(itemMap['tags']),
          coverImagePath: _optionalString(itemMap['cover_image']),
          createdAt: _parseDateTime(itemMap['created_at']) ?? DateTime.now(),
          updatedAt: _parseDateTime(itemMap['updated_at']) ?? DateTime.now(),
        ),
      );

      if (model.id.trim().isNotEmpty) {
        models.add(model);
      }
    }

    return List<MovieModel>.unmodifiable(models);
  }

  Future<MovieModel> upsert(
    MovieModel model, {
    required int accountId,
  }) async {
    final coverImageUrl = await _resolveCoverImage(model.coverImagePath);

    final response = await _apiConnect.postForm(
      marksEndpoint,
      body: {
        'action': 'upsert',
        'account_id': accountId.toString(),
        if (_isPositiveInt(model.id)) 'id': model.id,
        'title': model.title,
        'description': model.description,
        'notes': model.notes ?? '',
        'tags': jsonEncode(model.tags),
        'cover_image': coverImageUrl ?? '',
      },
    );

    final item = _readMap(response['item']);
    if (item != null) {
      return _movieFromResponse(
        item,
        fallback: model,
        coverOverride: coverImageUrl,
      );
    }

    final returnedId = response['id']?.toString().trim() ?? '';
    return MovieModel(
      id: returnedId.isEmpty ? model.id : returnedId,
      title: model.title,
      description: model.description,
      notes: model.notes,
      tags: List<String>.unmodifiable(model.tags),
      coverImagePath: coverImageUrl,
      createdAt: model.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> delete(
    String id, {
    required int accountId,
  }) async {
    if (!_isPositiveInt(id)) {
      return;
    }

    await _apiConnect.postForm(
      marksEndpoint,
      body: {
        'action': 'delete',
        'account_id': accountId.toString(),
        'id': id,
      },
    );
  }

  Future<String> uploadCoverImage(String localPath) async {
    late final http.MultipartFile file;
    try {
      file = await http.MultipartFile.fromPath('image', localPath);
    } on UnsupportedError {
      throw const ApiException(
        'Image upload from file path is not supported on this platform',
      );
    } catch (e) {
      throw ApiException('Failed to prepare image upload: $e');
    }

    final request = http.MultipartRequest(
      'POST',
      _apiConnect.buildUri(uploadImageEndpoint),
    )
      ..headers['Accept'] = 'application/json'
      ..files.add(file);

    late final http.StreamedResponse streamedResponse;
    try {
      streamedResponse =
          await _client.send(request).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ApiException('Image upload timed out');
    }

    final response = await http.Response.fromStream(streamedResponse);
    final responseText = utf8.decode(response.bodyBytes);

    dynamic decoded;
    try {
      decoded = jsonDecode(responseText);
    } catch (_) {
      throw ApiException(
        responseText.isEmpty
            ? 'Server returned non-JSON response while uploading image'
            : responseText,
        statusCode: response.statusCode,
      );
    }

    final map = _readMap(decoded);
    if (map == null) {
      throw const ApiException('Invalid upload response format');
    }

    final isSuccess = _readBool(map['success']) ||
        _readBool(map['ok']) ||
        (map['status']?.toString().toLowerCase() == 'success');

    if (!isSuccess || response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        map['message']?.toString() ?? 'Failed to upload image',
        statusCode: response.statusCode,
      );
    }

    final url = (map['url'] ?? map['image_url'] ?? map['cover_image'])
            ?.toString()
            .trim() ??
        '';
    if (url.isEmpty) {
      throw const ApiException('Upload response did not contain image URL');
    }

    return _toAbsoluteImageUrl(url);
  }

  void dispose() {
    _apiConnect.dispose();
    _client.close();
  }

  Future<String?> _resolveCoverImage(String? rawValue) async {
    final value = (rawValue ?? '').trim();
    if (value.isEmpty) return null;
    if (_isHttpUrl(value) ||
        value.startsWith('/img/') ||
        value.startsWith('img/')) {
      return _toAbsoluteImageUrl(value);
    }
    return uploadCoverImage(value);
  }

  MovieModel _movieFromResponse(
    Map<String, dynamic> raw, {
    required MovieModel fallback,
    String? coverOverride,
  }) {
    final idRaw = raw['id']?.toString().trim() ?? '';
    final titleRaw = raw['title']?.toString().trim() ?? '';
    final descriptionRaw = raw['description']?.toString().trim() ?? '';

    final tags = _parseTags(raw['tags']);
    final createdAt = _parseDateTime(raw['created_at']) ?? fallback.createdAt;
    final updatedAt = _parseDateTime(raw['updated_at']) ?? DateTime.now();

    final coverFromResponse = _optionalString(raw['cover_image']);
    final notesFromResponse = _optionalString(raw['notes']);
    final normalizedCover = coverFromResponse == null
        ? null
        : _toAbsoluteImageUrl(coverFromResponse);

    return MovieModel(
      id: idRaw.isEmpty ? fallback.id : idRaw,
      title: titleRaw.isEmpty ? fallback.title : titleRaw,
      description:
          descriptionRaw.isEmpty ? fallback.description : descriptionRaw,
      notes: notesFromResponse ?? fallback.notes,
      tags: tags.isEmpty
          ? List<String>.unmodifiable(fallback.tags)
          : List<String>.unmodifiable(tags),
      coverImagePath:
          normalizedCover ?? coverOverride ?? fallback.coverImagePath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  DateTime? _parseDateTime(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }

    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized)?.toLocal();
  }

  List<String> _parseTags(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
    }

    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return const <String>[];

    if (raw.startsWith('[')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((item) => item.toString().trim())
              .where((tag) => tag.isNotEmpty)
              .toList(growable: false);
        }
      } catch (_) {
        // Fallback to comma-separated parsing below.
      }
    }

    return raw
        .split(',')
        .map((item) => item.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic>? _readMap(Object? value) {
    if (value is! Map) return null;
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }

  String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  String _toAbsoluteImageUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (_isHttpUrl(trimmed)) {
      return trimmed;
    }

    if (trimmed.startsWith('/img/')) {
      final suffix = trimmed.substring('/img/'.length);
      return '$imageBaseUrl/$suffix';
    }

    if (trimmed.startsWith('img/')) {
      final suffix = trimmed.substring('img/'.length);
      return '$imageBaseUrl/$suffix';
    }

    if (trimmed.startsWith('/')) {
      return trimmed;
    }

    return '$imageBaseUrl/$trimmed';
  }

  bool _isPositiveInt(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed > 0;
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

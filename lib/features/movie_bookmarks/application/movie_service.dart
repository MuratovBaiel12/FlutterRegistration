import 'package:uuid/uuid.dart';

import '../domain/entities/movie.dart';
import '../domain/repositories/movie_repository.dart';

class MovieService {
  final MovieRepository _repository;
  final Uuid _uuid;

  MovieService({
    required MovieRepository repository,
    required Uuid uuid,
  })  : _repository = repository,
        _uuid = uuid;

  Stream<List<Movie>> watchMovies() {
    return _repository.watchMovies().map((movies) {
      final sorted = movies.toList(growable: false);
      sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sorted;
    });
  }

  Future<void> addMovie({
    required String title,
    required String description,
    String? notes,
    required List<String> tags,
    String? coverImagePath,
  }) async {
    final now = DateTime.now();

    final movie = Movie(
      id: _uuid.v4(),
      title: _validateRequired(title, fieldName: 'title', max: 120),
      description:
          _validateRequired(description, fieldName: 'description', max: 2000),
      notes: _validateOptional(notes, fieldName: 'notes', max: 1000),
      tags: _validateTags(tags),
      coverImagePath: _validateOptionalPathOrUrl(coverImagePath),
      createdAt: now,
      updatedAt: now,
    );

    await _repository.upsertMovie(movie);
  }

  Future<void> updateMovie({
    required Movie existing,
    required String title,
    required String description,
    String? notes,
    required List<String> tags,
    String? coverImagePath,
  }) async {
    final now = DateTime.now();

    final updated = existing.copyWith(
      title: _validateRequired(title, fieldName: 'title', max: 120),
      description:
          _validateRequired(description, fieldName: 'description', max: 2000),
      notes: _validateOptional(notes, fieldName: 'notes', max: 1000),
      tags: _validateTags(tags),
      coverImagePath: _validateOptionalPathOrUrl(coverImagePath),
      updatedAt: now,
    );

    await _repository.upsertMovie(updated);
  }

  Future<void> deleteMovie(String id) async {
    await _repository.deleteMovie(id);
  }
}

String _validateRequired(
  String value, {
  required String fieldName,
  required int max,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, fieldName, 'must not be empty');
  }
  if (trimmed.length > max) {
    throw ArgumentError.value(value, fieldName, 'must be <= $max chars');
  }
  return trimmed;
}

String? _validateOptional(
  String? value, {
  required String fieldName,
  required int max,
}) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.length > max) {
    throw ArgumentError.value(value, fieldName, 'must be <= $max chars');
  }
  return trimmed;
}

List<String> _validateTags(List<String> tags) {
  final normalized = <String>[];
  for (final raw in tags) {
    final t = raw.trim();
    if (t.isEmpty) continue;
    if (!normalized.contains(t)) {
      normalized.add(t);
    }
  }

  if (normalized.isEmpty) {
    throw ArgumentError.value(tags, 'tags', 'must contain at least 1 tag');
  }
  if (normalized.length > 20) {
    throw ArgumentError.value(tags, 'tags', 'must contain at most 20 tags');
  }

  return List<String>.unmodifiable(normalized);
}

String? _validateOptionalPathOrUrl(String? value) {
  final trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}


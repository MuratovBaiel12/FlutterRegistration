import 'package:hive/hive.dart';

import '../models/movie_model.dart';

class MovieLocalDataSource {
  static const String boxName = 'movie_bookmarks_box';

  Future<Box<MovieModel>> _box() async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box<MovieModel>(boxName);
      }
      return await Hive.openBox<MovieModel>(boxName);
    } catch (e) {
      throw MovieLocalDataSourceException('Failed to open Hive box: $boxName', e);
    }
  }

  Future<List<MovieModel>> getAll() async {
    try {
      final box = await _box();
      return box.values.toList(growable: false);
    } catch (e) {
      throw MovieLocalDataSourceException('Failed to load movies', e);
    }
  }

  Stream<List<MovieModel>> watchAll() async* {
    try {
      final box = await _box();
      yield box.values.toList(growable: false);
      yield* box.watch().map((_) => box.values.toList(growable: false));
    } catch (e) {
      throw MovieLocalDataSourceException('Failed to watch movies', e);
    }
  }

  Future<void> upsert(MovieModel model) async {
    try {
      final box = await _box();
      await box.put(model.id, model);
    } catch (e) {
      throw MovieLocalDataSourceException('Failed to save movie', e);
    }
  }

  Future<void> delete(String id) async {
    try {
      final box = await _box();
      await box.delete(id);
    } catch (e) {
      throw MovieLocalDataSourceException('Failed to delete movie', e);
    }
  }
}

class MovieLocalDataSourceException implements Exception {
  final String message;
  final Object cause;

  MovieLocalDataSourceException(this.message, this.cause);

  @override
  String toString() => 'MovieLocalDataSourceException($message, $cause)';
}


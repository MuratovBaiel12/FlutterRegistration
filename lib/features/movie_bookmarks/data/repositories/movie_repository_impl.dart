import '../../domain/entities/movie.dart';
import '../../domain/repositories/movie_repository.dart';
import '../datasources/movie_local_datasource.dart';
import '../models/movie_model.dart';

class MovieRepositoryImpl implements MovieRepository {
  final MovieLocalDataSource _local;

  MovieRepositoryImpl({required MovieLocalDataSource localDataSource})
      : _local = localDataSource;

  @override
  Stream<List<Movie>> watchMovies() {
    return _local.watchAll().map(
          (models) => models.map((m) => m.toEntity()).toList(growable: false),
        );
  }

  @override
  Future<List<Movie>> getMovies() async {
    final models = await _local.getAll();
    return models.map((m) => m.toEntity()).toList(growable: false);
  }

  @override
  Future<void> upsertMovie(Movie movie) async {
    await _local.upsert(MovieModel.fromEntity(movie));
  }

  @override
  Future<void> deleteMovie(String id) async {
    await _local.delete(id);
  }
}


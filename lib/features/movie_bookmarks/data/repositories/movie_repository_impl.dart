import '../../domain/entities/movie.dart';
import '../../domain/repositories/movie_repository.dart';
import '../../../../services/auth_session.dart';
import '../datasources/movie_local_datasource.dart';
import '../datasources/movie_remote_datasource.dart';
import '../models/movie_model.dart';

class MovieRepositoryImpl implements MovieRepository {
  final MovieLocalDataSource _local;
  final MovieRemoteDataSource _remote;

  MovieRepositoryImpl({
    required MovieLocalDataSource localDataSource,
    required MovieRemoteDataSource remoteDataSource,
  })  : _local = localDataSource,
        _remote = remoteDataSource;

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
  Future<void> syncCurrentAccountMovies() async {
    final accountId = AuthSession.requireAccountId();
    final models = await _remote.fetchMovies(accountId: accountId);
    await _local.replaceAll(models);
  }

  @override
  Future<void> upsertMovie(Movie movie) async {
    final localModel = MovieModel.fromEntity(movie);
    final accountId = AuthSession.requireAccountId();
    final remoteModel = await _remote.upsert(
      localModel,
      accountId: accountId,
    );

    if (remoteModel.id != localModel.id) {
      await _local.delete(localModel.id);
    }
    await _local.upsert(remoteModel);
  }

  @override
  Future<void> deleteMovie(String id) async {
    final accountId = AuthSession.requireAccountId();
    await _remote.delete(
      id,
      accountId: accountId,
    );
    await _local.delete(id);
  }

  @override
  Future<void> clearLocalMovies() async {
    await _local.clearAll();
  }
}

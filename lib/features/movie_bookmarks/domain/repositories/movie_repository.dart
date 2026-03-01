import '../entities/movie.dart';

abstract class MovieRepository {
  Stream<List<Movie>> watchMovies();
  Future<List<Movie>> getMovies();
  Future<void> syncCurrentAccountMovies();
  Future<void> upsertMovie(Movie movie);
  Future<void> deleteMovie(String id);
  Future<void> clearLocalMovies();
}

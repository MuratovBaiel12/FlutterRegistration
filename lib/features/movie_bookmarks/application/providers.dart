import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/datasources/movie_local_datasource.dart';
import '../data/datasources/movie_remote_datasource.dart';
import '../data/repositories/movie_repository_impl.dart';
import '../domain/entities/movie.dart';
import '../domain/repositories/movie_repository.dart';
import 'movie_ai_service.dart';
import 'movie_service.dart';
import 'movie_screenshot_service.dart';

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

final movieLocalDataSourceProvider =
    Provider<MovieLocalDataSource>((ref) => MovieLocalDataSource());

final movieRemoteDataSourceProvider = Provider<MovieRemoteDataSource>((ref) {
  final dataSource = MovieRemoteDataSource();
  ref.onDispose(dataSource.dispose);
  return dataSource;
});

final movieRepositoryProvider = Provider<MovieRepository>(
  (ref) => MovieRepositoryImpl(
    localDataSource: ref.watch(movieLocalDataSourceProvider),
    remoteDataSource: ref.watch(movieRemoteDataSourceProvider),
  ),
);

final movieServiceProvider = Provider<MovieService>(
  (ref) => MovieService(
    repository: ref.watch(movieRepositoryProvider),
    uuid: ref.watch(uuidProvider),
  ),
);

final movieScreenshotServiceProvider = Provider<MovieScreenshotService>((ref) {
  final service = createMovieScreenshotService();
  ref.onDispose(service.dispose);
  return service;
});

final movieAiServiceProvider = Provider<MovieAiService>((ref) {
  final service = MovieAiService(
    apiKey: const String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: 'AIzaSyCJYC4rB1pCuBe7FLTI-Y2kka-_Xo0vD4Y',
    ),
    model: 'gemini-2.5-flash',
  );
  ref.onDispose(service.dispose);
  return service;
});

final moviesProvider = StreamProvider<List<Movie>>(
  (ref) => ref.watch(movieServiceProvider).watchMovies(),
);

final selectedTagFiltersProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

final movieSearchQueryProvider = StateProvider<String>((ref) => '');

enum MovieSortOption {
  updatedAtDesc,
  createdAtDesc,
  titleAsc,
  titleDesc,
}

final movieSortOptionProvider =
    StateProvider<MovieSortOption>((ref) => MovieSortOption.updatedAtDesc);

final availableTagsProvider = Provider<List<String>>((ref) {
  final moviesAsync = ref.watch(moviesProvider);
  return moviesAsync.maybeWhen(
    data: (movies) {
      final tags = <String>{};
      for (final m in movies) {
        tags.addAll(m.tags);
      }
      final list = tags.toList()..sort();
      return list;
    },
    orElse: () => const <String>[],
  );
});

final filteredMoviesProvider = Provider<List<Movie>>((ref) {
  final moviesAsync = ref.watch(moviesProvider);
  final selected = ref.watch(selectedTagFiltersProvider);
  final query = ref.watch(movieSearchQueryProvider);
  final sort = ref.watch(movieSortOptionProvider);

  return moviesAsync.maybeWhen(
    data: (movies) {
      final normalizedQuery = query.trim().toLowerCase();

      final result = <Movie>[];
      for (final m in movies) {
        if (selected.isNotEmpty && !m.tags.any(selected.contains)) {
          continue;
        }

        if (normalizedQuery.isNotEmpty) {
          final haystacks = <String>[
            m.title,
            m.description,
            m.notes ?? '',
            m.tags.join(' '),
          ];
          final matches = haystacks.any(
            (s) => s.toLowerCase().contains(normalizedQuery),
          );
          if (!matches) continue;
        }

        result.add(m);
      }

      switch (sort) {
        case MovieSortOption.updatedAtDesc:
          result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          break;
        case MovieSortOption.createdAtDesc:
          result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case MovieSortOption.titleAsc:
          result.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
          break;
        case MovieSortOption.titleDesc:
          result.sort(
            (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
          );
          break;
      }

      return result;
    },
    orElse: () => const <Movie>[],
  );
});

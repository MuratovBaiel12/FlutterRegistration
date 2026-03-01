import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../services/auth_session.dart';
import '../../application/providers.dart';
import '../../domain/entities/movie.dart';
import '../widgets/movie_cover_image.dart';
import 'add_edit_movie_page.dart';

class MovieBookmarksPage extends ConsumerStatefulWidget {
  const MovieBookmarksPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const MovieBookmarksPage());
  }

  @override
  ConsumerState<MovieBookmarksPage> createState() => _MovieBookmarksPageState();
}

class _MovieBookmarksPageState extends ConsumerState<MovieBookmarksPage> {
  final _searchController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(movieSearchQueryProvider);
    _searchController.addListener(() {
      ref.read(movieSearchQueryProvider.notifier).state =
          _searchController.text;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCurrentAccountMovies();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _syncCurrentAccountMovies() async {
    try {
      await ref.read(movieServiceProvider).syncCurrentAccountMovies();
    } on StateError {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on Object catch (e) {
      if (!mounted) return;
      _showError(context, e);
    }
  }

  List<String> _titleCandidatesFromLines(List<String> lines) {
    final normalized = <String>[];
    for (final raw in lines) {
      final t = raw.trim();
      if (t.length < 2) continue;
      if (t.length > 120) continue;
      final hasLetter = RegExp(r'[A-Za-zА-Яа-я]').hasMatch(t);
      if (!hasLetter) continue;
      if (!normalized.contains(t)) {
        normalized.add(t);
      }
      if (normalized.length >= 12) break;
    }
    return normalized;
  }

  Future<void> _scanScreenshotAndAdd() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (picked == null) return;

      final service = ref.read(movieScreenshotServiceProvider);
      final lines = await service.extractTextLines(picked.path);
      final candidates = _titleCandidatesFromLines(lines);
      if (!mounted) return;

      if (candidates.isEmpty) {
        _showError(context, 'No readable title found in the screenshot');
        return;
      }

      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Select detected title',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                for (final c in candidates)
                  ListTile(
                    title: Text(
                      c,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).pop(c),
                  ),
              ],
            ),
          );
        },
      );

      if (!mounted) return;
      if (selected == null) return;

      await Navigator.of(context).push(
        AddEditMoviePage.routeAdd(prefillTitle: selected),
      );
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      _showError(context, e);
    } on Object catch (e) {
      if (!mounted) return;
      _showError(context, e);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Movie movie,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete movie?'),
          content: Text('Delete "${movie.title}" from bookmarks?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!context.mounted) return;
    if (shouldDelete != true) return;

    try {
      await ref.read(movieServiceProvider).deleteMovie(movie.id);
    } on Object catch (e) {
      if (!context.mounted) return;
      _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(moviesProvider, (prev, next) {
      next.whenOrNull(error: (e, _) => _showError(context, e));
    });

    final moviesAsync = ref.watch(moviesProvider);
    final availableTags = ref.watch(availableTagsProvider);
    final selectedTags = ref.watch(selectedTagFiltersProvider);
    final searchQuery = ref.watch(movieSearchQueryProvider);
    final sort = ref.watch(movieSortOptionProvider);
    final movies = ref.watch(filteredMoviesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie bookmarks'),
        actions: [
          Semantics(
            label: 'Log out',
            button: true,
            child: IconButton(
              tooltip: 'Log out',
              onPressed: () async {
                try {
                  await ref.read(movieServiceProvider).clearLocalMovies();
                } catch (_) {
                  // Ignore cache cleanup errors during logout.
                }
                AuthSession.clear();
                if (!context.mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
            ),
          ),
          Semantics(
            label: 'Scan screenshot and add movie',
            button: true,
            child: IconButton(
              tooltip: 'Scan screenshot',
              onPressed: _scanScreenshotAndAdd,
              icon: const Icon(Icons.document_scanner_outlined),
            ),
          ),
          Semantics(
            label: 'Change sorting',
            button: true,
            child: PopupMenuButton<MovieSortOption>(
              tooltip: 'Sort',
              initialValue: sort,
              onSelected: (value) =>
                  ref.read(movieSortOptionProvider.notifier).state = value,
              itemBuilder: (context) => [
                _sortMenuItem(
                  value: MovieSortOption.updatedAtDesc,
                  label: 'Recently updated',
                ),
                _sortMenuItem(
                  value: MovieSortOption.createdAtDesc,
                  label: 'Recently added',
                ),
                _sortMenuItem(
                  value: MovieSortOption.titleAsc,
                  label: 'Title A–Z',
                ),
                _sortMenuItem(
                  value: MovieSortOption.titleDesc,
                  label: 'Title Z–A',
                ),
              ],
              icon: const Icon(Icons.sort_outlined),
            ),
          ),
          Semantics(
            label: 'Clear tag filters',
            button: true,
            child: IconButton(
              tooltip: 'Clear filters',
              onPressed: selectedTags.isEmpty
                  ? null
                  : () => ref.read(selectedTagFiltersProvider.notifier).state =
                      <String>{},
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: Semantics(
        label: 'Add movie bookmark',
        button: true,
        child: FloatingActionButton(
          onPressed: () =>
              Navigator.of(context).push(AddEditMoviePage.routeAdd()),
          child: const Icon(Icons.add),
        ),
      ),
      body: SafeArea(
        child: moviesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Failed to load bookmarks'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.invalidate(moviesProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (_) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      prefixIcon: const Icon(Icons.search_outlined),
                      suffixIcon: searchQuery.trim().isEmpty
                          ? null
                          : Semantics(
                              label: 'Clear search',
                              button: true,
                              child: IconButton(
                                tooltip: 'Clear',
                                onPressed: () => _searchController.clear(),
                                icon: const Icon(Icons.clear),
                              ),
                            ),
                    ),
                  ),
                ),
                if (availableTags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const SizedBox(width: 4),
                            for (final tag in availableTags) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: FilterChip(
                                  label: Text(tag),
                                  selected: selectedTags.contains(tag),
                                  onSelected: (selected) {
                                    final next = {...selectedTags};
                                    if (selected) {
                                      next.add(tag);
                                    } else {
                                      next.remove(tag);
                                    }
                                    ref
                                        .read(
                                          selectedTagFiltersProvider.notifier,
                                        )
                                        .state = next;
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${movies.length} result${movies.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        _sortLabel(sort),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: movies.isEmpty
                      ? const Center(child: Text('No bookmarks yet'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: movies.length,
                          itemBuilder: (context, index) {
                            final movie = movies[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Card(
                                child: ListTile(
                                  key: ValueKey(movie.id),
                                  leading: MovieCoverImage(
                                    pathOrUrl: movie.coverImagePath,
                                    size: 56,
                                  ),
                                  title: Text(
                                    movie.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        movie.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          for (final tag in movie.tags.take(6))
                                            Chip(
                                              label: Text(tag),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          if (movie.tags.length > 6)
                                            Chip(
                                              label: Text(
                                                '+${movie.tags.length - 6}',
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  onTap: () => Navigator.of(context)
                                      .push(AddEditMoviePage.routeEdit(movie)),
                                  trailing: PopupMenuButton<_MovieMenuAction>(
                                    tooltip: 'Movie actions',
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: _MovieMenuAction.edit,
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: _MovieMenuAction.delete,
                                        child: Text('Delete'),
                                      ),
                                    ],
                                    onSelected: (action) {
                                      switch (action) {
                                        case _MovieMenuAction.edit:
                                          Navigator.of(context).push(
                                            AddEditMoviePage.routeEdit(movie),
                                          );
                                        case _MovieMenuAction.delete:
                                          _confirmDelete(context, ref, movie);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _MovieMenuAction { edit, delete }

PopupMenuItem<MovieSortOption> _sortMenuItem({
  required MovieSortOption value,
  required String label,
}) {
  return PopupMenuItem<MovieSortOption>(
    value: value,
    child: Text(label),
  );
}

String _sortLabel(MovieSortOption option) {
  switch (option) {
    case MovieSortOption.updatedAtDesc:
      return 'Sorted: updated';
    case MovieSortOption.createdAtDesc:
      return 'Sorted: added';
    case MovieSortOption.titleAsc:
      return 'Sorted: title A–Z';
    case MovieSortOption.titleDesc:
      return 'Sorted: title Z–A';
  }
}

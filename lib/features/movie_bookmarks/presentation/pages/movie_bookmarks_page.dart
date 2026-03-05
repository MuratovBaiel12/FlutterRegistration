import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../services/auth_session.dart';
import '../../../../widgets/app_logo.dart';
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
  static const Color _pageBackground = Color.fromARGB(255, 18, 18, 18);
  static const Color _surfaceColor = Color.fromARGB(255, 30, 30, 30);
  static const Color _surfaceBorder = Color(0xFF252C3A);
  static const Color _mutedText = Color.fromARGB(255, 82, 104, 130);
  static const Color _accent = Color(0xFF5E66FF);

  final _searchController = TextEditingController();
  final _picker = ImagePicker();
  bool _aiAddingInProgress = false;

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

  Future<void> _logout() async {
    try {
      await ref.read(movieServiceProvider).clearLocalMovies();
    } catch (_) {
      // Ignore cache cleanup errors during logout.
    }

    AuthSession.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _showAddMovieOptions() async {
    if (_aiAddingInProgress) return;

    final choice = await showModalBottomSheet<_MovieImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: _surfaceColor,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Сфоткать'),
                  subtitle: const Text('Сделать фото постера или кадра'),
                  onTap: () =>
                      Navigator.of(context).pop(_MovieImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Добавить картинку'),
                  subtitle: const Text('Выбрать изображение из галереи'),
                  onTap: () =>
                      Navigator.of(context).pop(_MovieImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || choice == null) return;

    final source = choice == _MovieImageSource.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    await _pickImageAndAutoFillMovie(source);
  }

  Future<void> _pickImageAndAutoFillMovie(ImageSource source) async {
    if (_aiAddingInProgress) return;

    var loadingShown = false;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        imageQuality: 90,
      );
      if (!mounted || picked == null) return;

      setState(() => _aiAddingInProgress = true);
      final bytes = await picked.readAsBytes();

      if (!mounted) return;
      loadingShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text('ИИ ищет фильм и заполняет данные...'),
                ),
              ],
            ),
          );
        },
      );

      final suggestion =
          await ref.read(movieAiServiceProvider).detectMovieFromImage(
                imageBytes: bytes,
                mimeType: _guessMimeType(picked.name),
              );

      if (loadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }
      if (!mounted) return;

      await Navigator.of(context).push(
        AddEditMoviePage.routeAdd(
          prefillTitle: suggestion.title,
          prefillDescription: suggestion.description,
          prefillMovieUrl: suggestion.movieUrl,
          prefillCoverImageUrl: suggestion.coverImageUrl,
        ),
      );
    } on UnsupportedError catch (e) {
      if (loadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }
      if (!mounted) return;
      _showError(context, e);
    } on Object catch (e) {
      if (loadingShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }
      if (!mounted) return;
      _showError(context, e);
    } finally {
      if (mounted) {
        setState(() => _aiAddingInProgress = false);
      }
    }
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
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

  Widget _buildToolbarButton({
    required String semanticsLabel,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final iconColor = onPressed == null ? _mutedText.withAlpha(90) : _mutedText;

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor),
      ),
    );
  }

  Widget _buildMovieTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF202634),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _surfaceBorder),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: _mutedText,
          fontSize: 14,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildMovieCard({
    required BuildContext context,
    required WidgetRef ref,
    required Movie movie,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;
    final coverSize = compact ? 74.0 : 92.0;

    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () =>
            Navigator.of(context).push(AddEditMoviePage.routeEdit(movie)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MovieCoverImage(
                pathOrUrl: movie.coverImagePath,
                size: coverSize,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 23 : 28,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      movie.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 17,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in movie.tags.take(6))
                          _buildMovieTag(tag),
                        if (movie.tags.length > 6)
                          _buildMovieTag('+${movie.tags.length - 6}'),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_MovieMenuAction>(
                tooltip: 'Movie actions',
                color: _surfaceColor,
                surfaceTintColor: Colors.transparent,
                icon: const Icon(Icons.more_horiz, color: _mutedText),
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
                      Navigator.of(context)
                          .push(AddEditMoviePage.routeEdit(movie));
                    case _MovieMenuAction.delete:
                      _confirmDelete(context, ref, movie);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
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
      backgroundColor: _pageBackground,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogo(size: 22),
            SizedBox(width: 10),
            Text('Закладки'),
          ],
        ),
        actions: [
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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x775E66FF),
                blurRadius: 26,
                spreadRadius: 1,
              ),
            ],
          ),
          child: FloatingActionButton(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onPressed: _aiAddingInProgress ? null : _showAddMovieOptions,
            child: _aiAddingInProgress
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add, size: 34),
          ),
        ),
      ),
      body: SafeArea(
        child: moviesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _accent),
          ),
          error: (e, _) => Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _surfaceBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Failed to load bookmarks',
                    style: TextStyle(color: Colors.white),
                  ),
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
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final outerPadding = wide ? 24.0 : 14.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1260),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        outerPadding,
                        18,
                        outerPadding,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Movie bookmarks',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: wide ? 44 : 34,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              _buildToolbarButton(
                                semanticsLabel: 'Log out',
                                tooltip: 'Log out',
                                icon: Icons.logout_outlined,
                                onPressed: _logout,
                              ),
                              _buildToolbarButton(
                                semanticsLabel: 'AI add movie from image',
                                tooltip: 'AI add from image',
                                icon: Icons.grid_view_rounded,
                                onPressed: _aiAddingInProgress
                                    ? null
                                    : _showAddMovieOptions,
                              ),
                              Semantics(
                                label: 'Change sorting',
                                button: true,
                                child: PopupMenuButton<MovieSortOption>(
                                  tooltip: 'Sort',
                                  initialValue: sort,
                                  color: _surfaceColor,
                                  surfaceTintColor: Colors.transparent,
                                  icon: const Icon(
                                    Icons.swap_vert_rounded,
                                    color: _mutedText,
                                  ),
                                  onSelected: (value) => ref
                                      .read(movieSortOptionProvider.notifier)
                                      .state = value,
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
                                      label: 'Title A-Z',
                                    ),
                                    _sortMenuItem(
                                      value: MovieSortOption.titleDesc,
                                      label: 'Title Z-A',
                                    ),
                                  ],
                                ),
                              ),
                              _buildToolbarButton(
                                semanticsLabel: 'Clear tag filters',
                                tooltip: 'Clear filters',
                                icon: Icons.filter_alt_outlined,
                                onPressed: selectedTags.isEmpty
                                    ? null
                                    : () => ref
                                        .read(
                                          selectedTagFiltersProvider.notifier,
                                        )
                                        .state = <String>{},
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            decoration: BoxDecoration(
                              color: _surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search',
                                hintStyle: const TextStyle(
                                  color: _mutedText,
                                  fontSize: 20,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: _mutedText,
                                ),
                                suffixIcon: searchQuery.trim().isEmpty
                                    ? null
                                    : Semantics(
                                        label: 'Clear search',
                                        button: true,
                                        child: IconButton(
                                          tooltip: 'Clear',
                                          onPressed: () =>
                                              _searchController.clear(),
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            color: _mutedText,
                                          ),
                                        ),
                                      ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          if (availableTags.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final tag in availableTags)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(tag),
                                        selected: selectedTags.contains(tag),
                                        side: const BorderSide(
                                          color: _surfaceBorder,
                                        ),
                                        labelStyle: const TextStyle(
                                          color: _mutedText,
                                        ),
                                        backgroundColor: _surfaceColor,
                                        selectedColor: const Color(0x335E66FF),
                                        onSelected: (selected) {
                                          final next = {...selectedTags};
                                          if (selected) {
                                            next.add(tag);
                                          } else {
                                            next.remove(tag);
                                          }
                                          ref
                                              .read(
                                                selectedTagFiltersProvider
                                                    .notifier,
                                              )
                                              .state = next;
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${movies.length} result${movies.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: _mutedText,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Text(
                                _sortLabel(sort),
                                style: const TextStyle(
                                  color: _mutedText,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: movies.isEmpty
                                ? Center(
                                    child: Text(
                                      'No bookmarks yet',
                                      style: TextStyle(
                                        color: _mutedText.withAlpha(210),
                                        fontSize: 18,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    itemCount: movies.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 14),
                                    itemBuilder: (context, index) {
                                      final movie = movies[index];
                                      return _buildMovieCard(
                                        context: context,
                                        ref: ref,
                                        movie: movie,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

enum _MovieMenuAction { edit, delete }

enum _MovieImageSource { camera, gallery }

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
      return 'Sorted: title A-Z';
    case MovieSortOption.titleDesc:
      return 'Sorted: title Z-A';
  }
}

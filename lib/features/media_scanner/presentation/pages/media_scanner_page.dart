import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../widgets/app_logo.dart';
import '../../application/providers.dart';
import '../../domain/media_result.dart';
import 'media_result_details_page.dart';

class MediaScannerPage extends ConsumerStatefulWidget {
  const MediaScannerPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (context) => const MediaScannerPage(),
    );
  }

  @override
  ConsumerState<MediaScannerPage> createState() => _MediaScannerPageState();
}

class _MediaScannerPageState extends ConsumerState<MediaScannerPage> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(mediaScannerControllerProvider).query;
    _queryController = TextEditingController(text: initial);
    _queryController.addListener(() {
      ref.read(mediaScannerControllerProvider.notifier).setQuery(
            _queryController.text,
          );
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(mediaScannerControllerProvider.notifier);
    final state = ref.watch(mediaScannerControllerProvider);

    if (_queryController.text != state.query) {
      _queryController.value = _queryController.value.copyWith(
        text: state.query,
        selection: TextSelection.collapsed(offset: state.query.length),
        composing: TextRange.empty,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogo(size: 22),
            SizedBox(width: 10),
            Text('Сканер'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => controller.clear(),
            tooltip: 'Очистить',
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Фото или скриншот',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _ImageCard(
              bytes: state.imageBytes,
              label: state.imageLabel,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: controller.pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Галерея'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.pickFromCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Камера'),
                ),
                FilledButton.tonalIcon(
                  onPressed: state.imageBytes == null || state.isOcrRunning
                      ? null
                      : controller.runOcr,
                  icon: kIsWeb
                      ? const Icon(Icons.info_outline)
                      : const Icon(Icons.document_scanner_outlined),
                  label: kIsWeb ? const Text('OCR недоступен') : const Text('OCR'),
                ),
              ],
            ),
            if (state.ocrText.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _OcrPreviewCard(
                text: state.ocrText,
                onCopy: () async {
                  await Clipboard.setData(
                    ClipboardData(text: state.ocrText),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Текст скопирован')),
                    );
                },
                onUseForSearch: () {
                  final guessed = _guessTitleForUi(state.ocrText);
                  if (guessed.isEmpty) return;
                  _queryController.text = guessed;
                  _queryController.selection = TextSelection.collapsed(
                    offset: guessed.length,
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Поиск по названию',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                labelText: 'Название',
                hintText: 'Например: Naruto / Interstellar',
                prefixIcon: const Icon(Icons.search_outlined),
                suffixIcon: IconButton(
                  onPressed: () => _queryController.clear(),
                  icon: const Icon(Icons.clear),
                  tooltip: 'Очистить',
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => controller.search(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.isSearching ? null : controller.search,
              icon: state.isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore_outlined),
              label: Text(state.isSearching ? 'Ищу...' : 'Найти'),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 120),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 70),
                  ),
                ),
                child: Text(
                  state.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Результаты',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (!state.isSearching && state.results.isEmpty)
              Text(
                'Сначала выберите картинку и/или введите название — затем нажмите "Найти".',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            for (final r in state.results) _ResultTile(result: r),
          ],
        ),
      ),
    );
  }
}

String _guessTitleForUi(String ocrText) {
  final cleaned = ocrText
      .replaceAll(RegExp(r'[|]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (cleaned.isEmpty) return '';

  final lines = ocrText
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.length >= 3)
      .toList();

  if (lines.isEmpty) return cleaned;

  lines.sort((a, b) => b.length.compareTo(a.length));
  return lines.first;
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.bytes, required this.label});

  final Uint8List? bytes;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageBytes = bytes;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.image_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label?.isNotEmpty == true ? label! : 'Картинка не выбрана',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageBytes == null
                    ? Container(
                        color: colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          color: colorScheme.onSurfaceVariant,
                          size: 40,
                        ),
                      )
                    : Image.memory(imageBytes, fit: BoxFit.cover),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrPreviewCard extends StatefulWidget {
  const _OcrPreviewCard({
    required this.text,
    required this.onCopy,
    required this.onUseForSearch,
  });

  final String text;
  final VoidCallback onCopy;
  final VoidCallback onUseForSearch;

  @override
  State<_OcrPreviewCard> createState() => _OcrPreviewCardState();
}

class _OcrPreviewCardState extends State<_OcrPreviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final text = widget.text.trim();
    final preview = text.length > 160 ? '${text.substring(0, 160)}…' : text;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.text_snippet_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Распознанный текст',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  tooltip: _expanded ? 'Свернуть' : 'Развернуть',
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedCrossFade(
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 160),
              firstChild: Text(
                preview,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              secondChild: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: widget.onUseForSearch,
                  icon: const Icon(Icons.auto_fix_high_outlined),
                  label: const Text('Вставить в поиск'),
                ),
                FilledButton.tonalIcon(
                  onPressed: widget.onCopy,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Копировать'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final MediaResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final year = result.yearLabel;
    final genres = result.genres.take(3).join(', ');

    return Card(
      elevation: 0,
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MediaResultDetailsPage.route(result),
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: result.imageUrl == null || result.imageUrl!.isEmpty
                ? Container(
                    color: colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      result.kind == MediaKind.anime
                          ? Icons.auto_awesome_outlined
                          : Icons.local_movies_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : Image.network(
                    result.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
        ),
        title: Text(
          result.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (year.isNotEmpty) year,
            if (genres.isNotEmpty) genres,
            result.source,
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          result.kind == MediaKind.anime
              ? Icons.tv_outlined
              : Icons.movie_outlined,
        ),
      ),
    );
  }
}

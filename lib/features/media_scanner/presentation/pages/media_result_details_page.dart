import 'package:flutter/material.dart';

import '../../domain/media_result.dart';

class MediaResultDetailsPage extends StatelessWidget {
  const MediaResultDetailsPage({super.key, required this.result});

  final MediaResult result;

  static Route<void> route(MediaResult result) {
    return MaterialPageRoute<void>(
      builder: (context) => MediaResultDetailsPage(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final year = result.yearLabel;
    final genres = result.genres.isEmpty ? '' : result.genres.join(', ');

    return Scaffold(
      appBar: AppBar(
        title: Text(result.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (result.imageUrl != null && result.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    result.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            if (result.imageUrl != null && result.imageUrl!.isNotEmpty)
              const SizedBox(height: 16),
            Text(
              result.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (year.isNotEmpty) Chip(label: Text('Год: $year')),
                Chip(label: Text('Источник: ${result.source}')),
                Chip(
                  label: Text(
                    result.kind == MediaKind.anime ? 'Аниме' : 'Фильм',
                  ),
                ),
                if (genres.isNotEmpty) Chip(label: Text(genres)),
              ],
            ),
            const SizedBox(height: 12),
            if (result.description != null && result.description!.trim().isNotEmpty)
              Text(result.description!.trim()),
            if (result.linkUrl != null && result.linkUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Ссылка:',
                style: theme.textTheme.titleMedium,
              ),
              SelectableText(result.linkUrl!.trim()),
            ],
          ],
        ),
      ),
    );
  }
}


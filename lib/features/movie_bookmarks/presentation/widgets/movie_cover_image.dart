import 'package:flutter/material.dart';

import 'movie_file_image.dart';

class MovieCoverImage extends StatelessWidget {
  final String? pathOrUrl;
  final double size;

  const MovieCoverImage({
    super.key,
    required this.pathOrUrl,
    required this.size,
  });

  bool _isNetwork(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final value = (pathOrUrl ?? '').trim();
    final borderRadius = BorderRadius.circular(12);

    Widget placeholder() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: colorScheme.surfaceContainerHighest,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.movie_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (value.isEmpty) return placeholder();

    Widget image;
    if (_isNetwork(value)) {
      image = Image.network(
        value,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    } else {
      image = buildMovieFileImage(
        path: value,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: placeholder,
      );
    }

    return ClipRRect(borderRadius: borderRadius, child: image);
  }
}

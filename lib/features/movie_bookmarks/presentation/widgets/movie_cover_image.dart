import 'package:flutter/material.dart';

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

  String _extractUrlFromHtmlLike(String value) {
    final sourceAttrPattern = RegExp(
      r'''(?:src|href)\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    final sourceAttrMatch = sourceAttrPattern.firstMatch(value);
    if (sourceAttrMatch != null) {
      return sourceAttrMatch.group(1)?.trim() ?? value;
    }

    final plainUrlPattern = RegExp(
      r'''https?:\/\/[^\s"'<>]+''',
      caseSensitive: false,
    );
    final plainUrlMatch = plainUrlPattern.firstMatch(value);
    if (plainUrlMatch != null) {
      return plainUrlMatch.group(0)?.trim() ?? value;
    }

    return value;
  }

  String _normalizeSource(String value) {
    final raw = _extractUrlFromHtmlLike(value).trim();
    if (raw.isEmpty) return '';

    final unquoted = ((raw.startsWith('"') && raw.endsWith('"')) ||
            (raw.startsWith("'") && raw.endsWith("'")))
        ? raw.substring(1, raw.length - 1).trim()
        : raw;

    final unescaped = unquoted.replaceAll(r'\/', '/').replaceAll('&amp;', '&');

    String candidate = unescaped;
    if (candidate.startsWith('//')) {
      candidate = 'https:$candidate';
    } else if (candidate.startsWith('www.') ||
        candidate.startsWith('films.pladzuma.com')) {
      candidate = 'https://$candidate';
    }

    final extracted = _extractWrappedUrl(candidate);
    if (extracted != null) {
      candidate = extracted;
    }

    final uri = Uri.tryParse(candidate);
    if (uri != null && uri.scheme.toLowerCase() == 'http') {
      return uri.replace(scheme: 'https').toString();
    }

    return candidate;
  }

  String? _extractWrappedUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    for (final key in const ['imgurl', 'url', 'mediaurl', 'u']) {
      final wrapped = uri.queryParameters[key]?.trim();
      if (wrapped == null || wrapped.isEmpty) continue;
      final decoded = Uri.decodeFull(wrapped);
      if (_isNetwork(decoded)) return decoded;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final url = _normalizeSource((pathOrUrl ?? '').trim());
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

    if (url.isEmpty || !_isNetwork(url)) return placeholder();

    final image = Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      errorBuilder: (_, __, ___) => placeholder(),
    );

    return ClipRRect(borderRadius: borderRadius, child: image);
  }
}

enum MediaKind {
  anime,
  movie,
}

class MediaResult {
  const MediaResult({
    required this.kind,
    required this.title,
    required this.source,
    this.year,
    this.genres = const [],
    this.description,
    this.imageUrl,
    this.linkUrl,
  });

  final MediaKind kind;
  final String title;
  final int? year;
  final List<String> genres;
  final String? description;
  final String? imageUrl;
  final String? linkUrl;
  final String source;

  String get yearLabel => year == null ? '' : year.toString();
}


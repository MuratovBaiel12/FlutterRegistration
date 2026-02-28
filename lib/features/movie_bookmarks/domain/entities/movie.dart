class Movie {
  final String id;
  final String title;
  final String description;
  final String? notes;
  final List<String> tags;
  final String? coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Movie({
    required this.id,
    required this.title,
    required this.description,
    required this.notes,
    required this.tags,
    required this.coverImagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  Movie copyWith({
    String? title,
    String? description,
    String? notes,
    List<String>? tags,
    String? coverImagePath,
    DateTime? updatedAt,
  }) {
    return Movie(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Movie(id: $id, title: $title)';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Movie &&
            other.id == id &&
            other.title == title &&
            other.description == description &&
            other.notes == notes &&
            _listEquals(other.tags, tags) &&
            other.coverImagePath == coverImagePath &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        notes,
        Object.hashAll(tags),
        coverImagePath,
        createdAt,
        updatedAt,
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}


import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/media_result.dart';

class ItunesMovieProvider {
  const ItunesMovieProvider({required http.Client client}) : _client = client;

  final http.Client _client;

  Future<List<MediaResult>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final uri = Uri.https(
      'itunes.apple.com',
      '/search',
      <String, String>{
        'term': normalized,
        'media': 'movie',
        'entity': 'movie',
        'limit': '10',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('iTunes error ${response.statusCode}');
    }

    final jsonBody = jsonDecode(response.body);
    final resultsRaw =
        jsonBody is Map<String, dynamic> ? jsonBody['results'] : null;
    if (resultsRaw is! List) return const [];

    final results = <MediaResult>[];
    for (final item in resultsRaw) {
      if (item is! Map) continue;

      final title = (item['trackName'] ?? '').toString().trim();
      if (title.isEmpty) continue;

      int? year;
      final releaseDate = item['releaseDate']?.toString();
      if (releaseDate != null && releaseDate.length >= 4) {
        year = int.tryParse(releaseDate.substring(0, 4));
      }

      final genre = item['primaryGenreName']?.toString().trim();
      final genres = <String>[];
      if (genre != null && genre.isNotEmpty) genres.add(genre);

      results.add(
        MediaResult(
          kind: MediaKind.movie,
          title: title,
          year: year,
          genres: genres,
          description: (item['longDescription'] ?? item['shortDescription'])
              ?.toString(),
          imageUrl: item['artworkUrl100']?.toString(),
          linkUrl: item['trackViewUrl']?.toString(),
          source: 'iTunes',
        ),
      );
    }

    return results;
  }
}


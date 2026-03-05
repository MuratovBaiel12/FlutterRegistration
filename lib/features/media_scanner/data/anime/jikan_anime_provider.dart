import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/media_result.dart';

class JikanAnimeProvider {
  const JikanAnimeProvider({required http.Client client}) : _client = client;

  final http.Client _client;

  Future<List<MediaResult>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final uri = Uri.https(
      'api.jikan.moe',
      '/v4/anime',
      <String, String>{
        'q': normalized,
        'limit': '10',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Jikan error ${response.statusCode}');
    }

    final jsonBody = jsonDecode(response.body);
    final data = jsonBody is Map<String, dynamic> ? jsonBody['data'] : null;
    if (data is! List) return const [];

    final results = <MediaResult>[];
    for (final item in data) {
      if (item is! Map) continue;
      final title = (item['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;

      final yearValue = item['year'];
      final year = yearValue is int ? yearValue : int.tryParse('$yearValue');

      final genres = <String>[];
      final genresRaw = item['genres'];
      if (genresRaw is List) {
        for (final g in genresRaw) {
          if (g is Map && g['name'] != null) {
            final name = g['name'].toString().trim();
            if (name.isNotEmpty) genres.add(name);
          }
        }
      }

      String? imageUrl;
      final images = item['images'];
      if (images is Map) {
        final jpg = images['jpg'];
        if (jpg is Map && jpg['image_url'] != null) {
          imageUrl = jpg['image_url'].toString();
        }
      }

      results.add(
        MediaResult(
          kind: MediaKind.anime,
          title: title,
          year: year,
          genres: genres,
          description: item['synopsis']?.toString(),
          imageUrl: imageUrl,
          linkUrl: item['url']?.toString(),
          source: 'Jikan',
        ),
      );
    }

    return results;
  }
}


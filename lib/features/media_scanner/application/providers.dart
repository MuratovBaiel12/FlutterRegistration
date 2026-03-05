import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../data/anime/jikan_anime_provider.dart';
import '../data/movies/itunes_movie_provider.dart';
import 'media_scanner_controller.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

final jikanAnimeProvider = Provider<JikanAnimeProvider>(
  (ref) => JikanAnimeProvider(client: ref.watch(httpClientProvider)),
);

final itunesMovieProvider = Provider<ItunesMovieProvider>(
  (ref) => ItunesMovieProvider(client: ref.watch(httpClientProvider)),
);

final mediaScannerControllerProvider =
    StateNotifierProvider<MediaScannerController, MediaScannerState>((ref) {
  return MediaScannerController(
    imagePicker: ref.watch(imagePickerProvider),
    jikan: ref.watch(jikanAnimeProvider),
    itunes: ref.watch(itunesMovieProvider),
  );
});


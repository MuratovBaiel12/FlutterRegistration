import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../data/anime/jikan_anime_provider.dart';
import '../data/movies/itunes_movie_provider.dart';
import '../domain/media_result.dart';

class MediaScannerState {
  const MediaScannerState({
    this.imageBytes,
    this.imageLabel,
    this.imagePath,
    this.ocrText = '',
    this.query = '',
    this.isOcrRunning = false,
    this.isSearching = false,
    this.results = const [],
    this.errorMessage,
  });

  final Uint8List? imageBytes;
  final String? imageLabel;
  final String? imagePath;
  final String ocrText;
  final String query;
  final bool isOcrRunning;
  final bool isSearching;
  final List<MediaResult> results;
  final String? errorMessage;

  MediaScannerState copyWith({
    Uint8List? imageBytes,
    String? imageLabel,
    String? imagePath,
    String? ocrText,
    String? query,
    bool? isOcrRunning,
    bool? isSearching,
    List<MediaResult>? results,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MediaScannerState(
      imageBytes: imageBytes ?? this.imageBytes,
      imageLabel: imageLabel ?? this.imageLabel,
      imagePath: imagePath ?? this.imagePath,
      ocrText: ocrText ?? this.ocrText,
      query: query ?? this.query,
      isOcrRunning: isOcrRunning ?? this.isOcrRunning,
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MediaScannerController extends StateNotifier<MediaScannerState> {
  MediaScannerController({
    required ImagePicker imagePicker,
    required JikanAnimeProvider jikan,
    required ItunesMovieProvider itunes,
  })  : _imagePicker = imagePicker,
        _jikan = jikan,
        _itunes = itunes,
        super(const MediaScannerState());

  final ImagePicker _imagePicker;
  final JikanAnimeProvider _jikan;
  final ItunesMovieProvider _itunes;

  void setQuery(String value) {
    state = state.copyWith(query: value, clearError: true);
  }

  Future<void> pickFromGallery() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    await _setPickedImage(file);
  }

  Future<void> pickFromCamera() async {
    final file = await _imagePicker.pickImage(source: ImageSource.camera);
    await _setPickedImage(file);
  }

  Future<void> clear() async {
    state = const MediaScannerState();
  }

  Future<void> _setPickedImage(XFile? file) async {
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      state = state.copyWith(
        imageBytes: bytes,
        imageLabel: file.name,
        imagePath: file.path,
        ocrText: '',
        results: const [],
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Не удалось прочитать файл: $e');
    }
  }

  Future<void> runOcr() async {
    if (kIsWeb) {
      state = state.copyWith(
        errorMessage:
            'OCR (ML Kit) не поддерживается в Web. Введите название вручную.',
      );
      return;
    }

    final path = state.imagePath;
    if (path == null || path.isEmpty) {
      state = state.copyWith(errorMessage: 'Сначала выберите фото/скрин.');
      return;
    }

    state = state.copyWith(isOcrRunning: true, clearError: true);

    final recognizer = TextRecognizer();
    try {
      final input = InputImage.fromFilePath(path);
      final recognized = await recognizer.processImage(input);
      final text = recognized.text.trim();
      final guessed = _guessTitle(text);

      state = state.copyWith(
        isOcrRunning: false,
        ocrText: text,
        query: guessed.isNotEmpty ? guessed : state.query,
      );
    } catch (e) {
      state = state.copyWith(
        isOcrRunning: false,
        errorMessage: 'Ошибка OCR: $e',
      );
    } finally {
      await recognizer.close();
    }
  }

  Future<void> search() async {
    final query = state.query.trim();
    if (query.isEmpty) {
      state = state.copyWith(errorMessage: 'Введите название для поиска.');
      return;
    }

    state = state.copyWith(
      isSearching: true,
      results: const [],
      clearError: true,
    );

    try {
      final merged = <MediaResult>[];
      final warnings = <String>[];

      try {
        merged.addAll(await _jikan.search(query));
      } catch (e) {
        warnings.add('Аниме: $e');
      }

      try {
        merged.addAll(await _itunes.search(query));
      } catch (e) {
        warnings.add('Фильмы: $e');
      }

      if (merged.isEmpty && warnings.isNotEmpty) {
        state = state.copyWith(
          isSearching: false,
          errorMessage: warnings.join('\n'),
        );
        return;
      }

      state = state.copyWith(
        isSearching: false,
        results: merged,
        errorMessage: warnings.isEmpty ? null : warnings.join('\n'),
      );
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        errorMessage: 'Ошибка поиска: $e',
      );
    }
  }

  String _guessTitle(String ocrText) {
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
}

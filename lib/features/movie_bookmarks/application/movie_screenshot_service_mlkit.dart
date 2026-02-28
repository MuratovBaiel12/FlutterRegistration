import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'movie_screenshot_service.dart';

MovieScreenshotService createMovieScreenshotServiceImpl() =>
    _MlKitMovieScreenshotService();

class _MlKitMovieScreenshotService implements MovieScreenshotService {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  @override
  Future<List<String>> extractTextLines(String imagePath) async {
    try {
      final input = InputImage.fromFilePath(imagePath);
      final recognized = await _recognizer.processImage(input);
      final lines = <String>[];

      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final t = line.text.trim();
          if (t.isEmpty) continue;
          lines.add(t);
        }
      }

      return lines;
    } on MissingPluginException catch (e) {
      throw UnsupportedError('Screenshot recognition plugin not available: $e');
    }
  }

  @override
  void dispose() {
    _recognizer.close();
  }
}


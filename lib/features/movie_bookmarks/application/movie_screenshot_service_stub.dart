import 'movie_screenshot_service.dart';

MovieScreenshotService createMovieScreenshotServiceImpl() =>
    _UnsupportedMovieScreenshotService();

class _UnsupportedMovieScreenshotService implements MovieScreenshotService {
  @override
  Future<List<String>> extractTextLines(String imagePath) async {
    throw UnsupportedError('Screenshot recognition is not supported here.');
  }

  @override
  void dispose() {}
}


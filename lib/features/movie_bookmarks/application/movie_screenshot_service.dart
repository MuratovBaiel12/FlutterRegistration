import 'movie_screenshot_service_stub.dart'
    if (dart.library.io) 'movie_screenshot_service_mlkit.dart';

abstract class MovieScreenshotService {
  Future<List<String>> extractTextLines(String imagePath);
  void dispose();
}

MovieScreenshotService createMovieScreenshotService() =>
    createMovieScreenshotServiceImpl();


import 'package:flutter/widgets.dart';

import 'movie_file_image_stub.dart'
    if (dart.library.io) 'movie_file_image_io.dart';

Widget buildMovieFileImage({
  required String path,
  required double width,
  required double height,
  required BoxFit fit,
  required Widget Function() placeholder,
}) {
  return buildMovieFileImageImpl(
    path: path,
    width: width,
    height: height,
    fit: fit,
    placeholder: placeholder,
  );
}


import 'dart:io';

import 'package:flutter/widgets.dart';

Widget buildMovieFileImageImpl({
  required String path,
  required double width,
  required double height,
  required BoxFit fit,
  required Widget Function() placeholder,
}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => placeholder(),
  );
}


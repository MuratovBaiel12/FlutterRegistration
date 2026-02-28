import 'package:flutter/widgets.dart';

Widget buildMovieFileImageImpl({
  required String path,
  required double width,
  required double height,
  required BoxFit fit,
  required Widget Function() placeholder,
}) {
  return SizedBox(width: width, height: height, child: placeholder());
}


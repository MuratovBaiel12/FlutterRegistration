import 'package:hive/hive.dart';

import '../../domain/entities/movie.dart';

class MovieModel {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final String title;
  final String description;
  final String? notes;
  final List<String> tags;
  final String? coverImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MovieModel({
    this.schemaVersion = currentSchemaVersion,
    required this.id,
    required this.title,
    required this.description,
    required this.notes,
    required this.tags,
    required this.coverImagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MovieModel.fromEntity(Movie movie) {
    return MovieModel(
      id: movie.id,
      title: movie.title,
      description: movie.description,
      notes: movie.notes,
      tags: List<String>.unmodifiable(movie.tags),
      coverImagePath: movie.coverImagePath,
      createdAt: movie.createdAt,
      updatedAt: movie.updatedAt,
    );
  }

  Movie toEntity() {
    return Movie(
      id: id,
      title: title,
      description: description,
      notes: notes,
      tags: List<String>.unmodifiable(tags),
      coverImagePath: coverImagePath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class MovieModelAdapter extends TypeAdapter<MovieModel> {
  @override
  final int typeId = 10;

  @override
  MovieModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      final fieldKey = reader.readByte();
      fields[fieldKey] = reader.read();
    }

    final schemaVersion =
        (fields[0] as int?) ?? MovieModel.currentSchemaVersion;

    final id = (fields[1] as String?) ?? '';
    final title = (fields[2] as String?) ?? '';
    final description = (fields[3] as String?) ?? '';
    final notes = fields[4] as String?;
    final tags = (fields[5] as List?)?.cast<String>() ?? const <String>[];
    final coverImagePath = fields[6] as String?;
    final createdAt = (fields[7] as DateTime?) ?? DateTime.now();
    final updatedAt = (fields[8] as DateTime?) ?? createdAt;

    return MovieModel(
      schemaVersion: schemaVersion,
      id: id,
      title: title,
      description: description,
      notes: notes,
      tags: List<String>.unmodifiable(tags),
      coverImagePath: coverImagePath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  void write(BinaryWriter writer, MovieModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.schemaVersion)
      ..writeByte(1)
      ..write(obj.id)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.coverImagePath)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovieModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}


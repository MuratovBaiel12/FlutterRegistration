import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/providers.dart';
import '../../domain/entities/movie.dart';
import '../widgets/movie_cover_image.dart';

class AddEditMoviePage extends ConsumerStatefulWidget {
  final Movie? movie;
  final String? prefillTitle;

  const AddEditMoviePage({super.key, this.movie, this.prefillTitle});

  static Route<void> routeAdd({String? prefillTitle}) {
    return MaterialPageRoute(
      builder: (_) => AddEditMoviePage(prefillTitle: prefillTitle),
    );
  }

  static Route<void> routeEdit(Movie movie) {
    return MaterialPageRoute(builder: (_) => AddEditMoviePage(movie: movie));
  }

  @override
  ConsumerState<AddEditMoviePage> createState() => _AddEditMoviePageState();
}

class _AddEditMoviePageState extends ConsumerState<AddEditMoviePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _coverController = TextEditingController();
  final _tagController = TextEditingController();

  final _picker = ImagePicker();

  bool _saving = false;
  final List<String> _tags = <String>[];

  bool get _isEdit => widget.movie != null;

  @override
  void initState() {
    super.initState();
    final movie = widget.movie;
    if (movie != null) {
      _titleController.text = movie.title;
      _descriptionController.text = movie.description;
      _notesController.text = movie.notes ?? '';
      _coverController.text = movie.coverImagePath ?? '';
      _tags.addAll(movie.tags);
    } else if ((widget.prefillTitle ?? '').trim().isNotEmpty) {
      _titleController.text = widget.prefillTitle!.trim();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _coverController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      setState(() {
        _coverController.text = picked.path;
      });
    } catch (e) {
      _showError(e);
    }
  }

  List<String> _titleCandidatesFromLines(List<String> lines) {
    final normalized = <String>[];
    for (final raw in lines) {
      final t = raw.trim();
      if (t.length < 2) continue;
      if (t.length > 120) continue;
      final hasLetter = RegExp(r'[A-Za-zА-Яа-я]').hasMatch(t);
      if (!hasLetter) continue;
      if (!normalized.contains(t)) {
        normalized.add(t);
      }
      if (normalized.length >= 12) break;
    }
    return normalized;
  }

  Future<void> _scanScreenshotForTitle() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final service = ref.read(movieScreenshotServiceProvider);
      final lines = await service.extractTextLines(picked.path);
      final candidates = _titleCandidatesFromLines(lines);
      if (!mounted) return;

      if (candidates.isEmpty) {
        _showError('No readable title found in the screenshot');
        return;
      }

      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Select detected title',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                for (final c in candidates)
                  ListTile(
                    title: Text(
                      c,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).pop(c),
                  ),
              ],
            ),
          );
        },
      );

      if (!mounted) return;
      if (selected == null) return;

      setState(() {
        _titleController.text = selected;
      });
    } on UnsupportedError catch (e) {
      _showError(e);
    } on Object catch (e) {
      _showError(e);
    }
  }

  void _addTag() {
    final raw = _tagController.text;
    final tag = raw.trim();
    if (tag.isEmpty) return;

    if (_tags.length >= 20) {
      _showError('Maximum 20 tags per movie');
      return;
    }

    if (!_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
      });
    }

    _tagController.clear();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_tags.isEmpty) {
      _showError('Please add at least 1 tag');
      return;
    }

    setState(() => _saving = true);
    final service = ref.read(movieServiceProvider);

    try {
      if (_isEdit) {
        await service.updateMovie(
          existing: widget.movie!,
          title: _titleController.text,
          description: _descriptionController.text,
          notes: _notesController.text,
          tags: _tags,
          coverImagePath: _coverController.text,
        );
      } else {
        await service.addMovie(
          title: _titleController.text,
          description: _descriptionController.text,
          notes: _notesController.text,
          tags: _tags,
          coverImagePath: _coverController.text,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverValue = _coverController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit movie' : 'Add movie'),
        actions: [
          Semantics(
            label: 'Save movie',
            button: true,
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  MovieCoverImage(pathOrUrl: coverValue, size: 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _coverController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Cover image path or URL (optional)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'Pick cover image from gallery',
                    button: true,
                    child: IconButton(
                      onPressed: _pickFromGallery,
                      tooltip: 'Pick from gallery',
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                  ),
                  Semantics(
                    label: 'Scan screenshot to detect title',
                    button: true,
                    child: IconButton(
                      onPressed: _scanScreenshotForTitle,
                      tooltip: 'Scan screenshot',
                      icon: const Icon(Icons.document_scanner_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Title is required';
                  if (t.length > 120) return 'Max 120 chars';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLength: 2000,
                minLines: 3,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Description is required';
                  if (t.length > 2000) return 'Max 2000 chars';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLength: 1000,
                minLines: 2,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length > 1000) return 'Max 1000 chars';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Tags',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _tags)
                    InputChip(
                      label: Text(tag),
                      onDeleted: () => _removeTag(tag),
                      deleteButtonTooltipMessage: 'Remove tag',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addTag(),
                      decoration: const InputDecoration(
                        labelText: 'Add tag',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'Add tag',
                    button: true,
                    child: FilledButton(
                      onPressed: _addTag,
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save movie'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

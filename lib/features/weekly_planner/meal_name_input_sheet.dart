import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/recipe.dart';
import '../../data/services/mock_recipe_dataset.dart';

/// Kullanıcının öğün ekleme sheet'inden dönebileceği iki yoldan biri:
/// metinle yemek adı veya fotoğraftan tarif.
class MealInputResult {
  const MealInputResult._({this.mealName, this.photoBytes, this.photoMimeType});

  factory MealInputResult.fromName(String name) => MealInputResult._(mealName: name);

  factory MealInputResult.fromPhoto({
    required Uint8List bytes,
    required String mimeType,
  }) =>
      MealInputResult._(photoBytes: bytes, photoMimeType: mimeType);

  final String? mealName;
  final Uint8List? photoBytes;
  final String? photoMimeType;

  bool get isPhoto => photoBytes != null && photoBytes!.isNotEmpty;
}

/// Kullanıcıya "Bu öğün için ne pişireceksin?" diye soran, alttan açılan
/// (bottom sheet) form. İki yol sunar:
/// 1) Yemek adı yaz / hızlı seçim çipleri
/// 2) Kameradan çek veya galeriden seç → fotoğraftan tarif
Future<MealInputResult?> showMealNameInputSheet(
  BuildContext context, {
  required MealType mealType,
}) {
  return showModalBottomSheet<MealInputResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
      ),
      child: _MealNameForm(mealType: mealType),
    ),
  );
}

class _MealNameForm extends StatefulWidget {
  const _MealNameForm({required this.mealType});

  final MealType mealType;

  @override
  State<_MealNameForm> createState() => _MealNameFormState();
}

class _MealNameFormState extends State<_MealNameForm> {
  final _controller = TextEditingController();
  bool _isPickingPhoto = false;

  static final List<String> _suggestions =
      mockRecipeDataset.map((dish) => dish['title'] as String).toList();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitName([String? value]) {
    final text = value ?? _controller.text;
    if (text.trim().isEmpty) return;
    Navigator.of(context).pop(MealInputResult.fromName(text.trim()));
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _isPickingPhoto = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || !mounted) return;

      final pathLower = file.path.toLowerCase();
      final mimeType = pathLower.endsWith('.png')
          ? 'image/png'
          : pathLower.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';

      Navigator.of(context).pop(
        MealInputResult.fromPhoto(bytes: bytes, mimeType: mimeType),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf seçilemedi. Lütfen tekrar dene.')),
      );
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.mealType.displayName} için ne pişiriyorsun?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Bir yemek adı yaz, popüler tariflerden seç veya fotoğraftan tarif oluştur.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: _submitName,
          decoration: const InputDecoration(
            hintText: 'Örn: Fırında Tavuk But',
            prefixIcon: Icon(Icons.restaurant_menu),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .map((title) => ActionChip(label: Text(title), onPressed: () => _submitName(title)))
              .toList(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'VEYA FOTOĞRAFTAN',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
            Expanded(child: Divider(color: AppColors.divider)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPickingPhoto ? null : () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Kamera'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPickingPhoto ? null : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeri'),
              ),
            ),
          ],
        ),
        if (_isPickingPhoto) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isPickingPhoto ? null : () => _submitName(),
            child: const Text('Tarifi Oluştur'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

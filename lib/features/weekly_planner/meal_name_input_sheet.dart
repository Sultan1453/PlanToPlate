import 'package:flutter/material.dart';

import '../../data/models/recipe.dart';
import '../../data/services/mock_recipe_dataset.dart';

/// Kullanıcıya "Bu öğün için ne pişireceksin?" diye soran, alttan açılan
/// (bottom sheet) basit bir form.
///
/// `mockRecipeDataset`teki 9 yemeğin isimlerini "hızlı seçim" çipleri
/// olarak gösteririz — bu sayede kullanıcı, henüz `.env` dosyasına gerçek
/// bir Gemini API anahtarı eklemediyse (Mock motor aktifken), hangi
/// isimlerin GARANTİ eşleşeceğini kolayca görür.
///
/// Döndürdüğü değer: kullanıcının yazdığı/seçtiği yemek adı, ya da
/// vazgeçtiyse `null`.
Future<String?> showMealNameInputSheet(
  BuildContext context, {
  required MealType mealType,
}) {
  return showModalBottomSheet<String>(
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

  // `mockRecipeDataset`teki her yemeğin sadece başlığını çekiyoruz; format
  // değişirse (Adım 3'te yazdığımız veri seti) bu liste otomatik güncel
  // kalır, elle senkronize etmeye gerek kalmaz.
  static final List<String> _suggestions =
      mockRecipeDataset.map((dish) => dish['title'] as String).toList();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    final text = value ?? _controller.text;
    if (text.trim().isEmpty) return;
    Navigator.of(context).pop(text.trim());
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
          'Bir yemek adı yaz ya da aşağıdaki popüler tariflerden birini seç.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
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
              .map((title) => ActionChip(label: Text(title), onPressed: () => _submit(title)))
              .toList(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _submit(),
            child: const Text('Tarifi Oluştur'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

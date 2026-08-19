import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/favorites_provider.dart';
import '../recipe_detail/recipe_detail_screen.dart';

/// Kaydedilmiş favori tarifler.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favori Tarifler')),
      body: favorites.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Henüz favori yok.\nTarif detayında kalp ikonuna dokunarak ekleyebilirsin.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final recipe = favorites[index];
                final minutes = recipe.prepTimeMinutes + recipe.cookTimeMinutes;
                return Card(
                  child: ListTile(
                    title: Text(recipe.title),
                    subtitle: Text(
                      '${recipe.mealType.displayName} · $minutes dk · ${recipe.servings} kişilik',
                    ),
                    trailing: IconButton(
                      tooltip: 'Favoriden çıkar',
                      icon: const Icon(Icons.favorite, color: Colors.redAccent),
                      onPressed: () =>
                          ref.read(favoritesProvider.notifier).remove(recipe.id),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => RecipeDetailScreen(recipe: recipe),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import '../panel/panel_widgets.dart';
import '../panel/category_editor.dart';
import '../panel/products_manager.dart';

class CategoriesManager extends StatelessWidget {
  const CategoriesManager({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoryModel>>(
      stream: Db.allCategories(),
      builder: (c, snap) {
        if (snap.hasError) return PanelPage(children: [EmptyState(emoji: '⚠️', title: 'Could not load categories', body: authErrorText(snap.error!))]);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final cats = snap.data!;
        return StreamBuilder<List<Product>>(
          stream: Db.allProducts(),
          builder: (c, ps) {
            final products = ps.data ?? const <Product>[];
            return PanelPage(children: [
              PageHeader(
                title: 'Categories',
                subtitle: 'Create categories with a photo. Every dish is added into one of these.',
                actions: [
                  ElevatedButton.icon(
                    onPressed: () => showCategoryEditor(context, nextOrder: cats.length),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New category'),
                  ),
                ],
              ),
              if (cats.isEmpty)
                PanelCard(
                  child: EmptyState(
                    emoji: '🗂️',
                    title: 'No categories yet',
                    body: 'Start with Biryani, Starters, Desserts… then add dishes into them.',
                    action: ElevatedButton(onPressed: () => showCategoryEditor(context, nextOrder: 0), child: const Text('Create category')),
                  ),
                )
              else
                ResponsiveGrid(minItemWidth: 250, children: [
                  for (final cat in cats)
                    _CategoryCard(
                      cat: cat,
                      dishes: products.where((p) => p.category == cat.name).toList(),
                      allCategories: cats,
                    ),
                ]),
            ]);
          },
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel cat;
  final List<Product> dishes;
  final List<CategoryModel> allCategories;
  const _CategoryCard({required this.cat, required this.dishes, required this.allCategories});

  @override
  Widget build(BuildContext context) {
    final cover = cat.imageUrl.isNotEmpty ? cat.imageUrl : dishes.where((d) => d.imageUrl.isNotEmpty).map((d) => d.imageUrl).firstOrNull ?? '';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: PK.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 140,
          child: Stack(fit: StackFit.expand, children: [
            Opacity(opacity: cat.active ? 1 : .45, child: SmartImage(url: cover, emoji: categoryEmoji(cat.name), emojiSize: 52)),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xAA000000)]))),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Text(cat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.display(22, color: Colors.white)),
            ),
            if (!cat.active) const Positioned(top: 10, left: 10, child: Pill('Hidden', color: PK.red, solid: true)),
            if (cat.imageUrl.isEmpty) const Positioned(top: 10, right: 10, child: Pill('No photo', color: PK.amber, solid: true)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(children: [
            Expanded(
              child: Text('${dishes.length} dish${dishes.length == 1 ? '' : 'es'} · #${cat.sortOrder}', style: AppTheme.body(13, color: PK.muted, weight: FontWeight.w600)),
            ),
            IconButton(
              tooltip: 'Add dish to ${cat.name}',
              onPressed: () => showProductEditor(context, isAdmin: true, initialCategory: cat.name),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 21, color: PK.green),
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: () => showCategoryEditor(context, existing: cat, nextOrder: cat.sortOrder),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () async {
                if (dishes.isNotEmpty) {
                  showToast(context, 'Move or delete the ${dishes.length} dishes in ${cat.name} first.', error: true);
                  return;
                }
                if (await confirmDialog(context, title: 'Delete ${cat.name}?', message: 'This category has no dishes.', confirm: 'Delete', destructive: true)) {
                  await Db.deleteCategory(cat.id);
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: PK.red),
            ),
          ]),
        ),
      ]),
    );
  }
}

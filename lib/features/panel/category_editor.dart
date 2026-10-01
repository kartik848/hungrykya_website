import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import 'products_manager.dart';

/// Create / edit a category. Returns the saved name.
Future<String?> showCategoryEditor(BuildContext context, {CategoryModel? existing, int nextOrder = 0}) {
  final name = TextEditingController(text: existing?.name);
  final sort = TextEditingController(text: '${existing?.sortOrder ?? nextOrder}');
  var image = existing?.imageUrl ?? '';
  var active = existing?.active ?? true;
  var uploading = false;
  var saving = false;
  final form = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(existing == null ? 'New category' : 'Edit category'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ImageField(
                  value: image,
                  height: 180,
                  maxWidth: 1000,
                  onChanged: (v) => setD(() => image = v),
                  onBusy: (v) => setD(() => uploading = v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: name,
                  autofocus: existing == null,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Category name', hintText: 'e.g. Biryani, Starters, Desserts'),
                  validator: (v) => validateRequired(v, 'Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: sort,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Display order', helperText: 'Lower numbers show first on the website'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show on website'),
                  value: active,
                  onChanged: (v) => setD(() => active = v),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: uploading || saving
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    setD(() => saving = true);
                    final n = name.text.trim();
                    try {
                      await Db.saveCategory(existing, {'name': n, 'imageUrl': image, 'sortOrder': int.tryParse(sort.text.trim()) ?? 0, 'active': active});
                      if (d.mounted) Navigator.pop(d, n);
                    } catch (e) {
                      setD(() => saving = false);
                      if (d.mounted) showToast(d, authErrorText(e), error: true);
                    }
                  },
            child: Text(uploading ? 'Uploading photo…' : (saving ? 'Saving…' : 'Save category')),
          ),
        ],
      ),
    ),
  );
}

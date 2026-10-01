import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../services/media.dart';
import '../../widgets/common.dart';
import 'category_editor.dart';
import 'panel_widgets.dart';

/// Menu management. Admin sees every kitchen; a vendor sees only their own items.
class ProductsManager extends StatefulWidget {
  final bool isAdmin;
  final String? vendorId;
  final String? vendorName;
  final List<Vendor> vendors;
  const ProductsManager({super.key, required this.isAdmin, this.vendorId, this.vendorName, this.vendors = const []});

  @override
  State<ProductsManager> createState() => _ProductsManagerState();
}

class _ProductsManagerState extends State<ProductsManager> {
  late final Stream<List<Product>> _stream = widget.isAdmin ? Db.allProducts() : Db.vendorProducts(widget.vendorId!);
  String _q = '';
  String _kitchen = 'all';
  bool _seeding = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: _stream,
      builder: (c, snap) {
        if (snap.hasError) return PanelPage(children: [EmptyState(emoji: '⚠️', title: 'Could not load menu', body: authErrorText(snap.error!))]);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final all = snap.data!;
        final categories = {for (final p in all) p.category}.toList()..sort();
        final kitchens = <String, String>{for (final p in all) p.vendorId: p.vendorName};
        final q = _q.trim().toLowerCase();
        final list = all.where((p) {
          if (_kitchen != 'all' && p.vendorId != _kitchen) return false;
          return q.isEmpty || p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q);
        }).toList();

        void openEditor([Product? p]) => showProductEditor(
              context,
              product: p,
              isAdmin: widget.isAdmin,
              vendorId: widget.vendorId,
              vendorName: widget.vendorName,
              vendors: widget.vendors,
              categories: categories,
            );

        return PanelPage(children: [
          PageHeader(
            title: 'Menu',
            subtitle: '${all.length} items · ${all.where((p) => p.isAvailable).length} in stock · ${all.where((p) => p.onSale).length} on sale',
            actions: [
              ElevatedButton.icon(onPressed: openEditor, icon: const Icon(Icons.add_rounded), label: const Text('Add item')),
            ],
          ),
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 340,
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(isDense: true, hintText: 'Search items or categories', prefixIcon: Icon(Icons.search_rounded)),
              ),
            ),
            if (widget.isAdmin && kitchens.length > 1)
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  value: _kitchen,
                  isDense: true,
                  decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.storefront_rounded)),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All kitchens')),
                    for (final e in kitchens.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _kitchen = v ?? 'all'),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          if (all.isEmpty)
            PanelCard(
              child: EmptyState(
                emoji: '🍽️',
                title: 'Your menu is empty',
                body: widget.isAdmin
                    ? 'Add your first dish, or load a sample menu to see how the store looks.'
                    : 'Add your first dish with a photo, price and category.',
                action: Wrap(spacing: 10, children: [
                  ElevatedButton.icon(onPressed: openEditor, icon: const Icon(Icons.add_rounded), label: const Text('Add item')),
                  if (widget.isAdmin)
                    OutlinedButton(
                      onPressed: _seeding
                          ? null
                          : () async {
                              setState(() => _seeding = true);
                              try {
                                await Db.seedSampleMenu();
                                if (context.mounted) showToast(context, 'Sample menu added — edit or delete items any time');
                              } catch (e) {
                                if (context.mounted) showToast(context, authErrorText(e), error: true);
                              }
                              if (mounted) setState(() => _seeding = false);
                            },
                      child: Text(_seeding ? 'Adding…' : 'Load sample menu'),
                    ),
                ]),
              ),
            )
          else
            ResponsiveGrid(
              minItemWidth: 260,
              children: [for (final p in list) _ProductTile(p: p, isAdmin: widget.isAdmin, onEdit: () => openEditor(p))],
            ),
        ]);
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product p;
  final bool isAdmin;
  final VoidCallback onEdit;
  const _ProductTile({required this.p, required this.isAdmin, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: PK.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 150,
          child: Stack(fit: StackFit.expand, children: [
            Opacity(opacity: p.isAvailable ? 1 : .45, child: SmartImage(url: p.imageUrl, emoji: categoryEmoji(p.category), emojiSize: 52)),
            Positioned(
              top: 10,
              left: 10,
              child: Wrap(spacing: 6, children: [
                if (p.onSale) Pill('${p.discountPercent}% OFF', color: PK.flame, solid: true),
                if (p.isBestseller) const Pill('Bestseller', color: PK.amber, solid: true),
                if (!p.vendorActive) const Pill('Kitchen hidden', color: PK.red, solid: true),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              VegMark(isVeg: p.isVeg, size: 13),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(15, color: PK.ink, weight: FontWeight.w700))),
            ]),
            const SizedBox(height: 4),
            Text(isAdmin ? '${p.category} · ${p.vendorName}' : p.category,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(12.5, color: PK.muted)),
            const SizedBox(height: 8),
            Row(children: [
              Text(rupees(p.finalPrice), style: AppTheme.body(16, color: PK.ink, weight: FontWeight.w800)),
              if (p.onSale) ...[
                const SizedBox(width: 6),
                Text(rupees(p.price), style: AppTheme.body(12.5, color: PK.muted).copyWith(decoration: TextDecoration.lineThrough)),
              ],
              const Spacer(),
              Text(p.isAvailable ? 'In stock' : 'Sold out',
                  style: AppTheme.body(12, color: p.isAvailable ? PK.green : PK.red, weight: FontWeight.w700)),
              Transform.scale(
                scale: .8,
                child: Switch(
                  value: p.isAvailable,
                  onChanged: (v) => Db.updateProduct(p.id, {'isAvailable': v}).catchError((e) {
                    if (context.mounted) showToast(context, authErrorText(e), error: true);
                  }),
                ),
              ),
            ]),
            Row(children: [
              TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 17), label: const Text('Edit')),
              const Spacer(),
              IconButton(
                tooltip: 'Delete',
                onPressed: () async {
                  if (await confirmDialog(context,
                      title: 'Delete ${p.name}?',
                      message: 'This removes the item from the menu permanently.',
                      confirm: 'Delete',
                      destructive: true)) {
                    try {
                      await Db.deleteProduct(p.id);
                    } catch (e) {
                      if (context.mounted) showToast(context, authErrorText(e), error: true);
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded, color: PK.red, size: 20),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

Future<void> showProductEditor(
  BuildContext context, {
  Product? product,
  required bool isAdmin,
  String? vendorId,
  String? vendorName,
  List<Vendor> vendors = const [],
  List<String> categories = const [],
  String? initialCategory,
}) =>
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductEditor(
        product: product,
        isAdmin: isAdmin,
        vendorId: vendorId,
        vendorName: vendorName,
        vendors: vendors,
        categories: categories,
        initialCategory: initialCategory,
      ),
    );

class _ProductEditor extends StatefulWidget {
  final Product? product;
  final bool isAdmin;
  final String? vendorId;
  final String? vendorName;
  final List<Vendor> vendors;
  final List<String> categories;
  final String? initialCategory;
  const _ProductEditor({
    this.product,
    required this.isAdmin,
    this.vendorId,
    this.vendorName,
    required this.vendors,
    required this.categories,
    this.initialCategory,
  });

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _desc = TextEditingController(text: widget.product?.description);
  late String? _category = widget.product?.category ?? widget.initialCategory;
  late final Stream<List<CategoryModel>> _categories = Db.allCategories();
  late final _price = TextEditingController(text: widget.product == null ? '' : _num(widget.product!.price));
  late final _discount = TextEditingController(text: '${widget.product?.discountPercent ?? 0}');
  late final _sort = TextEditingController(text: '${widget.product?.sortOrder ?? 0}');
  late String _image = widget.product?.imageUrl ?? '';
  late bool _veg = widget.product?.isVeg ?? true;
  late bool _available = widget.product?.isAvailable ?? true;
  late bool _best = widget.product?.isBestseller ?? false;
  late String _kitchen = widget.product?.vendorId ?? widget.vendorId ?? AppConfig.houseVendorId;
  bool _saving = false;
  bool _uploading = false;

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_name, _desc, _price, _discount, _sort]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if ((_category ?? '').isEmpty) {
      showToast(context, 'Please choose a category', error: true);
      return;
    }
    setState(() => _saving = true);
    String vid, vname;
    bool active = true;
    if (widget.isAdmin) {
      vid = _kitchen;
      if (vid == AppConfig.houseVendorId) {
        vname = AppConfig.houseVendorName;
      } else {
        final v = widget.vendors.where((v) => v.id == vid).firstOrNull;
        vname = v?.businessName ?? widget.product?.vendorName ?? 'Partner kitchen';
        active = v?.isApproved ?? widget.product?.vendorActive ?? false;
      }
    } else {
      vid = widget.vendorId!;
      vname = widget.vendorName ?? '';
    }
    final data = {
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'category': _category,
      'imageUrl': _image,
      'price': double.parse(_price.text.trim()),
      'discountPercent': int.tryParse(_discount.text.trim()) ?? 0,
      'isVeg': _veg,
      'isAvailable': _available,
      'isBestseller': _best,
      'vendorId': vid,
      'vendorName': vname,
      'vendorActive': active,
      'sortOrder': int.tryParse(_sort.text.trim()) ?? 0,
    };
    try {
      await Db.saveProduct(widget.product?.id, data);
      if (mounted) {
        Navigator.pop(context);
        showToast(context, widget.product == null ? 'Item added to menu' : 'Item updated');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, authErrorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    Widget pair(Widget a, Widget b) => m
        ? Column(children: [a, const SizedBox(height: 14), b])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]);
    final approvedVendors = widget.vendors.where((v) => v.isApproved || v.id == _kitchen).toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 860),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(children: [
                Expanded(
                    child: Text(widget.product == null ? 'Add menu item' : 'Edit menu item',
                        style: AppTheme.body(20, color: PK.ink, weight: FontWeight.w800))),
                IconButton(onPressed: _saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ImageField(
                    value: _image,
                    height: 220,
                    onChanged: (v) => setState(() => _image = v),
                    onBusy: (b) => setState(() => _uploading = b),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Item name'),
                    validator: (v) => validateRequired(v, 'Name'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _desc,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Description', hintText: 'What makes this dish special?'),
                  ),
                  const SizedBox(height: 14),
                  StreamBuilder<List<CategoryModel>>(
                    stream: _categories,
                    builder: (c, snap) {
                      final names = <String>[
                        ...?snap.data?.map((e) => e.name),
                        // Legacy categories that exist only on dishes.
                        ...widget.categories.where((n) => !(snap.data ?? const []).any((e) => e.name == n)),
                      ];
                      if (_category != null && _category!.isNotEmpty && !names.contains(_category)) names.add(_category!);
                      final images = {for (final e in snap.data ?? const <CategoryModel>[]) e.name: e.imageUrl};
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: names.contains(_category) ? _category : null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              hintText: names.isEmpty ? 'Create a category first →' : 'Choose category',
                              prefixIcon: const Icon(Icons.category_outlined),
                            ),
                            items: [
                              for (final n in names)
                                DropdownMenuItem(
                                  value: n,
                                  child: Row(children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: SizedBox(
                                          width: 28, height: 28, child: SmartImage(url: images[n] ?? '', emoji: categoryEmoji(n), emojiSize: 16)),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(child: Text(n, overflow: TextOverflow.ellipsis)),
                                  ]),
                                ),
                            ],
                            onChanged: (v) => setState(() => _category = v),
                            validator: (v) => (v ?? '').isEmpty ? 'Choose a category' : null,
                          ),
                        ),
                        ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final n = await showCategoryEditor(context, nextOrder: names.length);
                                if (n != null) setState(() => _category = n);
                              },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('New'),
                            ),
                          ),
                        ],
                      ]);
                    },
                  ),
                  const SizedBox(height: 14),
                  pair(
                    TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price (₹)', prefixText: '₹ '),
                      validator: (v) => (double.tryParse((v ?? '').trim()) ?? 0) > 0 ? null : 'Enter a valid price',
                    ),
                    TextFormField(
                      controller: _discount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sale discount (%)', suffixText: '%', helperText: '0 = no sale'),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        return n == null || n < 0 || n > 90 ? '0 – 90' : null;
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Veg'), icon: VegMark(isVeg: true, size: 14)),
                      ButtonSegment(value: false, label: Text('Non-veg'), icon: VegMark(isVeg: false, size: 14)),
                    ],
                    selected: {_veg},
                    onSelectionChanged: (s) => setState(() => _veg = s.first),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('In stock'),
                    subtitle: const Text('Customers can order this item'),
                    value: _available,
                    onChanged: (v) => setState(() => _available = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bestseller'),
                    subtitle: const Text('Show in the “Our bestsellers” section'),
                    value: _best,
                    onChanged: (v) => setState(() => _best = v),
                  ),
                  const SizedBox(height: 8),
                  pair(
                    TextFormField(
                      controller: _sort,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Display order', helperText: 'Lower numbers show first'),
                    ),
                    widget.isAdmin
                        ? DropdownButtonFormField<String>(
                            value: _kitchen,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Kitchen'),
                            items: [
                              const DropdownMenuItem(value: AppConfig.houseVendorId, child: Text(AppConfig.houseVendorName)),
                              for (final v in approvedVendors)
                                DropdownMenuItem(value: v.id, child: Text(v.businessName, overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) => setState(() => _kitchen = v ?? AppConfig.houseVendorId),
                          )
                        : const SizedBox(),
                  ),
                ]),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: PK.line))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saving || _uploading ? null : _save,
                  child: _saving ? const BtnSpinner() : Text(_uploading ? 'Uploading photo…' : 'Save item'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Photo upload field: pick → instant local preview → upload to imgbb with a
/// progress state → saved URL. Supports change, remove, retry and pasting a URL.
class ImageField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final double height;
  final double maxWidth;

  /// Reports upload in progress so the parent can block saving.
  final ValueChanged<bool>? onBusy;
  const ImageField({super.key, required this.value, required this.onChanged, this.height = 180, this.maxWidth = 1600, this.onBusy});

  @override
  State<ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends State<ImageField> {
  PickedImage? _local;
  bool _uploading = false;
  String? _error;

  void _setUploading(bool v) {
    setState(() => _uploading = v);
    widget.onBusy?.call(v);
  }

  Future<void> _pick() async {
    try {
      final img = await MediaService.pick(maxWidth: widget.maxWidth);
      if (img == null) return;
      setState(() {
        _local = img;
        _error = null;
      });
      await _upload();
    } catch (e) {
      setState(() => _error = authErrorText(e));
    }
  }

  Future<void> _upload() async {
    final img = _local;
    if (img == null) return;
    _setUploading(true);
    setState(() => _error = null);
    try {
      final url = await MediaService.upload(img);
      widget.onChanged(url);
      if (mounted) setState(() => _local = null);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(e));
    }
    if (mounted) _setUploading(false);
  }

  Future<void> _pasteUrl() async {
    final c = TextEditingController(text: widget.value.startsWith('http') ? widget.value : '');
    final url = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Image URL'),
        content: SizedBox(
          width: 420,
          child: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'https://…')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Use image')),
        ],
      ),
    );
    if (url != null && url.startsWith('http')) {
      setState(() {
        _local = null;
        _error = null;
      });
      widget.onChanged(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _local != null || widget.value.isNotEmpty;
    final kb = _local == null ? null : (_local!.bytes.length / 1024).round();

    if (!hasImage) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Hoverable(
          onTap: _pick,
          builder: (h) => AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: widget.height,
            decoration: BoxDecoration(
              color: h ? PK.amber.withOpacity(.10) : const Color(0xFFFFFAF2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: h ? PK.amber : PK.line, width: 1.6),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: PK.amber.withOpacity(.18), shape: BoxShape.circle),
                child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFB86E00), size: 30),
              ),
              const SizedBox(height: 10),
              Text('Click to upload a photo', style: AppTheme.body(15, color: PK.ink, weight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('JPG or PNG · resized automatically', style: AppTheme.body(12.5, color: PK.muted)),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(onPressed: _pasteUrl, icon: const Icon(Icons.link_rounded, size: 18), label: const Text('Or paste an image URL')),
        ),
        if (_error != null) _errorBox(),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: widget.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: PK.line)),
        child: Stack(fit: StackFit.expand, children: [
          if (_local != null)
            Image.memory(_local!.bytes, fit: BoxFit.cover, gaplessPlayback: true)
          else
            SmartImage(url: widget.value, emoji: '📷', emojiSize: 48),
          if (_uploading)
            Container(
              color: Colors.black.withOpacity(.45),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                const SizedBox(height: 12),
                Text('Uploading photo${kb == null ? '' : ' · $kb KB'}…', style: AppTheme.body(13.5, color: Colors.white, weight: FontWeight.w700)),
              ]),
            ),
          if (!_uploading && _local == null && widget.value.isNotEmpty)
            const Positioned(top: 10, left: 10, child: Pill('Uploaded', color: PK.green, solid: true, icon: Icons.cloud_done_rounded)),
          if (!_uploading)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                ElevatedButton.icon(onPressed: _pick, icon: const Icon(Icons.swap_horiz_rounded, size: 18), label: const Text('Change photo')),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: _pasteUrl,
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('URL'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: PK.red),
                  onPressed: () {
                    setState(() {
                      _local = null;
                      _error = null;
                    });
                    widget.onChanged('');
                  },
                  child: const Text('Remove'),
                ),
              ]),
            ),
        ]),
      ),
      if (_error != null) _errorBox(),
    ]);
  }

  Widget _errorBox() => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: PK.red.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: PK.red, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!, style: AppTheme.body(13, color: PK.red, weight: FontWeight.w600))),
          if (_local != null) TextButton(onPressed: _upload, child: const Text('Retry')),
        ]),
      );
}

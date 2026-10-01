import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../services/store_data.dart';
import '../../widgets/common.dart';
import '../panel/panel_widgets.dart';
import '../panel/products_manager.dart';

/// Admin list for one banner placement:
/// 'hero' = top slider, 'bottom' = "Don't miss these" specials.
class PromosManager extends StatelessWidget {
  final String placement;
  const PromosManager({super.key, required this.placement});

  bool get _specials => placement == 'bottom';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BannerModel>>(
      stream: Db.allBanners(),
      builder: (c, snap) {
        if (snap.hasError) return PanelPage(children: [EmptyState(emoji: '⚠️', title: 'Could not load', body: authErrorText(snap.error!))]);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!.where((b) => b.placement == placement).toList();
        final live = list.where((b) => b.isLive).length;
        return PanelPage(children: [
          PageHeader(
            title: _specials ? 'Specials' : 'Top banners',
            subtitle: _specials
                ? 'The “${context.watch<StoreData>().settings.specialsTitle}” cards on the home page. $live live now.'
                : 'Big slides at the top of the website. $live live now. Use wide (landscape) photos.',
            actions: [
              ElevatedButton.icon(
                onPressed: () => showPromoEditor(context, placement: placement, nextOrder: list.length + 1),
                icon: const Icon(Icons.add_rounded),
                label: Text(_specials ? 'New special' : 'New banner'),
              ),
            ],
          ),
          if (_specials) const _SpecialsHeadingCard(),
          if (list.isEmpty)
            PanelCard(
              child: EmptyState(
                emoji: _specials ? '⭐' : '🖼️',
                title: _specials ? 'No specials yet' : 'No banners yet',
                body: _specials
                    ? 'Add offers like “Desserts from ₹99” — they show as big cards on the home page.'
                    : 'Without banners, the website shows the HungryKya brand slide.',
                action: ElevatedButton(
                  onPressed: () => showPromoEditor(context, placement: placement, nextOrder: 1),
                  child: Text(_specials ? 'Create special' : 'Create banner'),
                ),
              ),
            )
          else
            ResponsiveGrid(minItemWidth: 360, children: [for (final b in list) _PromoCard(b: b)]),
        ]);
      },
    );
  }
}

class _SpecialsHeadingCard extends StatefulWidget {
  const _SpecialsHeadingCard();
  @override
  State<_SpecialsHeadingCard> createState() => _SpecialsHeadingCardState();
}

class _SpecialsHeadingCardState extends State<_SpecialsHeadingCard> {
  TextEditingController? _c;
  bool _saving = false;

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _c ??= TextEditingController(text: context.read<StoreData>().settings.specialsTitle);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PanelCard(
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _c,
              decoration: const InputDecoration(labelText: 'Section heading on website', isDense: true, prefixIcon: Icon(Icons.title_rounded)),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await Db.saveSettings({'specialsTitle': _c!.text.trim().isEmpty ? "Don't miss these" : _c!.text.trim()});
                      if (context.mounted) showToast(context, 'Heading updated');
                    } catch (e) {
                      if (context.mounted) showToast(context, authErrorText(e), error: true);
                    }
                    if (mounted) setState(() => _saving = false);
                  },
            child: Text(_saving ? 'Saving…' : 'Save heading'),
          ),
        ]),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final BannerModel b;
  const _PromoCard({required this.b});

  @override
  Widget build(BuildContext context) {
    final products = context.watch<StoreData>().products;
    final dish = b.productId.isEmpty ? null : products.where((p) => p.id == b.productId).firstOrNull;
    final target = dish != null ? '→ ${dish.name}' : (b.category.isNotEmpty ? '→ ${b.category}' : 'No link');
    final status = b.isExpired ? ('Expired', PK.red) : (b.active ? ('Live', PK.green) : ('Hidden', PK.muted));
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: PK.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 170,
          child: Stack(fit: StackFit.expand, children: [
            Opacity(opacity: b.isLive ? 1 : .5, child: SmartImage(url: b.imageUrl, emoji: '🖼️')),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xCC000000), Colors.transparent]))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (b.badge.isNotEmpty) ...[Pill(b.badge.toUpperCase(), color: PK.amber, solid: true), const SizedBox(height: 8)],
                Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.display(21, color: Colors.white)),
                if (b.subtitle.isNotEmpty)
                  Text(b.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(13, color: Colors.white70)),
              ]),
            ),
            Positioned(top: 10, right: 10, child: Pill(status.$1, color: status.$2, solid: true)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#${b.sortOrder} · $target', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(12.5, color: PK.ink, weight: FontWeight.w600)),
                if (b.endsAt != null)
                  Text('${b.isExpired ? 'Ended' : 'Until'} ${DateFormat('d MMM, h:mm a').format(b.endsAt!)}',
                      style: AppTheme.body(11.5, color: b.isExpired ? PK.red : PK.muted)),
              ]),
            ),
            Switch(value: b.active, onChanged: (v) => Db.saveBanner(b.id, {'active': v})),
            IconButton(
              tooltip: 'Edit',
              onPressed: () => showPromoEditor(context, existing: b, placement: b.placement, nextOrder: b.sortOrder),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () async {
                if (await confirmDialog(context, title: 'Delete?', message: b.title, confirm: 'Delete', destructive: true)) {
                  await Db.deleteBanner(b.id);
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

/// Create / edit a top banner or a special.
Future<void> showPromoEditor(BuildContext context, {BannerModel? existing, required String placement, int nextOrder = 1}) {
  final specials = placement == 'bottom';
  final title = TextEditingController(text: existing?.title);
  final subtitle = TextEditingController(text: existing?.subtitle);
  final badge = TextEditingController(text: existing?.badge ?? (specials ? 'Limited time' : ''));
  final cta = TextEditingController(text: existing?.ctaText ?? 'Order now');
  final sort = TextEditingController(text: '${existing?.sortOrder ?? nextOrder}');
  var image = existing?.imageUrl ?? '';
  var active = existing?.active ?? true;
  var linkType = (existing?.productId.isNotEmpty ?? false) ? 'dish' : ((existing?.category.isNotEmpty ?? false) ? 'category' : (specials ? 'category' : 'none'));
  String? category = (existing?.category.isNotEmpty ?? false) ? existing!.category : null;
  String? productId = (existing?.productId.isNotEmpty ?? false) ? existing!.productId : null;
  DateTime? endsAt = existing?.endsAt;
  var uploading = false;
  var saving = false;
  final form = GlobalKey<FormState>();
  final products = context.read<StoreData>().products;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (d) => StatefulBuilder(
      builder: (d, setD) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 880),
          child: Form(
            key: form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 4),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      existing == null ? (specials ? 'New special' : 'New top banner') : (specials ? 'Edit special' : 'Edit banner'),
                      style: AppTheme.body(20, color: PK.ink, weight: FontWeight.w800),
                    ),
                  ),
                  IconButton(onPressed: saving ? null : () => Navigator.pop(d), icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    ImageField(
                      value: image,
                      height: 200,
                      maxWidth: 1800,
                      onChanged: (v) => setD(() => image = v),
                      onBusy: (v) => setD(() => uploading = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: title,
                      decoration: InputDecoration(labelText: 'Heading', hintText: specials ? 'e.g. Desserts from ₹99' : 'e.g. Biryani Festival — 20% OFF'),
                      validator: (v) => validateRequired(v, 'Heading'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: subtitle, decoration: const InputDecoration(labelText: 'Sub-text (optional)')),
                    const SizedBox(height: 12),
                    Row(children: [
                      if (specials) ...[
                        Expanded(child: TextFormField(controller: badge, decoration: const InputDecoration(labelText: 'Badge', hintText: 'Limited time / New / Today only'))),
                        const SizedBox(width: 12),
                      ],
                      Expanded(child: TextFormField(controller: cta, decoration: const InputDecoration(labelText: 'Button text'))),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 90,
                        child: TextFormField(controller: sort, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Order')),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Text('WHEN CUSTOMER TAPS', style: AppTheme.body(11.5, color: PK.muted, weight: FontWeight.w800).copyWith(letterSpacing: 1.4)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'category', icon: Icon(Icons.category_rounded), label: Text('Open category')),
                        ButtonSegment(value: 'dish', icon: Icon(Icons.restaurant_rounded), label: Text('Open a dish')),
                        ButtonSegment(value: 'none', icon: Icon(Icons.block_rounded), label: Text('Menu')),
                      ],
                      selected: {linkType},
                      onSelectionChanged: (v) => setD(() => linkType = v.first),
                    ),
                    const SizedBox(height: 12),
                    if (linkType == 'category')
                      StreamBuilder<List<CategoryModel>>(
                        stream: Db.allCategories(),
                        builder: (c, s) {
                          final names = [...?s.data?.map((e) => e.name)];
                          if (category != null && !names.contains(category)) names.add(category!);
                          return DropdownButtonFormField<String>(
                            value: category,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                            items: [for (final n in names) DropdownMenuItem(value: n, child: Text(n))],
                            onChanged: (v) => setD(() => category = v),
                            validator: (v) => linkType == 'category' && (v ?? '').isEmpty ? 'Choose a category' : null,
                          );
                        },
                      ),
                    if (linkType == 'dish')
                      DropdownButtonFormField<String>(
                        value: products.any((p) => p.id == productId) ? productId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Dish', prefixIcon: Icon(Icons.restaurant_rounded)),
                        items: [
                          for (final p in products)
                            DropdownMenuItem(
                              value: p.id,
                              child: Row(children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(width: 28, height: 28, child: SmartImage(url: p.imageUrl, emoji: categoryEmoji(p.category), emojiSize: 16)),
                                ),
                                const SizedBox(width: 10),
                                Flexible(child: Text('${p.name} · ${rupees(p.finalPrice)}', overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                        ],
                        onChanged: (v) => setD(() => productId = v),
                        validator: (v) => linkType == 'dish' && (v ?? '').isEmpty ? 'Choose a dish' : null,
                      ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final day = await showDatePicker(
                              context: d,
                              initialDate: endsAt ?? now.add(const Duration(days: 7)),
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 365)),
                              helpText: 'Show until',
                            );
                            if (day != null) setD(() => endsAt = DateTime(day.year, day.month, day.day, 23, 59));
                          },
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(endsAt == null ? 'Show until… (no end date)' : 'Until ${DateFormat('d MMM yyyy').format(endsAt!)}'),
                        ),
                      ),
                      if (endsAt != null) IconButton(tooltip: 'Remove end date', onPressed: () => setD(() => endsAt = null), icon: const Icon(Icons.close_rounded)),
                    ]),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show on website'),
                      value: active,
                      onChanged: (v) => setD(() => active = v),
                    ),
                  ]),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: PK.line))),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: saving ? null : () => Navigator.pop(d), child: const Text('Cancel')),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: uploading || saving
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            if (image.isEmpty) {
                              showToast(d, 'Please upload a photo', error: true);
                              return;
                            }
                            setD(() => saving = true);
                            try {
                              await Db.saveBanner(existing?.id, {
                                'placement': placement,
                                'title': title.text.trim(),
                                'subtitle': subtitle.text.trim(),
                                'badge': badge.text.trim(),
                                'ctaText': cta.text.trim().isEmpty ? 'Order now' : cta.text.trim(),
                                'category': linkType == 'category' ? (category ?? '') : '',
                                'productId': linkType == 'dish' ? (productId ?? '') : '',
                                'endsAt': endsAt,
                                'imageUrl': image,
                                'active': active,
                                'sortOrder': int.tryParse(sort.text.trim()) ?? 0,
                              });
                              if (d.mounted) {
                                Navigator.pop(d);
                                showToast(context, specials ? 'Special saved' : 'Banner saved');
                              }
                            } catch (e) {
                              setD(() => saving = false);
                              if (d.mounted) showToast(d, authErrorText(e), error: true);
                            }
                          },
                    child: Text(uploading ? 'Uploading photo…' : (saving ? 'Saving…' : 'Save')),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}

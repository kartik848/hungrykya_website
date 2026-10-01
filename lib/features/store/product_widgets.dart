import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/cart.dart';
import '../../widgets/common.dart';

/// Adds to cart, asking first if the cart holds another kitchen's items.
Future<void> addToCart(BuildContext context, Product p) async {
  final cart = context.read<Cart>();
  if (cart.conflictsWith(p)) {
    final ok = await confirmDialog(
      context,
      title: 'Start a new cart?',
      message: 'Your cart has items from ${cart.vendorName}. Each order is cooked by one kitchen — '
          'discard those items and add ${p.name} from ${p.vendorName}?',
      confirm: 'Start fresh',
    );
    if (ok) cart.replaceWith(p);
    return;
  }
  cart.add(p);
}

class AddButton extends StatelessWidget {
  final Product product;
  final bool large;
  const AddButton({super.key, required this.product, this.large = false});

  @override
  Widget build(BuildContext context) {
    final qty = context.select<Cart, int>((c) => c.qtyOf(product.id));
    final h = large ? 52.0 : 40.0;
    final w = large ? 150.0 : 108.0;
    if (!product.isAvailable) {
      return SizedBox(
        height: h,
        child: Center(child: Text('Sold out', style: AppTheme.body(13, color: HK.muted, weight: FontWeight.w700))),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
      child: qty == 0
          ? SizedBox(
              key: const ValueKey('add'),
              height: h,
              width: w,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFFFFF5E5),
                  foregroundColor: HK.amberDeep,
                  side: const BorderSide(color: HK.amberDeep, width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => addToCart(context, product),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('ADD', style: AppTheme.body(large ? 15 : 14, color: HK.amberDeep, weight: FontWeight.w800).copyWith(letterSpacing: 1.2)),
                  const SizedBox(width: 4),
                  Icon(Icons.add_rounded, size: large ? 20 : 18),
                ]),
              ),
            )
          : Container(
              key: const ValueKey('stepper'),
              height: h,
              width: w,
              decoration: BoxDecoration(
                gradient: HK.fire,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: HK.flame.withOpacity(.35), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(children: [
                _StepBtn(Icons.remove_rounded, () => context.read<Cart>().decrement(product)),
                Expanded(
                  child: Center(
                    child: Text('$qty', style: AppTheme.body(large ? 18 : 16, color: Colors.black, weight: FontWeight.w800))
                        .animate(key: ValueKey(qty))
                        .scaleXY(begin: 1.4, end: 1, duration: 250.ms, curve: Curves.easeOutBack),
                  ),
                ),
                _StepBtn(Icons.add_rounded, () => addToCart(context, product)),
              ]),
            ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(width: 36, height: double.infinity, child: Icon(icon, color: Colors.black, size: 20)),
      );
}

class PriceTag extends StatelessWidget {
  final Product p;
  final double size;
  const PriceTag(this.p, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(rupees(p.finalPrice), style: AppTheme.body(size, weight: FontWeight.w800)),
        if (p.onSale) ...[
          const SizedBox(width: 8),
          Text(rupees(p.price),
              style: AppTheme.body(size * .72, color: HK.muted).copyWith(decoration: TextDecoration.lineThrough, decorationColor: HK.muted)),
        ],
      ]);
}

class _DiscountBadge extends StatelessWidget {
  final int percent;
  const _DiscountBadge(this.percent);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(gradient: HK.fire, borderRadius: BorderRadius.circular(8)),
        child: Text('$percent% OFF', style: AppTheme.body(11.5, color: Colors.black, weight: FontWeight.w800)),
      );
}

class _BestsellerBadge extends StatelessWidget {
  const _BestsellerBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.95), borderRadius: BorderRadius.circular(8), boxShadow: HK.shadow(.4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_fire_department_rounded, size: 13, color: HK.amberDeep),
          const SizedBox(width: 4),
          Text('Bestseller', style: AppTheme.body(11.5, color: HK.ink, weight: FontWeight.w700)),
        ]),
      );
}

/// Grid card used on tablet/desktop and in horizontal rails.
class ProductCard extends StatelessWidget {
  final Product p;
  const ProductCard(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    return Hoverable(
      onTap: () => showProductDetail(context, p),
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, h ? -6 : 0, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: HK.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: h ? HK.amber.withOpacity(.7) : HK.line.withOpacity(.7)),
          boxShadow: HK.shadow(h ? 1.6 : .9),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 190,
            child: Stack(fit: StackFit.expand, children: [
              AnimatedScale(
                scale: h ? 1.07 : 1,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: SmartImage(url: p.imageUrl, emoji: categoryEmoji(p.category), emojiSize: 64),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x33000000)]),
                ),
              ),
              if (p.onSale) Positioned(top: 12, left: 12, child: _DiscountBadge(p.discountPercent)),
              if (p.isBestseller) const Positioned(top: 12, right: 12, child: _BestsellerBadge()),
              if (!p.isAvailable)
                Container(
                  color: Colors.white.withOpacity(.75),
                  alignment: Alignment.center,
                  child: Text('Currently unavailable', style: AppTheme.body(14, weight: FontWeight.w700)),
                ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  VegMark(isVeg: p.isVeg, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.category.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(11, color: HK.muted, weight: FontWeight.w700).copyWith(letterSpacing: 1.4)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(17, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                _KitchenTag(p.vendorName),
                const SizedBox(height: 5),
                Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.body(13, color: HK.muted, height: 1.45)),
                const Spacer(),
                Row(children: [Expanded(child: PriceTag(p)), AddButton(product: p)]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Zomato-style list row used on phones.
class ProductRow extends StatelessWidget {
  final Product p;
  const ProductRow(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showProductDetail(context, p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                VegMark(isVeg: p.isVeg, size: 14),
                if (p.isBestseller) ...[const SizedBox(width: 8), const _BestsellerBadge()],
              ]),
              const SizedBox(height: 8),
              Text(p.name, style: AppTheme.body(16.5, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              _KitchenTag(p.vendorName),
              const SizedBox(height: 4),
              PriceTag(p, size: 16),
              const SizedBox(height: 8),
              Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.body(13, color: HK.muted, height: 1.45)),
            ]),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 130,
            height: 144,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 124,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(fit: StackFit.expand, children: [
                    SmartImage(url: p.imageUrl, emoji: categoryEmoji(p.category), emojiSize: 46),
                    if (p.onSale) Positioned(top: 8, left: 8, child: _DiscountBadge(p.discountPercent)),
                  ]),
                ),
              ),
              Positioned(left: 11, right: 11, bottom: 0, child: Center(child: AddButton(product: p))),
            ]),
          ),
        ]),
      ),
    );
  }
}

void showProductDetail(BuildContext context, Product p) {
  if (isMobile(context)) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _ProductDetail(p, compact: true),
    );
  } else {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: HK.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: _ProductDetail(p, compact: false)),
      ),
    );
  }
}

class _ProductDetail extends StatelessWidget {
  final Product p;
  final bool compact;
  const _ProductDetail(this.p, {required this.compact});

  @override
  Widget build(BuildContext context) {
    final image = Stack(fit: StackFit.expand, children: [
      SmartImage(url: p.imageUrl, emoji: categoryEmoji(p.category), emojiSize: 96),
      if (p.onSale) Positioned(top: 16, left: 16, child: _DiscountBadge(p.discountPercent)),
      Positioned(
        top: 12,
        right: 12,
        child: IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ),
    ]);

    final details = Padding(
      padding: EdgeInsets.all(compact ? 22 : 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          VegMark(isVeg: p.isVeg),
          const SizedBox(width: 10),
          Text(p.isVeg ? 'Pure veg' : 'Non-veg', style: AppTheme.body(13, color: HK.muted, weight: FontWeight.w600)),
          const SizedBox(width: 10),
          Pill(p.category, color: HK.amberDeep),
          if (p.isBestseller) ...[const SizedBox(width: 8), const _BestsellerBadge()],
        ]),
        const SizedBox(height: 16),
        Text(p.name, style: AppTheme.display(compact ? 28 : 34)),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.storefront_rounded, size: 15, color: HK.amberDeep),
          const SizedBox(width: 6),
          Text('by ${p.vendorName}', style: AppTheme.body(13.5, color: HK.amberDeep, weight: FontWeight.w600)),
        ]),
        const SizedBox(height: 16),
        Text(p.description.isEmpty ? 'Freshly prepared in our kitchen the moment you order.' : p.description,
            style: AppTheme.body(15, color: HK.muted, height: 1.6)),
        const SizedBox(height: 20),
        const Wrap(spacing: 10, runSpacing: 10, children: [
          _Perk(Icons.local_fire_department_rounded, 'Cooked fresh'),
          _Perk(Icons.verified_rounded, 'Hygienically packed'),
          _Perk(Icons.delivery_dining_rounded, 'Hot delivery'),
        ]),
        const SizedBox(height: 26),
        Row(children: [
          Expanded(child: PriceTag(p, size: 26)),
          AddButton(product: p, large: true),
        ]),
      ]),
    );

    if (compact) {
      return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 280, child: image),
          details,
        ]),
      );
    }
    return SizedBox(
      height: 460,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 380, child: image),
        Expanded(child: SingleChildScrollView(child: details)),
      ]),
    );
  }
}

class _Perk extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Perk(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: HK.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: HK.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: HK.amberDeep),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.body(12.5, weight: FontWeight.w600)),
        ]),
      );
}

/// "by <kitchen>" line so customers see which kitchen cooks the dish.
class _KitchenTag extends StatelessWidget {
  final String name;
  const _KitchenTag(this.name);
  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.storefront_rounded, size: 13, color: HK.amberDeep),
        const SizedBox(width: 4),
        Flexible(
          child: Text('by $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(12, color: HK.amberDeep, weight: FontWeight.w600)),
        ),
      ]);
}

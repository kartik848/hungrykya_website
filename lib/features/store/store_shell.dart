import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/cart.dart';
import '../../services/store_data.dart';
import '../../widgets/common.dart';
import '../../widgets/doodles.dart';
import 'address_widgets.dart';
import 'product_widgets.dart';

/// Scaffold for every customer page: cart drawer + floating "view cart" bar.
class StoreShell extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final bool showCartBar;
  const StoreShell({super.key, required this.body, this.appBar, this.showCartBar = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      endDrawer: const Drawer(
        width: 440,
        backgroundColor: HK.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(28))),
        child: SafeArea(child: CartPanel()),
      ),
      body: Stack(children: [
        Positioned.fill(child: body),
        if (showCartBar) const Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(child: FloatingCartBar())),
      ]),
    );
  }
}

void openCart(BuildContext context) {
  if (!isMobile(context)) {
    final s = Scaffold.maybeOf(context);
    if (s != null && s.hasEndDrawer) {
      s.openEndDrawer();
      return;
    }
  }
  final h = MediaQuery.sizeOf(context).height;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => SizedBox(height: h * .88, child: const CartPanel()),
  );
}

class StoreTopBar extends StatelessWidget implements PreferredSizeWidget {
  /// On the home page, scrolls to a section; elsewhere navigates home first.
  final void Function(String section)? onNav;
  const StoreTopBar({super.key, this.onNav});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  void _nav(BuildContext context, String section) => onNav != null ? onNav!(section) : context.go('/?s=$section');

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final m = isMobile(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.86),
            border: const Border(bottom: BorderSide(color: HK.line)),
          ),
          child: MaxWidth(
            child: Row(children: [
              InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: () => onNav != null ? onNav!('top') : context.go('/'),
                child: BrandLogo(size: m ? 38 : 44),
              ),
              if (!m && auth.signedIn) ...[const SizedBox(width: 16), DeliverToChip(compact: MediaQuery.sizeOf(context).width < 1200)],
              const Spacer(),
              if (m && auth.signedIn) const DeliverToChip(compact: true),
              if (wide) ...[
                _NavLink('Menu', () => _nav(context, 'menu')),
                _NavLink('Offers', () => _nav(context, 'offers')),
                _NavLink('Kitchens', () => _nav(context, 'kitchens')),
                _NavLink('Partner with us', () => context.go('/partner')),
                const SizedBox(width: 12),
              ],
              if (auth.signedIn && !m)
                IconButton(
                  tooltip: 'My orders',
                  onPressed: () => context.go('/orders'),
                  icon: const Icon(Icons.receipt_long_rounded, color: HK.ink),
                ),
              const _AccountButton(),
              const SizedBox(width: 8),
              const _CartButton(),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (h) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: AppTheme.body(14.5, color: h ? HK.amberDeep : HK.ink, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: h ? 22 : 0,
              decoration: const BoxDecoration(gradient: HK.fire),
            ),
          ]),
        ),
      );
}

class _AccountButton extends StatelessWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.signedIn) {
      if (isMobile(context)) {
        return IconButton(onPressed: () => context.go('/login'), icon: const Icon(Icons.person_outline_rounded, color: HK.ink));
      }
      return TextButton.icon(
        onPressed: () => context.go('/login'),
        icon: const Icon(Icons.person_outline_rounded, size: 20),
        label: const Text('Login'),
        style: TextButton.styleFrom(foregroundColor: HK.ink),
      );
    }
    final name = auth.displayName;
    return PopupMenuButton<String>(
      tooltip: 'Account',
      color: Colors.white,
      offset: const Offset(0, 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) async {
        if (v == 'logout') {
          await auth.signOut();
          if (context.mounted) context.go('/');
        } else {
          context.go(v);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: AppTheme.body(14, weight: FontWeight.w700)),
            Text(auth.user?.email ?? '', style: AppTheme.body(12, color: HK.muted)),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: '/orders', child: _MenuRow(Icons.receipt_long_rounded, 'My orders')),
        if (auth.vendor != null) const PopupMenuItem(value: '/vendor', child: _MenuRow(Icons.storefront_rounded, 'Vendor dashboard')),
        const PopupMenuItem(value: 'logout', child: _MenuRow(Icons.logout_rounded, 'Log out')),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: HK.amber,
          child: Text(name.isEmpty ? '🙂' : name[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow(this.icon, this.label);
  @override
  Widget build(BuildContext context) =>
      Row(children: [Icon(icon, size: 18, color: HK.amberDeep), const SizedBox(width: 12), Text(label, style: AppTheme.body(14))]);
}

class _CartButton extends StatelessWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context) {
    final count = context.select<Cart, int>((c) => c.count);
    return Hoverable(
      onTap: () => openCart(context),
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: count > 0 ? HK.fire : null,
          color: count > 0 ? null : (h ? HK.cardHi : HK.card),
          borderRadius: BorderRadius.circular(14),
          border: count > 0 ? null : Border.all(color: HK.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_bag_rounded, size: 20, color: count > 0 ? Colors.black : HK.ink),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Text('$count', style: AppTheme.body(15, color: Colors.black, weight: FontWeight.w800))
                .animate(key: ValueKey(count))
                .scaleXY(begin: 1.6, end: 1, duration: 350.ms, curve: Curves.easeOutBack),
          ],
        ]),
      ),
    );
  }
}

class FloatingCartBar extends StatelessWidget {
  const FloatingCartBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final empty = cart.isEmpty;
    return IgnorePointer(
      ignoring: empty,
      child: AnimatedSlide(
        offset: empty ? const Offset(0, 1.6) : Offset.zero,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Hoverable(
                onTap: () => openCart(context),
                builder: (h) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: HK.fire,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: HK.flame.withOpacity(h ? .55 : .38), blurRadius: h ? 36 : 26, offset: const Offset(0, 12))],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.shopping_bag_rounded, color: Colors.black),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${cart.count} item${cart.count == 1 ? '' : 's'}  ·  ${rupees(cart.subtotal)}',
                            style: AppTheme.body(16, color: Colors.black, weight: FontWeight.w800)),
                        Text('From ${cart.vendorName ?? ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(12, color: Colors.black.withOpacity(.65))),
                      ]),
                    ),
                    Text('View cart', style: AppTheme.body(15, color: Colors.black, weight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.black),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<Cart>();
    final s = context.watch<StoreData>().settings;
    final fee = s.deliveryFor(cart.subtotal);
    final router = GoRouter.of(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
        child: Row(children: [
          Text('Your cart', style: AppTheme.display(26)),
          const Spacer(),
          if (!cart.isEmpty)
            TextButton(
              onPressed: () async {
                if (await confirmDialog(context, title: 'Clear cart?', message: 'All items will be removed.', confirm: 'Clear', destructive: true)) {
                  cart.clear();
                }
              },
              child: const Text('Clear'),
            ),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
      ),
      if (cart.isEmpty)
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🛒', style: TextStyle(fontSize: 72))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: 0, end: -8, duration: 1200.ms, curve: Curves.easeInOut),
                const SizedBox(height: 16),
                Text('Your cart is hungry too', style: AppTheme.display(24), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Add something delicious from the menu.', style: AppTheme.body(14, color: HK.muted), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    router.go('/?s=menu');
                  },
                  child: const Text('Browse menu'),
                ),
              ]),
            ),
          ),
        )
      else ...[
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: HK.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: HK.line)),
              child: Row(children: [
                const Icon(Icons.storefront_rounded, color: HK.amberDeep, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('From ${cart.vendorName}', style: AppTheme.body(14, weight: FontWeight.w700))),
              ]),
            ),
            const SizedBox(height: 8),
            for (final l in cart.lines) _CartLineTile(l),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add more items'),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: HK.cardHi, borderRadius: BorderRadius.circular(18), border: Border.all(color: HK.line)),
              child: Column(children: [
                BillRow('Item total', rupees(cart.mrpTotal)),
                if (cart.saleSavings > 0) BillRow('Sale savings', '− ${rupees(cart.saleSavings)}', color: HK.veg),
                BillRow('Delivery fee', fee == 0 ? 'FREE' : rupees(fee), color: fee == 0 ? HK.veg : null),
                if (fee > 0 && s.freeDeliveryAbove > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text('Add ${rupees(s.freeDeliveryAbove - cart.subtotal)} more for FREE delivery 🛵',
                        style: AppTheme.body(12.5, color: HK.amberDeep, weight: FontWeight.w600)),
                  ),
                const Divider(height: 22),
                BillRow('To pay', rupees(cart.subtotal + fee), bold: true),
                const SizedBox(height: 6),
                Text('Have a coupon? Apply it on the next step.', style: AppTheme.body(12, color: HK.muted)),
              ]),
            ),
            if (cart.subtotal < s.minOrder)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text('Minimum order value is ${rupees(s.minOrder)}. Add ${rupees(s.minOrder - cart.subtotal)} more.',
                    style: AppTheme.body(13, color: HK.nonVeg, weight: FontWeight.w600)),
              ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: HK.line))),
          child: SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: cart.subtotal < s.minOrder
                  ? null
                  : () {
                      Navigator.pop(context);
                      router.go('/checkout');
                    },
              child: Row(children: [
                Text(rupees(cart.subtotal + fee), style: const TextStyle(fontSize: 17)),
                const Spacer(),
                const Text('Proceed to checkout'),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ]),
            ),
          ),
        ),
      ],
    ]);
  }
}

class _CartLineTile extends StatelessWidget {
  final CartLine line;
  const _CartLineTile(this.line);

  @override
  Widget build(BuildContext context) {
    final p = line.product;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 56, height: 56, child: SmartImage(url: p.imageUrl, emoji: categoryEmoji(p.category), emojiSize: 24)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              VegMark(isVeg: p.isVeg, size: 13),
              const SizedBox(width: 6),
              Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(14.5, weight: FontWeight.w700))),
            ]),
            const SizedBox(height: 4),
            Text(rupees(line.total), style: AppTheme.body(14, color: HK.muted, weight: FontWeight.w600)),
          ]),
        ),
        AddButton(product: p),
      ]),
    );
  }
}

class StoreFooter extends StatelessWidget {
  const StoreFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreData>().settings;
    final m = isMobile(context);
    Widget col(String title, List<(String, VoidCallback)> links) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: AppTheme.body(12, color: HK.amberDeep, weight: FontWeight.w800).copyWith(letterSpacing: 2)),
          const SizedBox(height: 16),
          for (final (label, onTap) in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Hoverable(
                onTap: onTap,
                builder: (h) => Text(label, style: AppTheme.body(14.5, color: h ? HK.ink : HK.muted, weight: FontWeight.w500)),
              ),
            ),
        ]);

    final brand = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const BrandLogo(size: 56),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text('Ghar jaisa khana, restaurant wala swaad. Freshly cooked in our cloud kitchen and delivered hot to your door.',
            style: AppTheme.body(14, color: HK.muted, height: 1.6)),
      ),
      const SizedBox(height: 18),
      if (s.contactPhone.isNotEmpty) _contact(Icons.call_rounded, s.contactPhone, () => launchUrl(Uri.parse('tel:${s.contactPhone}'))),
      if (s.contactEmail.isNotEmpty) _contact(Icons.mail_rounded, s.contactEmail, () => launchUrl(Uri.parse('mailto:${s.contactEmail}'))),
      if (s.address.isNotEmpty) _contact(Icons.location_on_rounded, s.address, null),
    ]);

    final links = [
      col('Explore', [
        ('Menu', () => context.go('/?s=menu')),
        ('Offers', () => context.go('/?s=offers')),
        ('Track my order', () => context.go('/orders')),
        ('Login / Sign up', () => context.go('/login')),
      ]),
      col('For kitchens', [
        ('Register as vendor', () => context.go('/partner')),
        ('Vendor login', () => context.go('/vendor')),
        ('Only 2% commission', () => context.go('/partner')),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WE ACCEPT', style: AppTheme.body(12, color: HK.amberDeep, weight: FontWeight.w800).copyWith(letterSpacing: 2)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in ['UPI', 'GPay', 'PhonePe', 'Paytm', 'BHIM', 'Cash on delivery'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: HK.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: HK.line)),
              child: Text(p, style: AppTheme.body(12.5, weight: FontWeight.w700)),
            ),
        ]),
      ]),
    ];

    return Container(
      decoration: const BoxDecoration(color: HK.tint, border: Border(top: BorderSide(color: HK.line))),
      padding: const EdgeInsets.only(top: 64, bottom: 110),
      child: Stack(children: [
        const Positioned.fill(child: Doodles(seed: 21, opacity: .08, spacing: 150)),
        MaxWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (m) ...[
              brand,
              const SizedBox(height: 36),
              Wrap(spacing: 48, runSpacing: 32, children: links),
            ] else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 4, child: brand),
                for (final l in links) Expanded(flex: 3, child: l),
              ]),
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 20),
            Text('© ${DateTime.now().year} HungryKya. Made with ❤️ for food lovers.', style: AppTheme.body(13, color: HK.muted)),
          ]),
        ),
      ]),
    );
  }

  Widget _contact(IconData icon, String text, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: HK.amberDeep),
            const SizedBox(width: 10),
            Flexible(child: Text(text, style: AppTheme.body(14, color: HK.ink))),
          ]),
        ),
      );
}

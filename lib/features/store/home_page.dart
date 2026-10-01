import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/store_data.dart';
import '../../widgets/common.dart';
import 'home_sections.dart';
import 'product_widgets.dart';
import 'store_shell.dart';

class HomePage extends StatefulWidget {
  /// Section to scroll to on open (`/?s=menu`), used by links from other pages.
  final String? section;
  const HomePage({super.key, this.section});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scroll = ScrollController();
  final _menuKey = GlobalKey();
  final _offersKey = GlobalKey();
  final _kitchensKey = GlobalKey();
  final _search = TextEditingController();

  String _category = 'All';
  String? _vendorFilter;
  bool _vegOnly = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.section != null) {
      // Wait for products to lay out before jumping.
      Future.delayed(const Duration(milliseconds: 700), () => _scrollTo(widget.section!));
    }
  }

  @override
  void didUpdateWidget(covariant HomePage old) {
    super.didUpdateWidget(old);
    if (widget.section != null && widget.section != old.section) _scrollTo(widget.section!);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _scrollTo(String section) {
    if (!mounted) return;
    if (section == 'top') {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
      return;
    }
    final key = switch (section) {
      'menu' => _menuKey,
      'offers' => _offersKey,
      'kitchens' => _kitchensKey,
      _ => null,
    };
    final ctx = key?.currentContext ?? (section == 'offers' ? _menuKey.currentContext : null);
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
    }
  }

  List<Product> _filtered(List<Product> all) {
    final q = _query.trim().toLowerCase();
    return all.where((p) {
      if (_vegOnly && !p.isVeg) return false;
      if (_vendorFilter != null && p.vendorId != _vendorFilter) return false;
      if (_category != 'All' && p.category != _category) return false;
      if (q.isNotEmpty && !p.name.toLowerCase().contains(q) && !p.description.toLowerCase().contains(q) && !p.category.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StoreData>();
    final auth = context.watch<AuthService>();
    final m = isMobile(context);
    final pad = sidePad(context);
    final filtered = _filtered(data.visibleProducts);
    final groups = <String, List<Product>>{for (final c in data.categories) c: []};
    for (final p in filtered) {
      groups.putIfAbsent(p.category, () => []).add(p);
    }
    groups.removeWhere((_, v) => v.isEmpty);

    final slivers = <Widget>[
      SliverPersistentHeader(pinned: true, delegate: _FixedHeader(72, StoreTopBar(onNav: _scrollTo))),
      if (auth.isBlocked)
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: HK.nonVeg.withOpacity(.18),
            child: Text('Your account has been blocked by HungryKya. Please contact support.',
                textAlign: TextAlign.center, style: AppTheme.body(14, weight: FontWeight.w600)),
          ),
        ),
      if (!data.settings.storeOpen) const SliverToBoxAdapter(child: StoreClosedBanner()),
      if (auth.currentAddress != null && !data.settings.serves(auth.currentAddress!))
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: HK.nonVeg.withOpacity(.1),
            child: Text(
              "📍 We don't deliver to ${auth.currentAddress!.short} yet. We currently deliver in ${data.settings.areaSummary}.",
              textAlign: TextAlign.center,
              style: AppTheme.body(14, weight: FontWeight.w600),
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: HeroCarousel(
          banners: data.heroBanners,
          etaMinutes: data.settings.etaMinutes,
          onOrderNow: () => _scrollTo('menu'),
          onOffers: () => _scrollTo(data.offers.isEmpty ? 'menu' : 'offers'),
          onBannerTap: (b) {
            final dish = b.productId.isEmpty ? null : data.products.where((p) => p.id == b.productId).firstOrNull;
            if (dish != null) {
              showProductDetail(context, dish);
              return;
            }
            if (b.category.isNotEmpty && data.categories.contains(b.category)) setState(() => _category = b.category);
            _scrollTo('menu');
          },
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      SliverToBoxAdapter(child: TrustStrip(etaMinutes: data.settings.etaMinutes)),
      if (data.offers.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
        SliverToBoxAdapter(child: OfferTicker(offers: data.offers)),
        SliverToBoxAdapter(
          child: Padding(
            key: _offersKey,
            padding: const EdgeInsets.only(top: 72),
            child: OffersSection(offers: data.offers),
          ),
        ),
      ],
      if (data.categories.length > 1)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: CategoryRail(
              categories: data.categories,
              products: data.visibleProducts,
              categoryImage: data.categoryImage,
              selected: _category,
              onSelect: (c) {
                setState(() => _category = _category == c ? 'All' : c);
                _scrollTo('menu');
              },
            ),
          ),
        ),
      if (data.bestsellers.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: ProductRail(
              eyebrow: 'Most loved',
              title: 'Our bestsellers',
              subtitle: 'The dishes everyone keeps coming back for.',
              products: data.bestsellers,
            ),
          ),
        ),
      // ---------------- Menu ----------------
      SliverToBoxAdapter(
        child: Padding(
          key: _menuKey,
          padding: const EdgeInsets.only(top: 88, bottom: 20),
          child: MaxWidth(
            child: Flex(
              direction: m ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: m ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
              children: [
                if (m)
                  const SectionTitle(eyebrow: 'Our menu', title: 'Freshly made, just for you')
                else
                  const Expanded(child: SectionTitle(eyebrow: 'Our menu', title: 'Freshly made, just for you')),
                SizedBox(height: m ? 18 : 0, width: m ? 0 : 24),
                SizedBox(
                  width: m ? double.infinity : 340,
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search biryani, paneer, rolls…',
                      prefixIcon: const Icon(Icons.search_rounded, color: HK.muted),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Pinned filter bar stays only while the menu is on screen.
      SliverMainAxisGroup(slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _FixedHeader(
            64,
            _MenuFilterBar(
              categories: data.categories,
              selected: _category,
              vegOnly: _vegOnly,
              vendorName: _vendorFilter == null ? null : data.kitchens[_vendorFilter],
              onCategory: (c) => setState(() => _category = c),
              onVeg: () => setState(() => _vegOnly = !_vegOnly),
              onClearVendor: () => setState(() => _vendorFilter = null),
            ),
          ),
        ),
        if (!data.loaded)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(80), child: Center(child: CircularProgressIndicator())))
        else if (data.error != null && data.products.isEmpty)
          SliverToBoxAdapter(child: _MenuEmpty(title: 'Could not load the menu', subtitle: data.error!))
        else if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: _MenuEmpty(
              title: data.products.isEmpty ? 'Menu coming soon' : 'No dishes match',
              subtitle:
                  data.products.isEmpty ? 'Our chefs are setting up the kitchen. Check back shortly!' : 'Try another search or clear the filters.',
            ),
          )
        else
          for (final e in groups.entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 34, pad, 18),
                child: Row(children: [
                  Text(categoryEmoji(e.key), style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text(e.key, style: AppTheme.display(m ? 24 : 28)),
                  const SizedBox(width: 12),
                  Text('${e.value.length} item${e.value.length == 1 ? '' : 's'}', style: AppTheme.body(13, color: HK.muted)),
                ]),
              ),
            ),
            if (m)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                sliver: SliverList.separated(
                  itemCount: e.value.length,
                  itemBuilder: (c, i) => ProductRow(e.value[i]),
                  separatorBuilder: (_, __) => const Divider(),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 310,
                    mainAxisExtent: 384,
                    mainAxisSpacing: 22,
                    crossAxisSpacing: 22,
                  ),
                  itemCount: e.value.length,
                  itemBuilder: (c, i) => ProductCard(e.value[i]).animate().fadeIn(duration: 400.ms, delay: (40 * (i % 8)).ms).slideY(begin: .08),
                ),
              ),
          ],
      ]),
      // ---------------- Below the menu ----------------
      if (data.bottomBanners.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 100),
            child: PromoBanners(
              banners: data.bottomBanners,
              title: data.settings.specialsTitle,
              onTap: (b) {
                final dish = b.productId.isEmpty ? null : data.products.where((p) => p.id == b.productId).firstOrNull;
                if (dish != null) {
                  showProductDetail(context, dish);
                  return;
                }
                if (b.category.isNotEmpty && data.categories.contains(b.category)) setState(() => _category = b.category);
                _scrollTo('menu');
              },
            ),
          ),
        ),
      if (data.kitchens.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            key: _kitchensKey,
            padding: const EdgeInsets.only(top: 100),
            child: KitchensSection(
              kitchens: data.kitchens,
              products: data.products,
              onSelect: (id) {
                setState(() {
                  _vendorFilter = id;
                  _category = 'All';
                });
                _scrollTo('menu');
              },
            ),
          ),
        ),
      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 100), child: HowItWorks())),
      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 100, bottom: 100), child: PartnerCta())),
      const SliverToBoxAdapter(child: StoreFooter()),
    ];

    return StoreShell(
      body: CustomScrollView(
        controller: _scroll,
        // Build everything so section links can scroll to off-screen sections.
        cacheExtent: 30000,
        slivers: slivers,
      ),
    );
  }
}

class _FixedHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  _FixedHeader(this.height, this.child);

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox(height: height, child: child);

  @override
  bool shouldRebuild(covariant _FixedHeader old) => true;
}

class _MenuFilterBar extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final bool vegOnly;
  final String? vendorName;
  final ValueChanged<String> onCategory;
  final VoidCallback onVeg;
  final VoidCallback onClearVendor;
  const _MenuFilterBar({
    required this.categories,
    required this.selected,
    required this.vegOnly,
    required this.vendorName,
    required this.onCategory,
    required this.onVeg,
    required this.onClearVendor,
  });

  @override
  Widget build(BuildContext context) {
    final pad = sidePad(context);
    Widget chip(String label, bool sel, VoidCallback onTap, {Widget? leading}) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Hoverable(
            onTap: onTap,
            builder: (h) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                gradient: sel ? HK.fire : null,
                color: sel ? null : (h ? HK.cardHi : HK.card),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: sel ? Colors.transparent : HK.line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (leading != null) ...[leading, const SizedBox(width: 7)],
                Text(label, style: AppTheme.body(13.5, color: sel ? Colors.black : HK.ink, weight: FontWeight.w700)),
              ]),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(color: HK.bg.withOpacity(.97), border: const Border(bottom: BorderSide(color: HK.line))),
      alignment: Alignment.centerLeft,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
        children: [
          chip('Veg only', vegOnly, onVeg, leading: const VegMark(isVeg: true, size: 13)),
          if (vendorName != null) chip(vendorName!, true, onClearVendor, leading: const Icon(Icons.close_rounded, size: 15, color: Colors.black)),
          Container(width: 1, margin: const EdgeInsets.only(right: 10, top: 6, bottom: 6), color: HK.line),
          chip('All', selected == 'All', () => onCategory('All')),
          for (final c in categories) chip(c, selected == c, () => onCategory(c)),
        ],
      ),
    );
  }
}

class _MenuEmpty extends StatelessWidget {
  final String title;
  final String subtitle;
  const _MenuEmpty({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
        child: Column(children: [
          const Text('👨‍🍳', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(title, style: AppTheme.display(26), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTheme.body(14.5, color: HK.muted), textAlign: TextAlign.center),
        ]),
      );
}

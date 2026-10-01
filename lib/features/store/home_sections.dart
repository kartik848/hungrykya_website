import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/doodles.dart';
import 'product_widgets.dart';

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class HeroCarousel extends StatefulWidget {
  final List<BannerModel> banners;
  final int etaMinutes;
  final VoidCallback onOrderNow;
  final VoidCallback onOffers;
  final void Function(BannerModel banner) onBannerTap;
  const HeroCarousel({
    super.key,
    required this.banners,
    required this.etaMinutes,
    required this.onOrderNow,
    required this.onOffers,
    required this.onBannerTap,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final _pc = PageController();
  int _i = 0;
  Timer? _timer;

  int get _count => 1 + widget.banners.length;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted && _count > 1 && _pc.hasClients) _go((_i + 1) % _count);
    });
  }

  void _go(int i) => _pc.animateToPage(i, duration: const Duration(milliseconds: 750), curve: Curves.easeInOutCubic);

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    if (_i >= _count) _i = 0;
    return SizedBox(
      height: _heroHeight(MediaQuery.sizeOf(context).width),
      child: Stack(children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
          ),
          child: PageView.builder(
            controller: _pc,
            itemCount: _count,
            onPageChanged: (i) {
              setState(() => _i = i);
              _restartTimer();
            },
            itemBuilder: (c, i) => i == 0
                ? _BrandSlide(etaMinutes: widget.etaMinutes, onOrderNow: widget.onOrderNow, onOffers: widget.onOffers)
                : _BannerSlide(
                    banner: widget.banners[i - 1],
                    active: i == _i,
                    onTap: () => widget.onBannerTap(widget.banners[i - 1]),
                  ),
          ),
        ),
        if (_count > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: MaxWidth(
              child: Row(children: [
                for (var i = 0; i < _count; i++)
                  GestureDetector(
                    onTap: () => _go(i),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        margin: const EdgeInsets.only(right: 8),
                        width: i == _i ? 38 : 10,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: i == _i ? HK.fire : null,
                          color: i == _i ? null : HK.ink.withOpacity(.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                if (!m) ...[
                  _ArrowBtn(Icons.arrow_back_rounded, () => _go((_i - 1 + _count) % _count)),
                  const SizedBox(width: 10),
                  _ArrowBtn(Icons.arrow_forward_rounded, () => _go((_i + 1) % _count)),
                ],
              ]),
            ),
          ),
      ]),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (h) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: h ? HK.amber : Colors.white,
            border: Border.all(color: h ? HK.amber : HK.line),
            boxShadow: HK.shadow(.6),
          ),
          child: Icon(icon, color: h ? Colors.black : HK.ink, size: 20),
        ),
      );
}

class _BrandSlide extends StatelessWidget {
  final int etaMinutes;
  final VoidCallback onOrderNow;
  final VoidCallback onOffers;
  const _BrandSlide({required this.etaMinutes, required this.onOrderNow, required this.onOffers});

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    final w = MediaQuery.sizeOf(context).width;
    // Side-by-side only when there's room; otherwise stack visual over text.
    final side = w >= _heroSideBySide;
    final headline = m ? 38.0 : (!side ? 50.0 : (w >= 1300 ? 66.0 : 56.0));

    final text = Column(
      crossAxisAlignment: side ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: HK.amber.withOpacity(.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: HK.amber.withOpacity(.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text('Freshly cooked · Delivered hot', style: AppTheme.body(13, color: HK.amberDeep, weight: FontWeight.w700)),
          ]),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: .4),
        SizedBox(height: m ? 16 : 24),
        Text('Bhook lagi?', style: AppTheme.script(m ? 34 : 48)).animate().fadeIn(delay: 120.ms, duration: 500.ms).slideX(begin: -.08),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(style: AppTheme.display(headline), children: [
            const TextSpan(text: 'Ghar jaisa khana,\nrestaurant wala '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: FireText('swaad.', style: AppTheme.display(headline)),
            ),
          ]),
          textAlign: side ? TextAlign.start : TextAlign.center,
        ).animate().fadeIn(delay: 220.ms, duration: 600.ms).slideY(begin: .12),
        SizedBox(height: m ? 14 : 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Hot, fresh meals from the HungryKya cloud kitchen and partner kitchens near you. '
            'Order in seconds, pay by UPI or cash, and track your food live.',
            textAlign: side ? TextAlign.start : TextAlign.center,
            style: AppTheme.body(m ? 15 : 17, color: HK.muted, height: 1.65),
          ),
        ).animate().fadeIn(delay: 320.ms, duration: 600.ms),
        SizedBox(height: m ? 24 : 34),
        Wrap(spacing: 14, runSpacing: 12, alignment: side ? WrapAlignment.start : WrapAlignment.center, children: [
          ElevatedButton(
            onPressed: onOrderNow,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Order now'),
              SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded, size: 20),
            ]),
          ),
          OutlinedButton(
            onPressed: onOffers,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22)),
            child: const Text('View offers'),
          ),
        ]).animate().fadeIn(delay: 420.ms, duration: 600.ms).slideY(begin: .2),
        if (side) ...[
          const SizedBox(height: 42),
          Wrap(spacing: 36, runSpacing: 16, children: [
            _HeroStat('$etaMinutes min', 'avg. delivery'),
            const _HeroStat('Fresh', 'cooked to order'),
            const _HeroStat('UPI · COD', 'pay your way'),
          ]).animate().fadeIn(delay: 560.ms, duration: 600.ms),
        ],
      ],
    );

    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [HK.tint, HK.bg]),
        ),
      ),
      const Positioned.fill(child: Doodles(seed: 3, opacity: .10, spacing: 120)),
      // ambient glow
      Positioned(
        right: m ? -120 : -60,
        top: m ? -40 : 40,
        child: Container(
          width: 620,
          height: 620,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [HK.amber.withOpacity(.30), HK.flame.withOpacity(.06), HK.bg.withOpacity(0)]),
          ),
        ),
      ),
      Positioned(
        left: -200,
        bottom: -220,
        child: Container(
          width: 520,
          height: 520,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [HK.flame.withOpacity(.10), HK.bg.withOpacity(0)]),
          ),
        ),
      ),
      MaxWidth(
        child: side
            ? Row(children: [
                Expanded(flex: 6, child: _noOverflow(text)),
                const Expanded(flex: 5, child: Center(child: SizedBox(height: 480, child: FittedBox(child: _HeroVisual())))),
              ])
            : _noOverflow(Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(height: m ? 230 : 280, child: const FittedBox(child: _HeroVisual())),
                const SizedBox(height: 18),
                text,
                const SizedBox(height: 56),
              ])),
      ),
    ]);
  }
}

/// Centres [child] vertically and clips (instead of overflow stripes) if it is too tall.
Widget _noOverflow(Widget child) =>
    Center(child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: child));

const _heroSideBySide = 1100.0;

double _heroHeight(double width) {
  if (width >= _heroSideBySide) return 680;
  if (width >= 700) return 880;
  return 740;
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  const _HeroStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 3, height: 38, decoration: BoxDecoration(gradient: HK.fire, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: AppTheme.display(24)),
          Text(label, style: AppTheme.body(13, color: HK.muted)),
        ]),
      ]);
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    const size = 480.0;
    Widget bubble(String emoji, double dx, double dy, int i) => Positioned(
          left: size / 2 + dx - 36,
          top: size / 2 + dy - 36,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: HK.amber.withOpacity(.45)),
              boxShadow: HK.shadow(1.1),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 34)),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: -9, end: 9, duration: (2200 + i * 380).ms, curve: Curves.easeInOut)
              .animate()
              .fadeIn(delay: (300 + i * 120).ms)
              .scaleXY(begin: .4, end: 1, delay: (300 + i * 120).ms, duration: 600.ms, curve: Curves.easeOutBack),
        );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        Container(
          width: 400,
          height: 400,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [HK.amber.withOpacity(.32), HK.flame.withOpacity(.08), Colors.transparent]),
          ),
        ),
        SizedBox(width: 430, height: 430, child: CustomPaint(painter: _DashedRingPainter()))
            .animate(onPlay: (c) => c.repeat())
            .rotate(duration: 40.seconds),
        Container(
          width: 350,
          height: 350,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: HK.amber.withOpacity(.18), width: 1.2)),
        ),
        Container(
          width: 290,
          height: 290,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: HK.amber.withOpacity(.35), blurRadius: 80, spreadRadius: 4),
              BoxShadow(color: const Color(0xFF8A4B0F).withOpacity(.25), blurRadius: 40, offset: const Offset(0, 24)),
            ],
          ),
          child: ClipOval(child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover)),
        ).animate().scaleXY(begin: .7, end: 1, duration: 900.ms, curve: Curves.easeOutBack).fadeIn(),
        bubble('🍕', -190, -120, 0),
        bubble('🍛', 195, -70, 1),
        bubble('🍔', -170, 140, 2),
        bubble('🥤', 170, 150, 3),
        bubble('🍜', 40, -215, 4),
      ]),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HK.amber.withOpacity(.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final r = size.width / 2;
    const dashes = 64;
    for (var i = 0; i < dashes; i++) {
      final a = 2 * math.pi * i / dashes;
      canvas.drawArc(Rect.fromCircle(center: Offset(r, r), radius: r), a, 2 * math.pi / dashes * .45, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BannerSlide extends StatelessWidget {
  final BannerModel banner;
  final bool active;
  final VoidCallback onTap;
  const _BannerSlide({required this.banner, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    return Stack(fit: StackFit.expand, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: active ? 1.08 : 1.0),
        duration: const Duration(seconds: 9),
        builder: (c, s, child) => Transform.scale(scale: s, child: child),
        child: SmartImage(url: banner.imageUrl, emoji: '🍽️', emojiSize: 120),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: m
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, HK.bg.withOpacity(.75), HK.bg],
                  stops: const [.15, .6, 1],
                )
              : LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [HK.bg.withOpacity(.96), HK.bg.withOpacity(.6), Colors.transparent],
                  stops: const [0, .45, .85],
                ),
        ),
      ),
      const Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 120,
        child: DecoratedBox(
          decoration:
              BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, HK.bg])),
        ),
      ),
      MaxWidth(
        child: Align(
          alignment: m ? Alignment.bottomLeft : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(bottom: m ? 80 : 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Pill("Today's special", color: HK.amberDeep, icon: Icons.local_fire_department_rounded),
                const SizedBox(height: 18),
                Text(banner.title, style: AppTheme.display(m ? 38 : 62)),
                if (banner.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(banner.subtitle, style: AppTheme.body(m ? 15 : 18, color: HK.ink.withOpacity(.8), height: 1.55)),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(banner.ctaText),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ]),
                ),
              ]).animate(target: active ? 1 : 0).fadeIn(duration: 600.ms).slideY(begin: .12, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Trust strip & ticker
// ---------------------------------------------------------------------------

class TrustStrip extends StatelessWidget {
  final int etaMinutes;
  const TrustStrip({super.key, required this.etaMinutes});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.bolt_rounded, 'Lightning fast', '~$etaMinutes min delivery'),
      (Icons.soup_kitchen_rounded, 'Kitchen fresh', 'Cooked only after you order'),
      (Icons.verified_user_rounded, 'Hygiene first', 'Sealed, tamper-proof packs'),
      (Icons.account_balance_wallet_rounded, 'Pay your way', 'UPI apps or cash on delivery'),
    ];
    return MaxWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
        decoration: BoxDecoration(
          color: HK.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: HK.line),
          boxShadow: HK.shadow(),
        ),
        child: LayoutBuilder(builder: (c, cons) {
          final cols = cons.maxWidth < 640 ? 2 : 4;
          final w = cons.maxWidth / cols;
          return Wrap(runSpacing: 20, children: [
            for (final (i, (icon, title, sub)) in items.indexed)
              SizedBox(
                width: w,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: HK.amber.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
                      child: Icon(icon, color: HK.amberDeep),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: AppTheme.body(14.5, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(sub, style: AppTheme.body(12.5, color: HK.muted)),
                      ]),
                    ),
                  ]),
                ).animate().fadeIn(delay: (100 * i).ms, duration: 500.ms).slideY(begin: .3),
              ),
          ]);
        }),
      ),
    );
  }
}

class OfferTicker extends StatefulWidget {
  final List<Offer> offers;
  const OfferTicker({super.key, required this.offers});
  @override
  State<OfferTicker> createState() => _OfferTickerState();
}

class _OfferTickerState extends State<OfferTicker> {
  final _sc = ScrollController();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_sc.hasClients) _sc.jumpTo(_sc.offset + 1.2);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offers;
    return Container(
      height: 48,
      decoration: const BoxDecoration(gradient: HK.fire),
      child: ListView.builder(
        controller: _sc,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (c, i) {
          final x = o[i % o.length];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Row(children: [
              const Text('🎉', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Text('${x.shortLabel} — use code ', style: AppTheme.body(14, color: Colors.black, weight: FontWeight.w600)),
              Text(x.code, style: AppTheme.body(14, color: Colors.black, weight: FontWeight.w900).copyWith(letterSpacing: 1.2)),
              const SizedBox(width: 26),
              Text('✦', style: AppTheme.body(14, color: Colors.black54)),
            ]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offers
// ---------------------------------------------------------------------------

class OffersSection extends StatelessWidget {
  final List<Offer> offers;
  const OffersSection({super.key, required this.offers});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const MaxWidth(
        child: SectionTitle(eyebrow: 'Deals', title: 'Offers for you', subtitle: 'Tap a code to copy it, then apply it at checkout.'),
      ),
      const SizedBox(height: 26),
      SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: sidePad(context)),
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 18),
          itemBuilder: (c, i) => CouponCard(offers[i]).animate().fadeIn(delay: (80 * i).ms).slideX(begin: .15),
        ),
      ),
    ]);
  }
}

class CouponCard extends StatelessWidget {
  final Offer o;
  const CouponCard(this.o, {super.key});

  @override
  Widget build(BuildContext context) {
    return Hoverable(
      onTap: () {
        Clipboard.setData(ClipboardData(text: o.code));
        showToast(context, 'Code ${o.code} copied! Apply it at checkout.');
      },
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 350,
        clipBehavior: Clip.antiAlias,
        transform: Matrix4.translationValues(0, h ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: HK.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: h ? HK.amber.withOpacity(.8) : HK.line),
          boxShadow: HK.shadow(h ? 1.3 : .8),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 112,
            decoration: const BoxDecoration(gradient: HK.fire),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${o.discountPercent}%', style: AppTheme.display(40, color: Colors.black)),
              Text('OFF', style: AppTheme.body(14, color: Colors.black, weight: FontWeight.w900).copyWith(letterSpacing: 3)),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.title.isEmpty ? o.shortLabel : o.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.body(15.5, weight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: 6),
                Text(
                  [
                    if (o.description.isNotEmpty) o.description,
                    if (o.description.isEmpty && o.minOrder > 0) 'On orders above ${rupees(o.minOrder)}',
                    if (o.description.isEmpty && o.maxDiscount > 0) 'Max ${rupees(o.maxDiscount)} off',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(12.5, color: HK.muted),
                ),
                const Spacer(),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: HK.amber.withOpacity(.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HK.amber.withOpacity(.6)),
                    ),
                    child: Text(o.code, style: AppTheme.body(13.5, color: HK.amberDeep, weight: FontWeight.w800).copyWith(letterSpacing: 1.6)),
                  ),
                  const Spacer(),
                  Icon(Icons.copy_rounded, size: 18, color: h ? HK.amberDeep : HK.muted),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Categories & bestsellers
// ---------------------------------------------------------------------------

class CategoryRail extends StatelessWidget {
  final List<String> categories;
  final List<Product> products;
  final String Function(String category)? categoryImage;
  final String selected;
  final ValueChanged<String> onSelect;
  const CategoryRail({super.key, required this.categories, required this.products, this.categoryImage, required this.selected, required this.onSelect});

  String _imageFor(String cat) {
    final own = categoryImage?.call(cat) ?? '';
    if (own.isNotEmpty) return own;
    for (final p in products) {
      if (p.category == cat && p.imageUrl.isNotEmpty) return p.imageUrl;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    final tile = m ? 84.0 : 112.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const MaxWidth(child: SectionTitle(eyebrow: 'Categories', title: "What's on your mind?")),
      const SizedBox(height: 26),
      SizedBox(
        height: tile + 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: sidePad(context)),
          itemCount: categories.length,
          separatorBuilder: (_, __) => SizedBox(width: m ? 14 : 22),
          itemBuilder: (c, i) {
            final cat = categories[i];
            final sel = cat == selected;
            return Hoverable(
              onTap: () => onSelect(cat),
              builder: (h) => Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: tile,
                  height: tile,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: sel ? HK.fire : null,
                    border: sel ? null : Border.all(color: h ? HK.amber.withOpacity(.6) : HK.line, width: 2),
                    boxShadow: sel || h ? [BoxShadow(color: HK.amber.withOpacity(.25), blurRadius: 24)] : const [],
                  ),
                  child: ClipOval(
                    child: AnimatedScale(
                      scale: h ? 1.08 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: SmartImage(url: _imageFor(cat), emoji: categoryEmoji(cat), emojiSize: tile * .4),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: tile + 16,
                  child: Text(cat,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(13.5, color: sel ? HK.amberDeep : HK.ink, weight: FontWeight.w700)),
                ),
              ]),
            ).animate().fadeIn(delay: (50 * i).ms).scaleXY(begin: .8, curve: Curves.easeOutBack);
          },
        ),
      ),
    ]);
  }
}

class ProductRail extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Product> products;
  const ProductRail({super.key, required this.eyebrow, required this.title, this.subtitle, required this.products});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MaxWidth(child: SectionTitle(eyebrow: eyebrow, title: title, subtitle: subtitle)),
      const SizedBox(height: 26),
      SizedBox(
        height: 392,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(sidePad(context), 8, sidePad(context), 8),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 20),
          itemBuilder: (c, i) => SizedBox(width: 290, child: ProductCard(products[i])),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Kitchens, how it works, partner CTA
// ---------------------------------------------------------------------------

class KitchensSection extends StatelessWidget {
  final Map<String, String> kitchens;
  final List<Product> products;
  final ValueChanged<String> onSelect;
  const KitchensSection({super.key, required this.kitchens, required this.products, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      for (final e in kitchens.entries) _KitchenCard(vendorId: e.key, name: e.value, products: products, onTap: () => onSelect(e.key)),
      const _JoinKitchenCard(),
    ];
    return MaxWidth(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle(
          eyebrow: 'Kitchens',
          title: 'Our kitchens',
          subtitle: 'One app, many kitchens. Every partner is verified by the HungryKya team.',
        ),
        const SizedBox(height: 26),
        LayoutBuilder(builder: (c, cons) {
          final cols = cons.maxWidth < 640 ? 1 : (cons.maxWidth < 1000 ? 2 : 3);
          final w = (cons.maxWidth - (cols - 1) * 18) / cols;
          return Wrap(spacing: 18, runSpacing: 18, children: [for (final card in cards) SizedBox(width: w, child: card)]);
        }),
      ]),
    );
  }
}

class _KitchenCard extends StatelessWidget {
  final String vendorId;
  final String name;
  final List<Product> products;
  final VoidCallback onTap;
  const _KitchenCard({required this.vendorId, required this.name, required this.products, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mine = products.where((p) => p.vendorId == vendorId).toList();
    final cats = {for (final p in mine) p.category}.take(3).join(' · ');
    final house = vendorId == AppConfig.houseVendorId;
    return Hoverable(
      onTap: onTap,
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 104,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: h ? HK.cardHi : HK.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: h ? HK.amber.withOpacity(.7) : HK.line),
          boxShadow: HK.shadow(h ? 1.2 : .7),
        ),
        child: Row(children: [
          house
              ? const BrandLogo(size: 62, wordmark: false)
              : Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: HK.fire),
                  alignment: Alignment.center,
                  child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: AppTheme.display(28, color: Colors.black)),
                ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(16.5, weight: FontWeight.w700))),
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, size: 16, color: HK.amberDeep),
              ]),
              const SizedBox(height: 4),
              Text('${mine.length} dishes${cats.isEmpty ? '' : ' · $cats'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(13, color: HK.muted)),
            ]),
          ),
          AnimatedSlide(
            offset: Offset(h ? .2 : 0, 0),
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.arrow_forward_rounded, color: h ? HK.amberDeep : HK.muted),
          ),
        ]),
      ),
    );
  }
}

class _JoinKitchenCard extends StatelessWidget {
  const _JoinKitchenCard();
  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: () => context.go('/partner'),
        builder: (h) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 104,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: HK.amber.withOpacity(h ? .12 : .06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: HK.amber.withOpacity(.45), width: 1.4),
          ),
          child: Row(children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: HK.amberDeep, width: 1.5)),
              child: const Icon(Icons.add_business_rounded, color: HK.amberDeep, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Your kitchen here?', style: AppTheme.body(16.5, color: HK.amberDeep, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Join as a partner · just 2% commission', style: AppTheme.body(13, color: HK.muted)),
              ]),
            ),
            const Icon(Icons.arrow_forward_rounded, color: HK.amberDeep),
          ]),
        ),
      );
}

class HowItWorks extends StatelessWidget {
  const HowItWorks({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.restaurant_menu_rounded, 'Pick your cravings', 'Browse the menu, grab an offer and add your favourites to the cart.'),
      (Icons.qr_code_scanner_rounded, 'Pay your way', 'Pay instantly with any UPI app — GPay, PhonePe, Paytm — or choose cash on delivery.'),
      (Icons.delivery_dining_rounded, 'Track it live', 'Watch your order go from kitchen to doorstep, step by step, in real time.'),
    ];
    return Container(
      color: HK.tint,
      padding: const EdgeInsets.symmetric(vertical: 84),
      child: Stack(children: [
        const Positioned.fill(child: Doodles(seed: 11, opacity: .09, spacing: 140)),
        _content(steps),
      ]),
    );
  }

  Widget _content(List<(IconData, String, String)> steps) {
    return MaxWidth(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle(eyebrow: 'How it works', title: 'Hot food in 3 easy steps'),
        const SizedBox(height: 30),
        LayoutBuilder(builder: (c, cons) {
          final cols = cons.maxWidth < 760 ? 1 : 3;
          final w = (cons.maxWidth - (cols - 1) * 20) / cols;
          return Wrap(spacing: 20, runSpacing: 20, children: [
            for (final (i, (icon, title, body)) in steps.indexed)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: HK.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: HK.line),
                    boxShadow: HK.shadow(),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      FireText('0${i + 1}', style: AppTheme.display(54)),
                      const Spacer(),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(color: HK.amber.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
                        child: Icon(icon, color: HK.amberDeep, size: 26),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Text(title, style: AppTheme.body(19, weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(body, style: AppTheme.body(14, color: HK.muted, height: 1.6)),
                  ]),
                ).animate().fadeIn(delay: (120 * i).ms, duration: 500.ms).slideY(begin: .2),
              ),
          ]);
        }),
      ]),
    );
  }
}

class PartnerCta extends StatelessWidget {
  const PartnerCta({super.key});

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final ticks = [
      'Only 2% commission per order',
      'Free listing, zero setup fee',
      'Your own dashboard for menu & orders',
      'Admin-verified, trusted platform'
    ];
    final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('FOR KITCHENS & HOME CHEFS', style: AppTheme.body(12.5, color: Colors.black, weight: FontWeight.w800).copyWith(letterSpacing: 2.4)),
      const SizedBox(height: 14),
      Text('Grow your food business\nwith HungryKya', style: AppTheme.display(m ? 32 : 50, color: Colors.black)),
      const SizedBox(height: 22),
      for (final t in ticks)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 14, color: HK.amber),
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(t, style: AppTheme.body(15.5, color: Colors.black, weight: FontWeight.w600))),
          ]),
        ),
      const SizedBox(height: 22),
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ElevatedButton(
          onPressed: () => context.go('/partner'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: HK.amber,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Register as vendor'),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ]),
        ),
        TextButton(
          onPressed: () => context.go('/vendor'),
          style: TextButton.styleFrom(foregroundColor: Colors.black),
          child: const Text('Already a partner? Log in'),
        ),
      ]),
    ]);

    return MaxWidth(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: HK.fire,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: HK.flame.withOpacity(.25), blurRadius: 60, offset: const Offset(0, 24))],
        ),
        child: Stack(children: [
          Positioned(
            right: -80,
            top: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black.withOpacity(.08), width: 40)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(m ? 28 : 56),
            child: wide
                ? Row(children: [
                    Expanded(flex: 3, child: left),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 40, offset: const Offset(0, 20))],
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            FireText('2%', style: AppTheme.display(110)),
                            Text('commission only', style: AppTheme.body(16, color: Colors.white, weight: FontWeight.w600)),
                          ]),
                        ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.04, duration: 2.seconds, curve: Curves.easeInOut),
                      ),
                    ),
                  ])
                : left,
          ),
        ]),
      ),
    );
  }
}

class StoreClosedBanner extends StatelessWidget {
  const StoreClosedBanner({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        color: HK.nonVeg.withOpacity(.15),
        child: Text(
          '🌙  We are closed right now. You can browse the menu — ordering opens again soon.',
          textAlign: TextAlign.center,
          style: AppTheme.body(14, weight: FontWeight.w600),
        ),
      );
}

// ---------------------------------------------------------------------------
// Promo banners (admin-managed, placement = bottom)
// ---------------------------------------------------------------------------

class PromoBanners extends StatefulWidget {
  final List<BannerModel> banners;
  final String title;
  final ValueChanged<BannerModel> onTap;
  const PromoBanners({super.key, required this.banners, required this.title, required this.onTap});

  @override
  State<PromoBanners> createState() => _PromoBannersState();
}

class _PromoBannersState extends State<PromoBanners> {
  final _sc = ScrollController();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    // Gentle auto-advance; stops at the end and loops back.
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_sc.hasClients) return;
      final p = _sc.position;
      final next = p.pixels + p.viewportDimension * .8;
      _sc.animateTo(next >= p.maxScrollExtent + 4 ? 0 : next.clamp(0, p.maxScrollExtent),
          duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    final w = MediaQuery.sizeOf(context).width;
    final cardW = m ? w - 48 : (w >= 1300 ? 600.0 : 520.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MaxWidth(child: SectionTitle(eyebrow: 'Specials', title: widget.title)),
      const SizedBox(height: 26),
      SizedBox(
        height: m ? 210 : 260,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad}),
          child: ListView.separated(
            controller: _sc,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: sidePad(context)),
            itemCount: widget.banners.length,
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemBuilder: (c, i) => SizedBox(
              width: cardW,
              child: _PromoCard(banner: widget.banners[i], onTap: () => widget.onTap(widget.banners[i])),
            ).animate().fadeIn(delay: (100 * i).ms).slideX(begin: .1),
          ),
        ),
      ),
    ]);
  }
}

class _PromoCard extends StatelessWidget {
  final BannerModel banner;
  final VoidCallback onTap;
  const _PromoCard({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    return Hoverable(
      onTap: onTap,
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        transform: Matrix4.translationValues(0, h ? -5 : 0, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: HK.shadow(h ? 1.6 : 1)),
        child: Stack(fit: StackFit.expand, children: [
          AnimatedScale(
            scale: h ? 1.06 : 1,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            child: SmartImage(url: banner.imageUrl, emoji: '🍽️', emojiSize: 80),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xE6140C05), Color(0x99140C05), Color(0x00140C05)],
                stops: [0, .5, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(m ? 20 : 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (banner.badge.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(gradient: HK.fire, borderRadius: BorderRadius.circular(8)),
                  child: Text(banner.badge.toUpperCase(), style: AppTheme.body(10.5, color: Colors.black, weight: FontWeight.w900).copyWith(letterSpacing: 1.4)),
                ),
                const SizedBox(height: 12),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(banner.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.display(m ? 24 : 30, color: Colors.white)),
              ),
              if (banner.subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(banner.subtitle,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.body(13.5, color: Colors.white.withOpacity(.85), height: 1.4)),
                ),
              ],
              const SizedBox(height: 14),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(banner.ctaText, style: AppTheme.body(14.5, color: HK.amber, weight: FontWeight.w800)),
                const SizedBox(width: 6),
                AnimatedSlide(
                  offset: Offset(h ? .3 : 0, 0),
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.arrow_forward_rounded, color: HK.amber, size: 18),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

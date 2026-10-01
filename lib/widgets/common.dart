import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../services/media.dart';

const kMaxContentWidth = 1240.0;

bool isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < 700;
bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= 1000;

/// Horizontal padding that centres content within [kMaxContentWidth].
double sidePad(BuildContext c) {
  final w = MediaQuery.sizeOf(c).width;
  final min = w < 700 ? 16.0 : 32.0;
  return w - 2 * min > kMaxContentWidth ? (w - kMaxContentWidth) / 2 : min;
}

class MaxWidth extends StatelessWidget {
  final Widget child;
  final double max;
  final EdgeInsetsGeometry? padding;
  const MaxWidth({super.key, required this.child, this.max = kMaxContentWidth, this.padding});

  @override
  Widget build(BuildContext context) {
    final h = isMobile(context) ? 16.0 : 32.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max + 2 * h),
        child: Padding(padding: padding ?? EdgeInsets.symmetric(horizontal: h), child: child),
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  final double size;
  final bool wordmark;
  final Color textColor;
  const BrandLogo({super.key, this.size = 44, this.wordmark = true, this.textColor = HK.ink});

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: HK.amber.withOpacity(.25), blurRadius: size * .4)],
      ),
      child: ClipOval(child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover)),
    );
    if (!wordmark) return logo;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      logo,
      SizedBox(width: size * .25),
      Text.rich(TextSpan(children: [
        TextSpan(text: 'Hungry', style: AppTheme.script(size * .55, color: textColor)),
        TextSpan(text: 'Kya', style: AppTheme.script(size * .55, color: HK.amberDeep)),
      ])),
    ]);
  }
}

/// Renders `media:<id>` (Firestore-stored photo) or a normal URL, with a
/// branded placeholder when empty or broken.
class SmartImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final String emoji;
  final double emojiSize;
  const SmartImage({super.key, required this.url, this.fit = BoxFit.cover, this.emoji = '🍽️', this.emojiSize = 44});

  @override
  Widget build(BuildContext context) {
    final u = url ?? '';
    if (u.isEmpty) return _placeholder();
    if (u.startsWith('media:')) {
      return FutureBuilder<Uint8List?>(
        future: MediaCache.load(u.substring(6)),
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return _loading();
          if (s.data == null) return _placeholder();
          return Image.memory(s.data!, fit: fit, gaplessPlayback: true, width: double.infinity, height: double.infinity);
        },
      );
    }
    return Image.network(
      u,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _placeholder(),
      loadingBuilder: (c, child, p) => p == null ? child : _loading(),
    );
  }

  Widget _loading() => Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFF0DC), Color(0xFFFFF8EF)])),
      );

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(colors: [Color(0xFFFFE1B3), Color(0xFFFFF4E4)], radius: 1.1, center: Alignment(-.3, -.4)),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: TextStyle(fontSize: emojiSize)),
      );
}

class VegMark extends StatelessWidget {
  final bool isVeg;
  final double size;
  const VegMark({super.key, required this.isVeg, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final c = isVeg ? HK.veg : HK.nonVeg;
    return Tooltip(
      message: isVeg ? 'Vegetarian' : 'Non-vegetarian',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: c, width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.center,
        child: isVeg
            ? Container(width: size * .5, height: size * .5, decoration: BoxDecoration(color: c, shape: BoxShape.circle))
            : CustomPaint(size: Size(size * .55, size * .5), painter: _TrianglePainter(c)),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width / 2, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;
  const Pill(this.label, {super.key, required this.color, this.icon, this.solid = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? color : color.withOpacity(.14),
        borderRadius: BorderRadius.circular(100),
        border: solid ? null : Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: solid ? Colors.white : color), const SizedBox(width: 5)],
        Text(label, style: TextStyle(color: solid ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .2)),
      ]),
    );
  }
}

/// Text painted with the brand fire gradient.
class FireText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const FireText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => HK.fire.createShader(r),
        child: Text(text, style: style),
      );
}

class SectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionTitle({super.key, required this.eyebrow, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 22, height: 2, decoration: const BoxDecoration(gradient: HK.fire)),
            const SizedBox(width: 10),
            Text(eyebrow.toUpperCase(), style: AppTheme.body(12, color: HK.amberDeep, weight: FontWeight.w800).copyWith(letterSpacing: 2.4)),
          ]),
          const SizedBox(height: 10),
          Text(title, style: AppTheme.display(m ? 28 : 40)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: AppTheme.body(m ? 14 : 16, color: HK.muted, height: 1.5)),
          ],
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

void showToast(BuildContext context, String msg, {bool error = false, SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: error ? HK.nonVeg : HK.veg, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      action: action,
    ));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String confirm = 'Confirm', bool destructive = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        ElevatedButton(
          style: destructive ? ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r == true;
}

/// Small loading spinner sized for buttons.
class BtnSpinner extends StatelessWidget {
  final Color color;
  const BtnSpinner({super.key, this.color = Colors.black});
  @override
  Widget build(BuildContext context) => SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: color));
}

/// Adds a small lift + glow on hover (desktop web).
class Hoverable extends StatefulWidget {
  final Widget Function(bool hovering) builder;
  final VoidCallback? onTap;
  const Hoverable({super.key, required this.builder, this.onTap});

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(onTap: widget.onTap, behavior: HitTestBehavior.opaque, child: widget.builder(_h)),
      );
}

/// One line of a bill: label on the left, amount on the right.
class BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const BillRow(this.label, this.value, {super.key, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style.color ?? HK.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text(label,
            style: AppTheme.body(bold ? 17 : 14, color: bold ? base : base.withOpacity(.7), weight: bold ? FontWeight.w800 : FontWeight.w500)),
        const Spacer(),
        Text(value, style: AppTheme.body(bold ? 18 : 14, color: color ?? base, weight: bold ? FontWeight.w800 : FontWeight.w600)),
      ]),
    );
  }
}

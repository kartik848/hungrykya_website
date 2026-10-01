import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Storefront palette: warm white with the logo's saffron and flame accents.
class HK {
  static const bg = Color(0xFFFFFBF5);
  static const surface = Colors.white;
  static const card = Colors.white;
  static const cardHi = Color(0xFFFFF6EA);
  static const tint = Color(0xFFFFF3E0);
  static const line = Color(0xFFF1E5D4);
  static const ink = Color(0xFF231A12);
  static const muted = Color(0xFF85776A);

  /// Bright saffron for fills (buttons, badges) — pair with black text.
  static const amber = Color(0xFFFFB321);

  /// Deep saffron for text and icons on white (readable contrast).
  static const amberDeep = Color(0xFFB85C00);
  static const flame = Color(0xFFFF5A1F);
  static const veg = Color(0xFF1E9E55);
  static const nonVeg = Color(0xFFE23744);

  static const fire = LinearGradient(
    colors: [amber, flame],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> shadow([double strength = 1]) => [
        BoxShadow(color: const Color(0xFF8A4B0F).withOpacity(.07 * strength), blurRadius: 30 * strength, offset: Offset(0, 12 * strength)),
        BoxShadow(color: const Color(0xFF8A4B0F).withOpacity(.04), blurRadius: 6, offset: const Offset(0, 2)),
      ];
}

/// Admin / vendor console palette: light SaaS surface with the same accents.
class PK {
  static const bg = Color(0xFFF6F4F1);
  static const card = Colors.white;
  static const line = Color(0xFFEAE4DC);
  static const ink = Color(0xFF1C1713);
  static const muted = Color(0xFF7A6F64);
  static const sidebar = Color(0xFF15110D);
  static const amber = Color(0xFFF5A00B);
  static const flame = HK.flame;
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF7C3AED);
}

class AppTheme {
  static TextStyle display(double size, {Color color = HK.ink, FontWeight weight = FontWeight.w700, double height = 1.08}) =>
      GoogleFonts.fraunces(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: -0.4);

  static TextStyle script(double size, {Color color = HK.flame}) => GoogleFonts.kaushanScript(fontSize: size, color: color, height: 1.1);

  static TextStyle body(double size, {Color color = HK.ink, FontWeight weight = FontWeight.w400, double? height}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, color: color, fontWeight: weight, height: height);

  static InputDecorationTheme _inputs({required Color fill, required Color border, required Color focus, required Color hint}) {
    OutlineInputBorder b(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(color: hint),
      labelStyle: TextStyle(color: hint),
      floatingLabelStyle: TextStyle(color: focus, fontWeight: FontWeight.w600),
      border: b(border),
      enabledBorder: b(border),
      focusedBorder: b(focus, 1.6),
      errorBorder: b(HK.nonVeg),
      focusedErrorBorder: b(HK.nonVeg, 1.6),
    );
  }

  static ThemeData get store {
    final scheme = ColorScheme.fromSeed(seedColor: HK.amber, brightness: Brightness.light).copyWith(
      primary: HK.amber,
      onPrimary: Colors.black,
      secondary: HK.flame,
      surface: Colors.white,
      onSurface: HK.ink,
      error: HK.nonVeg,
    );
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: HK.bg,
      canvasColor: HK.bg,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: HK.ink, displayColor: HK.ink),
      iconTheme: const IconThemeData(color: HK.ink),
      dividerColor: HK.line,
      dividerTheme: const DividerThemeData(color: HK.line, space: 1),
      inputDecorationTheme: _inputs(fill: Colors.white, border: HK.line, focus: HK.amberDeep, hint: HK.muted),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HK.amber,
          foregroundColor: Colors.black,
          disabledBackgroundColor: HK.line,
          disabledForegroundColor: HK.muted,
          elevation: 0,
          shadowColor: HK.flame.withOpacity(.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HK.ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: HK.line, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HK.amberDeep,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: HK.ink,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        width: 420,
      ),
      dialogBackgroundColor: Colors.white,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: HK.line,
      ),
      popupMenuTheme: const PopupMenuThemeData(color: Colors.white, surfaceTintColor: Colors.transparent, elevation: 8, shadowColor: Colors.black26),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? HK.amber : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(Colors.black),
        side: const BorderSide(color: HK.muted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: HK.flame),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: HK.ink, borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  static ThemeData get panel {
    final scheme = ColorScheme.fromSeed(seedColor: PK.amber, brightness: Brightness.light).copyWith(
      primary: PK.amber,
      onPrimary: Colors.black,
      secondary: PK.flame,
      surface: Colors.white,
      onSurface: PK.ink,
      error: PK.red,
    );
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: PK.bg,
      canvasColor: PK.bg,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: PK.ink, displayColor: PK.ink),
      dividerColor: PK.line,
      dividerTheme: const DividerThemeData(color: PK.line, space: 1),
      inputDecorationTheme: _inputs(fill: Colors.white, border: PK.line, focus: PK.amber, hint: PK.muted),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PK.amber,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PK.ink,
          side: const BorderSide(color: PK.line, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFB86E00), textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PK.ink,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        width: 420,
      ),
      dialogBackgroundColor: Colors.white,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? PK.green : null),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: PK.amber.withOpacity(.18),
        side: const BorderSide(color: PK.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: GoogleFonts.plusJakartaSans(color: PK.ink, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

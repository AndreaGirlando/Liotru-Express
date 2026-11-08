import 'package:flutter/material.dart';

class BusDesign {
  static const ink = Color(0xff142d40);
  static const lime = Color(0xffc0f578);
  static const teal = Color(0xff08745d);
  static ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(seedColor: teal, brightness: brightness)
        .copyWith(
          primary: dark ? lime : ink,
          onPrimary: dark ? ink : Colors.white,
          secondary: teal,
          surface: dark ? const Color(0xff182b3a) : Colors.white,
          onSurface: dark ? const Color(0xffedf5f2) : ink,
          onSurfaceVariant: dark
              ? const Color(0xffa4b7bd)
              : const Color(0xff64757a),
          outlineVariant: dark
              ? const Color(0xff304554)
              : const Color(0xffe3e9e4),
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: dark
          ? const Color(0xff0e1e2a)
          : const Color(0xfff3f6f1),
      textTheme:
          const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -1.3,
            ),
            headlineMedium: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -.8,
            ),
            headlineSmall: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -.6,
            ),
            titleLarge: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.3,
              letterSpacing: -.4,
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
            bodyLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
            bodyMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
            labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            labelSmall: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ).apply(
            fontFamily: 'Manrope',
            bodyColor: colors.onSurface,
            displayColor: colors.onSurface,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: teal, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          side: BorderSide(color: colors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: dark ? teal : lime,
        elevation: 0,
        height: 74,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            fontFamily: 'Manrope',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}

class SmallPill extends StatelessWidget {
  const SmallPill(
    this.label, {
    this.color,
    this.background,
    this.icon,
    super.key,
  });
  final String label;
  final Color? color, background;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color:
          background ??
          Theme.of(context).colorScheme.primary.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Wrap(
      spacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (icon != null)
          Icon(
            icon,
            size: 13,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (trailing != null) trailing!,
    ],
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    required this.title,
    required this.message,
    this.icon = Icons.directions_bus_outlined,
    this.action,
    super.key,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, size: 28),
        ),
        const SizedBox(height: 18),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

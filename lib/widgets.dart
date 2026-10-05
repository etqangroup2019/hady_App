import 'package:flutter/material.dart';

import 'models.dart';

/// لوحة هادئة بحواف مستديرة تُستخدم بدل Card لتبقى متوافقة مع كل إصدارات Flutter.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final bg = color ?? (dark ? const Color(0xFF18241F) : Colors.white);
    final radius = BorderRadius.circular(20);
    return Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: borderColor ?? cs.outlineVariant.withAlpha(110)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class StepperField extends StatelessWidget {
  final String label;
  final int value;
  final int min, max, step;
  final String Function(int)? format;
  final ValueChanged<int> onChanged;

  const StepperField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 120,
    this.step = 5,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canDec = value - step >= min;
    final canInc = value + step <= max;

    Widget btn(IconData ic, bool on, VoidCallback f) => InkResponse(
          onTap: on ? f : null,
          radius: 24,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(ic, size: 20, color: on ? cs.primary : cs.onSurface.withOpacity(0.28)),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          // أزرار موحّدة الحجم داخل كبسولة واحدة (− يسار، + يمين كالعدّاد)
          Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  btn(Icons.remove_rounded, canDec, () => onChanged(value - step)),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 58),
                    child: Center(
                      child: Text(
                        format != null ? format!(value) : '$value د',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
                  btn(Icons.add_rounded, canInc, () => onChanged(value + step)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color catColor(Cat c) {
  switch (c) {
    case Cat.worship:
      return const Color(0xFF2E7D6B);
    case Cat.quran:
      return const Color(0xFFB08D3C);
    case Cat.dhikr:
      return const Color(0xFF4A8FB3);
    case Cat.sleep:
      return const Color(0xFF6C74C4);
    case Cat.work:
      return const Color(0xFF607D8B);
    case Cat.family:
      return const Color(0xFFCB7A83);
    case Cat.personal:
      return const Color(0xFF8D6E63);
    case Cat.home:
      return const Color(0xFF3FA796);
  }
}

IconData catIcon(Cat c) {
  switch (c) {
    case Cat.worship:
      return Icons.mosque_outlined;
    case Cat.quran:
      return Icons.menu_book_outlined;
    case Cat.dhikr:
      return Icons.spa_outlined;
    case Cat.sleep:
      return Icons.bedtime_outlined;
    case Cat.work:
      return Icons.work_outline;
    case Cat.family:
      return Icons.family_restroom_outlined;
    case Cat.personal:
      return Icons.person_outline;
    case Cat.home:
      return Icons.cleaning_services_outlined;
  }
}

class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PageTitle(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: tt.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class AngleField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const AngleField({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    double r(double v) => (v * 10).round() / 10;
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton.outlined(
          visualDensity: VisualDensity.compact,
          onPressed: value > 10 ? () => onChanged(r(value - 0.5)) : null,
          icon: const Icon(Icons.remove, size: 18),
        ),
        SizedBox(
          width: 70,
          child: Center(
            child: Text('${value.toStringAsFixed(1)}°', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        IconButton.outlined(
          visualDensity: VisualDensity.compact,
          onPressed: value < 25 ? () => onChanged(r(value + 0.5)) : null,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/roles.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF182025) : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cs.outlineVariant.withOpacity(.55))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

Color statusColor(String s) {
  switch (s.toUpperCase()) {
    case 'ACTIVO':
    case 'APROBADA':
    case 'PAGADO':
    case 'FINALIZADA':
    case 'PRINCIPAL':
      return const Color(0xFF27AE60);
    case 'PENDIENTE':
      return const Color(0xFFE0A100);
    case 'EN CURSO':
      return const Color(0xFF2F80ED);
    case 'RECHAZADA':
    case 'VENCIDO':
    case 'FALLECIDO':
      return const Color(0xFFEB5757);
    case 'EN_ENFERMERIA':
      return const Color(0xFF2F80ED);
    case 'HOSPITALIZADO':
      return const Color(0xFFF2994A);
    default:
      return roleColors[s.toUpperCase()] ?? const Color(0xFF828282);
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  const StatusChip(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = statusColor(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(.14), borderRadius: BorderRadius.circular(99)),
      child: Text(text.replaceAll('_', ' '),
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: .2)),
    );
  }
}

class Avatar extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final double size;
  const Avatar(this.text, this.color, {super.key, this.icon, this.size = 46});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .32),
          gradient: LinearGradient(
              colors: [color.withOpacity(.22), color.withOpacity(.08)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: icon != null
            ? Icon(icon, color: color, size: size * .5)
            : Text(initials(text),
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: size * .34)),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget? action;
  const EmptyState(this.icon, this.title, this.subtitle, {super.key, this.action});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cs.primaryContainer.withOpacity(.5), shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: cs.primary)),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

class Fact extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const Fact(this.icon, this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: cs.primaryContainer.withOpacity(.55), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: cs.primary)),
      const SizedBox(width: 12),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ])),
    ]);
  }
}

/// Distribuye hijos en 1 o 2 columnas según el ancho disponible.
class Responsive extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;
  const Responsive(this.children, {super.key, this.minWidth = 300});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, box) {
        final cols = (box.maxWidth / minWidth).floor().clamp(1, 4);
        final w = (box.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(spacing: 16, runSpacing: 16, children: [for (final x in children) SizedBox(width: w, child: x)]);
      });
}

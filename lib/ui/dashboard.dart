import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/format.dart';
import '../core/roles.dart';
import '../core/schema.dart';
import '../state/auth_state.dart';
import '../state/stores.dart';
import 'actions.dart';
import 'entity_detail.dart';
import 'widgets.dart';

const _quick = {
  'ADMIN': ['internos', 'solicitudes', 'transacciones', 'usuarios'],
  'RECEPCION': ['solicitudes', 'visitas', 'visitantes', 'internos'],
  'MEDICO': ['fichas'],
  'ENFERMERO': ['fichas'],
  'FINANCIERO': ['transacciones'],
};

class DashboardPage extends StatefulWidget {
  final void Function(String key) onNavigate;
  const DashboardPage({super.key, required this.onNavigate});
  @override
  State<DashboardPage> createState() => _S();
}

class _S extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final st = context.read<Stores>();
      final role = context.read<AuthState>().rol;
      for (final s in schemas) {
        if (can(role, s.key, 'r')) st.of(s.key).load();
      }
      for (final k in ['internos', 'visitantes', 'usuarios']) {
        st.of(k).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stores = context.read<Stores>();
    final auth = context.watch<AuthState>();
    final role = auth.rol;
    final cs = Theme.of(context).colorScheme;
    final rc = roleColors[role] ?? brandColor;
    final readable = [for (final s in schemas) if (can(role, s.key, 'r')) stores.of(s.key)];

    return ListenableBuilder(
      listenable: Listenable.merge([...readable, stores.of('internos'), stores.of('visitantes'), stores.of('usuarios')]),
      builder: (context, _) {
        List<Item> items(String k) => can(role, k, 'r') ? stores.of(k).items : const [];
        final internos = items('internos');
        final sol = items('solicitudes').where((i) => i['estadoSolicitud'] == 'PENDIENTE').toList();
        final vis = items('visitas').where((i) => i['fechaHoraSalida'] == null).toList();
        final fichas = items('fichas');
        final now = DateTime.now();
        final fichasMes = fichas.where((f) {
          final d = parseDt(f['fechaRegistro']);
          return d != null && d.year == now.year && d.month == now.month;
        }).length;
        final trans = items('transacciones');
        bool ingreso(Item t) => t['tipo'] == 'INGRESO_CUOTA' || t['tipo'] == 'DONACION';
        num sum(String e) => trans.where((t) => ingreso(t) && t['estadoPago'] == e).fold<num>(0, (a, t) => a + ((t['monto'] ?? 0) as num));
        final pend = trans.where((t) => ingreso(t) && t['estadoPago'] == 'PENDIENTE').toList();

        final stats = <(String, String, String, IconData, Color, String)>[
          if (can(role, 'internos', 'r')) ('Internos activos', '${internos.where((i) => i['estado'] == 'ACTIVO').length}', 'de ${internos.length} registrados', Icons.elderly, const Color(0xFF0E7C86), 'internos'),
          if (can(role, 'solicitudes', 'r')) ('Solicitudes pendientes', '${sol.length}', 'por revisar', Icons.assignment_ind_outlined, const Color(0xFFF2994A), 'solicitudes'),
          if (can(role, 'visitas', 'r')) ('Visitas en curso', '${vis.length}', 'dentro del hogar ahora', Icons.how_to_reg_outlined, const Color(0xFF2D9CDB), 'visitas'),
          if (can(role, 'fichas', 'r')) ('Fichas este mes', '$fichasMes', '${fichas.length} en total', Icons.medical_services_outlined, const Color(0xFFEB5757), 'fichas'),
          if (can(role, 'transacciones', 'r')) ('Por cobrar', money(sum('PENDIENTE')), '${pend.length} pago(s) pendiente(s)', Icons.hourglass_bottom, const Color(0xFFE0A100), 'transacciones'),
          if (can(role, 'transacciones', 'r')) ('Cobrado', money(sum('PAGADO')), 'pagos confirmados', Icons.check_circle_outline, const Color(0xFF27AE60), 'transacciones'),
          if (can(role, 'usuarios', 'r')) ('Usuarios', '${items('usuarios').length}', 'con acceso al sistema', Icons.admin_panel_settings_outlined, const Color(0xFF6D4AFF), 'usuarios'),
        ];

        final quick = [for (final k in _quick[role] ?? const <String>[]) if (can(role, k, 'c')) schemaOf(k)];

        Widget panel(String title, IconData icon, String key, List<Item> rows, String empty, {Widget Function(Item)? trailing}) {
          final s = schemaOf(key);
          return AppCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 20, color: s.color),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                TextButton(onPressed: () => widget.onNavigate(key), child: const Text('Ver todo')),
              ]),
              if (rows.isEmpty) Padding(padding: const EdgeInsets.fromLTRB(0, 8, 8, 16), child: Text(empty, style: TextStyle(color: cs.onSurfaceVariant))),
              for (final r in rows.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Avatar(s.titleOf(r, stores.label), s.color, size: 38),
                  title: Text(s.titleOf(r, stores.label), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(s.subtitleOf?.call(r, stores.label) ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: trailing?.call(r) ?? (s.trailingOf != null ? Text(s.trailingOf!(r) ?? '', style: const TextStyle(fontWeight: FontWeight.w800)) : null),
                  onTap: () => openDetail(context, s, r),
                ),
            ]),
          );
        }

        return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(colors: [rc, Color.lerp(rc, const Color(0xFF0B3C49), .55)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  ),
                  child: Row(children: [
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${greeting()},', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                      Text(auth.username ?? '', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(99)),
                          child: Text('${roleLabels[role] ?? role} · ${roleTaglines[role] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600))),
                    ])),
                    if (MediaQuery.of(context).size.width > 520) const Icon(Icons.volunteer_activism, color: Colors.white24, size: 72),
                  ]),
                ),
                const SizedBox(height: 20),
                Responsive([
                  for (final t in stats)
                    AppCard(
                      onTap: () => widget.onNavigate(t.$6),
                      child: Row(children: [
                        Avatar('', t.$5, icon: t.$4),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(t.$2, maxLines: 1, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
                          Text(t.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(t.$3, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ])),
                      ]),
                    ),
                ], minWidth: 250),
                if (quick.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final s in quick) FilledButton.tonalIcon(onPressed: () => openForm(context, s), icon: Icon(s.icon), label: Text(s.newLabel)),
                  ]),
                ],
                const SizedBox(height: 20),
                Responsive([
                  if (can(role, 'solicitudes', 'r')) panel('Solicitudes pendientes', Icons.assignment_ind_outlined, 'solicitudes', sol, 'No hay solicitudes por revisar.'),
                  if (can(role, 'visitas', 'r'))
                    panel('Visitas en curso', Icons.how_to_reg_outlined, 'visitas', vis, 'No hay visitas dentro del hogar.',
                        trailing: can(role, 'visitas', 'c')
                            ? (r) => TextButton(onPressed: () => runAction(context, schemaOf('visitas'), schemaOf('visitas').actions.first, r), child: const Text('Salida'))
                            : null),
                  if (can(role, 'fichas', 'r')) panel('Últimas fichas médicas', Icons.medical_services_outlined, 'fichas', fichas, 'Aún no hay fichas.'),
                  if (can(role, 'transacciones', 'r')) panel('Pagos pendientes', Icons.payments_outlined, 'transacciones', pend, 'No hay pagos pendientes.'),
                ], minWidth: 420),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

const brandColor = Color(0xFF0E7C86);

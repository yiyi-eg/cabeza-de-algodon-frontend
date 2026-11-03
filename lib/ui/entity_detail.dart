import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/format.dart';
import '../core/roles.dart';
import '../core/schema.dart';
import '../state/auth_state.dart';
import '../state/stores.dart';
import 'actions.dart';
import 'entity_list.dart';
import 'widgets.dart';

void openDetail(BuildContext c, Schema s, Item item) {
  if (s.key == 'internos') {
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => InternoDetailPage(internoId: item[s.idKey])));
    return;
  }
  showModalBottomSheet(
      context: c,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _DetailSheet(schema: s, item: item));
}

class _DetailSheet extends StatelessWidget {
  final Schema schema;
  final Item item;
  const _DetailSheet({required this.schema, required this.item});

  @override
  Widget build(BuildContext context) {
    final stores = context.read<Stores>();
    final role = context.watch<AuthState>().rol;
    final s = schema;
    final title = s.titleOf(item, stores.label);
    final badge = s.badgeOf?.call(item);
    final canEdit = s.apiUpdate && can(role, s.key, 'u');
    final canDel = s.apiDelete && can(role, s.key, 'd');
    final acts = [for (final a in s.actions) if (can(role, s.key, a.perm) && a.visible(item)) a];
    final fields = s.fields.where((f) => f.type != FT.password).toList();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), shrinkWrap: true, children: [
          Row(children: [
            Avatar(title, s.color, icon: s.icon),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            if (badge != null) StatusChip(badge),
          ]),
          const SizedBox(height: 20),
          for (final f in fields)
            Padding(padding: const EdgeInsets.only(bottom: 14), child: Fact(f.icon == Icons.edit_outlined ? Icons.info_outline : f.icon, f.label, stores.show(f, item))),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final a in acts)
              FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await runAction(context, s, a, item);
                  },
                  icon: Icon(a.icon),
                  label: Text(a.label)),
            if (canEdit)
              OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    openForm(context, s, item: item);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar')),
            if (canDel)
              OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    if (await confirmDelete(context, s, item)) nav.pop();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar')),
          ]),
        ]),
      ),
    );
  }
}

/// Ficha completa del interno: datos, salud, responsables, finanzas y visitas.
class InternoDetailPage extends StatefulWidget {
  final Object? internoId;
  const InternoDetailPage({super.key, required this.internoId});
  @override
  State<InternoDetailPage> createState() => _IS();
}

class _IS extends State<InternoDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final st = context.read<Stores>();
      final role = context.read<AuthState>().rol;
      for (final k in ['solicitudes', 'responsables', 'asignaciones', 'usuarios', 'visitantes']) {
        st.of(k).load();
      }
      for (final k in ['fichas', 'transacciones', 'visitas']) {
        if (can(role, k, 'r')) st.of(k).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stores = context.read<Stores>();
    final role = context.watch<AuthState>().rol;
    final s = schemaOf('internos');
    return ListenableBuilder(
      listenable: Listenable.merge([for (final x in schemas) stores.of(x.key)]),
      builder: (context, _) {
        final it = stores.of('internos').byId(widget.internoId);
        if (it == null) {
          return Scaffold(appBar: AppBar(), body: const EmptyState(Icons.search_off, 'Registro no disponible', 'Es posible que haya sido eliminado.'));
        }
        final id = it[s.idKey];
        final name = s.titleOf(it, stores.label);
        final tabs = <(String, IconData, Widget)>[
          ('Datos', Icons.badge_outlined, _datos(context, it)),
          if (can(role, 'fichas', 'r')) ('Salud', Icons.monitor_heart_outlined, _salud(context, it, id)),
          ('Responsables', Icons.family_restroom, _responsables(context, id)),
          if (can(role, 'transacciones', 'r')) ('Finanzas', Icons.payments_outlined, _finanzas(context, id)),
          if (can(role, 'visitas', 'r')) ('Visitas', Icons.how_to_reg_outlined, _visitas(context, id)),
        ];
        final age = ageOf(it['fechaNacimiento']);
        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(title: const Text('Ficha del interno'), actions: [
              if (can(role, 'internos', 'u')) IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined), onPressed: () => openForm(context, s, item: it)),
              if (can(role, 'internos', 'd'))
                IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      if (await confirmDelete(context, s, it)) nav.pop();
                    }),
            ]),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(children: [
                  Avatar(name, s.color, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    Text('${age != null ? '$age años · ' : ''}Hab. ${it['numeroHabitacion']} · Cama ${it['numeroCama']}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ])),
                  StatusChip('${it['estado']}'),
                ]),
              ),
              TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in tabs) Tab(icon: Icon(t.$2, size: 20), text: t.$1)]),
              Expanded(child: TabBarView(children: [for (final t in tabs) t.$3])),
            ]),
          ),
        );
      },
    );
  }

  Widget _page(List<Widget> children) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: ListView(padding: const EdgeInsets.all(20), children: children)));

  Widget _head(BuildContext c, String title, {String? action, VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          if (action != null && onTap != null) FilledButton.tonalIcon(onPressed: onTap, icon: const Icon(Icons.add), label: Text(action)),
        ]),
      );

  Widget _list(String key, List<Item> rows, String empty) => rows.isEmpty
      ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(empty, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))))
      : Column(children: [for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 12), child: EntityCard(schema: schemaOf(key), item: r))]);

  Widget _datos(BuildContext c, Item it) {
    final stores = c.read<Stores>();
    final age = ageOf(it['fechaNacimiento']);
    return _page([
      AppCard(
        child: Responsive([
          Fact(Icons.badge_outlined, 'DPI', '${it['dpi']}'),
          Fact(Icons.cake_outlined, 'Fecha de nacimiento', '${fmtDate(it['fechaNacimiento'])}${age != null ? ' ($age años)' : ''}'),
          Fact(Icons.wc_outlined, 'Género', '${it['genero']}'),
          Fact(Icons.meeting_room_outlined, 'Habitación', '${it['numeroHabitacion']}'),
          Fact(Icons.bed_outlined, 'Cama', '${it['numeroCama']}'),
          Fact(Icons.login, 'Fecha de ingreso', fmtDate(it['fechaIngreso'])),
          Fact(Icons.assignment_ind_outlined, 'Solicitud de referencia', stores.label('solicitudes', it['solicitudReferenciaId'])),
          Fact(Icons.update, 'Última actualización', fmtDateTime(it['actualizadoEn'])),
        ], minWidth: 240),
      ),
    ]);
  }

  Widget _salud(BuildContext c, Item it, dynamic id) {
    final role = c.read<AuthState>().rol;
    final cs = Theme.of(c).colorScheme;
    final fichas = [for (final f in c.read<Stores>().of('fichas').items) if ('${idOf(f['interno'], 'idInterno')}' == '$id') f];
    Widget note(IconData i, String t, String v, Color col) => AppCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: col),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)), const SizedBox(height: 2), Text(v.isEmpty ? '—' : v, style: const TextStyle(fontWeight: FontWeight.w600))])),
        ]));
    return _page([
      Responsive([
        note(Icons.bloodtype_outlined, 'Tipo de sangre', '${it['tipoSangre']}', const Color(0xFFEB5757)),
        note(Icons.warning_amber_outlined, 'Alergias', '${it['alergias']}', const Color(0xFFF2994A)),
        note(Icons.monitor_heart_outlined, 'Condiciones crónicas', '${it['condicionesCronicas']}', const Color(0xFF0E7C86)),
      ], minWidth: 240),
      const SizedBox(height: 24),
      _head(c, 'Historial médico', action: can(role, 'fichas', 'c') ? 'Nueva ficha' : null, onTap: () => openForm(c, schemaOf('fichas'), preset: {'interno': id}, lock: {'interno'})),
      _list('fichas', fichas, 'Sin fichas médicas registradas.'),
    ]);
  }

  Widget _responsables(BuildContext c, dynamic id) {
    final stores = c.read<Stores>();
    final role = c.read<AuthState>().rol;
    final cs = Theme.of(c).colorScheme;
    final rows = [for (final a in stores.of('asignaciones').items) if ('${a['internoId']}' == '$id') a];
    return _page([
      _head(c, 'Familiares y responsables', action: can(role, 'asignaciones', 'c') ? 'Asignar' : null, onTap: () => openForm(c, schemaOf('asignaciones'), preset: {'internoId': id}, lock: {'internoId'})),
      if (rows.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Sin responsables asignados.', style: TextStyle(color: cs.onSurfaceVariant)))),
      for (final a in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Builder(builder: (_) {
            final r = stores.of('responsables').byId(a['responsableId']);
            final name = r == null ? '#${a['responsableId']}' : '${r['nombre']} ${r['apellido']}';
            return AppCard(
              onTap: r == null ? null : () => openDetail(c, schemaOf('responsables'), r),
              child: Row(children: [
                Avatar(name, const Color(0xFF9B51E0)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('${a['parentesco']}${r != null ? ' · ${r['telefono']}' : ''}', style: TextStyle(color: cs.onSurfaceVariant)),
                  if (r != null) Text('${r['direccion']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                ])),
                if (a['esContactoPrincipal'] == true) const StatusChip('PRINCIPAL'),
                if (can(role, 'asignaciones', 'd')) IconButton(tooltip: 'Quitar', icon: Icon(Icons.link_off, color: cs.error), onPressed: () => confirmDelete(c, schemaOf('asignaciones'), a)),
              ]),
            );
          }),
        ),
    ]);
  }

  Widget _finanzas(BuildContext c, dynamic id) {
    final role = c.read<AuthState>().rol;
    final rows = [for (final t in c.read<Stores>().of('transacciones').items) if ('${idOf(t['interno'], 'idInterno')}' == '$id') t];
    num sum(String e) => rows.where((t) => (t['tipo'] == 'INGRESO_CUOTA' || t['tipo'] == 'DONACION') && t['estadoPago'] == e).fold<num>(0, (a, t) => a + ((t['monto'] ?? 0) as num));
    return _page([
      Responsive([
        AppCard(child: Fact(Icons.hourglass_bottom, 'Pendiente de pago', money(sum('PENDIENTE')))),
        AppCard(child: Fact(Icons.check_circle_outline, 'Pagado', money(sum('PAGADO')))),
      ], minWidth: 240),
      const SizedBox(height: 24),
      _head(c, 'Movimientos', action: can(role, 'transacciones', 'c') ? 'Nueva transacción' : null, onTap: () => openForm(c, schemaOf('transacciones'), preset: {'interno': id}, lock: {'interno'})),
      _list('transacciones', rows, 'Sin movimientos financieros.'),
    ]);
  }

  Widget _visitas(BuildContext c, dynamic id) {
    final role = c.read<AuthState>().rol;
    final rows = [for (final v in c.read<Stores>().of('visitas').items) if ('${v['internoId']}' == '$id') v];
    return _page([
      _head(c, 'Historial de visitas', action: can(role, 'visitas', 'c') ? 'Registrar visita' : null, onTap: () => openForm(c, schemaOf('visitas'), preset: {'internoId': id}, lock: {'internoId'})),
      _list('visitas', rows, 'Sin visitas registradas.'),
    ]);
  }
}

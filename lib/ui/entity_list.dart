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

class EntityListPage extends StatefulWidget {
  final Schema schema;
  const EntityListPage({super.key, required this.schema});
  @override
  State<EntityListPage> createState() => _S();
}

class _S extends State<EntityListPage> {
  String _q = '';
  String? _filter;
  Schema get s => widget.schema;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    final st = context.read<Stores>();
    for (final k in s.relatedKeys) {
      st.of(k).load();
    }
    await st.of(s.key).load(force: force);
  }

  @override
  Widget build(BuildContext context) {
    final stores = context.read<Stores>();
    final role = context.watch<AuthState>().rol;
    final st = stores.of(s.key);
    final cs = Theme.of(context).colorScheme;
    final canNew = s.apiCreate && can(role, s.key, 'c');

    return ListenableBuilder(
      listenable: Listenable.merge([st, ...s.relatedKeys.map(stores.of)]),
      builder: (context, _) {
        final all = st.items;
        final badges = {for (final i in all) if (s.badgeOf?.call(i) != null) s.badgeOf!(i)!}.toList()..sort();
        final q = _q.trim().toLowerCase();
        final shown = all.where((i) {
          if (_filter != null && s.badgeOf?.call(i) != _filter) return false;
          return q.isEmpty || stores.searchText(s, i).contains(q);
        }).toList();

        Widget body;
        if (st.loading && all.isEmpty) {
          body = const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
        } else if (st.error != null && all.isEmpty) {
          body = EmptyState(Icons.cloud_off_outlined, 'No se pudo cargar', st.error!,
              action: FilledButton.icon(onPressed: () => _load(force: true), icon: const Icon(Icons.refresh), label: const Text('Reintentar')));
        } else if (shown.isEmpty) {
          body = EmptyState(s.icon, all.isEmpty ? 'Aún no hay registros' : 'Sin resultados',
              all.isEmpty ? 'Cuando agregues ${s.title.toLowerCase()}, aparecerán aquí.' : 'Prueba con otra búsqueda o filtro.',
              action: all.isEmpty && canNew
                  ? FilledButton.icon(onPressed: () => openForm(context, s), icon: const Icon(Icons.add), label: Text(s.newLabel))
                  : null);
        } else {
          body = Responsive([for (final i in shown) EntityCard(schema: s, item: i)], minWidth: s.key == 'fichas' ? 640 : 520);
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: RefreshIndicator(
              onRefresh: () => _load(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                children: [
                  if (MediaQuery.of(context).size.width < 600) ...[
                    Text('${all.length} registro${all.length == 1 ? '' : 's'}', style: TextStyle(color: cs.onSurfaceVariant)),
                    if (canNew) ...[
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => openForm(context, s), icon: const Icon(Icons.add), label: Text(s.newLabel))),
                    ],
                  ] else
                    Row(children: [
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text('${all.length} registro${all.length == 1 ? '' : 's'}', style: TextStyle(color: cs.onSurfaceVariant)),
                      ])),
                      if (canNew) FilledButton.icon(onPressed: () => openForm(context, s), icon: const Icon(Icons.add), label: Text(s.newLabel)),
                    ]),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(
                        hintText: 'Buscar en ${s.title.toLowerCase()}…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _q.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _q = ''))),
                  ),
                  if (badges.length > 1) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text('Todos'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null))),
                        for (final b in badges)
                          Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(b.replaceAll('_', ' ')), selected: _filter == b, onSelected: (_) => setState(() => _filter = _filter == b ? null : b))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  body,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tarjeta reutilizable de cualquier entidad (con menú de acciones según rol).
class EntityCard extends StatelessWidget {
  final Schema schema;
  final Item item;
  const EntityCard({super.key, required this.schema, required this.item});

  @override
  Widget build(BuildContext context) {
    final stores = context.read<Stores>();
    final role = context.watch<AuthState>().rol;
    final s = schema;
    if (s.key == 'fichas') return _FichaCard(item: item);
    final cs = Theme.of(context).colorScheme;
    final title = s.titleOf(item, stores.label);
    final sub = s.subtitleOf?.call(item, stores.label);
    final badge = s.badgeOf?.call(item);
    final trailing = s.trailingOf?.call(item);
    final metas = [
      for (final f in s.fields)
        if (f.inCard && item[f.key] != null) (f, stores.show(f, item)),
    ];
    final canEdit = s.apiUpdate && can(role, s.key, 'u');
    final canDel = s.apiDelete && can(role, s.key, 'd');
    final acts = [for (final a in s.actions) if (can(role, s.key, a.perm) && a.visible(item)) a];

    return AppCard(
      onTap: () => openDetail(context, s, item),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Avatar(title, s.color, icon: s.key == 'transacciones' ? s.icon : null),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            if (trailing != null) Padding(padding: const EdgeInsets.only(left: 8), child: Text(trailing, style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
          if (sub != null && sub.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurfaceVariant))),
          if (badge != null || metas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (badge != null) StatusChip(badge),
                for (final (f, v) in metas)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(f.icon, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant))),
                  ]),
              ]),
            ),
        ])),
        if (canEdit || canDel || acts.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'edit') openForm(context, s, item: item);
              if (v == 'del') confirmDelete(context, s, item);
              if (v.startsWith('act')) runAction(context, s, acts[int.parse(v.substring(3))], item);
            },
            itemBuilder: (_) => [
              for (var k = 0; k < acts.length; k++) PopupMenuItem(value: 'act$k', child: ListTile(leading: Icon(acts[k].icon), title: Text(acts[k].label), dense: true, contentPadding: EdgeInsets.zero)),
              if (canEdit) const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar'), dense: true, contentPadding: EdgeInsets.zero)),
              if (canDel) PopupMenuItem(value: 'del', child: ListTile(leading: Icon(Icons.delete_outline, color: cs.error), title: Text('Eliminar', style: TextStyle(color: cs.error)), dense: true, contentPadding: EdgeInsets.zero)),
            ],
          ),
      ]),
    );
  }
}


/// Tarjeta de ficha médica: muestra todos los datos de la tabla sin abrir el detalle.
class _FichaCard extends StatelessWidget {
  final Item item;
  const _FichaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final stores = context.read<Stores>();
    final s = schemaOf('fichas');
    final cs = Theme.of(context).colorScheme;
    final name = s.titleOf(item, stores.label);
    final medico = stores.label('usuarios', idOf(item['usuario'], 'idUsuario'));

    Widget block(IconData icon, String label, Color color, dynamic value) {
      final t = '${value ?? ''}'.trim();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(t.isEmpty ? '—' : t),
          ])),
        ]),
      );
    }

    return AppCard(
      onTap: () => openDetail(context, s, item),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(name, s.color, size: 40),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Row(children: [
              Icon(Icons.event_outlined, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(child: Text(fmtDateTime(item['fechaRegistro']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant))),
            ]),
          ])),
        ]),
        const SizedBox(height: 12),
        block(Icons.healing, 'Diagnóstico', const Color(0xFFEB5757), item['diagnostico']),
        const SizedBox(height: 8),
        block(Icons.medication_outlined, 'Tratamiento recetado', const Color(0xFF0E7C86), item['tratamientoRecetado']),
        const SizedBox(height: 8),
        block(Icons.notes, 'Observaciones de enfermería', const Color(0xFF2F80ED), item['observacionesEnfermeria']),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 4, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_outline, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(child: Text('Registrado por $medico', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant))),
          ]),
          Text('Creado ${fmtDateTime(item['creadoEn'])}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}
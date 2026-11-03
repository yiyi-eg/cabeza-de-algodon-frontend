import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/roles.dart';
import '../core/schema.dart';
import '../state/auth_state.dart';
import '../state/stores.dart';
import 'dashboard.dart';
import 'entity_list.dart';
import 'widgets.dart';

class _Dest {
  final String key, label;
  final IconData icon;
  const _Dest(this.key, this.label, this.icon);
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _S();
}

class _S extends State<Shell> {
  String _page = 'dashboard';
  final _sk = GlobalKey<ScaffoldState>();

  List<_Dest> _dests(String? role) => [
        const _Dest('dashboard', 'Inicio', Icons.dashboard_outlined),
        for (final k in navOrder)
          if (can(role, k, 'r')) _Dest(k, schemaOf(k).title, schemaOf(k).icon),
      ];

  Widget _body() => _page == 'dashboard'
      ? DashboardPage(onNavigate: (k) => setState(() => _page = k))
      : EntityListPage(key: ValueKey(_page), schema: schemaOf(_page));

  Widget _brand() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: brandColor, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.volunteer_activism, color: Colors.white)),
          const SizedBox(width: 12),
          const Text('Cabeza de\nAlgodón', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.1)),
        ]),
      );

  Widget _user(AuthState a) {
    final c = roleColors[a.rol] ?? brandColor;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withOpacity(.5), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Row(children: [
          Avatar(a.username ?? '', c, size: 40),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.username ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            StatusChip(a.rol ?? ''),
          ])),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: a.logout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar sesión')),
        ),
      ]),
    );
  }

  Widget _sidebar(AuthState auth, List<_Dest> dests, int idx) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 270,
      decoration: BoxDecoration(
          color: dark ? const Color(0xFF131A1E) : Colors.white,
          border: Border(right: BorderSide(color: cs.outlineVariant.withOpacity(.6)))),
      child: Column(children: [
        _brand(),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), children: [
            for (var i = 0; i < dests.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: i == idx ? cs.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _page = dests[i].key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Icon(dests[i].icon, size: 22, color: i == idx ? cs.primary : cs.onSurfaceVariant),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Text(dests[i].label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: i == idx ? FontWeight.w700 : FontWeight.w500, color: i == idx ? cs.primary : null))),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        _user(auth),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final dests = _dests(auth.rol);
    var idx = dests.indexWhere((d) => d.key == _page);
    if (idx < 0) {
      idx = 0;
      _page = 'dashboard';
    }
    final wide = MediaQuery.of(context).size.width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          _sidebar(auth, dests, idx),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 20), child: _body())),
        ]),
      );
    }
    return Scaffold(
      key: _sk,
      appBar: AppBar(
        title: Text(dests[idx].label, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                final st = context.read<Stores>();
                if (_page == 'dashboard') {
                  for (final s in schemas) {
                    if (can(auth.rol, s.key, 'r')) st.of(s.key).load(force: true);
                  }
                } else {
                  st.of(_page).load(force: true);
                }
              }),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          setState(() => _page = dests[i].key);
          _sk.currentState?.closeDrawer();
        },
        children: [
          _brand(),
          for (final d in dests) NavigationDrawerDestination(icon: Icon(d.icon), label: Text(d.label)),
          const Divider(indent: 20, endIndent: 20),
          _user(auth),
        ],
      ),
      body: _body(),
    );
  }
}

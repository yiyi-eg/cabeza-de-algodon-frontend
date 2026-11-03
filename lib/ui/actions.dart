import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/schema.dart';
import '../state/stores.dart';
import 'entity_form.dart';

void toast(BuildContext c, String m, {bool error = false}) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(m), backgroundColor: error ? Theme.of(c).colorScheme.error : null));
}

Future<Item?> openForm(BuildContext c, Schema s,
        {Item? item, Map<String, dynamic> preset = const {}, Set<String> lock = const {}}) =>
    Navigator.of(c).push<Item>(MaterialPageRoute(
        builder: (_) => EntityFormPage(schema: s, item: item, preset: preset, lock: lock)));

Future<bool> confirmDelete(BuildContext c, Schema s, Item item) async {
  final stores = c.read<Stores>();
  final ok = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text('Eliminar ${s.singular}'),
      content: Text('¿Seguro que deseas eliminar "${s.titleOf(item, stores.label)}"? Esta acción no se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Eliminar')),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await stores.of(s.key).delete(item[s.idKey]);
    if (c.mounted) toast(c, '${cap(s.singular)} eliminado');
    return true;
  } on ApiException catch (e) {
    if (c.mounted) toast(c, e.message, error: true);
    return false;
  }
}

Future<void> runAction(BuildContext c, Schema s, RowAction a, Item item) async {
  try {
    await c.read<Stores>().of(s.key).runAction(a, item);
    if (c.mounted) toast(c, '${a.label}: listo');
  } on ApiException catch (e) {
    if (c.mounted) toast(c, e.message, error: true);
  }
}

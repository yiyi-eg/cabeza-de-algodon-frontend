import 'package:flutter/foundation.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/schema.dart';

/// Lista en memoria + CRUD de una entidad.
class EntityStore extends ChangeNotifier {
  final Schema schema;
  final ApiClient api;
  EntityStore(this.schema, this.api);

  List<Item> items = [];
  bool loading = false, loaded = false;
  String? error;
  bool _dirty = false;

  Item? byId(dynamic id) {
    for (final i in items) {
      if ('${i[schema.idKey]}' == '$id') return i;
    }
    return null;
  }

  Future<void> load({bool force = false, bool silent = false}) async {
    if (loading) {
      _dirty = true;
      return;
    }
    if (loaded && !force && !silent) return;
    loading = true;
    if (!silent) {
      error = null;
      notifyListeners();
    }
    try {
      final r = await api.get(schema.path);
      items = (r as List).map((e) => _norm(Map<String, dynamic>.from(e as Map))).toList()
        ..sort((a, b) => ((b[schema.idKey] ?? 0) as num).compareTo((a[schema.idKey] ?? 0) as num));
      loaded = true;
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'No se pudieron leer los datos de ${schema.title.toLowerCase()}.';
    } finally {
      loading = false;
      notifyListeners();
    }
    if (_dirty) {
      _dirty = false;
      load(force: true, silent: true);
    }
  }

  /// Acepta objetos anidados {"interno": {...}}, DTOs planos ({"internoId": 1},
  /// {"idUsuario": 2}, {"usuario_id": 2}...) y claves alternativas.
  Item _norm(Item i) {
    if (i[schema.idKey] == null && i['id'] != null) i[schema.idKey] = i['id'];
    for (final f in schema.fields) {
      final r = f.rel;
      if (r == null || r.nestedIdKey == null || i[f.key] is Map) continue;
      final nk = r.nestedIdKey!;
      final stems = <String>{
        f.key.toLowerCase(),
        ...f.alt.map((a) => a.toLowerCase()),
        nk.toLowerCase().replaceFirst('id', ''),
        r.entity.toLowerCase().replaceFirst(RegExp(r's$'), ''),
      };
      dynamic found;
      for (final k in [f.key, ...f.alt]) {
        final c = i[k];
        if (c is Map || c is num) {
          found = c;
          break;
        }
      }
      if (found == null) {
        for (final e in i.entries) {
          final k = e.key.toLowerCase();
          if (e.value is num && k.contains('id') && stems.any(k.contains)) {
            found = e.value;
            break;
          }
        }
      }
      if (found is Map) {
        i[f.key] = found;
      } else if (found != null) {
        i[f.key] = {nk: found};
      }
    }
    return i;
  }

  Future<Item> create(Item body) async {
    final r = await api.post(schema.createPath ?? schema.path, body);
    await load(force: true, silent: true);
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }

  Future<Item> update(dynamic id, Item body) async {
    final r = await api.put('${schema.path}/$id', body);
    await load(force: true, silent: true);
    return r is Map ? Map<String, dynamic>.from(r) : {};
  }

  Future<void> delete(dynamic id) async {
    await api.delete('${schema.path}/$id');
    await load(force: true, silent: true);
  }

  Future<void> runAction(RowAction a, Item item) async {
    await api.put(a.path(item));
    await load(force: true, silent: true);
  }

  void reset() {
    items = [];
    loaded = false;
    error = null;
    notifyListeners();
  }
}

/// Registro de todas las entidades + resolución de etiquetas de relaciones.
class Stores {
  final ApiClient api;
  late final Map<String, EntityStore> _m;
  Stores(this.api) {
    _m = {for (final s in schemas) s.key: EntityStore(s, api)};
  }

  EntityStore of(String key) => _m[key]!;
  void clear() {
    for (final s in _m.values) {
      s.reset();
    }
  }

  String label(String entity, dynamic id) {
    if (id == null) return '—';
    final st = _m[entity];
    final it = st?.byId(id);
    return it == null ? '#$id' : st!.schema.titleOf(it, label);
  }

  /// Valor legible de un campo (resuelve relaciones, fechas, dinero…).
  String show(Field f, Item item) {
    if (f.type == FT.password) return '••••••';
    if (f.rel != null) {
      final raw = item[f.key];
      final id = raw is Map ? raw[f.rel!.nestedIdKey ?? 'id'] : raw;
      return label(f.rel!.entity, id);
    }
    final v = item[f.key];
    if (v == null || '$v'.isEmpty) return '—';
    switch (f.type) {
      case FT.date:
        return fmtDate(v);
      case FT.dateTime:
        return fmtDateTime(v);
      case FT.money:
        return money(v);
      case FT.flag:
        return v == true ? 'Sí' : 'No';
      default:
        return '$v';
    }
  }

  String searchText(Schema s, Item i) {
    final parts = <String>[s.titleOf(i, label), s.subtitleOf?.call(i, label) ?? ''];
    for (final f in s.fields) {
      if (f.type != FT.password && f.type != FT.flag) parts.add(show(f, i));
    }
    return parts.join(' ').toLowerCase();
  }
}

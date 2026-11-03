import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/roles.dart';
import '../core/schema.dart';
import '../state/auth_state.dart';
import '../state/stores.dart';
import 'actions.dart';

/// Formulario generado a partir del Schema: un campo por cada columna del backend.
class EntityFormPage extends StatefulWidget {
  final Schema schema;
  final Item? item;
  final Map<String, dynamic> preset;
  final Set<String> lock;
  const EntityFormPage({super.key, required this.schema, this.item, this.preset = const {}, this.lock = const {}});
  @override
  State<EntityFormPage> createState() => _S();
}

class _S extends State<EntityFormPage> {
  final _form = GlobalKey<FormState>();
  final _v = <String, dynamic>{};
  final _c = <String, TextEditingController>{};
  bool _saving = false, _obscure = true;
  String? _error;

  Schema get s => widget.schema;
  bool get editing => widget.item != null;
  bool _textual(Field f) => const [FT.text, FT.multiline, FT.integer, FT.money, FT.dpi, FT.phone, FT.password].contains(f.type);
  List<Field> get _fields => s.fields.where((f) => f.inForm && !(f.createOnly && editing)).toList();

  @override
  void initState() {
    super.initState();
    for (final f in s.fields) {
      Object? val;
      if (editing) {
        final raw = widget.item![f.key];
        val = f.rel != null ? idOf(raw, f.rel!.nestedIdKey ?? 'id') : raw;
        if (f.type == FT.date || f.type == FT.dateTime) val = parseDt(val);
      } else {
        val = widget.preset.containsKey(f.key) ? widget.preset[f.key] : f.initial;
        if (val == 'now') val = DateTime.now();
        if (f.auto == Auto.currentUser && f.inForm && val == null) val = context.read<AuthState>().userId;
      }
      _v[f.key] = val;
      if (_textual(f)) _c[f.key] = TextEditingController(text: val?.toString() ?? '');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final st = context.read<Stores>();
      for (final k in s.relatedKeys) {
        st.of(k).load();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(Field f, String? raw) {
    final t = raw?.trim() ?? '';
    if (t.isEmpty) return f.required ? 'Campo requerido' : null;
    switch (f.type) {
      case FT.dpi:
        if (!RegExp(r'^\d{13}$').hasMatch(t)) return 'El DPI debe tener 13 dígitos';
        break;
      case FT.phone:
        if (!RegExp(r'^[+\d][\d\s\-]{6,}$').hasMatch(t)) return 'Teléfono inválido';
        break;
      case FT.integer:
        final n = int.tryParse(t);
        if (n == null) return 'Número entero inválido';
        if (f.min != null && n < f.min!) return 'Mínimo ${f.min}';
        if (f.max != null && n > f.max!) return 'Máximo ${f.max}';
        return null;
      case FT.money:
        final d = double.tryParse(t.replaceAll(',', '.'));
        if (d == null || d <= 0) return 'Ingresa un monto mayor a 0';
        if (d > 99999999.99) return 'Monto demasiado grande';
        return null;
      case FT.password:
        if (t.length < 6) return 'Mínimo 6 caracteres';
        break;
      default:
    }
    if (f.max != null && t.length > f.max!) return 'Máximo ${f.max} caracteres';
    return null;
  }

  InputDecoration _dec(Field f, {Widget? suffix}) =>
      InputDecoration(labelText: f.required ? '${f.label} *' : f.label, prefixIcon: Icon(f.icon, size: 20), suffixIcon: suffix);

  Widget _field(Field f) {
    final locked = widget.lock.contains(f.key);
    switch (f.type) {
      case FT.date:
      case FT.dateTime:
        return _dateField(f, locked);
      case FT.select:
        final cur = _v[f.key] as String?;
        final opts = {...f.options, if (cur != null && cur.isNotEmpty) cur}.toList();
        return DropdownButtonFormField<String>(
          value: cur != null && cur.isNotEmpty ? cur : null,
          isExpanded: true,
          decoration: _dec(f),
          items: [for (final o in opts) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: locked ? null : (x) => setState(() => _v[f.key] = x),
          validator: (x) => f.required && x == null ? 'Selecciona una opción' : null,
        );
      case FT.relation:
        return _relField(f, locked);
      case FT.flag:
        return SwitchListTile(
          value: _v[f.key] == true,
          onChanged: locked ? null : (x) => setState(() => _v[f.key] = x),
          title: Text(f.label),
          secondary: Icon(f.icon),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          tileColor: Theme.of(context).inputDecorationTheme.fillColor,
        );
      default:
        final fmts = <TextInputFormatter>[
          if (f.type == FT.dpi) FilteringTextInputFormatter.digitsOnly,
          if (f.type == FT.dpi) LengthLimitingTextInputFormatter(13),
          if (f.type == FT.integer) FilteringTextInputFormatter.digitsOnly,
          if (f.type == FT.phone) FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
          if (f.type == FT.money) FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          if (f.max != null && f.type != FT.dpi && f.type != FT.integer) LengthLimitingTextInputFormatter(f.max),
        ];
        final pw = f.type == FT.password;
        return TextFormField(
          controller: _c[f.key],
          enabled: !locked,
          obscureText: pw && _obscure,
          minLines: f.type == FT.multiline ? 3 : 1,
          maxLines: f.type == FT.multiline ? 6 : 1,
          keyboardType: switch (f.type) {
            FT.integer || FT.dpi => TextInputType.number,
            FT.money => const TextInputType.numberWithOptions(decimal: true),
            FT.phone => TextInputType.phone,
            FT.multiline => TextInputType.multiline,
            _ => TextInputType.text,
          },
          inputFormatters: fmts,
          decoration: _dec(f,
              suffix: pw
                  ? IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure))
                  : null),
          validator: (x) => _validate(f, x),
        );
    }
  }

  Widget _dateField(Field f, bool locked) {
    final withTime = f.type == FT.dateTime;
    return FormField<DateTime>(
      validator: (_) => f.required && _v[f.key] == null ? 'Campo requerido' : null,
      builder: (st) {
        final d = _v[f.key] as DateTime?;
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: locked
              ? null
              : () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                      context: context, initialDate: d ?? now, firstDate: DateTime(1900), lastDate: DateTime(2100));
                  if (date == null || !mounted) return;
                  var out = DateTime(date.year, date.month, date.day);
                  if (withTime) {
                    final t = await showTimePicker(
                        context: context, initialTime: TimeOfDay.fromDateTime(d ?? now));
                    if (t == null || !mounted) return;
                    out = DateTime(date.year, date.month, date.day, t.hour, t.minute);
                  }
                  setState(() => _v[f.key] = out);
                  st.didChange(out);
                },
          child: InputDecorator(
            decoration: _dec(f, suffix: const Icon(Icons.calendar_month_outlined)).copyWith(errorText: st.errorText),
            child: Text(d == null ? 'Seleccionar' : (withTime ? fmtDateTime(d) : fmtDate(d)),
                style: TextStyle(color: d == null ? Theme.of(context).hintColor : null)),
          ),
        );
      },
    );
  }

  Widget _relField(Field f, bool locked) {
    final stores = context.read<Stores>();
    final role = context.read<AuthState>().rol;
    final rs = stores.of(f.rel!.entity);
    final rschema = rs.schema;
    final canAdd = !locked && rschema.apiCreate && can(role, rschema.key, 'c') && rschema.key != 'usuarios';
    return ListenableBuilder(
      listenable: rs,
      builder: (_, __) {
        final cur = _v[f.key];
        final opts = [for (final i in rs.items) if (f.rel!.filter?.call(i) ?? true) i];
        final exists = opts.any((i) => i[rschema.idKey] == cur);
        return DropdownButtonFormField<Object>(
          key: ValueKey('${f.key}-$cur-${opts.length}'),
          value: exists ? cur as Object : null,
          isExpanded: true,
          decoration: _dec(f,
              suffix: canAdd
                  ? IconButton(
                      tooltip: 'Crear ${rschema.singular}',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () async {
                        final saved = await openForm(context, rschema);
                        if (saved != null && saved[rschema.idKey] != null && mounted) {
                          setState(() => _v[f.key] = saved[rschema.idKey]);
                        }
                      })
                  : null),
          items: [
            for (final i in opts)
              DropdownMenuItem<Object>(
                  value: i[rschema.idKey] as Object,
                  child: Text(rschema.titleOf(i, stores.label), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: locked ? null : (x) => setState(() => _v[f.key] = x),
          validator: (x) => f.required && x == null ? 'Selecciona una opción' : null,
        );
      },
    );
  }

  dynamic _out(Field f) {
    final v = _v[f.key];
    switch (f.type) {
      case FT.integer:
        return int.parse(_c[f.key]!.text.trim());
      case FT.money:
        return double.parse(_c[f.key]!.text.trim().replaceAll(',', '.'));
      case FT.date:
        return v == null ? null : isoDate(v as DateTime);
      case FT.dateTime:
        return v == null ? null : isoDateTime(v as DateTime);
      case FT.relation:
        return f.rel!.nestedIdKey != null ? {f.rel!.nestedIdKey!: v} : v;
      case FT.flag:
        return v == true;
      case FT.select:
        return v;
      default:
        return _c[f.key]!.text.trim();
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthState>();
    final st = context.read<Stores>().of(s.key);
    final body = <String, dynamic>{if (editing) s.idKey: widget.item![s.idKey]};
    final now = isoDateTime(DateTime.now());
    for (final f in s.fields) {
      final shown = f.inForm && !(f.createOnly && editing);
      if (shown) {
        body[f.key] = _out(f);
      } else if (f.auto == Auto.nowOnCreate && !editing) {
        body[f.key] = now;
      } else if (f.auto == Auto.nowOnSave) {
        body[f.key] = now;
      } else if (f.auto == Auto.currentUser && !editing) {
        if (auth.userId == null) {
          setState(() => _error = 'No se pudo identificar tu usuario. Cierra sesión y vuelve a entrar.');
          return;
        }
        body[f.key] = {f.rel!.nestedIdKey!: auth.userId};
      }
    }
    for (final f in s.fields) {
      if (f.alt.isNotEmpty && body[f.key] != null) {
        for (final a in f.alt) {
          body[a] = body[f.key];
        }
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = editing ? await st.update(widget.item![s.idKey], body) : await st.create(body);
      if (!mounted) return;
      toast(context, editing ? '${cap(s.singular)} actualizado' : '${cap(s.singular)} guardado');
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar ${s.singular}' : s.newLabel)),
      body: Form(
        key: _form,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: s.color.withOpacity(.14), borderRadius: BorderRadius.circular(14)),
                    child: Icon(s.icon, color: s.color)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(s.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 20),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: TextStyle(color: cs.onErrorContainer))),
                  ]),
                ),
              LayoutBuilder(builder: (ctx, box) {
                final wide = box.maxWidth > 560;
                final half = (box.maxWidth - 16) / 2;
                return Wrap(spacing: 16, runSpacing: 16, children: [
                  for (final f in _fields)
                    SizedBox(
                        width: (wide && !f.full && f.type != FT.multiline && f.type != FT.flag) ? half : box.maxWidth,
                        child: _field(f)),
                ]);
              }),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar'))),
                const SizedBox(width: 12),
                Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(editing ? 'Guardar cambios' : 'Guardar'),
                    )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/config.dart';
import '../state/auth_state.dart';
import 'theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _S();
}

class _S extends State<LoginPage> {
  final _u = TextEditingController(), _p = TextEditingController();
  final _k = GlobalKey<FormState>();
  bool _busy = false, _hide = true;
  String? _err;

  Future<void> _go() async {
    if (!_k.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<AuthState>().login(_u.text, _p.text);
    } on ApiException catch (e) {
      setState(() => _err = e.message);
    } catch (_) {
      setState(() => _err = 'No se pudo iniciar sesión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _hero(bool wide) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(wide ? 56 : 28),
        decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0E7C86), Color(0xFF0B3C49)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 34)),
            const SizedBox(height: 20),
            const Text('Cabeza de Algodón', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Cuidado y gestión geriátrica,\ncon calidez y orden.', style: TextStyle(color: Colors.white70, fontSize: 17, height: 1.35)),
          ]),
        ),
      );

  Widget _form() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _k,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Iniciar sesión', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Ingresa con tu usuario del sistema', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                TextFormField(
                    controller: _u,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Ingresa tu usuario' : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _p,
                    obscureText: _hide,
                    onFieldSubmitted: (_) => _go(),
                    decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide))),
                    validator: (v) => (v ?? '').isEmpty ? 'Ingresa tu contraseña' : null),
                if (_err != null)
                  Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                      child: Text(_err!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer))),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: _busy ? null : _go,
                    child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Entrar')),
                const SizedBox(height: 20),
                Text('Servidor: $baseUrl', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: LayoutBuilder(builder: (c, box) {
          final wide = box.maxWidth >= 900;
          return wide
              ? Row(children: [Expanded(flex: 5, child: _hero(true)), Expanded(flex: 4, child: _form())])
              : Column(children: [_hero(false), Expanded(child: _form())]);
        }),
      );
}

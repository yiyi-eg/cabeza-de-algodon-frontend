import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/api.dart';
import 'state/auth_state.dart';
import 'state/realtime.dart';
import 'state/stores.dart';
import 'ui/login_page.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AsiloApp());
}

class AsiloApp extends StatefulWidget {
  const AsiloApp({super.key});
  @override
  State<AsiloApp> createState() => _S();
}

class _S extends State<AsiloApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final ApiClient api = ApiClient();
  late final AuthState auth = AuthState(api);
  late final Stores stores = Stores(api);
  late final Realtime realtime = Realtime(stores, _messenger);
  bool _was = false;

  @override
  void initState() {
    super.initState();
    auth.addListener(_onAuth);
    auth.restore();
  }

  void _onAuth() {
    if (auth.isLogged && !_was) {
      _was = true;
      realtime.start(api.token!);
    } else if (!auth.isLogged && _was) {
      _was = false;
      realtime.stop();
      stores.clear();
    }
  }

  @override
  void dispose() {
    realtime.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          Provider.value(value: stores),
          Provider.value(value: api),
        ],
        child: MaterialApp(
          title: 'Cabeza de Algodón',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messenger,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2)),
              child: child!,
            );
          },
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ListenableBuilder(
            listenable: auth,
            builder: (_, __) => auth.loading
                ? const Scaffold(body: Center(child: CircularProgressIndicator()))
                : (auth.isLogged ? const Shell() : const LoginPage()),
          ),
        ),
      );
}

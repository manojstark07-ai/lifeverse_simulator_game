import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/dev_demo.dart';
import 'app/di.dart';
import 'engine/game_engine.dart';
import 'data/settings_repository.dart';
import 'app/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Boot());
}

/// Loads content and services, then hands over to the app. Shows a branded
/// loading screen (and any content error) meanwhile.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  late final Future<AppSettings> _ready = () async {
    await configureDependencies();
    return getIt<SettingsRepository>().load();
  }();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSettings>(
      future: _ready,
      builder: (context, snap) {
        if (snap.hasData) {
          final demo = buildDemoState(getIt<GameEngine>());
          return LifeverseApp(
            initialSettings: snap.data!,
            initialGame: demo,
            initialLocation: demo == null ? '/' : (demoRoute == '/story' ? '/hub' : demoRoute),
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: LvTheme.light(),
          darkTheme: LvTheme.dark(),
          home: Scaffold(
            body: Center(
              child: snap.hasError
                  ? Padding(padding: const EdgeInsets.all(24), child: Text('Could not start LIFEVERSE:\n${snap.error}'))
                  : const CircularProgressIndicator(),
            ),
          ),
        );
      },
    );
  }
}

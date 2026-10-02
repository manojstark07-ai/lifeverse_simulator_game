import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../data/save_repository.dart';
import '../data/analytics_service.dart';
import '../data/settings_repository.dart';
import '../engine/game_engine.dart';
import '../engine/game_state.dart';
import '../features/game/game_cubit.dart';
import '../features/settings/settings_cubit.dart';
import 'di.dart';
import 'feedback_host.dart';
import 'router.dart';
import 'theme.dart';

class LifeverseApp extends StatefulWidget {
  const LifeverseApp({
    super.key,
    required this.initialSettings,
    this.initialGame,
    this.initialLocation = '/',
  });

  final AppSettings initialSettings;

  /// Used by the debug demo launcher; normal launches start at the title.
  final GameState? initialGame;
  final String initialLocation;

  @override
  State<LifeverseApp> createState() => _LifeverseAppState();
}

class _LifeverseAppState extends State<LifeverseApp> {
  late final SettingsCubit _settings = SettingsCubit(
    getIt<SettingsRepository>(),
    widget.initialSettings,
  );
  late final GameCubit _game = GameCubit(
    engine: getIt<GameEngine>(),
    saves: getIt<SaveRepository>(),
    autosaveEnabled: () => _settings.state.autosave,
    analyticsEnabled: () => _settings.state.analyticsOptIn,
    initial: widget.initialGame,
  );
  late final GoRouter _router = buildRouter(
    hasGame: () => _game.state.hasGame,
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _game.close();
    _settings.close();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _settings),
        BlocProvider.value(value: _game),
      ],
      child: BlocBuilder<SettingsCubit, AppSettings>(
        builder: (context, settings) => MaterialApp.router(
          title: 'LIFEVERSE',
          locale: Locale(settings.locale),
          supportedLocales: const [Locale('en'), Locale('hi'), Locale('ta')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          debugShowCheckedModeBanner: false,
          theme: LvTheme.light(),
          darkTheme: LvTheme.dark(),
          themeMode: switch (settings.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          scaffoldMessengerKey: scaffoldMessengerKey,
          routerConfig: _router,
          builder: (context, child) {
            AnalyticsService.instance.enabled = settings.analyticsOptIn;
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(settings.textScale),
                disableAnimations:
                    media.disableAnimations || settings.reducedMotion,
              ),
              child: FeedbackHost(router: _router, child: child!),
            );
          },
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

class AppSettings {
  const AppSettings({
    this.reducedMotion = false,
    this.textScale = 1.0,
    this.themeMode = 'system',
    this.autosave = true,
    this.matureThemes = true,
    this.locale = 'en',
    this.analyticsOptIn = false,
    this.cloudSyncEnabled = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    reducedMotion: j['reducedMotion'] as bool? ?? false,
    textScale: (j['textScale'] as num?)?.toDouble() ?? 1.0,
    themeMode: j['themeMode'] as String? ?? 'system',
    autosave: j['autosave'] as bool? ?? true,
    matureThemes: j['matureThemes'] as bool? ?? true,
    locale: j['locale'] as String? ?? 'en',
    analyticsOptIn: j['analyticsOptIn'] as bool? ?? false,
    cloudSyncEnabled: j['cloudSyncEnabled'] as bool? ?? false,
  );

  final bool reducedMotion;
  final double textScale;

  /// `system`, `light` or `dark`.
  final String themeMode;
  final bool autosave;

  /// Alcohol, smoking, crime and dating storylines.
  final bool matureThemes;

  /// UI locale. Content remains authored in its original language until a
  /// translated pack is selected.
  final String locale;
  final bool analyticsOptIn;
  final bool cloudSyncEnabled;

  AppSettings copyWith({
    bool? reducedMotion,
    double? textScale,
    String? themeMode,
    bool? autosave,
    bool? matureThemes,
    String? locale,
    bool? analyticsOptIn,
    bool? cloudSyncEnabled,
  }) => AppSettings(
    reducedMotion: reducedMotion ?? this.reducedMotion,
    textScale: textScale ?? this.textScale,
    themeMode: themeMode ?? this.themeMode,
    autosave: autosave ?? this.autosave,
    matureThemes: matureThemes ?? this.matureThemes,
    locale: locale ?? this.locale,
    analyticsOptIn: analyticsOptIn ?? this.analyticsOptIn,
    cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
  );

  Map<String, dynamic> toJson() => {
    'reducedMotion': reducedMotion,
    'textScale': textScale,
    'themeMode': themeMode,
    'autosave': autosave,
    'matureThemes': matureThemes,
    'locale': locale,
    'analyticsOptIn': analyticsOptIn,
    'cloudSyncEnabled': cloudSyncEnabled,
  };
}

abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class FileSettingsRepository implements SettingsRepository {
  FileSettingsRepository(this.directory);

  final Directory directory;

  File get _file => File('${directory.path}/settings.json');

  @override
  Future<AppSettings> load() async {
    try {
      if (!await _file.exists()) return const AppSettings();
      return AppSettings.fromJson(
        (jsonDecode(await _file.readAsString()) as Map).cast(),
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await directory.create(recursive: true);
    await _file.writeAsString(jsonEncode(settings.toJson()), flush: true);
  }
}

class InMemorySettingsRepository implements SettingsRepository {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}

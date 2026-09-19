import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальные настройки звука детского режима.
///
/// Значения хранятся в диапазоне 0.0..1.0 и применяются ко всему приложению:
/// [backgroundMusicVolume] — фоновая музыка;
/// [voiceVolume] — озвучка слов, заданий и литературного контента.
class AudioSettingsService extends ChangeNotifier {
  AudioSettingsService._();

  static final AudioSettingsService instance = AudioSettingsService._();

  static const String _musicVolumeKey = 'child_background_music_volume';
  static const String _voiceVolumeKey = 'child_voice_volume';

  // Сохраняем прежнюю тихую громкость фоновой музыки как значение по умолчанию.
  static const double defaultBackgroundMusicVolume = .16;
  static const double defaultVoiceVolume = 1.0;

  double _backgroundMusicVolume = defaultBackgroundMusicVolume;
  double _voiceVolume = defaultVoiceVolume;
  bool _loaded = false;
  Future<void>? _loadingFuture;

  double get backgroundMusicVolume => _backgroundMusicVolume;
  double get voiceVolume => _voiceVolume;
  bool get isLoaded => _loaded;

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loadingFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _backgroundMusicVolume = _normalize(
        prefs.getDouble(_musicVolumeKey) ?? defaultBackgroundMusicVolume,
      );
      _voiceVolume = _normalize(
        prefs.getDouble(_voiceVolumeKey) ?? defaultVoiceVolume,
      );
    } finally {
      _loaded = true;
      _loadingFuture = null;
      notifyListeners();
    }
  }

  Future<void> setBackgroundMusicVolume(double value) async {
    await load();
    final normalized = _normalize(value);
    if ((_backgroundMusicVolume - normalized).abs() < .001) return;

    _backgroundMusicVolume = normalized;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_musicVolumeKey, normalized);
  }

  Future<void> setVoiceVolume(double value) async {
    await load();
    final normalized = _normalize(value);
    if ((_voiceVolume - normalized).abs() < .001) return;

    _voiceVolume = normalized;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_voiceVolumeKey, normalized);
  }

  static double _normalize(double value) => value.clamp(0.0, 1.0).toDouble();
}

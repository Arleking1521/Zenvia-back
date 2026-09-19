import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'audio_settings_service.dart';

/// Управляет тихой фоновой музыкой только в детском режиме.
///
/// Экран может временно выключить музыку через [silence] и вернуть через
/// [unsilence]. Используется Set токенов, поэтому вложенные игровые экраны не
/// включат музыку раньше времени.
class BackgroundMusicService with WidgetsBindingObserver {
  BackgroundMusicService._() {
    WidgetsBinding.instance.addObserver(this);
    AudioSettingsService.instance.addListener(_onAudioSettingsChanged);
  }

  static final BackgroundMusicService instance = BackgroundMusicService._();

  static const String _asset = 'audio/zenvia_learning_background.wav';

  final AudioPlayer _player = AudioPlayer();
  final Set<Object> _silenceTokens = <Object>{};

  bool _childModeActive = false;
  bool _appActive = true;
  bool _trackLoaded = false;
  bool _busy = false;
  Timer? _resumeTimer;

  Future<void> startChildMode() async {
    _childModeActive = true;
    await AudioSettingsService.instance.load();
    await _ensurePlaying();
  }

  Future<void> stopChildMode() async {
    _childModeActive = false;
    _silenceTokens.clear();
    _resumeTimer?.cancel();
    _resumeTimer = null;
    _trackLoaded = false;
    try {
      await _player.stop();
    } catch (_) {
      // Музыка не должна мешать работе приложения при ошибке аудиодрайвера.
    }
  }

  Future<void> silence(Object token) async {
    _silenceTokens.add(token);
    _resumeTimer?.cancel();
    _resumeTimer = null;
    try {
      await _player.pause();
    } catch (_) {
      // Игровой/обучающий экран должен открываться даже без аудиовыхода.
    }
  }

  void unsilence(Object token) {
    _silenceTokens.remove(token);
    if (_silenceTokens.isNotEmpty) return;

    // Небольшая задержка не даёт музыке на мгновение включиться при
    // pushReplacement между игрой и экраном результата.
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(milliseconds: 180), _ensurePlaying);
  }

  Future<void> _ensurePlaying() async {
    if (_busy ||
        !_childModeActive ||
        !_appActive ||
        _silenceTokens.isNotEmpty) {
      return;
    }

    await AudioSettingsService.instance.load();
    final volume = AudioSettingsService.instance.backgroundMusicVolume;

    // При 0% не держим трек проигрывающимся в фоне. Если ребёнок снова
    // поднимет громкость, listener ниже возобновит его с прежней позиции.
    if (volume <= .001) {
      if (_trackLoaded) {
        try {
          await _player.pause();
        } catch (_) {}
      }
      return;
    }

    _busy = true;
    try {
      await _player.setVolume(volume);
      if (_trackLoaded) {
        await _player.resume();
      } else {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(
          AssetSource(_asset),
          volume: volume,
        );
        _trackLoaded = true;
      }
    } catch (_) {
      // Отсутствие музыки не должно ломать детский режим.
      _trackLoaded = false;
    } finally {
      _busy = false;
    }
  }

  void _onAudioSettingsChanged() {
    _applyMusicVolume();
  }

  Future<void> _applyMusicVolume() async {
    final volume = AudioSettingsService.instance.backgroundMusicVolume;
    try {
      await _player.setVolume(volume);
      if (volume <= .001) {
        if (_trackLoaded) await _player.pause();
        return;
      }
      await _ensurePlaying();
    } catch (_) {
      // Изменение громкости не должно влиять на навигацию приложения.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appActive = true;
        _ensurePlaying();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _appActive = false;
        _resumeTimer?.cancel();
        _player.pause();
        break;
    }
  }
}

/// Удобная обёртка для StatelessWidget-экранов, на которых фоновой музыки
/// быть не должно (например, экран результата игры).
class BackgroundMusicSilence extends StatefulWidget {
  final Widget child;

  const BackgroundMusicSilence({
    super.key,
    required this.child,
  });

  @override
  State<BackgroundMusicSilence> createState() => _BackgroundMusicSilenceState();
}

class _BackgroundMusicSilenceState extends State<BackgroundMusicSilence> {
  final Object _token = Object();

  @override
  void initState() {
    super.initState();
    BackgroundMusicService.instance.silence(_token);
  }

  @override
  void dispose() {
    BackgroundMusicService.instance.unsilence(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

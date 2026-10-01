import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/api/api_client.dart';
import 'data/api_app_repository.dart';
import 'data/api_auth_repository.dart';
import 'data/api_game_repository.dart';
import 'data/api_legal_repository.dart';
import 'data/api_parent_repository.dart';
import 'data/app_repository.dart';
import 'data/auth_repository.dart';
import 'data/game_repository.dart';
import 'data/legal_repository.dart';
import 'data/parent_repository.dart';
import 'models/child_profile.dart';
import 'models/subscription.dart';
import 'services/background_music_service.dart';
import 'services/app_locale_controller.dart';
import 'screens/achievements_screen.dart';
import 'screens/adventure_choice_screen.dart';
import 'screens/child_settings_screen.dart';
import 'screens/learned_words_games_screen.dart';
import 'screens/home_screen.dart';
import 'screens/parent_dashboard_screen.dart';
import 'screens/parent_login_screen.dart';
import 'screens/play_cave_screen.dart';
import 'screens/topics_screen.dart';
import 'screens/smart_content_screen.dart';
import 'screens/subscription_blocked_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/adaptive_app_viewport.dart';
import 'widgets/parent_pin_dialog.dart';
import 'widgets/magic_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  appLocaleController.useDeviceLocale();
  runApp(const KidsLangApp());
}

final ApiClient apiClient = ApiClient();
final AuthRepository authRepository = ApiAuthRepository(apiClient);
final ParentRepository parentRepository = ApiParentRepository(apiClient);
final AppRepository appRepository = ApiAppRepository(apiClient);
final GameRepository gameRepository = ApiGameRepository(apiClient);
final LegalRepository legalRepository = ApiLegalRepository(apiClient);

class KidsLangApp extends StatelessWidget {
  const KidsLangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appLocaleController,
      builder: (context, _) => MaterialApp(
        title: 'Zenvia Kids',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: appLocaleController.locale,
        supportedLocales: const [
          Locale('ru'),
          Locale('kk'),
          Locale('en'),
          Locale('zh'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => AdaptiveAppViewport(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _StartupSession {
  final bool loggedIn;
  final int? childId;

  const _StartupSession({
    required this.loggedIn,
    this.childId,
  });
}

class _AuthGateState extends State<_AuthGate> {
  late Future<_StartupSession> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _loadStartupSession();
  }

  Future<void> _applyParentLocale() async {
    try {
      final parent = await authRepository.getParent();
      appLocaleController.setCode(parent.interfaceLanguage);
    } catch (_) {
      // Если профиль временно недоступен, оставляем текущий locale.
    }
  }

  Future<_StartupSession> _loadStartupSession() async {
    final loggedIn = await authRepository.isLoggedIn();
    if (!loggedIn) {
      return const _StartupSession(loggedIn: false);
    }

    final selectedChildId = await parentRepository.getSelectedChildId();
    if (selectedChildId == null || selectedChildId <= 0) {
      await _applyParentLocale();
      return const _StartupSession(loggedIn: true);
    }

    // Проверяем, что сохранённый профиль всё ещё существует и активен.
    // Если профиль удалили/архивировали, возвращаем родительский кабинет.
    try {
      final child = await parentRepository.getChild(selectedChildId);
      if (!child.isActive) {
        await parentRepository.clearSelectedChild();
        await _applyParentLocale();
        return const _StartupSession(loggedIn: true);
      }

      appLocaleController.setCode(child.baseLanguage?.code);
      return _StartupSession(
        loggedIn: true,
        childId: child.id,
      );
    } catch (_) {
      await parentRepository.clearSelectedChild();
      await _applyParentLocale();
      return const _StartupSession(loggedIn: true);
    }
  }

  void _refresh() {
    setState(() {
      _sessionFuture = _loadStartupSession();
    });
  }

  Future<void> _openChild(BuildContext context, ChildProfile child) async {
    appLocaleController.setCode(child.baseLanguage?.code);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChildRootShell(childId: child.id),
      ),
    );
    await _applyParentLocale();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupSession>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            body: FantasyBackground(
              light: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/zenvia_kids_logo.png',
                      width: 270,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 22),
                    const CircularProgressIndicator(color: Colors.white),
                  ],
                ),
              ),
            ),
          );
        }

        final session = snapshot.data!;

        if (!session.loggedIn) {
          return ParentLoginScreen(
            authRepository: authRepository,
            legalRepository: legalRepository,
            onLoggedIn: _refresh,
          );
        }

        // Если приложение было закрыто в детском режиме, выбранный профиль
        // остаётся в ChildSessionStorage. При следующем запуске сразу
        // возвращаем ребёнка в его обучающий режим.
        if (session.childId != null) {
          return ChildRootShell(
            childId: session.childId!,
            onReturnToParent: _refresh,
          );
        }

        return ParentDashboardScreen(
          authRepository: authRepository,
          parentRepository: parentRepository,
          legalRepository: legalRepository,
          onOpenChild: (child) => _openChild(context, child),
          onLoggedOut: _refresh,
        );
      },
    );
  }
}

class ChildRootShell extends StatefulWidget {
  final int childId;
  final VoidCallback? onReturnToParent;

  const ChildRootShell({
    super.key,
    required this.childId,
    this.onReturnToParent,
  });

  @override
  State<ChildRootShell> createState() => _ChildRootShellState();
}

class _ChildRootShellState extends State<ChildRootShell> with WidgetsBindingObserver {
  int _index = 0;
  int _homeRevision = 0;
  int _languageRevision = 0;
  bool _allowPop = false;
  bool _exitInProgress = false;
  bool _checkingSubscription = true;
  SubscriptionAccessStatus? _subscriptionAccess;
  StreamSubscription<String>? _subscriptionGateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BackgroundMusicService.instance.startChildMode();
    _subscriptionGateSubscription = apiClient.subscriptionGateEvents.listen(
      _handleSubscriptionGateEvent,
    );
    _checkSubscriptionAccess(showLoading: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSubscriptionAccess();
    }
  }

  void _handleSubscriptionGateEvent(String reason) {
    if (!mounted) return;
    setState(() {
      _checkingSubscription = false;
      _subscriptionAccess = SubscriptionAccessStatus(
        active: false,
        reason: reason,
      );
    });
  }

  Future<void> _checkSubscriptionAccess({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() => _checkingSubscription = true);
    }

    try {
      final access = await parentRepository.getSubscriptionAccessStatus();
      if (!mounted) return;
      setState(() {
        _subscriptionAccess = access;
        _checkingSubscription = false;
        if (access.active) {
          _homeRevision++;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subscriptionAccess = SubscriptionAccessStatus.connectionError();
        _checkingSubscription = false;
      });
    }
  }

  Future<void> _openFreePlay() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PlayCaveScreen(),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscriptionGateSubscription?.cancel();
    BackgroundMusicService.instance.stopChildMode();
    super.dispose();
  }

  Future<void> _applyParentLocale() async {
    try {
      final parent = await authRepository.getParent();
      appLocaleController.setCode(parent.interfaceLanguage);
    } catch (_) {}
  }

  Future<void> _refreshChildLocale() async {
    try {
      final child = await parentRepository.getChild(widget.childId);
      appLocaleController.setCode(child.baseLanguage?.code);
    } catch (_) {}
  }

  Future<bool> _verifyParentPin() {
    return showParentPinVerifyDialog(
      context: context,
      repository: parentRepository,
    );
  }

  Future<void> _leaveChildMode({bool alreadyVerified = false}) async {
    if (_exitInProgress) return;
    _exitInProgress = true;
    try {
      final allowed = alreadyVerified || await _verifyParentPin();
      if (!allowed || !mounted) return;

      await parentRepository.clearSelectedChild();
      await _applyParentLocale();
      if (!mounted) return;

      // При восстановлении детского режима после перезапуска ChildRootShell
      // является корневым экраном, поэтому pop() делать некуда. В этом случае
      // просим AuthGate заново показать родительский кабинет.
      if (widget.onReturnToParent != null) {
        widget.onReturnToParent!();
        return;
      }

      setState(() {
        _allowPop = true;
      });

      // Обычный сценарий: детский режим был открыт из родительского кабинета
      // через Navigator.push(), поэтому после PIN можно закрыть route.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      Navigator.of(context).pop();
    } finally {
      _exitInProgress = false;
    }
  }

  Future<void> _openSettings() async {
    final returnToParent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChildSettingsScreen(
          repository: parentRepository,
          childId: widget.childId,
          requestParentAccess: _verifyParentPin,
        ),
      ),
    );

    if (!mounted) return;
    if (returnToParent == true) {
      await _leaveChildMode(alreadyVerified: true);
      return;
    }

    await _refreshChildLocale();
    if (!mounted) return;
    setState(() {
      _homeRevision++;
    });
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() {
      // Пересоздаём скрытые экраны, зависящие от языка.
      _languageRevision++;
    });
    _openAdventureChoice();
  }

  Future<void> _openAdventureChoice() async {
    while (mounted) {
      final destination = await Navigator.of(context).push<AdventureDestination>(
        MaterialPageRoute(
          builder: (_) => AdventureChoiceScreen(repository: appRepository),
        ),
      );

      if (!mounted) return;

      // Закрытие экрана пещер кнопкой Back всегда возвращает ребёнка
      // на главный экран выбора языка. Это одинаково работает независимо
      // от того, открыли пещеры после выбора языка или со страницы тем.
      if (destination == null) {
        setState(() {
          _index = 0;
          _homeRevision++;
        });
        return;
      }

      switch (destination) {
        case AdventureDestination.learn:
          setState(() => _index = 1);
          return;
        case AdventureDestination.play:
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LearnedWordsGamesScreen(repository: appRepository),
            ),
          );
          if (!mounted) return;
          break;
        case AdventureDestination.smart:
          final language = await appRepository.getSelectedLanguage();
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SmartContentScreen(
                repository: appRepository,
                language: language,
              ),
            ),
          );
          if (!mounted) return;
          break;
      }
    }
  }

  void _onNavTap(int index) {
    setState(() {
      if (index == 0) _homeRevision++;
      _index = index;
    });
  }

  Future<void> _openAchievements() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AchievementsScreen(
          repository: appRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSubscription) {
      return const Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: AssetImage('assets/images/adventure_bg.webp'),
              fit: BoxFit.cover,
            ),
            Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ],
        ),
      );
    }

    final access = _subscriptionAccess ??
        const SubscriptionAccessStatus(active: false, reason: 'none');

    if (!access.active) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leaveChildMode();
        },
        child: SubscriptionBlockedScreen(
          access: access,
          onPlay: () {
            _openFreePlay();
          },
          onParent: () => _leaveChildMode(),
          onSettings: _openSettings,
          onRetry: () => _checkSubscriptionAccess(showLoading: false),
        ),
      );
    }

    final screens = [
      HomeScreen(
        key: ValueKey('home-$_homeRevision'),
        repository: appRepository,
        onOpenSettings: _openSettings,
        onSeeAllTopics: () => _onNavTap(1),
        onOpenAchievements: _openAchievements,
        onLanguageChanged: _onLanguageChanged,
      ),
      TopicsScreen(
        key: ValueKey('topics-language-$_languageRevision'),
        repository: appRepository,
        gameRepository: gameRepository,
        onBack: () => _openAdventureChoice(),
      ),
    ];

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Если ребёнок находится на экране тем, системная кнопка
        // «Назад» должна вернуть его к выбору пещеры, а не к выбору языка
        // и не выводить сразу в родительский кабинет.
        if (_index == 1) {
          _openAdventureChoice();
          return;
        }

        _leaveChildMode();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _index, children: screens),
      ),
    );
  }
}

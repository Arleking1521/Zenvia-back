import 'package:flutter/material.dart';

import 'data/api/api_client.dart';
import 'data/api_app_repository.dart';
import 'data/api_auth_repository.dart';
import 'data/api_game_repository.dart';
import 'data/api_parent_repository.dart';
import 'data/app_repository.dart';
import 'data/auth_repository.dart';
import 'data/game_repository.dart';
import 'data/parent_repository.dart';
import 'models/child_profile.dart';
import 'screens/achievements_screen.dart';
import 'screens/adventure_choice_screen.dart';
import 'screens/child_settings_screen.dart';
import 'screens/learned_words_games_screen.dart';
import 'screens/home_screen.dart';
import 'screens/parent_dashboard_screen.dart';
import 'screens/parent_login_screen.dart';
import 'screens/topics_screen.dart';
import 'screens/smart_content_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/adaptive_app_viewport.dart';
import 'widgets/parent_pin_dialog.dart';
import 'widgets/magic_ui.dart';

void main() => runApp(const KidsLangApp());

final ApiClient apiClient = ApiClient();
final AuthRepository authRepository = ApiAuthRepository(apiClient);
final ParentRepository parentRepository = ApiParentRepository(apiClient);
final AppRepository appRepository = ApiAppRepository(apiClient);
final GameRepository gameRepository = ApiGameRepository(apiClient);

class KidsLangApp extends StatelessWidget {
  const KidsLangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenvia Kids',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => AdaptiveAppViewport(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late Future<bool> _loggedInFuture;

  @override
  void initState() {
    super.initState();
    _loggedInFuture = authRepository.isLoggedIn();
  }

  void _refresh() {
    setState(() {
      _loggedInFuture = authRepository.isLoggedIn();
    });
  }

  Future<void> _openChild(BuildContext context, ChildProfile child) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChildRootShell(childId: child.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loggedInFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: FantasyBackground(
              light: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ZenviaLogo(scale: .85),
                    SizedBox(height: 22),
                    CircularProgressIndicator(color: Colors.white),
                  ],
                ),
              ),
            ),
          );
        }

        if (!snapshot.data!) {
          return ParentLoginScreen(
            authRepository: authRepository,
            onLoggedIn: _refresh,
          );
        }

        return ParentDashboardScreen(
          authRepository: authRepository,
          parentRepository: parentRepository,
          onOpenChild: (child) => _openChild(context, child),
          onLoggedOut: _refresh,
        );
      },
    );
  }
}

class ChildRootShell extends StatefulWidget {
  final int childId;

  const ChildRootShell({super.key, required this.childId});

  @override
  State<ChildRootShell> createState() => _ChildRootShellState();
}

class _ChildRootShellState extends State<ChildRootShell> {
  int _index = 0;
  int _homeRevision = 0;
  int _languageRevision = 0;
  bool _allowPop = false;
  bool _exitInProgress = false;

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
      if (!mounted) return;

      setState(() {
        _allowPop = true;
      });

      // Даём PopScope перестроиться с canPop=true перед закрытием route.
      // К этому моменту PIN-диалог уже полностью завершил exit-анимацию.
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

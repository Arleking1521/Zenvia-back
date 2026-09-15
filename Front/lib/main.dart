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
import 'screens/child_settings_screen.dart';
import 'screens/games_screen.dart';
import 'screens/home_screen.dart';
import 'screens/parent_dashboard_screen.dart';
import 'screens/parent_login_screen.dart';
import 'screens/topics_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/parent_pin_dialog.dart';

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
      title: 'Учим языки',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

  void _onNavTap(int index) {
    setState(() {
      if (index == 0) _homeRevision++;
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        key: ValueKey('home-$_homeRevision'),
        repository: appRepository,
        onOpenSettings: _openSettings,
        onSeeAllTopics: () => _onNavTap(1),
      ),
      TopicsScreen(repository: appRepository),
      GamesScreen(
        appRepository: appRepository,
        gameRepository: gameRepository,
      ),
      AchievementsScreen(repository: appRepository),
    ];

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _leaveChildMode();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _index, children: screens),
        bottomNavigationBar: AppBottomNav(
          currentIndex: _index,
          onTap: _onNavTap,
        ),
      ),
    );
  }
}

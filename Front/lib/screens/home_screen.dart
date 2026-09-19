import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_repository.dart';
import '../models/language.dart';
import '../theme/app_colors.dart';
import '../widgets/magic_ui.dart';
import 'dragon_evolution_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppRepository repository;
  final VoidCallback onOpenSettings;
  final VoidCallback onSeeAllTopics;
  final VoidCallback onOpenAchievements;
  final VoidCallback? onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.onOpenSettings,
    required this.onSeeAllTopics,
    required this.onOpenAchievements,
    this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<LanguageOption>> _languagesFuture;
  AppLanguage _selectedLanguage = AppLanguage.english;
  String? _levelDragonUrl;

  @override
  void initState() {
    super.initState();
    _languagesFuture = _load();
  }

  Future<List<LanguageOption>> _load() async {
    final selected = await widget.repository.getSelectedLanguage();
    final languages = await widget.repository.getAvailableLanguages();

    String? dragonUrl;
    try {
      dragonUrl = await widget.repository.getLevelDragonUrl();
    } catch (_) {
      // Если картинку уровня временно не удалось получить,
      // ниже останется локальный fallback-дракончик.
    }

    if (mounted) {
      setState(() {
        _selectedLanguage = selected;
        _levelDragonUrl = dragonUrl;
      });
    } else {
      _selectedLanguage = selected;
      _levelDragonUrl = dragonUrl;
    }
    return languages;
  }

  Future<void> _openDragonEvolution() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DragonEvolutionScreen(repository: widget.repository),
      ),
    );

    // После возврата обновляем изображение: уровень мог измениться.
    try {
      final url = await widget.repository.getLevelDragonUrl();
      if (!mounted) return;
      setState(() => _levelDragonUrl = url);
    } catch (_) {
      // Сохраняем уже показанное изображение при временной ошибке сети.
    }
  }

  Future<void> _selectLanguage(LanguageOption option) async {
    final language = option.appLanguage;
    if (language == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Язык «${option.title}» пока не поддерживается этой версией приложения.',
          ),
        ),
      );
      return;
    }

    if (language == _selectedLanguage) return;

    // Сначала мгновенно меняем визуальное состояние карточки.
    // Главный экран при этом не пересоздаётся и не показывает loader.
    final previousLanguage = _selectedLanguage;
    setState(() => _selectedLanguage = language);

    try {
      await widget.repository.setSelectedLanguage(language);
      if (!mounted) return;

      // Обновляем только скрытые экраны: Темы / Игры / Награды.
      widget.onLanguageChanged?.call();
    } catch (_) {
      if (!mounted) return;
      // Если сохранение не удалось, возвращаем предыдущий выбор.
      setState(() => _selectedLanguage = previousLanguage);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить язык. Попробуйте ещё раз.')),
      );
    }
  }

  void _retry() {
    setState(() => _languagesFuture = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LanguageOption>>(
      future: _languagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Color(0xFF7ED8F4),
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return _ApiErrorState(
            message: snapshot.error.toString(),
            onRetry: _retry,
          );
        }

        final languages = snapshot.data ?? const <LanguageOption>[];

        return ColoredBox(
          color: const Color(0xFF7ED8F4),
          child: Stack(
            children: [
              const Positioned.fill(
                child: Image(
                  image: AssetImage('assets/images/home_language_bg.webp'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.blue.withValues(alpha: .06),
                        Colors.transparent,
                        Colors.white.withValues(alpha: .04),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    final width = constraints.maxWidth;
                    final dragonSize = math.min(
                      width * .66,
                      height * .30,
                    ).clamp(190.0, 270.0).toDouble();

                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async {
                        setState(() => _languagesFuture = _load());
                        await _languagesFuture;
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                              child: Stack(
                                fit: StackFit.expand,
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: _TopBar(
                                      onSettings: widget.onOpenSettings,
                                      onAchievements: widget.onOpenAchievements,
                                    ),
                                  ),
                                  const Positioned(
                                    top: 58,
                                    left: 0,
                                    right: 0,
                                    child: Text(
                                      'Выбери язык',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 25,
                                        fontWeight: FontWeight.w900,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x990E3B7D),
                                            blurRadius: 7,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Кнопки языков находятся ровно в средней
                                  // части экрана по высоте.
                                  Align(
                                    alignment: const Alignment(0, -0.10),
                                    child: languages.isEmpty
                                        ? const _EmptyLanguages()
                                        : Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              for (var i = 0; i < languages.length; i++) ...[
                                                _LanguageChoiceCard(
                                                  language: languages[i],
                                                  selected: languages[i].appLanguage == _selectedLanguage,
                                                  onTap: () => _selectLanguage(languages[i]),
                                                ),
                                                if (i != languages.length - 1)
                                                  const SizedBox(height: 10),
                                              ],
                                            ],
                                          ),
                                  ),

                                  // Дракон текущего уровня. Положение оставляем
                                  // прежним, но теперь картинка приходит с backend.
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 24,
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: _openDragonEvolution,
                                        behavior: HitTestBehavior.opaque,
                                        child: SizedBox(
                                          width: dragonSize,
                                          height: dragonSize,
                                          child: _LevelDragonImage(
                                            url: _levelDragonUrl,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LevelDragonImage extends StatelessWidget {
  final String? url;

  const _LevelDragonImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final value = url?.trim();

    if (value == null || value.isEmpty) {
      return Image.asset(
        'assets/images/home_language_dragon.webp',
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
      );
    }

    return Image.network(
      value,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/home_language_dragon.webp',
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onSettings;
  final VoidCallback onAchievements;

  const _TopBar({
    required this.onSettings,
    required this.onAchievements,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: const Color(0x332A85B7),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onSettings,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        const Spacer(),
        Material(
          color: const Color(0x332A85B7),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onAchievements,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 25,
                shadows: [
                  Shadow(color: Color(0x660E3B7D), blurRadius: 7),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageChoiceCard extends StatelessWidget {
  final LanguageOption language;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageChoiceCard({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 300,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.fromLTRB(10, 7, 18, 7),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: .97)
                  : const Color(0xFFF7EDF7).withValues(alpha: .93),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: selected
                    ? const Color(0xFF56D98A)
                    : Colors.white.withValues(alpha: .92),
                width: selected ? 2.3 : 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? const Color(0xFF28C96C).withValues(alpha: .24)
                      : const Color(0xFF315B88).withValues(alpha: .12),
                  blurRadius: selected ? 17 : 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                _LanguageIcon(language: language),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    language.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF32323B),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFF28C96C),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageIcon extends StatelessWidget {
  final LanguageOption language;

  const _LanguageIcon({required this.language});

  @override
  Widget build(BuildContext context) {
    final url = language.iconUrl;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D5790).withValues(alpha: .12),
            blurRadius: 7,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? Center(
              child: Text(
                language.appLanguage?.flagEmoji ?? '🌐',
                style: const TextStyle(fontSize: 27),
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  language.appLanguage?.flagEmoji ?? '🌐',
                  style: const TextStyle(fontSize: 27),
                ),
              ),
            ),
    );
  }
}

class _EmptyLanguages extends StatelessWidget {
  const _EmptyLanguages();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .90),
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Text(
          'В базе пока нет доступных языков.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.deepBlue,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ApiErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ApiErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: Image(
            image: AssetImage('assets/images/home_language_bg.webp'),
            fit: BoxFit.cover,
          ),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: MagicCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('☁️', style: TextStyle(fontSize: 46)),
                    const SizedBox(height: 10),
                    const Text(
                      'Не удалось загрузить языки',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    MagicPrimaryButton(
                      label: 'Повторить',
                      onPressed: onRetry,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

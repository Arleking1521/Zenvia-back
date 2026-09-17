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
  final VoidCallback? onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.onOpenSettings,
    required this.onSeeAllTopics,
    this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _homeFuture;
  AppLanguage _selectedLanguage = AppLanguage.english;

  @override
  void initState() {
    super.initState();
    _homeFuture = _load();
  }

  Future<_HomeData> _load() async {
    final selected = await widget.repository.getSelectedLanguage();
    final results = await Future.wait<dynamic>([
      widget.repository.getAvailableLanguages(),
      widget.repository.getLevelDragonUrl(),
    ]);

    if (mounted) {
      setState(() => _selectedLanguage = selected);
    } else {
      _selectedLanguage = selected;
    }

    return _HomeData(
      languages: results[0] as List<LanguageOption>,
      levelDragonUrl: results[1] as String?,
    );
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

    if (language == _selectedLanguage) {
      // Даже если язык уже выбран, нажатие на карточку ведёт сразу к темам.
      widget.onLanguageChanged?.call();
      return;
    }

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
    setState(() => _homeFuture = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _homeFuture,
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

        final data = snapshot.data ?? const _HomeData();
        final languages = data.languages;

        return ColoredBox(
          color: const Color(0xFF7ED8F4),
          child: Stack(
            children: [
              const Positioned.fill(
                child: Image(
                  image: AssetImage('assets/images/home_language_bg.png'),
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
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    setState(() => _homeFuture = _load());
                    await _homeFuture;
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                    children: [
                      _TopBar(onSettings: widget.onOpenSettings),
                      const SizedBox(height: 10),
                      const Text(
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
                      const SizedBox(height: 18),
                      if (languages.isEmpty)
                        const _EmptyLanguages()
                      else
                        ...languages.map(
                          (language) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LanguageChoiceCard(
                              language: language,
                              selected: language.appLanguage == _selectedLanguage,
                              onTap: () => _selectLanguage(language),
                            ),
                          ),
                        ),
                      const SizedBox(height: 2),
                      _LevelDragon(
                        imageUrl: data.levelDragonUrl,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DragonEvolutionScreen(
                              repository: widget.repository,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _HomeData {
  final List<LanguageOption> languages;
  final String? levelDragonUrl;

  const _HomeData({
    this.languages = const <LanguageOption>[],
    this.levelDragonUrl,
  });
}

class _LevelDragon extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback onTap;

  const _LevelDragon({required this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 265,
          height: 265,
          child: url == null || url.isEmpty
              ? const Center(
                  child: Text('🐉', style: TextStyle(fontSize: 120)),
                )
              : Image.network(
                  url,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('🐉', style: TextStyle(fontSize: 120)),
                  ),
                ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onSettings;

  const _TopBar({required this.onSettings});

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
        const Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
          size: 25,
          shadows: [
            Shadow(color: Color(0x660E3B7D), blurRadius: 7),
          ],
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
            image: AssetImage('assets/images/home_language_bg.png'),
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

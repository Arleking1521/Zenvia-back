import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../data/parent_repository.dart';
import '../models/child_profile.dart';
import '../models/parent_account.dart';
import '../theme/app_colors.dart';
import '../widgets/magic_ui.dart';
import '../widgets/parent_pin_dialog.dart';
import 'child_editor_screen.dart';
import 'parent_settings_screen.dart';
import 'tariffs_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final ParentRepository parentRepository;
  final Future<void> Function(ChildProfile child) onOpenChild;
  final VoidCallback onLoggedOut;

  const ParentDashboardScreen({
    super.key,
    required this.authRepository,
    required this.parentRepository,
    required this.onOpenChild,
    required this.onLoggedOut,
  });

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  late Future<ParentDashboard> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.parentRepository.getDashboard();
  }

  void _reload() {
    setState(() {
      _future = widget.parentRepository.getDashboard();
    });
  }

  Future<void> _requestAddChild(ParentDashboard data) async {
    if (!data.childAccess.canCreateChild) {
      final goToTariffs = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          title: Text(
            data.childAccess.activeSubscription
                ? 'Лимит профилей исчерпан'
                : 'Нужна активная подписка',
          ),
          content: Text(
            data.childAccess.reason ??
                'По текущему тарифу нельзя создать ещё один профиль ребёнка.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Закрыть'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Тарифы'),
            ),
          ],
        ),
      );
      if (goToTariffs == true && mounted) await _openTariffs();
      return;
    }

    final created = await Navigator.of(context).push<ChildProfile>(
      MaterialPageRoute(
        builder: (_) => ChildEditorScreen(repository: widget.parentRepository),
      ),
    );
    if (created != null && mounted) _reload();
  }

  Future<void> _openChild(ChildProfile child) async {
    try {
      final hasPin = await widget.parentRepository.hasParentPin();
      if (!mounted) return;

      if (!hasPin) {
        final created = await showParentPinSetupDialog(
          context: context,
          repository: widget.parentRepository,
        );
        if (!created || !mounted) return;
      }

      await widget.parentRepository.selectChild(child.id);
      await widget.onOpenChild(child);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _editChild(ChildProfile child) async {
    final result = await Navigator.of(context).push<ChildProfile>(
      MaterialPageRoute(
        builder: (_) => ChildEditorScreen(
          repository: widget.parentRepository,
          child: child,
        ),
      ),
    );
    if (result != null && mounted) _reload();
  }

  Future<void> _archiveChild(ChildProfile child) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text('Удалить профиль?'),
        content: Text(
          'Профиль «${child.name}» будет скрыт, но учебная история сохранится в базе.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.parentRepository.archiveChild(child.id);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _openTariffs() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TariffsScreen(repository: widget.parentRepository),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ParentSettingsScreen(
          authRepository: widget.authRepository,
          parentRepository: widget.parentRepository,
          onLoggedOut: widget.onLoggedOut,
        ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FantasyBackground(
        child: SafeArea(
          child: FutureBuilder<ParentDashboard>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: MagicCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('☁️', style: TextStyle(fontSize: 44)),
                          const SizedBox(height: 8),
                          Text(snapshot.error.toString(), textAlign: TextAlign.center),
                          const SizedBox(height: 14),
                          MagicPrimaryButton(label: 'Повторить', onPressed: _reload),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final data = snapshot.data!;
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _future;
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  children: [
                    Row(
                      children: [
                        const ZenviaLogo(scale: .56),
                        const Spacer(),
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: _openSettings,
                            icon: const Icon(Icons.settings_rounded, color: AppColors.deepBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    MagicCard(
                      padding: EdgeInsets.zero,
                      gradient: AppColors.magicGradient,
                      child: SizedBox(
                        height: 168,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  'assets/images/dragon_wave.webp',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.deepBlue.withValues(alpha: .88),
                                      AppColors.skyTop.withValues(alpha: .52),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 18,
                              top: 24,
                              width: 215,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Здравствуйте, ${data.parent.firstName}!',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data.parent.email,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Здесь вы управляете семейным обучением ✨',
                                    style: TextStyle(color: Colors.white, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SubscriptionCard(dashboard: data, onTap: _openTariffs),
                    const SizedBox(height: 22),
                    MagicSectionTitle(
                      title: 'Профили детей',
                      action: 'Добавить',
                      onAction: () => _requestAddChild(data),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.childAccess.activeSubscription
                          ? '${data.childAccess.activeChildren} из ${data.childAccess.maxChildren} профилей'
                          : 'Нет активной подписки',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (!data.childAccess.canCreateChild) ...[
                      const SizedBox(height: 10),
                      _LimitNotice(access: data.childAccess, onTariffs: _openTariffs),
                    ],
                    const SizedBox(height: 12),
                    if (data.children.isEmpty)
                      MagicCard(
                        child: Column(
                          children: [
                            const Text('🐣', style: TextStyle(fontSize: 54)),
                            const SizedBox(height: 8),
                            Text(
                              data.childAccess.canCreateChild
                                  ? 'Создайте первый профиль ребёнка и начните приключение.'
                                  : (data.childAccess.reason ?? 'Сначала выберите тариф.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 14),
                            MagicPrimaryButton(
                              label: data.childAccess.canCreateChild
                                  ? 'Создать профиль'
                                  : 'Выбрать тариф',
                              icon: data.childAccess.canCreateChild
                                  ? Icons.add_rounded
                                  : Icons.workspace_premium_rounded,
                              onPressed: () => data.childAccess.canCreateChild
                                  ? _requestAddChild(data)
                                  : _openTariffs(),
                            ),
                          ],
                        ),
                      ),
                    ...data.children.map(
                      (child) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ChildCard(
                          child: child,
                          onOpen: () => _openChild(child),
                          onEdit: () => _editChild(child),
                          onDelete: () => _archiveChild(child),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final ParentDashboard dashboard;
  final VoidCallback onTap;
  const _SubscriptionCard({required this.dashboard, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sub = dashboard.subscription;
    final access = dashboard.childAccess;
    String subtitle;
    if (sub == null) {
      subtitle = 'Выберите тариф для семьи';
    } else if (sub.status == 'pending') {
      subtitle = 'Ожидает оплаты · профили пока недоступны';
    } else if (access.activeSubscription) {
      subtitle = 'Активна · ${access.activeChildren}/${access.maxChildren} профилей';
    } else {
      subtitle = 'Статус: ${sub.statusLabel}';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF4C7), Color(0xFFFFE3A1)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.gold.withValues(alpha: .55)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: Icon(Icons.workspace_premium_rounded, color: AppColors.goldDark, size: 28),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub?.tariff.title ?? 'Тариф не выбран',
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.goldDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _LimitNotice extends StatelessWidget {
  final ChildProfileAccess access;
  final VoidCallback onTariffs;
  const _LimitNotice({required this.access, required this.onTariffs});

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      color: const Color(0xFFFFF3E6),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              access.reason ?? 'Создание дополнительного профиля недоступно.',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          TextButton(onPressed: onTariffs, child: const Text('Тарифы')),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final ChildProfile child;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ChildCard({
    required this.child,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return MagicCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE6F7FF), Color(0xFFE9FFE9)]),
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: child.avatar?.imageUrl == null
                ? const Center(child: Text('🐉', style: TextStyle(fontSize: 34)))
                : Image.network(
                    child.avatar!.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(child: Text('🐉', style: TextStyle(fontSize: 34))),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Уровень ${child.level?.number ?? 0} · ${child.totalXp} XP',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                Text(
                  child.baseLanguage?.title ?? 'Язык не выбран',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Редактировать')),
              PopupMenuItem(value: 'delete', child: Text('Удалить')),
            ],
          ),
          IconButton.filled(
            onPressed: onOpen,
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

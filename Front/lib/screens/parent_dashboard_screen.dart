import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../data/parent_repository.dart';
import '../models/child_profile.dart';
import '../models/parent_account.dart';
import '../theme/app_colors.dart';
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
      if (goToTariffs == true && mounted) {
        await _openTariffs();
      }
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<ParentDashboard>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(snapshot.error.toString(), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _reload, child: const Text('Повторить')),
                    ],
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Здравствуйте, ${data.parent.firstName}!',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              data.parent.email,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SubscriptionCard(dashboard: data, onTap: _openTariffs),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Профили детей',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data.childAccess.activeSubscription
                                  ? '${data.childAccess.activeChildren} из ${data.childAccess.maxChildren} профилей'
                                  : 'Нет активной подписки',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _requestAddChild(data),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Добавить'),
                      ),
                    ],
                  ),
                  if (!data.childAccess.canCreateChild) ...[
                    const SizedBox(height: 6),
                    _LimitNotice(
                      access: data.childAccess,
                      onTariffs: _openTariffs,
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (data.children.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.child_care_rounded,
                              size: 52,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data.childAccess.canCreateChild
                                  ? 'Создайте профиль ребёнка, чтобы начать обучение.'
                                  : (data.childAccess.reason ??
                                      'Сначала активируйте подходящий тариф.'),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => data.childAccess.canCreateChild
                                  ? _requestAddChild(data)
                                  : _openTariffs(),
                              icon: Icon(
                                data.childAccess.canCreateChild
                                    ? Icons.add
                                    : Icons.workspace_premium_rounded,
                              ),
                              label: Text(
                                data.childAccess.canCreateChild
                                    ? 'Создать профиль'
                                    : 'Выбрать тариф',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ...data.children.map(
                    (child) => _ChildCard(
                      child: child,
                      onOpen: () => _openChild(child),
                      onEdit: () => _editChild(child),
                      onDelete: () => _archiveChild(child),
                    ),
                  ),
                ],
              ),
            );
          },
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              child: Icon(Icons.workspace_premium_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub?.tariff.title ?? 'Тариф не выбран',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              access.reason ?? 'Создание дополнительного профиля недоступно.',
              style: const TextStyle(fontSize: 13),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 31,
              backgroundColor: AppColors.background,
              backgroundImage: child.avatar?.imageUrl == null
                  ? null
                  : NetworkImage(child.avatar!.imageUrl!),
              child: child.avatar?.imageUrl == null
                  ? const Text('🙂', style: TextStyle(fontSize: 28))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  Text('${child.totalXp} XP · Уровень ${child.level?.number ?? 0}'),
                  Text(
                    child.baseLanguage?.title ?? 'Язык не выбран',
                    style: const TextStyle(color: AppColors.textSecondary),
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
            FilledButton(onPressed: onOpen, child: const Text('Открыть')),
          ],
        ),
      ),
    );
  }
}

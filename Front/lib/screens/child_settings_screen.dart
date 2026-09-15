import 'package:flutter/material.dart';

import '../data/parent_repository.dart';
import '../models/child_profile.dart';
import '../theme/app_colors.dart';
import 'child_editor_screen.dart';

class ChildSettingsScreen extends StatefulWidget {
  final ParentRepository repository;
  final int childId;
  final Future<bool> Function() requestParentAccess;

  const ChildSettingsScreen({
    super.key,
    required this.repository,
    required this.childId,
    required this.requestParentAccess,
  });

  @override
  State<ChildSettingsScreen> createState() => _ChildSettingsScreenState();
}

class _ChildSettingsScreenState extends State<ChildSettingsScreen> {
  late Future<ChildProfile> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getChild(widget.childId);
  }

  Future<void> _edit(ChildProfile child) async {
    final allowed = await widget.requestParentAccess();
    if (!allowed || !mounted) return;

    final updated = await Navigator.of(context).push<ChildProfile>(
      MaterialPageRoute(
        builder: (_) => ChildEditorScreen(
          repository: widget.repository,
          child: child,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _future = widget.repository.getChild(widget.childId);
      });
    }
  }

  Future<void> _returnToParent() async {
    final allowed = await widget.requestParentAccess();
    if (!allowed || !mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Профиль ребёнка')),
      body: FutureBuilder<ChildProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final child = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white,
                  backgroundImage: child.avatar?.imageUrl == null
                      ? null
                      : NetworkImage(child.avatar!.imageUrl!),
                  child: child.avatar?.imageUrl == null
                      ? const Text('🙂', style: TextStyle(fontSize: 40))
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                child.name,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'XP: ${child.totalXp} · Уровень ${child.level?.number ?? 0}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.translate_rounded),
                title: const Text('Базовый язык'),
                subtitle: Text(child.baseLanguage?.title ?? 'Не выбран'),
                trailing: const Icon(Icons.lock_outline_rounded),
                onTap: () => _edit(child),
              ),
              const SizedBox(height: 8),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.face_rounded),
                title: const Text('Имя и аватар'),
                trailing: const Icon(Icons.lock_outline_rounded),
                onTap: () => _edit(child),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _returnToParent,
                icon: const Icon(Icons.family_restroom_rounded),
                label: const Text('Вернуться в кабинет родителя'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Изменение профиля и выход защищены родительским PIN.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

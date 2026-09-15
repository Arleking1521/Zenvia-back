import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../data/parent_repository.dart';
import '../models/parent_account.dart';
import '../theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/parent_pin_dialog.dart';

class ParentSettingsScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final ParentRepository parentRepository;
  final VoidCallback onLoggedOut;

  const ParentSettingsScreen({
    super.key,
    required this.authRepository,
    required this.parentRepository,
    required this.onLoggedOut,
  });

  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  late Future<ParentAccount> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.authRepository.getParent();
  }

  Future<void> _changeName(ParentAccount parent) async {
    final controller = TextEditingController(text: parent.firstName);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Имя родителя'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Имя')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Сохранить')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().length < 2) return;
    try {
      await widget.authRepository.updateParentName(value);
      if (mounted) {
        setState(() {
          _future = widget.authRepository.getParent();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _changePassword() async {
    final old = TextEditingController();
    final fresh = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Сменить пароль'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: old, label: 'Текущий пароль', hint: 'Введите пароль', obscure: true),
                const SizedBox(height: 10),
                AppTextField(controller: fresh, label: 'Новый пароль', hint: 'Минимум 6 символов', obscure: true),
                const SizedBox(height: 10),
                AppTextField(controller: confirm, label: 'Подтверждение', hint: 'Повторите пароль', obscure: true),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                if (fresh.text != confirm.text) {
                  setDialogState(() => error = 'Новые пароли не совпадают.');
                  return;
                }
                try {
                  await widget.authRepository.changePassword(
                    oldPassword: old.text,
                    newPassword: fresh.text,
                    newPasswordConfirm: confirm.text,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  setDialogState(() => error = e.toString());
                }
              },
              child: const Text('Изменить'),
            ),
          ],
        ),
      ),
    );
    old.dispose();
    fresh.dispose();
    confirm.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пароль изменён.')));
    }
  }


  Future<void> _changeParentPin() async {
    try {
      final hasPin = await widget.parentRepository.hasParentPin();
      if (!mounted) return;
      final saved = await showParentPinSetupDialog(
        context: context,
        repository: widget.parentRepository,
        changing: hasPin,
      );
      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hasPin ? 'Родительский PIN изменён.' : 'Родительский PIN создан.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _logout() async {
    await widget.authRepository.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onLoggedOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Настройки родителя')),
      body: FutureBuilder<ParentAccount>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final parent = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                  title: Text(parent.firstName),
                  subtitle: Text(parent.email),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Изменить имя'),
                onTap: () => _changeName(parent),
              ),
              const SizedBox(height: 8),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.lock_reset_rounded),
                title: const Text('Сменить пароль'),
                onTap: _changePassword,
              ),
              const SizedBox(height: 8),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.lock_rounded),
                title: const Text('Родительский PIN'),
                subtitle: const Text('Защита выхода из режима обучения'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _changeParentPin,
              ),
              const SizedBox(height: 8),
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text('Выйти', style: TextStyle(color: Colors.red)),
                onTap: _logout,
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/magic_ui.dart';

class ParentRegisterScreen extends StatefulWidget {
  final AuthRepository authRepository;
  const ParentRegisterScreen({super.key, required this.authRepository});
  @override
  State<ParentRegisterScreen> createState() => _ParentRegisterScreenState();
}

class _ParentRegisterScreenState extends State<ParentRegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Пароли не совпадают.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.authRepository.register(
        parentName: _name.text,
        email: _email.text,
        password: _password.text,
        passwordConfirm: _confirm.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FantasyBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  IconButton.filled(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
                  const SizedBox(width: 10),
                  const Text('Новая семья', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.deepBlue)),
                ],
              ),
              const SizedBox(height: 16),
              const ZenviaLogo(scale: .7),
              const SizedBox(height: 18),
              MagicCard(
                child: Column(
                  children: [
                    AppTextField(controller: _name, label: 'Имя родителя', hint: 'Наргиз'),
                    const SizedBox(height: 12),
                    AppTextField(controller: _email, label: 'Email', hint: 'parent@example.com', keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    AppTextField(controller: _password, label: 'Пароль', hint: 'Минимум 6 символов', obscure: true),
                    const SizedBox(height: 12),
                    AppTextField(controller: _confirm, label: 'Подтверждение пароля', hint: 'Повторите пароль', obscure: true),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, child: MagicPrimaryButton(label: _loading ? 'Создаём…' : 'Создать аккаунт', icon: Icons.favorite_rounded, onPressed: _loading ? null : _submit)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

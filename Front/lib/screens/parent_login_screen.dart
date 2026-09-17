import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/magic_ui.dart';
import 'parent_register_screen.dart';

class ParentLoginScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final VoidCallback onLoggedIn;
  const ParentLoginScreen({super.key, required this.authRepository, required this.onLoggedIn});
  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Введите email и пароль.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.authRepository.login(email: _email.text, password: _password.text);
      if (mounted) widget.onLoggedIn();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ParentRegisterScreen(authRepository: widget.authRepository)),
    );
    if (success == true && mounted) widget.onLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FantasyBackground(
        light: false,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    const ZenviaLogo(scale: .9),
                    const SizedBox(height: 14),
                    DragonImage(asset: 'assets/images/dragon_hero.png', height: 220),
                    const SizedBox(height: 14),
                    MagicCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Кабинет родителя', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.deepBlue)),
                          const SizedBox(height: 6),
                          const Text('Управляйте профилями детей, тарифом и безопасностью.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 20),
                          AppTextField(controller: _email, label: 'Email', hint: 'parent@example.com', keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          AppTextField(controller: _password, label: 'Пароль', hint: 'Введите пароль', obscure: true),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                          ],
                          const SizedBox(height: 18),
                          MagicPrimaryButton(label: _loading ? 'Входим…' : 'Войти', icon: Icons.login_rounded, onPressed: _loading ? null : _submit),
                          const SizedBox(height: 8),
                          TextButton(onPressed: _loading ? null : _register, child: const Text('Создать аккаунт родителя')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

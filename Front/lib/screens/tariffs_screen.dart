import 'package:flutter/material.dart';

import '../data/parent_repository.dart';
import '../models/subscription.dart';
import '../theme/app_colors.dart';

class TariffsScreen extends StatefulWidget {
  final ParentRepository repository;
  const TariffsScreen({super.key, required this.repository});

  @override
  State<TariffsScreen> createState() => _TariffsScreenState();
}

class _TariffsScreenState extends State<TariffsScreen> {
  late Future<_Data> _future;
  final TextEditingController _promoController = TextEditingController();

  int? _processingId;
  bool _validatingPromo = false;
  KindergartenPromoOffer? _promoOffer;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<_Data> _load() async {
    final values = await Future.wait([
      widget.repository.getTariffs(),
      widget.repository.getCurrentSubscription(),
    ]);
    return _Data(
      tariffs: values[0] as List<TariffPlan>,
      current: values[1] as SubscriptionInfo?,
    );
  }

  Future<void> _validatePromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите промокод детского сада.')),
      );
      return;
    }

    setState(() => _validatingPromo = true);
    try {
      final offer = await widget.repository.validatePromoCode(code);
      if (!mounted) return;
      setState(() {
        _promoOffer = offer;
        _promoController.text = offer.code;
        _promoController.selection = TextSelection.collapsed(
          offset: _promoController.text.length,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Промокод применён: ${offer.kindergartenName}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _promoOffer = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _validatingPromo = false);
    }
  }

  Future<void> _buy(
    TariffPlan plan, {
    String? promoCode,
  }) async {
    setState(() => _processingId = plan.id);
    try {
      final sub = await widget.repository.createSubscription(
        plan.id,
        promoCode: promoCode,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Тариф оформлен'),
          content: Text(
            'Создана подписка со статусом «${sub.statusLabel}». '
            'Текущий backend пока не подключён к платёжному провайдеру, '
            'поэтому реальная оплата и активация выполняются отдельно.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
      setState(() {
        _promoOffer = null;
        _promoController.clear();
        _future = _load();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Widget _tariffCard({
    required BuildContext context,
    required TariffPlan plan,
    required bool disabled,
    String? promoCode,
    String? badge,
    String? subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              plan.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(plan.description),
            ],
            const SizedBox(height: 10),
            Text(
              '${plan.price} ${plan.currency} / ${plan.durationDays} дней',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('Профилей детей: до ${plan.maxChildren}'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: disabled || _processingId != null
                    ? null
                    : () => _buy(
                          plan,
                          promoCode: promoCode,
                        ),
                child: _processingId == plan.id
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        promoCode == null
                            ? 'Оформить тариф'
                            : 'Подключить по промокоду',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promoSection({
    required bool disabled,
  }) {
    final offer = _promoOffer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Промокод детского сада',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Введите код, выданный детским садом, чтобы открыть специальный тариф.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _promoController,
          enabled: !disabled && !_validatingPromo,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'Например, BALAPAN2026',
            prefixIcon: const Icon(Icons.confirmation_number_outlined),
            suffixIcon: _promoController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Очистить',
                    onPressed: disabled || _validatingPromo
                        ? null
                        : () {
                            setState(() {
                              _promoController.clear();
                              _promoOffer = null;
                            });
                          },
                    icon: const Icon(Icons.close),
                  ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            if (offer != null &&
                value.trim().toUpperCase() != offer.code.toUpperCase()) {
              setState(() => _promoOffer = null);
            } else {
              setState(() {});
            }
          },
          onSubmitted: disabled || _validatingPromo
              ? null
              : (_) => _validatePromo(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: disabled || _validatingPromo
                ? null
                : _validatePromo,
            icon: _validatingPromo
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_outlined),
            label: Text(
              _validatingPromo ? 'Проверяем...' : 'Применить промокод',
            ),
          ),
        ),
        if (offer != null) ...[
          const SizedBox(height: 16),
          _tariffCard(
            context: context,
            plan: offer.tariff,
            disabled: disabled,
            promoCode: offer.code,
            badge: 'Специальный тариф',
            subtitle: 'Детский сад «${offer.kindergartenName}»',
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Тарифы')),
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final data = snapshot.data!;
          final hasSubscription = data.current != null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data.current != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium_rounded),
                    title: Text(data.current!.tariff.title),
                    subtitle: Text(
                      'Статус: ${data.current!.statusLabel}',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              ...data.tariffs.map(
                (plan) => _tariffCard(
                  context: context,
                  plan: plan,
                  disabled: hasSubscription,
                ),
              ),
              const Divider(height: 32),
              _promoSection(disabled: hasSubscription),
            ],
          );
        },
      ),
    );
  }
}

class _Data {
  final List<TariffPlan> tariffs;
  final SubscriptionInfo? current;

  const _Data({
    required this.tariffs,
    required this.current,
  });
}

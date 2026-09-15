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
  int? _processingId;

  @override
  void initState() {
    super.initState();
    _future = _load();
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

  Future<void> _buy(TariffPlan plan) async {
    setState(() => _processingId = plan.id);
    try {
      final sub = await widget.repository.createSubscription(plan.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Тариф оформлен'),
          content: Text(
            'Создана подписка со статусом «${sub.statusLabel}». '
            'Текущий backend пока не подключён к платёжному провайдеру, поэтому реальная оплата и активация выполняются отдельно.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно'))],
        ),
      );
      setState(() {
        _future = _load();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Тарифы')),
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data.current != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium_rounded),
                    title: Text(data.current!.tariff.title),
                    subtitle: Text('Статус: ${data.current!.statusLabel}'),
                  ),
                ),
              const SizedBox(height: 12),
              ...data.tariffs.map((plan) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(plan.description),
                          const SizedBox(height: 10),
                          Text('${plan.price} ${plan.currency} / ${plan.durationDays} дней', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('Профилей детей: до ${plan.maxChildren}'),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: data.current != null || _processingId != null ? null : () => _buy(plan),
                              child: _processingId == plan.id
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Оформить тариф'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
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
  const _Data({required this.tariffs, required this.current});
}

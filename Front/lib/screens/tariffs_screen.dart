import 'package:flutter/material.dart';

import '../data/parent_repository.dart';
import '../models/subscription.dart';
import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';

const bool _fakePaymentsEnabled = bool.fromEnvironment(
  'FAKE_PAYMENTS',
  defaultValue: true,
);

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
        SnackBar(content: Text(context.tr('promoEnter'))),
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
            context.tr('promoApplied', {'name': offer.kindergartenName}),
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

  Future<FakePaymentScenario?> _chooseFakePaymentScenario(
    TariffPlan plan,
  ) {
    return showModalBottomSheet<FakePaymentScenario>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        Widget option({
          required FakePaymentScenario scenario,
          required IconData icon,
          required String subtitle,
          required Color color,
        }) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: .14),
              child: Icon(icon, color: color),
            ),
            title: Text(
              _fakeScenarioTitle(sheetContext, scenario),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(subtitle),
            onTap: () => Navigator.of(sheetContext).pop(scenario),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheetContext.tr('fakePayment'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.title} • ${plan.price} ${plan.currency}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                option(
                  scenario: FakePaymentScenario.success,
                  icon: Icons.check_circle_rounded,
                  subtitle: sheetContext.tr('fakeImmediate'),
                  color: AppColors.primary,
                ),
                option(
                  scenario: FakePaymentScenario.declined,
                  icon: Icons.credit_card_off_rounded,
                  subtitle: sheetContext.tr('fakeDecline'),
                  color: AppColors.coral,
                ),
                option(
                  scenario: FakePaymentScenario.cancelled,
                  icon: Icons.close_rounded,
                  subtitle: sheetContext.tr('fakeCancel'),
                  color: AppColors.purple,
                ),
                option(
                  scenario: FakePaymentScenario.pending,
                  icon: Icons.hourglass_top_rounded,
                  subtitle: sheetContext.tr('fakePending'),
                  color: AppColors.goldDark,
                ),
                option(
                  scenario: FakePaymentScenario.networkError,
                  icon: Icons.wifi_off_rounded,
                  subtitle: sheetContext.tr('fakeError'),
                  color: AppColors.deepBlue,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fakeScenarioTitle(BuildContext context, FakePaymentScenario scenario) {
    switch (scenario) {
      case FakePaymentScenario.success:
        return context.tr('fakeSuccess');
      case FakePaymentScenario.declined:
        return context.tr('paymentDeclined');
      case FakePaymentScenario.cancelled:
        return context.tr('paymentCancelled');
      case FakePaymentScenario.pending:
        return context.tr('paymentPending');
      case FakePaymentScenario.networkError:
        return context.tr('fakePaymentError');
    }
  }

  Future<void> _showFakePaymentResult(FakePaymentResult result) async {
    if (!mounted) return;

    final success = result.result == 'success';
    final pending = result.result == 'pending';
    final title = success
        ? context.tr('fakeSuccess')
        : pending
            ? context.tr('paymentPending')
            : result.result == 'declined'
                ? context.tr('paymentDeclined')
                : result.result == 'cancelled'
                    ? context.tr('paymentCancelled')
                    : context.tr('fakePayment');

    final subscription = result.subscription;
    final period = subscription?.endsAt == null
        ? ''
        : '\nПодписка действует до: '
            '${subscription!.endsAt!.toLocal().toString().split(' ').first}.';

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text('${result.message}$period'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('understood')),
          ),
        ],
      ),
    );
  }

  Future<void> _buy(
    TariffPlan plan, {
    String? promoCode,
  }) async {
    if (_fakePaymentsEnabled) {
      final scenario = await _chooseFakePaymentScenario(plan);
      if (scenario == null || !mounted) return;

      setState(() => _processingId = plan.id);
      try {
        final result = await widget.repository.fakePurchase(
          plan.id,
          promoCode: promoCode,
          scenario: scenario,
        );
        if (!mounted) return;

        await _showFakePaymentResult(result);

        if (result.subscription != null) {
          setState(() {
            _promoOffer = null;
            _promoController.clear();
            _future = _load();
          });
        }
      } catch (e) {
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(context.tr('fakePaymentError')),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('close')),
                ),
              ],
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _processingId = null);
      }
      return;
    }

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
          title: Text(context.tr('planCreated')),
          content: Text(
            context.tr('subscriptionStatusCreated', {'status': AppStrings.subscriptionStatus(context, sub.status)}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('understood')),
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

  Future<void> _resetFakeSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('resetFakeTitle')),
        content: Text(context.tr('resetFakeText')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('reset')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.resetFakeSubscription();
      if (!mounted) return;
      setState(() {
        _promoOffer = null;
        _promoController.clear();
        _future = _load();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('fakeResetDone'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
              context.tr('priceDays', {'price': plan.price, 'currency': plan.currency, 'days': plan.durationDays}),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(context.tr('childrenUpTo', {'count': plan.maxChildren})),
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
                        _fakePaymentsEnabled
                            ? (promoCode == null
                                ? context.tr('fakePayment')
                                : context.tr('fakePromoPayment'))
                            : (promoCode == null
                                ? context.tr('purchasePlan')
                                : context.tr('connectPromo')),
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
          context.tr('kindergartenPromo'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(context.tr('promoHint')),
        const SizedBox(height: 12),
        TextField(
          controller: _promoController,
          enabled: !disabled && !_validatingPromo,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: context.tr('promoExample'),
            prefixIcon: const Icon(Icons.confirmation_number_outlined),
            suffixIcon: _promoController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: context.tr('clear'),
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
              _validatingPromo ? context.tr('checking') : context.tr('applyPromo'),
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
            badge: context.tr('specialPlan'),
            subtitle: context.tr('kindergartenName', {'name': offer.kindergartenName}),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(context.tr('tariffs'))),
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
              if (_fakePaymentsEnabled) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.goldDark.withValues(alpha: .35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.science_rounded, color: AppColors.goldDark),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('fakeModeNotice'),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      if (data.current?.paymentProvider == 'fake') ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _resetFakeSubscription,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: Text(context.tr('resetFakeSubscription')),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (data.current != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium_rounded),
                    title: Text(data.current!.tariff.title),
                    subtitle: Text(
                      context.tr('statusValue', {'status': AppStrings.subscriptionStatus(context, data.current!.status)}),
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

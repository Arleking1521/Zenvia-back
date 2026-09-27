class TariffPlan {
  final int id;
  final String code;
  final String title;
  final String description;
  final String price;
  final String currency;
  final int durationDays;
  final int maxChildren;

  const TariffPlan({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.durationDays,
    required this.maxChildren,
  });
}

class SubscriptionInfo {
  final int id;
  final TariffPlan tariff;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool autoRenew;
  final bool isCurrent;
  final String paymentProvider;
  final String externalPaymentId;

  const SubscriptionInfo({
    required this.id,
    required this.tariff,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.autoRenew,
    required this.isCurrent,
    this.paymentProvider = '',
    this.externalPaymentId = '',
  });

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Активна';
      case 'pending':
        return 'Ожидает оплаты';
      case 'expired':
        return 'Истекла';
      case 'cancelled':
        return 'Отменена';
      default:
        return status;
    }
  }
}


class KindergartenPromoOffer {
  final String code;
  final int kindergartenId;
  final String kindergartenName;
  final TariffPlan tariff;

  const KindergartenPromoOffer({
    required this.code,
    required this.kindergartenId,
    required this.kindergartenName,
    required this.tariff,
  });
}

enum FakePaymentScenario {
  success,
  declined,
  cancelled,
  pending,
  networkError,
}

extension FakePaymentScenarioX on FakePaymentScenario {
  String get apiValue {
    switch (this) {
      case FakePaymentScenario.success:
        return 'success';
      case FakePaymentScenario.declined:
        return 'declined';
      case FakePaymentScenario.cancelled:
        return 'cancelled';
      case FakePaymentScenario.pending:
        return 'pending';
      case FakePaymentScenario.networkError:
        return 'network_error';
    }
  }

  String get title {
    switch (this) {
      case FakePaymentScenario.success:
        return 'Успешная оплата';
      case FakePaymentScenario.declined:
        return 'Отклонено банком';
      case FakePaymentScenario.cancelled:
        return 'Пользователь отменил';
      case FakePaymentScenario.pending:
        return 'Платёж в ожидании';
      case FakePaymentScenario.networkError:
        return 'Ошибка сети';
    }
  }
}

class FakePaymentResult {
  final String result;
  final String message;
  final SubscriptionInfo? subscription;

  const FakePaymentResult({
    required this.result,
    required this.message,
    required this.subscription,
  });
}

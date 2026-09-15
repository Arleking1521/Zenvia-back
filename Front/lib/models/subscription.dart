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

  const SubscriptionInfo({
    required this.id,
    required this.tariff,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.autoRenew,
    required this.isCurrent,
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

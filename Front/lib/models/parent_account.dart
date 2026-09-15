import 'child_profile.dart';
import 'subscription.dart';

class ParentAccount {
  final int id;
  final String email;
  final String firstName;
  final int childrenCount;

  const ParentAccount({
    required this.id,
    required this.email,
    required this.firstName,
    required this.childrenCount,
  });
}

class ChildProfileAccess {
  final bool activeSubscription;
  final int? subscriptionId;
  final int? tariffId;
  final String? tariffTitle;
  final int maxChildren;
  final int activeChildren;
  final int remainingSlots;
  final bool canCreateChild;
  final String? reason;

  const ChildProfileAccess({
    required this.activeSubscription,
    required this.subscriptionId,
    required this.tariffId,
    required this.tariffTitle,
    required this.maxChildren,
    required this.activeChildren,
    required this.remainingSlots,
    required this.canCreateChild,
    required this.reason,
  });
}

class ParentDashboard {
  final ParentAccount parent;
  final List<ChildProfile> children;
  final SubscriptionInfo? subscription;
  final ChildProfileAccess childAccess;

  const ParentDashboard({
    required this.parent,
    required this.children,
    required this.subscription,
    required this.childAccess,
  });
}

import '../models/child_profile.dart';
import '../models/parent_account.dart';
import '../models/registration_option.dart';
import '../models/subscription.dart';

abstract class ParentRepository {
  Future<ParentDashboard> getDashboard();
  Future<List<ChildProfile>> getChildren();
  Future<ChildProfile> getChild(int id);

  Future<List<RegistrationLanguage>> getLanguages();
  Future<List<AvatarOption>> getAvatars();

  Future<ChildProfile> createChild({
    required String name,
    required int baseLanguageId,
    required int avatarId,
  });

  Future<ChildProfile> updateChild({
    required int childId,
    String? name,
    int? baseLanguageId,
    int? avatarId,
  });

  Future<void> archiveChild(int childId);

  Future<void> selectChild(int childId);
  Future<int?> getSelectedChildId();
  Future<void> clearSelectedChild();

  Future<bool> hasParentPin();
  Future<void> setParentPin({
    required String password,
    required String pin,
    required String pinConfirm,
  });
  Future<bool> verifyParentPin(String pin);

  Future<List<TariffPlan>> getTariffs();
  Future<SubscriptionInfo?> getCurrentSubscription();
  Future<SubscriptionInfo> createSubscription(int tariffId);
}

class ParentApiException implements Exception {
  final String message;
  const ParentApiException(this.message);

  @override
  String toString() => message;
}

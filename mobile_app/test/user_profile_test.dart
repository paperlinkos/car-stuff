import 'package:flutter_test/flutter_test.dart';
import 'package:mota_mobile/domain/user_profile.dart';

void main() {
  test('profiles preserve independently activated roles', () {
    final profile = UserProfile.fromMap('u1', {'roles': ['customer', 'owner']});
    expect(profile.canUseOwnerArea, isTrue);
    expect(profile.canUseDriverArea, isFalse);
  });

  test('only owner and driver roles can be requested for activation', () {
    expect(canRequestActivation(AccountRole.customer), isFalse);
    expect(canRequestActivation(AccountRole.owner), isTrue);
    expect(canRequestActivation(AccountRole.driver), isTrue);
  });
}

enum AccountRole { customer, owner, driver }

enum VerificationStatus { notStarted, pending, approved, rejected, expired }

enum AccountStatus { active, suspended, closed }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.roles,
    required this.createdAt,
    required this.updatedAt,
    this.displayName = '',
    this.email,
    this.phoneNumber,
    this.profileImageUrl,
    this.accountStatus = AccountStatus.active,
  });
  final String id;
  final String displayName;
  final String? email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final Set<AccountRole> roles;
  final AccountStatus accountStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool hasRole(AccountRole role) => roles.contains(role);
  bool get canUseOwnerArea => hasRole(AccountRole.owner);
  bool get canUseDriverArea => hasRole(AccountRole.driver);

  factory UserProfile.fromMap(String id, Map<String, dynamic> data) =>
      UserProfile(
        id: id,
        displayName: data['displayName'] as String? ?? '',
        email: data['email'] as String?,
        phoneNumber: data['phoneNumber'] as String?,
        profileImageUrl: data['profileImageUrl'] as String?,
        roles: _rolesFrom(data['roles']),
        accountStatus: _accountStatusFrom(data['accountStatus']),
        createdAt: _dateFrom(data['createdAt']),
        updatedAt: _dateFrom(data['updatedAt']),
      );

  static Set<AccountRole> _rolesFrom(Object? value) {
    final roles = (value as List<dynamic>? ?? const ['customer'])
        .whereType<String>()
        .map((role) => AccountRole.values.where((item) => item.name == role))
        .where((matches) => matches.isNotEmpty)
        .map((matches) => matches.first)
        .toSet();
    return roles.isEmpty ? {AccountRole.customer} : roles;
  }

  static AccountStatus _accountStatusFrom(Object? value) {
    for (final status in AccountStatus.values) {
      if (status.name == value) return status;
    }
    return AccountStatus.active;
  }

  static DateTime _dateFrom(Object? value) {
    if (value is DateTime) return value;
    // Firestore Timestamp intentionally remains dynamic here to keep the domain
    // model independent from the Firebase plugin.
    final dynamic timestamp = value;
    if (timestamp != null && timestamp.toDate is Function) {
      return timestamp.toDate() as DateTime;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

bool canRequestActivation(AccountRole role) =>
    role == AccountRole.owner || role == AccountRole.driver;

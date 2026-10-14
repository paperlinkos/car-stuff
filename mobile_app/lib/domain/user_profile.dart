enum AccountRole { customer, owner, driver }

enum VerificationStatus { notStarted, pending, approved, rejected, expired }

class UserProfile {
  const UserProfile({required this.id, required this.roles, required this.createdAt, required this.updatedAt, this.displayName = '', this.email});
  final String id;
  final String displayName;
  final String? email;
  final Set<AccountRole> roles;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool hasRole(AccountRole role) => roles.contains(role);
  bool get canUseOwnerArea => hasRole(AccountRole.owner);
  bool get canUseDriverArea => hasRole(AccountRole.driver);

  factory UserProfile.fromMap(String id, Map<String, dynamic> data) => UserProfile(
    id: id,
    displayName: data['displayName'] as String? ?? '',
    email: data['email'] as String?,
    roles: ((data['roles'] as List<dynamic>? ?? const ['customer']).whereType<String>().map(AccountRole.values.byName)).toSet(),
    createdAt: data['createdAt'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: data['updatedAt'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

bool canRequestActivation(AccountRole role) => role == AccountRole.owner || role == AccountRole.driver;

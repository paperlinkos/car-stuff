import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../domain/user_profile.dart';

class RoleRequest {
  const RoleRequest({required this.role, required this.status});

  final AccountRole role;
  final VerificationStatus status;

  factory RoleRequest.fromMap(Map<String, dynamic> data) {
    final roleName = data['requestedRole'] as String? ?? '';
    final statusName = data['status'] as String? ?? '';
    AccountRole? role;
    for (final candidate in AccountRole.values) {
      if (candidate.name == roleName) role = candidate;
    }
    var status = VerificationStatus.notStarted;
    for (final candidate in VerificationStatus.values) {
      if (candidate.name == statusName) status = candidate;
    }
    if (role == null || !canRequestActivation(role)) {
      throw const FormatException('Invalid role request.');
    }
    return RoleRequest(role: role, status: status);
  }
}

class ProfileRepository {
  ProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ??
            (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null),
        _functions = functions ??
            (Firebase.apps.isNotEmpty ? FirebaseFunctions.instance : null);

  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  Stream<UserProfile?> watchProfile(String uid) {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(null);
    return firestore.collection('users').doc(uid).snapshots().map((snapshot) =>
        snapshot.exists ? UserProfile.fromMap(uid, snapshot.data()!) : null);
  }

  Stream<List<RoleRequest>> watchRoleRequests(String uid) {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(const <RoleRequest>[]);
    return firestore
        .collection('roleRequests')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RoleRequest.fromMap(doc.data())).toList());
  }

  Future<void> updateProfile({
    required String uid,
    required String displayName,
    String? phoneNumber,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;
    await firestore.collection('users').doc(uid).update({
      'displayName': displayName.trim(),
      'phoneNumber':
          phoneNumber?.trim().isEmpty ?? true ? null : phoneNumber!.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestRole(AccountRole role) async {
    if (!canRequestActivation(role)) {
      throw ArgumentError.value(
          role, 'role', 'Only owner or driver can be requested.');
    }
    final functions = _functions;
    if (functions == null) return;
    await functions
        .httpsCallable('requestRoleActivation')
        .call(<String, String>{'requestedRole': role.name});
  }
}

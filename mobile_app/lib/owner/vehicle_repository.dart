import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import '../domain/vehicle_listing.dart';

class VehicleRepository {
  VehicleRepository(
      {FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ??
            (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null),
        _functions = functions ??
            (Firebase.apps.isNotEmpty ? FirebaseFunctions.instance : null);
  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  Stream<List<VehicleListing>> watchMine(String uid) {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(const <VehicleListing>[]);
    return firestore
        .collection('vehicles')
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => VehicleListing.fromMap(d.id, d.data())).toList());
  }
  Future<String> saveDraft(VehicleListing listing) async {
    final firestore = _firestore;
    if (firestore == null) return listing.id.isEmpty ? 'demo-draft-id' : listing.id;
    final ref = listing.id.isEmpty
        ? firestore.collection('vehicles').doc()
        : firestore.collection('vehicles').doc(listing.id);
    await ref.set({
      ...listing.toDraftMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (listing.id.isEmpty) 'createdAt': FieldValue.serverTimestamp()
    }, SetOptions(merge: listing.id.isNotEmpty));
    return ref.id;
  }

  Future<void> submit(String listingId) async {
    final functions = _functions;
    if (functions == null) return;
    await functions
        .httpsCallable('submitVehicleListing')
        .call({'listingId': listingId});
  }
}

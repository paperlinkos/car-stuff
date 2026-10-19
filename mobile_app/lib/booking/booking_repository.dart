import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'booking.dart';

class BookingRepository {
  BookingRepository(
      {FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ??
            (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null),
        _functions = functions ??
            (Firebase.apps.isNotEmpty ? FirebaseFunctions.instance : null);
  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  Stream<List<Booking>> watchCustomer(String userId) =>
      _watch('customerId', userId);
  Stream<List<Booking>> watchOwner(String userId) => _watch('ownerId', userId);
  Stream<List<Booking>> _watch(String field, String userId) {
    final firestore = _firestore;
    if (firestore == null) return Stream.value(const <Booking>[]);
    return firestore
        .collection('bookings')
        .where(field, isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Booking.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.pickupAt.compareTo(a.pickupAt)));
  }

  Future<void> request({
    required String vehicleId,
    required String rentalMode,
    required String pickupArea,
    required DateTime pickupAt,
    required DateTime returnAt,
    String? pickupNotes,
    String? customerMessage,
    required String idempotencyKey,
  }) async {
    final functions = _functions;
    if (functions == null) return;
    await functions.httpsCallable('createBookingRequest').call({
      'vehicleId': vehicleId,
      'rentalMode': rentalMode,
      'pickupArea': pickupArea,
      'pickupAt': pickupAt.toUtc().toIso8601String(),
      'returnAt': returnAt.toUtc().toIso8601String(),
      'pickupNotes': pickupNotes,
      'customerMessage': customerMessage,
      'idempotencyKey': idempotencyKey,
    });
  }

  Future<void> transition(String bookingId, String action) async {
    final functions = _functions;
    if (functions == null) return;
    await functions
        .httpsCallable('transitionBooking')
        .call({'bookingId': bookingId, 'action': action});
  }
}

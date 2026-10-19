import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'financial_models.dart';

class FinancialRepository {
  FinancialRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ??
            (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null),
        _functions = functions ??
            (Firebase.apps.isNotEmpty ? FirebaseFunctions.instance : null);

  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  Stream<List<PaymentRecord>> watchPaymentsForCustomer(String customerId) {
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value([
        PaymentRecord(
          id: 'demo_pay_1',
          reference: 'mota_demo_ref_101',
          bookingId: 'demo_book_1',
          amountNgn: 180000,
          grossRentalNgn: 180000,
          commissionNgn: 27000,
          depositNgn: 0,
          ownerNetNgn: 153000,
          status: 'successful',
          currency: 'NGN',
          paidAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ]);
    }

    return firestore
        .collection('payments')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentRecord.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => (b.paidAt ?? DateTime.now())
              .compareTo(a.paidAt ?? DateTime.now())));
  }

  Stream<List<PaymentRecord>> watchPaymentsForOwner(String ownerId) {
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value([
        PaymentRecord(
          id: 'demo_pay_owner_1',
          reference: 'mota_demo_owner_ref_1',
          bookingId: 'demo_book_1',
          amountNgn: 180000,
          grossRentalNgn: 180000,
          commissionNgn: 27000,
          depositNgn: 0,
          ownerNetNgn: 153000,
          status: 'successful',
          currency: 'NGN',
          paidAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ]);
    }

    return firestore
        .collection('payments')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentRecord.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => (b.paidAt ?? DateTime.now())
              .compareTo(a.paidAt ?? DateTime.now())));
  }

  Stream<List<PayoutRecord>> watchPayouts(String ownerId) {
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value([
        PayoutRecord(
          id: 'demo_payout_1',
          ownerId: ownerId,
          amountNgn: 150000,
          status: 'completed',
          requestedAt: DateTime.now().subtract(const Duration(days: 5)),
          reviewNote: 'Processed via automated sandbox batch',
        ),
        PayoutRecord(
          id: 'demo_payout_2',
          ownerId: ownerId,
          amountNgn: 80000,
          status: 'requested',
          requestedAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
      ]);
    }

    return firestore
        .collection('payouts')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PayoutRecord.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt)));
  }

  Future<OwnerBalanceSummary> getOwnerBalances(String ownerId) async {
    final functions = _functions;
    if (functions == null) {
      return OwnerBalanceSummary.prototypeDefault;
    }

    final result = await functions
        .httpsCallable('getOwnerFinancialSummary')
        .call({'ownerId': ownerId});
    final data = result.data as Map<String, dynamic>;
    return OwnerBalanceSummary.fromMap(data);
  }

  Future<Map<String, dynamic>> initializePayment({
    required String bookingId,
  }) async {
    final functions = _functions;
    if (functions == null) {
      return {
        'reference': 'demo_pay_ref_${DateTime.now().millisecondsSinceEpoch}',
        'authorizationUrl': 'https://checkout.sandbox.mota.ng/demo',
        'provider': 'sandbox',
        'amountNgn': 150000,
        'isPrototype': true,
      };
    }

    final result = await functions
        .httpsCallable('initializeBookingPayment')
        .call({'bookingId': bookingId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String reference,
  }) async {
    final functions = _functions;
    if (functions == null) {
      return {
        'reference': reference,
        'status': 'successful',
        'amountPaidNgn': 150000,
        'isPrototype': true,
      };
    }

    final result = await functions
        .httpsCallable('verifyPaymentStatus')
        .call({'reference': reference});
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> requestPayout({
    required int amountNgn,
  }) async {
    final functions = _functions;
    if (functions == null) {
      return {
        'payoutId': 'demo_payout_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'requested',
        'amountNgn': amountNgn,
        'isPrototype': true,
      };
    }

    final result = await functions
        .httpsCallable('requestOwnerPayout')
        .call({'amountNgn': amountNgn});
    return Map<String, dynamic>.from(result.data as Map);
  }
}

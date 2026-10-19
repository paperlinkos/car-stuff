import 'package:flutter_test/flutter_test.dart';
import 'package:mota_mobile/financial/financial_models.dart';
import 'package:mota_mobile/financial/financial_repository.dart';

void main() {
  group('Financial Models & Repository', () {
    test('PaymentRecord parses Firestore maps safely', () {
      final payment = PaymentRecord.fromMap('pay_123', {
        'reference': 'mota_ref_123',
        'bookingId': 'book_456',
        'amountNgn': 150000,
        'grossRentalNgn': 120000,
        'platformCommissionNgn': 18000,
        'depositNgn': 30000,
        'ownerNetEarningsNgn': 102000,
        'status': 'successful',
        'currency': 'NGN',
        'reconciliationRequired': false,
      });

      expect(payment.id, 'pay_123');
      expect(payment.reference, 'mota_ref_123');
      expect(payment.amountNgn, 150000);
      expect(payment.grossRentalNgn, 120000);
      expect(payment.commissionNgn, 18000);
      expect(payment.depositNgn, 30000);
      expect(payment.ownerNetNgn, 102000);
      expect(payment.status, 'successful');
    });

    test('OwnerBalanceSummary parses and provides prototype defaults', () {
      final summary = OwnerBalanceSummary.fromMap({
        'ownerId': 'owner_1',
        'totalEarnedNgn': 200000,
        'totalRefundedNgn': 10000,
        'netEarnedNgn': 190000,
        'pendingPayoutNgn': 50000,
        'paidOutNgn': 80000,
        'availableForPayoutNgn': 60000,
      });

      expect(summary.ownerId, 'owner_1');
      expect(summary.netEarnedNgn, 190000);
      expect(summary.availableForPayoutNgn, 60000);

      const proto = OwnerBalanceSummary.prototypeDefault;
      expect(proto.availableForPayoutNgn, 190000);
      expect(proto.totalEarnedNgn, 420000);
    });

    test('FinancialRepository safely handles uninitialized Firebase in prototype mode', () async {
      final repo = FinancialRepository();

      // Streams should yield safely without throwing
      final customerPayments = await repo.watchPaymentsForCustomer('cust_demo').first;
      expect(customerPayments.isNotEmpty, isTrue);
      expect(customerPayments.first.currency, 'NGN');

      final ownerPayments = await repo.watchPaymentsForOwner('owner_demo').first;
      expect(ownerPayments.isNotEmpty, isTrue);

      final payouts = await repo.watchPayouts('owner_demo').first;
      expect(payouts.isNotEmpty, isTrue);

      final balances = await repo.getOwnerBalances('owner_demo');
      expect(balances.availableForPayoutNgn, greaterThan(0));

      final initRes = await repo.initializePayment(bookingId: 'book_demo');
      expect(initRes['isPrototype'], isTrue);
      expect(initRes['reference'], isNotNull);

      final payoutRes = await repo.requestPayout(amountNgn: 50000);
      expect(payoutRes['isPrototype'], isTrue);
      expect(payoutRes['amountNgn'], 50000);
    });
  });
}

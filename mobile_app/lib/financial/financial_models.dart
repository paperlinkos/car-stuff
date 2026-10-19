import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.reference,
    required this.bookingId,
    required this.amountNgn,
    required this.grossRentalNgn,
    required this.commissionNgn,
    required this.depositNgn,
    required this.ownerNetNgn,
    required this.status,
    required this.currency,
    this.authorizationUrl,
    this.paidAt,
    this.reconciliationRequired = false,
    this.reconciliationReason,
  });

  final String id;
  final String reference;
  final String bookingId;
  final int amountNgn;
  final int grossRentalNgn;
  final int commissionNgn;
  final int depositNgn;
  final int ownerNetNgn;
  final String status;
  final String currency;
  final String? authorizationUrl;
  final DateTime? paidAt;
  final bool reconciliationRequired;
  final String? reconciliationReason;

  factory PaymentRecord.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return PaymentRecord(
      id: id,
      reference: data['reference'] as String? ?? id,
      bookingId: data['bookingId'] as String? ?? '',
      amountNgn: (data['amountNgn'] as num?)?.toInt() ?? 0,
      grossRentalNgn: (data['grossRentalNgn'] as num?)?.toInt() ?? 0,
      commissionNgn: (data['platformCommissionNgn'] as num?)?.toInt() ?? 0,
      depositNgn: (data['depositNgn'] as num?)?.toInt() ?? 0,
      ownerNetNgn: (data['ownerNetEarningsNgn'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'pending',
      currency: data['currency'] as String? ?? 'NGN',
      authorizationUrl: data['authorizationUrl'] as String?,
      paidAt: parseDate(data['paidAt']),
      reconciliationRequired: data['reconciliationRequired'] as bool? ?? false,
      reconciliationReason: data['reconciliationReason'] as String?,
    );
  }
}

class OwnerBalanceSummary {
  const OwnerBalanceSummary({
    required this.ownerId,
    required this.totalEarnedNgn,
    required this.totalRefundedNgn,
    required this.netEarnedNgn,
    required this.pendingPayoutNgn,
    required this.paidOutNgn,
    required this.availableForPayoutNgn,
    this.currency = 'NGN',
  });

  final String ownerId;
  final int totalEarnedNgn;
  final int totalRefundedNgn;
  final int netEarnedNgn;
  final int pendingPayoutNgn;
  final int paidOutNgn;
  final int availableForPayoutNgn;
  final String currency;

  factory OwnerBalanceSummary.fromMap(Map<String, dynamic> data) {
    return OwnerBalanceSummary(
      ownerId: data['ownerId'] as String? ?? '',
      totalEarnedNgn: (data['totalEarnedNgn'] as num?)?.toInt() ?? 0,
      totalRefundedNgn: (data['totalRefundedNgn'] as num?)?.toInt() ?? 0,
      netEarnedNgn: (data['netEarnedNgn'] as num?)?.toInt() ?? 0,
      pendingPayoutNgn: (data['pendingPayoutNgn'] as num?)?.toInt() ?? 0,
      paidOutNgn: (data['paidOutNgn'] as num?)?.toInt() ?? 0,
      availableForPayoutNgn: (data['availableForPayoutNgn'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'NGN',
    );
  }

  static const prototypeDefault = OwnerBalanceSummary(
    ownerId: 'demo_owner',
    totalEarnedNgn: 420000,
    totalRefundedNgn: 0,
    netEarnedNgn: 420000,
    pendingPayoutNgn: 80000,
    paidOutNgn: 150000,
    availableForPayoutNgn: 190000,
    currency: 'NGN',
  );
}

class PayoutRecord {
  const PayoutRecord({
    required this.id,
    required this.ownerId,
    required this.amountNgn,
    required this.status,
    required this.requestedAt,
    this.reviewNote,
    this.currency = 'NGN',
  });

  final String id;
  final String ownerId;
  final int amountNgn;
  final String status;
  final DateTime requestedAt;
  final String? reviewNote;
  final String currency;

  factory PayoutRecord.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return PayoutRecord(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      amountNgn: (data['amountNgn'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'requested',
      requestedAt: parseDate(data['requestedAt']),
      reviewNote: data['reviewNote'] as String?,
      currency: data['currency'] as String? ?? 'NGN',
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { requested, accepted, active, declined, cancelled, completed }

class Booking {
  const Booking({
    required this.id,
    required this.status,
    required this.customerId,
    required this.ownerId,
    required this.vehicleId,
    required this.vehicleName,
    required this.rentalMode,
    required this.pickupArea,
    required this.pickupAt,
    required this.returnAt,
    required this.durationDays,
    required this.dailyRateNgn,
    required this.estimateNgn,
    this.customerMessage,
    this.paymentStatus = 'unpaid',
  });
  final String id,
      customerId,
      ownerId,
      vehicleId,
      vehicleName,
      rentalMode,
      pickupArea,
      paymentStatus;
  final BookingStatus status;
  final DateTime pickupAt, returnAt;
  final int durationDays, dailyRateNgn, estimateNgn;
  final String? customerMessage;

  factory Booking.fromMap(String id, Map<String, dynamic> data) {
    final statusName = data['status'] as String? ?? 'requested';
    final status = BookingStatus.values.firstWhere(
        (item) => item.name == statusName,
        orElse: () => BookingStatus.requested);
    final vehicle =
        data['vehicleSnapshot'] as Map<String, dynamic>? ?? const {};
    final pricing = data['pricing'] as Map<String, dynamic>? ?? const {};
    final paymentStatus = data['paymentStatus'] as String? ?? 'unpaid';
    DateTime date(String key) =>
        (data[key] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return Booking(
      id: id,
      status: status,
      customerId: data['customerId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      vehicleId: data['vehicleId'] as String? ?? '',
      vehicleName:
          '${vehicle['make'] ?? 'Vehicle'} ${vehicle['model'] ?? ''}'.trim(),
      rentalMode: data['rentalMode'] as String? ?? '',
      pickupArea: data['pickupArea'] as String? ?? '',
      pickupAt: date('pickupAt'),
      returnAt: date('returnAt'),
      durationDays: pricing['durationDays'] as int? ?? 0,
      dailyRateNgn: pricing['dailyRateNgn'] as int? ?? 0,
      estimateNgn: pricing['estimateNgn'] as int? ?? 0,
      customerMessage: data['customerMessage'] as String?,
      paymentStatus: paymentStatus,
    );
  }
}

int displayDurationDays(DateTime pickup, DateTime returnAt) =>
    ((returnAt.difference(pickup).inMinutes + 1439) ~/ 1440).clamp(0, 31);

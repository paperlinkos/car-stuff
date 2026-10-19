import 'package:flutter_test/flutter_test.dart';
import 'package:mota_mobile/booking/booking.dart';
import 'package:mota_mobile/booking/booking_repository.dart';

void main() {
  test('display duration rounds partial days up for the estimate', () {
    final pickup = DateTime(2026, 10, 20, 10);
    expect(
        displayDurationDays(pickup, pickup.add(const Duration(hours: 2))), 1);
    expect(displayDurationDays(pickup, pickup.add(const Duration(days: 2))), 2);
    expect(
        displayDurationDays(pickup, pickup.subtract(const Duration(hours: 1))),
        0);
    // Upper boundary test: 31 days maximum
    expect(
        displayDurationDays(pickup, pickup.add(const Duration(days: 45))), 31);
  });

  test('BookingRepository safely handles uninitialized Firebase in prototype mode',
      () async {
    final repo = BookingRepository();
    // Streams must return empty lists without throwing
    final customerBookings = await repo.watchCustomer('proto-user').first;
    expect(customerBookings, isEmpty);

    final ownerBookings = await repo.watchOwner('proto-user').first;
    expect(ownerBookings, isEmpty);

    // Mutations must complete safely without throwing
    await expectLater(
        repo.request(
          vehicleId: 'test-v',
          rentalMode: 'selfDrive',
          pickupArea: 'Wuse II',
          pickupAt: DateTime.now().add(const Duration(days: 1)),
          returnAt: DateTime.now().add(const Duration(days: 3)),
          idempotencyKey: 'test-key-1',
        ),
        completes);

    await expectLater(
        repo.transition('test-b', 'cancel'), completes);
  });

  test('Booking model parses map and snapshots safely', () {
    final booking = Booking.fromMap('b-1', {
      'status': 'requested',
      'customerId': 'c-1',
      'ownerId': 'o-1',
      'vehicleId': 'v-1',
      'vehicleSnapshot': {'make': 'Tesla', 'model': 'Model Y'},
      'rentalMode': 'selfDrive',
      'pickupArea': 'Maitama',
      'pricing': {
        'durationDays': 2,
        'dailyRateNgn': 90000,
        'estimateNgn': 180000,
      },
    });

    expect(booking.id, 'b-1');
    expect(booking.status, BookingStatus.requested);
    expect(booking.vehicleName, 'Tesla Model Y');
    expect(booking.durationDays, 2);
    expect(booking.estimateNgn, 180000);
  });
}

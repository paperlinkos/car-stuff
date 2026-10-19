import 'package:flutter_test/flutter_test.dart';
import 'package:mota_mobile/discovery/discovery_repository.dart';
import 'package:mota_mobile/domain/vehicle_listing.dart';

void main() {
  test('discovery exposes only approved listings', () {
    final hidden = VehicleListing(
        id: 'hidden',
        ownerId: 'x',
        make: 'Hidden',
        model: 'Draft',
        year: 2020,
        category: 'SUV',
        transmission: 'Automatic',
        fuelType: 'Petrol',
        seats: 5,
        colour: 'Black',
        registrationNumber: 'x',
        description: 'x',
        rentalMode: 'selfDrive',
        dailyRateNgn: 1,
        minimumRentalDays: 1,
        pickupArea: 'Jabi',
        status: ListingStatus.draft);
    expect(
        filterApproved([...demoVehicles, hidden], const DiscoveryFilters())
            .length,
        demoVehicles.length);
  });
  test('combined filters and empty values behave safely', () {
    final result = filterApproved(
        demoVehicles,
        const DiscoveryFilters(
            keyword: 'toyota',
            category: 'Compact',
            rentalMode: 'selfDrive',
            pickupArea: 'Jabi',
            maximumRate: 50000));
    expect(result.single.model, 'Corolla');
    expect(
        filterApproved(
            demoVehicles, const DiscoveryFilters(keyword: 'not-a-car')),
        isEmpty);
  });
}

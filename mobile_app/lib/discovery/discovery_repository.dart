// ignore_for_file: prefer_interpolation_to_compose_strings

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../domain/vehicle_listing.dart';

class DiscoveryFilters {
  const DiscoveryFilters(
      {this.keyword = '',
      this.category,
      this.rentalMode,
      this.pickupArea,
      this.maximumRate});
  final String keyword;
  final String? category, rentalMode, pickupArea;
  final int? maximumRate;
  bool get active =>
      keyword.isNotEmpty ||
      category != null ||
      rentalMode != null ||
      pickupArea != null ||
      maximumRate != null;
}

List<VehicleListing> filterApproved(
    List<VehicleListing> listings, DiscoveryFilters f) {
  final key = f.keyword.toLowerCase();
  return listings
      .where((v) =>
          v.status == ListingStatus.approved &&
          (key.isEmpty ||
              (v.make + ' ' + v.model).toLowerCase().contains(key) ||
              v.category.toLowerCase().contains(key)) &&
          (f.category == null ||
              f.category == 'All' ||
              v.category.toLowerCase() == f.category!.toLowerCase()) &&
          (f.rentalMode == null ||
              v.rentalMode == f.rentalMode ||
              v.rentalMode == 'both') &&
          (f.pickupArea == null || v.pickupArea == f.pickupArea) &&
          (f.maximumRate == null || v.dailyRateNgn <= f.maximumRate!))
      .toList();
}

class DiscoveryRepository {
  DiscoveryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ??
            (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null);
  final FirebaseFirestore? _firestore;

  Stream<List<VehicleListing>> approved() {
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value(demoVehicles);
    }
    return firestore
        .collection('vehicles')
        .where('status', isEqualTo: 'approved')
        .limit(40)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => VehicleListing.fromMap(d.id, d.data())).toList());
  }
}

final demoVehicles = <VehicleListing>[
  const VehicleListing(
      id: 'demo-tesla-y',
      ownerId: 'demo',
      make: 'Tesla',
      model: 'Model Y',
      year: 2023,
      category: 'Electric',
      transmission: 'Automatic',
      fuelType: 'Electric',
      seats: 5,
      colour: 'Pearl White',
      registrationNumber: 'DEMO-TSL',
      description:
          'Long Range all-wheel drive, autopilot, premium white vegan leather interior.',
      rentalMode: 'selfDrive',
      dailyRateNgn: 90000,
      minimumRentalDays: 1,
      pickupArea: 'Maitama',
      status: ListingStatus.approved,
      photoPaths: [
        'https://images.unsplash.com/photo-1560958089-b8a1929cea89?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=900&q=80',
      ]),
  const VehicleListing(
      id: 'demo-mercedes-g',
      ownerId: 'demo',
      make: 'Mercedes-Benz',
      model: 'G-Class',
      year: 2023,
      category: 'SUV',
      transmission: 'Automatic',
      fuelType: 'Petrol',
      seats: 5,
      colour: 'Obsidian Black',
      registrationNumber: 'DEMO-AMG',
      description:
          'Iconic luxury G-Wagon, 4.0L Bi-Turbo V8, executive comfort and commanding presence.',
      rentalMode: 'both',
      dailyRateNgn: 180000,
      minimumRentalDays: 1,
      pickupArea: 'Wuse II',
      status: ListingStatus.approved,
      photoPaths: [
        'https://images.unsplash.com/photo-1520050206274-a1ae44613e6d?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1580273916550-e323be2ae537?auto=format&fit=crop&w=900&q=80',
      ]),
  const VehicleListing(
      id: 'demo-range-rover',
      ownerId: 'demo',
      make: 'Range Rover',
      model: 'Sport HSE',
      year: 2023,
      category: 'SUV',
      transmission: 'Automatic',
      fuelType: 'Petrol',
      seats: 5,
      colour: 'Carpathian Grey',
      registrationNumber: 'DEMO-RR',
      description:
          'Dynamic luxury SUV with Meridian sound system, panoramic glass roof and adaptive air suspension.',
      rentalMode: 'both',
      dailyRateNgn: 160000,
      minimumRentalDays: 1,
      pickupArea: 'Maitama',
      status: ListingStatus.approved,
      photoPaths: [
        'https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?auto=format&fit=crop&w=900&q=80',
      ]),
  const VehicleListing(
      id: 'demo-porsche-taycan',
      ownerId: 'demo',
      make: 'Porsche',
      model: 'Taycan 4S',
      year: 2023,
      category: 'Electric',
      transmission: 'Automatic',
      fuelType: 'Electric',
      seats: 4,
      colour: 'Frozen Metallic',
      registrationNumber: 'DEMO-TYC',
      description:
          'Pure sports car excitement with zero emissions, launch control and luxury cockpit.',
      rentalMode: 'selfDrive',
      dailyRateNgn: 150000,
      minimumRentalDays: 1,
      pickupArea: 'Central Business District',
      status: ListingStatus.approved,
      photoPaths: [
        'https://images.unsplash.com/photo-1614162692292-7ac56d7f7f1e?auto=format&fit=crop&w=900&q=80',
      ]),
  const VehicleListing(
      id: 'demo-sedan',
      ownerId: 'demo',
      make: 'Lexus',
      model: 'ES 350',
      year: 2021,
      category: 'Sedan',
      transmission: 'Automatic',
      fuelType: 'Petrol',
      seats: 5,
      colour: 'Black',
      registrationNumber: 'DEMO-LEX',
      description:
          'Illustrative executive sedan for city and airport journeys with chauffeur option.',
      rentalMode: 'both',
      dailyRateNgn: 85000,
      minimumRentalDays: 1,
      pickupArea: 'Wuse II',
      status: ListingStatus.approved,
      photoPaths: [
        'https://images.unsplash.com/photo-1550355291-bbee04a92027?auto=format&fit=crop&w=900&q=80',
      ]),
  const VehicleListing(
      id: 'demo-suv',
      ownerId: 'demo',
      make: 'Toyota',
      model: 'Land Cruiser',
      year: 2022,
      category: 'SUV',
      transmission: 'Automatic',
      fuelType: 'Petrol',
      seats: 7,
      colour: 'White',
      registrationNumber: 'DEMO-TLC',
      description: 'Illustrative premium SUV with chauffeur option.',
      rentalMode: 'chauffeur',
      dailyRateNgn: 140000,
      minimumRentalDays: 1,
      pickupArea: 'Airport handover',
      status: ListingStatus.approved,
      photoPaths: [
        'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=900&q=80',
      ]),
  const VehicleListing(
      id: 'demo-compact',
      ownerId: 'demo',
      make: 'Toyota',
      model: 'Corolla',
      year: 2020,
      category: 'Compact',
      transmission: 'Automatic',
      fuelType: 'Petrol',
      seats: 5,
      colour: 'Silver',
      registrationNumber: 'DEMO',
      description: 'Illustrative compact for everyday Abuja travel.',
      rentalMode: 'selfDrive',
      dailyRateNgn: 45000,
      minimumRentalDays: 2,
      pickupArea: 'Jabi',
      status: ListingStatus.approved,
      photoPaths: [
        'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?auto=format&fit=crop&w=900&q=80',
      ]),
];

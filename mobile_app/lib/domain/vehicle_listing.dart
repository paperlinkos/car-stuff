enum ListingStatus {
  draft,
  submitted,
  underReview,
  changesRequested,
  approved,
  rejected,
  suspended
}

class VehicleListing {
  const VehicleListing(
      {required this.id,
      required this.ownerId,
      required this.make,
      required this.model,
      required this.year,
      required this.category,
      required this.transmission,
      required this.fuelType,
      required this.seats,
      required this.colour,
      required this.registrationNumber,
      required this.description,
      required this.rentalMode,
      required this.dailyRateNgn,
      required this.minimumRentalDays,
      required this.pickupArea,
      required this.status,
      this.photoPaths = const [],
      this.reviewNote});
  final String id,
      ownerId,
      make,
      model,
      category,
      transmission,
      fuelType,
      colour,
      registrationNumber,
      description,
      rentalMode,
      pickupArea;
  final int year, seats, dailyRateNgn, minimumRentalDays;
  final ListingStatus status;
  final List<String> photoPaths;
  final String? reviewNote;
  factory VehicleListing.fromMap(String id, Map<String, dynamic> data) {
    var status = ListingStatus.draft;
    for (final candidate in ListingStatus.values) {
      if (candidate.name == data['status']) status = candidate;
    }
    return VehicleListing(
        id: id,
        ownerId: data['ownerId'] as String? ?? '',
        make: data['make'] as String? ?? '',
        model: data['model'] as String? ?? '',
        year: data['year'] as int? ?? 0,
        category: data['category'] as String? ?? '',
        transmission: data['transmission'] as String? ?? '',
        fuelType: data['fuelType'] as String? ?? '',
        seats: data['seats'] as int? ?? 0,
        colour: data['colour'] as String? ?? '',
        registrationNumber: data['registrationNumber'] as String? ?? '',
        description: data['description'] as String? ?? '',
        rentalMode: data['rentalMode'] as String? ?? '',
        dailyRateNgn: data['dailyRateNgn'] as int? ?? 0,
        minimumRentalDays: data['minimumRentalDays'] as int? ?? 1,
        pickupArea: data['pickupArea'] as String? ?? '',
        photoPaths: (data['photoPaths'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        status: status,
        reviewNote: data['reviewNote'] as String?);
  }
  Map<String, dynamic> toDraftMap() => {
        'ownerId': ownerId,
        'make': make.trim(),
        'model': model.trim(),
        'year': year,
        'category': category,
        'transmission': transmission,
        'fuelType': fuelType,
        'seats': seats,
        'colour': colour.trim(),
        'registrationNumber': registrationNumber.trim(),
        'description': description.trim(),
        'rentalMode': rentalMode,
        'dailyRateNgn': dailyRateNgn,
        'minimumRentalDays': minimumRentalDays,
        'pickupArea': pickupArea,
        'photoPaths': photoPaths,
        'status': status.name
      };
}

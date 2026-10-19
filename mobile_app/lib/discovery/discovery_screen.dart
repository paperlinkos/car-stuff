// ignore_for_file: prefer_interpolation_to_compose_strings

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../booking/booking_screens.dart';
import '../domain/vehicle_listing.dart';
import 'discovery_repository.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final repository = DiscoveryRepository();
  String keyword = '';
  String? category, mode, area;
  int? cap;
  bool low = true;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('DISCOVER')),
      body: StreamBuilder<List<VehicleListing>>(
          stream: repository.approved(),
          builder: (_, snap) {
            final live = snap.data ?? const <VehicleListing>[];
            final demo = live.isEmpty;
            final result = filterApproved(
                demo ? demoVehicles : live,
                DiscoveryFilters(
                    keyword: keyword,
                    category: category,
                    rentalMode: mode,
                    pickupArea: area,
                    maximumRate: cap))
              ..sort((a, b) => low
                  ? a.dailyRateNgn.compareTo(b.dailyRateNgn)
                  : b.dailyRateNgn.compareTo(a.dailyRateNgn));
            return ListView(padding: const EdgeInsets.all(20), children: [
              const Text('Find your fit.',
                  style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 34,
                      fontWeight: FontWeight.w600)),
              if (demo)
                const Text(
                    'DEMO VEHICLES · Not live inventory or bookable availability.',
                    style: TextStyle(
                        color: Color(0xff008751),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                  onChanged: (v) => setState(() => keyword = v),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search make or model')),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                chip('SUV', () => category = 'SUV'),
                chip('Self-drive', () => mode = 'selfDrive'),
                chip('With driver', () => mode = 'chauffeur'),
                chip('Wuse II', () => area = 'Wuse II'),
                chip('≤ ₦90k', () => cap = 90000),
                ActionChip(
                    label: const Text('Clear'),
                    onPressed: () => setState(() {
                          keyword = '';
                          category = null;
                          mode = null;
                          area = null;
                          cap = null;
                        })),
                ActionChip(
                    label: Text(low ? 'Low price' : 'High price'),
                    onPressed: () => setState(() => low = !low))
              ]),
              const SizedBox(height: 16),
              if (snap.hasError)
                const Text(
                    'Live inventory could not load; showing labelled demo data.'),
              if (result.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                        child: Text(
                            'No approved vehicles match. Clear filters and try again.'))),
              ...result.map((v) => card(v, demo)),
            ]);
          }));
  Widget chip(String label, VoidCallback action) =>
      ActionChip(label: Text(label), onPressed: () => setState(action));
  Widget card(VehicleListing v, bool demo) => Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => VehicleDetail(vehicle: v, demo: demo))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
                aspectRatio: 16 / 8,
                child: v.photoPaths.isEmpty
                    ? const ColoredBox(
                        color: Color(0xffe5e9e4),
                        child:
                            Center(child: Icon(Icons.directions_car_outlined)))
                    : Image.network(v.photoPaths.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xffe5e9e4),
                            child: Center(
                                child: Icon(Icons.directions_car_outlined))))),
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.make + ' ' + v.model,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 17)),
                      Text(v.year.toString() +
                          ' · ' +
                          v.category +
                          ' · ' +
                          v.pickupArea),
                      const SizedBox(height: 6),
                      Text(
                          v.rentalMode +
                              ' · From ₦' +
                              v.dailyRateNgn.toString() +
                              ' / day',
                          style: const TextStyle(
                              color: Color(0xff008751),
                              fontWeight: FontWeight.w700))
                    ]))
          ])));
}

class VehicleDetail extends StatelessWidget {
  const VehicleDetail({super.key, required this.vehicle, required this.demo});
  final VehicleListing vehicle;
  final bool demo;
  static const _authenticationEnabled = bool.fromEnvironment('ENABLE_AUTH');
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(vehicle.make + ' ' + vehicle.model)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (demo)
          const Text('ILLUSTRATIVE DEMO LISTING · Not available to book',
              style: TextStyle(
                  color: Color(0xff008751),
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        AspectRatio(
            aspectRatio: 16 / 9,
            child: vehicle.photoPaths.isEmpty
                ? const ColoredBox(color: Color(0xffe5e9e4))
                : Image.network(vehicle.photoPaths.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xffe5e9e4),
                        child: Icon(Icons.directions_car_outlined)))),
        const SizedBox(height: 18),
        Text('From ₦' + vehicle.dailyRateNgn.toString() + ' / day',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(vehicle.description),
        const SizedBox(height: 16),
        Text(vehicle.seats.toString() +
            ' seats · ' +
            vehicle.transmission +
            ' · ' +
            vehicle.fuelType +
            ' · ' +
            vehicle.colour),
        Text('Pickup: ' + vehicle.pickupArea + ' · ' + vehicle.rentalMode),
        const SizedBox(height: 18),
        if (!demo &&
            _authenticationEnabled &&
            FirebaseAuth.instance.currentUser != null)
          FilledButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BookingRequestScreen(vehicle: vehicle))),
              child: const Text('Request this vehicle'))
        else
          const Text(
              'Booking requests require an authenticated customer account and an approved live listing.'),
        const SizedBox(height: 12),
        const Text(
            'Published status does not confirm date-specific availability, insurance, roadworthiness or a booking.')
      ]));
}

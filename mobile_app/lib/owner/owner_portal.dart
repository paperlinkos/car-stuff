import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../domain/vehicle_listing.dart';
import 'vehicle_repository.dart';
import '../booking/booking_screens.dart';
import '../financial/financial_screens.dart';

class OwnerPortal extends StatelessWidget {
  const OwnerPortal({super.key, required this.user});
  final User user;
  @override
  Widget build(BuildContext context) {
    final repository = VehicleRepository();
    return Scaffold(
        appBar: AppBar(title: const Text('OWNER PORTAL')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        VehicleForm(user: user, repository: repository))),
            label: const Text('Add vehicle'),
            icon: const Icon(Icons.add)),
        body: StreamBuilder<List<VehicleListing>>(
            stream: repository.watchMine(user.uid),
            builder: (_, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                    child: Text(
                        'Listings could not load. Check your secure account setup.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!;
              return ListView(padding: const EdgeInsets.all(24), children: [
                const Text('List with care.',
                    style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 34,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text(
                    'Submissions require administrator review. Completing this form does not verify you, your vehicle, insurance or roadworthiness.'),
                const Card(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Owner onboarding · 1 of 3',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            SizedBox(height: 8),
                            LinearProgressIndicator(value: .33),
                            SizedBox(height: 10),
                            Text(
                                'Review contact details, add vehicle information, then provide protected review documents.')
                          ])),
                ),
                const SizedBox(height: 18),
                OutlinedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BookingListScreen(
                                userId: user.uid, owner: true))),
                    child: const Text('Review booking requests')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('Financial Workspace & Payouts'),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                OwnerFinancialWorkspaceScreen(ownerId: user.uid)))),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Card(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                              'No drafts yet. Add your first vehicle when ready.')))
                else
                  ...items.map((item) => Card(
                      child: ListTile(
                          title: Text('${item.make} ${item.model}'),
                          subtitle: Text(item.status.name +
                              (item.reviewNote == null
                                  ? ''
                                  : ' · ${item.reviewNote!}')),
                          trailing: (item.status == ListingStatus.draft ||
                                  item.status == ListingStatus.changesRequested)
                              ? TextButton(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => VehicleForm(
                                              user: user,
                                              repository: repository,
                                              existing: item))),
                                  child: const Text('Edit'))
                              : null))),
              ]);
            }));
  }
}

class VehicleForm extends StatefulWidget {
  const VehicleForm(
      {super.key, required this.user, required this.repository, this.existing});
  final User user;
  final VehicleRepository repository;
  final VehicleListing? existing;
  @override
  State<VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<VehicleForm> {
  final form = GlobalKey<FormState>();
  var step = 0;
  var busy = false;
  String? message;
  final photos = <String>[];
  late final make = TextEditingController(text: widget.existing?.make);
  late final model = TextEditingController(text: widget.existing?.model);
  late final year =
      TextEditingController(text: widget.existing?.year.toString());
  late final seats =
      TextEditingController(text: widget.existing?.seats.toString());
  late final colour = TextEditingController(text: widget.existing?.colour);
  late final registration =
      TextEditingController(text: widget.existing?.registrationNumber);
  late final description =
      TextEditingController(text: widget.existing?.description);
  late final rate =
      TextEditingController(text: widget.existing?.dailyRateNgn.toString());
  late final minimum = TextEditingController(
      text: widget.existing?.minimumRentalDays.toString() ?? '1');
  String category = 'SUV',
      transmission = 'Automatic',
      fuel = 'Petrol',
      rental = 'selfDrive',
      pickup = 'Wuse II';
  @override
  void initState() {
    super.initState();
    photos.addAll(widget.existing?.photoPaths ?? []);
  }

  @override
  void dispose() {
    for (final c in [
      make,
      model,
      year,
      seats,
      colour,
      registration,
      description,
      rate,
      minimum
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  VehicleListing current() => VehicleListing(
      id: widget.existing?.id ?? '',
      ownerId: widget.user.uid,
      make: make.text,
      model: model.text,
      year: int.tryParse(year.text) ?? 0,
      category: category,
      transmission: transmission,
      fuelType: fuel,
      seats: int.tryParse(seats.text) ?? 0,
      colour: colour.text,
      registrationNumber: registration.text,
      description: description.text,
      rentalMode: rental,
      dailyRateNgn: int.tryParse(rate.text) ?? 0,
      minimumRentalDays: int.tryParse(minimum.text) ?? 1,
      pickupArea: pickup,
      photoPaths: photos,
      status: widget.existing?.status == ListingStatus.changesRequested
          ? ListingStatus.changesRequested
          : ListingStatus.draft);
  Future<void> save(bool submit) async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      final id = await widget.repository.saveDraft(current());
      if (submit) await widget.repository.submit(id);
      if (mounted) {
        setState(() => message =
            submit ? 'Submitted for administrator review.' : 'Draft saved.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = submit
            ? 'Submission needs required protected documents and Firebase backend setup.'
            : 'Draft could not be saved.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title:
              Text(widget.existing == null ? 'Add vehicle' : 'Edit vehicle')),
      body: Form(
          key: form,
          child: Stepper(
              currentStep: step,
              onStepContinue: () => setState(() => step < 3 ? step++ : step),
              onStepCancel: () =>
                  setState(() => step = step > 0 ? step - 1 : 0),
              steps: [
                Step(
                    title: const Text('Vehicle details'),
                    content: Column(children: [
                      field(make, 'Make'),
                      field(model, 'Model'),
                      field(year, 'Model year', number: true),
                      select(
                          'Category',
                          category,
                          ['SUV', 'Sedan', 'Compact', 'Luxury'],
                          (v) => setState(() => category = v!)),
                      select(
                          'Transmission',
                          transmission,
                          ['Automatic', 'Manual'],
                          (v) => setState(() => transmission = v!)),
                      select(
                          'Fuel type',
                          fuel,
                          ['Petrol', 'Diesel', 'Hybrid', 'Electric'],
                          (v) => setState(() => fuel = v!)),
                      field(seats, 'Seating capacity', number: true),
                      field(colour, 'Colour'),
                      field(registration, 'Registration number'),
                      field(description, 'General description', lines: 3)
                    ])),
                Step(
                    title: const Text('Rental and availability'),
                    content: Column(children: [
                      select(
                          'Rental option',
                          rental,
                          ['selfDrive', 'chauffeur', 'both'],
                          (v) => setState(() => rental = v!)),
                      field(rate, 'Indicative daily rate (NGN)', number: true),
                      field(minimum, 'Minimum rental days', number: true),
                      select(
                          'Pickup area',
                          pickup,
                          [
                            'Wuse II',
                            'Jabi',
                            'Maitama',
                            'Gwarinpa',
                            'Airport handover'
                          ],
                          (v) => setState(() => pickup = v!)),
                      const Text(
                          'This is the owner-entered rate only. Platform fees and customer totals are not calculated.')
                    ])),
                Step(
                    title: const Text('Photos'),
                    content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'Local prototype: Firebase Storage is not configured, so these are not uploaded images.'),
                          Wrap(
                              children: photos
                                  .map((p) => Chip(
                                      label: Text(p),
                                      onDeleted: () =>
                                          setState(() => photos.remove(p))))
                                  .toList()),
                          OutlinedButton(
                              onPressed: () => setState(() => photos.add(
                                  'local-preview-${photos.length + 1}.jpg')),
                              child: const Text('Add local photo preview')),
                          const Text(
                              'JPEG, PNG or WebP up to 10 MB will be required before live upload. The first photo is the cover.')
                        ])),
                const Step(
                    title: Text('Review requirements'),
                    content: Text(
                        'Required private checklist: ownership or authorization evidence and vehicle registration documentation. Upload is unavailable until protected Firebase Storage is configured. Documents do not establish insurance, roadworthiness or legal compliance.')),
              ])),
      bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (message != null) Text(message!),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: busy ? null : () => save(false),
                      child: const Text('Save draft'))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton(
                      onPressed: busy ? null : () => save(true),
                      child: Text(busy ? 'Working…' : 'Submit for review'))),
            ]),
          ])));
  Widget field(TextEditingController c, String label,
          {bool number = false, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
              controller: c,
              maxLines: lines,
              keyboardType: number ? TextInputType.number : null,
              decoration: InputDecoration(labelText: label),
              validator: requiredText));
  Widget select(String label, String value, List<String> items,
          ValueChanged<String?> change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField(
              initialValue: value,
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: change,
              decoration: InputDecoration(labelText: label)));
}

import 'package:flutter/material.dart';
import '../domain/vehicle_listing.dart';
import '../financial/financial_repository.dart';
import 'booking.dart';
import 'booking_repository.dart';

String formatNgn(int value) =>
    '₦${value.toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (m) => ',')}';
String formatBookingDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')} WAT';

class BookingRequestScreen extends StatefulWidget {
  const BookingRequestScreen({super.key, required this.vehicle});
  final VehicleListing vehicle;
  @override
  State<BookingRequestScreen> createState() => _BookingRequestScreenState();
}

class _BookingRequestScreenState extends State<BookingRequestScreen> {
  final form = GlobalKey<FormState>();
  final area = TextEditingController();
  final notes = TextEditingController();
  final message = TextEditingController();
  late String mode;
  late DateTime pickup;
  late DateTime returnAt;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    mode = widget.vehicle.rentalMode == 'chauffeur' ? 'chauffeur' : 'selfDrive';
    area.text = widget.vehicle.pickupArea;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    pickup = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10);
    returnAt =
        pickup.add(Duration(days: widget.vehicle.minimumRentalDays, hours: 2));
  }

  @override
  void dispose() {
    area.dispose();
    notes.dispose();
    message.dispose();
    super.dispose();
  }

  List<String> get modes => widget.vehicle.rentalMode == 'both'
      ? const ['selfDrive', 'chauffeur']
      : [widget.vehicle.rentalMode];
  int get days => displayDurationDays(pickup, returnAt);
  int get estimate => days * widget.vehicle.dailyRateNgn;

  Future<void> chooseDate(bool isPickup) async {
    final current = isPickup ? pickup : returnAt;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current.hour, minute: current.minute));
    if (time == null) return;
    setState(() {
      final next = DateTime(
          selected.year, selected.month, selected.day, time.hour, time.minute);
      if (isPickup) {
        pickup = next;
      } else {
        returnAt = next;
      }
    });
  }

  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    if (!pickup.isAfter(DateTime.now()) ||
        !returnAt.isAfter(pickup) ||
        days < widget.vehicle.minimumRentalDays ||
        days > 31) {
      setState(() => error =
          'Choose a future return after pickup, from ${widget.vehicle.minimumRentalDays} to 31 rental days.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await BookingRepository().request(
        vehicleId: widget.vehicle.id,
        rentalMode: mode,
        pickupArea: area.text,
        pickupAt: pickup,
        returnAt: returnAt,
        pickupNotes: notes.text,
        customerMessage: message.text,
        idempotencyKey: '${DateTime.now().microsecondsSinceEpoch}',
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'We could not send this request. Check your secure account and try again.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('REQUEST BOOKING')),
        body: Form(
            key: form,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Text('${widget.vehicle.make} ${widget.vehicle.model}',
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                  'A request is not confirmed, reserved or paid until the owner accepts it under the platform rules.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'Rental mode'),
                  items: modes
                      .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item == 'selfDrive'
                              ? 'Self-drive'
                              : 'Chauffeur-driven')))
                      .toList(),
                  onChanged: (value) => setState(() => mode = value!)),
              const SizedBox(height: 12),
              _DateLine(
                  label: 'Pickup',
                  value: formatBookingDate(pickup),
                  onTap: () => chooseDate(true)),
              _DateLine(
                  label: 'Return',
                  value: formatBookingDate(returnAt),
                  onTap: () => chooseDate(false)),
              TextFormField(
                  controller: area,
                  decoration: const InputDecoration(labelText: 'Pickup area'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Pickup area is required'
                      : null),
              TextFormField(
                  controller: notes,
                  maxLength: 500,
                  decoration: const InputDecoration(
                      labelText: 'Pickup notes (optional)')),
              TextFormField(
                  controller: message,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                      labelText: 'Message to owner (optional)')),
              const SizedBox(height: 12),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Indicative estimate',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            Text(
                                '$days day(s) × ${formatNgn(widget.vehicle.dailyRateNgn)} = ${formatNgn(estimate)}'),
                            const SizedBox(height: 6),
                            const Text(
                                'Estimate only. No fees, deposit, payment, insurance or final total is included.'),
                          ]))),
              if (mode == 'selfDrive')
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                        'Licence checks, eligibility, handover and any required deposit remain subject to future operational policy.')),
              if (mode == 'chauffeur')
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                        'Driver assignment and trip confirmation are not yet implemented or guaranteed.')),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.red))),
              const SizedBox(height: 18),
              FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'Sending…' : 'Send booking request')),
            ])),
      );
}

class BookingListScreen extends StatelessWidget {
  const BookingListScreen(
      {super.key, required this.userId, required this.owner});
  final String userId;
  final bool owner;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(owner ? 'BOOKING REQUESTS' : 'YOUR BOOKINGS')),
        body: StreamBuilder<List<Booking>>(
          stream: owner
              ? BookingRepository().watchOwner(userId)
              : BookingRepository().watchCustomer(userId),
          builder: (_, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                  child: Text('Booking requests could not load.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const Center(child: Text('No booking requests yet.'));
            }
            return ListView(
                padding: const EdgeInsets.all(16),
                children: items
                    .map((item) => _BookingCard(booking: item, owner: owner))
                    .toList());
          },
        ),
      );
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.owner});
  final Booking booking;
  final bool owner;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(booking.vehicleName,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            Text(
                '${booking.status.name.toUpperCase()} · ${booking.rentalMode}'),
            const SizedBox(height: 6),
            Text(
                '${formatBookingDate(booking.pickupAt)} → ${formatBookingDate(booking.returnAt)}'),
            Text(
                '${booking.pickupArea} · ${booking.durationDays} day(s) · Estimate ${formatNgn(booking.estimateNgn)}'),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: booking.paymentStatus == 'paid'
                        ? const Color(0xFFE9F5ED)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PAYMENT: ${booking.paymentStatus.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: booking.paymentStatus == 'paid'
                          ? const Color(0xFF13382C)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (booking.status == BookingStatus.requested)
              Wrap(spacing: 8, children: [
                if (owner) ...[
                  OutlinedButton(
                      onPressed: () =>
                          BookingRepository().transition(booking.id, 'decline'),
                      child: const Text('Decline')),
                  FilledButton(
                      onPressed: () =>
                          BookingRepository().transition(booking.id, 'accept'),
                      child: const Text('Accept request')),
                ] else
                  OutlinedButton(
                      onPressed: () =>
                          BookingRepository().transition(booking.id, 'cancel'),
                      child: const Text('Cancel request')),
              ]),
            if (booking.status == BookingStatus.accepted &&
                !owner &&
                booking.paymentStatus != 'paid')
              FilledButton.icon(
                onPressed: () async {
                  final scaffold = ScaffoldMessenger.of(context);
                  try {
                    final res = await FinancialRepository()
                        .initializePayment(bookingId: booking.id);
                    scaffold.showSnackBar(
                      SnackBar(
                        content: Text(
                            'Sandbox checkout initialized for ${booking.vehicleName}. Ref: ${res['reference']}'),
                      ),
                    );
                    await FinancialRepository()
                        .verifyPayment(reference: res['reference']);
                    scaffold.showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Sandbox payment verified! Ledger entries recorded.'),
                      ),
                    );
                  } catch (e) {
                    scaffold.showSnackBar(
                      SnackBar(content: Text('Payment initiation failed: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.payment, size: 16),
                label: const Text('Pay with Sandbox Checkout'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF13382C),
                ),
              ),
          ])));
}

class _DateLine extends StatelessWidget {
  const _DateLine(
      {required this.label, required this.value, required this.onTap});
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.calendar_month),
      onTap: onTap);
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth/auth_gate.dart';
import 'customer/customer_home_screen.dart';
import 'financial/financial_screens.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The product walkthrough is deliberately the default while the marketplace
  // is being built. Authentication can be enabled later without removing the
  // real Firebase-backed flow: flutter run --dart-define=ENABLE_AUTH=true
  const enableAuthentication = bool.fromEnvironment('ENABLE_AUTH');
  const useFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  if (enableAuthentication) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    if (useFirebaseEmulators) {
      // iOS Simulator resolves localhost through IPv6 on some machines while
      // the Firebase emulators listen on IPv4. Keep the local development
      // connection explicit and entirely off the cloud project.
      FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
      FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
    }
  }
  runApp(MotaApp(
    authState:
        enableAuthentication ? FirebaseAuth.instance.authStateChanges() : null,
  ));
}

class MotaApp extends StatelessWidget {
  const MotaApp({super.key, this.authState});
  final Stream<User?>? authState;
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xff008751))),
        home: authState == null
            ? const RoleDemo()
            : AuthGate(authState: authState!),
      );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    const CircleAvatar(
                        radius: 26,
                        backgroundColor: Color(0xff008751),
                        child: Text('M',
                            style: TextStyle(
                                fontFamily: 'serif',
                                color: Colors.white,
                                fontSize: 28))),
                    const SizedBox(height: 28),
                    const Text('Move through Abuja\non your own terms.',
                        style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 38,
                            height: 1.08,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    const Text(
                        'A considerate way to access and share exceptional vehicles.'),
                    const SizedBox(height: 36),
                    FilledButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RoleDemo())),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54)),
                        child: const Text('Explore the prototype')),
                    const SizedBox(height: 10),
                    const SizedBox(height: 13),
                    const Center(
                        child: Text(
                            'Demo catalogue · No booking or payment is live',
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey))),
                    const Spacer(),
                  ]))));
}

class RoleDemo extends StatefulWidget {
  const RoleDemo({super.key});
  @override
  State<RoleDemo> createState() => _RoleDemoState();
}

class _RoleDemoState extends State<RoleDemo> {
  int index = 0;
  final tabs = ['Customer', 'Owner', 'Driver'];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xffe9f5ed),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text(
                'LOCAL PROTOTYPE · NO ACCOUNT REQUIRED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff175d3b),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _roleChip(0, 'Customer', Icons.directions_car_rounded),
                  const SizedBox(width: 8),
                  _roleChip(1, 'Owner', Icons.car_rental_rounded),
                  const SizedBox(width: 8),
                  _roleChip(2, 'Driver', Icons.badge_outlined),
                ],
              ),
            ),
            Expanded(
              child: index == 0
                  ? CustomerHomeScreen(
                      onSwitchToOwner: () => setState(() => index = 1),
                      onSwitchToDriver: () => setState(() => index = 2),
                    )
                  : index == 1
                      ? const OwnerPreview()
                      : const DriverPreview(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(int tabIndex, String label, IconData icon) {
    final active = index == tabIndex;
    return InkWell(
      onTap: () => setState(() => index = tabIndex),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF13382C) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? Colors.white : const Color(0xFF4B5563),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget card(String title, String body,
          {required IconData icon, VoidCallback? onTap}) =>
      Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xffdfe4df))),
          child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: const Color(0xff008751)),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              const SizedBox(height: 7),
                              Text(body,
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xff65706a)))
                            ])),
                        if (onTap != null) const Icon(Icons.chevron_right)
                      ]))));
}

class OwnerPreview extends StatelessWidget {
  const OwnerPreview({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('OWNER WORKSPACE')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Vehicle-listing form comes next.'))),
            icon: const Icon(Icons.add),
            label: const Text('List a vehicle')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Text('List with care.',
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 34,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
              'This local walkthrough does not publish a vehicle or collect documents.'),
          const SizedBox(height: 24),
          _PreviewCard(
              title: 'Onboarding progress',
              body: '1 of 3 · Vehicle details ready for review',
              icon: Icons.assignment_turned_in_outlined),
          _PreviewCard(
              title: 'Toyota Prado · 2021',
              body: 'Draft · SUV · Wuse II · ₦120,000/day',
              icon: Icons.directions_car_outlined),
          _PreviewCard(
              title: 'Honda Accord · 2020',
              body: 'Awaiting review · Sedan · Jabi · ₦75,000/day',
              icon: Icons.hourglass_top_outlined),
          _PreviewCard(
              title: 'Payouts & Ledger',
              body: 'Verified available balance: ₦190,000 · Tap to view financial workspace',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const OwnerFinancialWorkspaceScreen(ownerId: 'demo_owner'),
                ),
              )),
        ]),
      );
}

class DriverPreview extends StatelessWidget {
  const DriverPreview({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('DRIVER WORKSPACE')),
        body: ListView(padding: const EdgeInsets.all(24), children: const [
          Text('Ready when the city moves.',
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 34,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text(
              'Trips and verification remain illustrative until driver operations are connected.'),
          SizedBox(height: 24),
          _PreviewCard(
              title: 'Verification',
              body: 'Not submitted · Licence and identity review required',
              icon: Icons.verified_user_outlined),
          _PreviewCard(
              title: 'Next assignment',
              body: 'No active assignment · Requests will appear here.',
              icon: Icons.route_outlined),
          _PreviewCard(
              title: 'Availability',
              body: 'Set availability when driver onboarding is enabled.',
              icon: Icons.schedule_outlined),
          _PreviewCard(
              title: 'Support & safety',
              body: 'Incident reporting and trip handover tools are planned.',
              icon: Icons.health_and_safety_outlined),
        ]),
      );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.body,
    required this.icon,
    this.onTap,
  });
  final String title;
  final String body;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xffdfe4df))),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: ListTile(
            leading: Icon(icon, color: const Color(0xff008751)),
            title:
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Padding(
                padding: const EdgeInsets.only(top: 6), child: Text(body)),
            trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
          ),
        ),
      );
}

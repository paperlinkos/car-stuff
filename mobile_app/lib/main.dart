import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth/auth_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const useFirebase = bool.fromEnvironment('USE_FIREBASE');
  if (useFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(MotaApp(
    authState: useFirebase ? FirebaseAuth.instance.authStateChanges() : null,
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
        home: authState == null ? const WelcomeScreen() : AuthGate(authState: authState!),
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
                    const SizedBox(height: 13),
                    const Center(
                        child: Text('Local demo mode · No account required',
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
    final role = tabs[index];
    final items = role == 'Customer'
        ? [
            card('Explore vehicles',
                'Search by dates, category and journey type.'),
            card('Your bookings', 'No active demonstration bookings.'),
            card('Verification',
                'Secure identity and licence review planned for Phase 2.')
          ]
        : role == 'Owner'
            ? [
                card('List a vehicle',
                    'Owner onboarding is planned for Phase 3.'),
                card('Vehicle status', 'No demonstration listings.')
              ]
            : [
                card('Verification status',
                    'Driver credentials require manual review.'),
                card('Assignments', 'No demonstration assignments.')
              ];
    return Scaffold(
      appBar: AppBar(
          title: const Text('MOTA',
              style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w800)),
          actions: [
            TextButton(
                onPressed: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => ListView(
                        children: tabs
                            .asMap()
                            .entries
                            .map((entry) => ListTile(
                                title: Text(entry.value),
                                onTap: () {
                                  setState(() => index = entry.key);
                                  Navigator.pop(context);
                                }))
                            .toList())),
                child: Text(role))
          ]),
      body: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(role == 'Customer' ? 'Good afternoon.' : 'Your $role space.',
                style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 34,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(role == 'Customer'
                ? 'Find a car that meets the moment.'
                : 'This role-aware area is ready for secure data in later phases.'),
            const SizedBox(height: 30),
            Expanded(child: ListView(children: items))
          ])),
      bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.directions_car_outlined), label: 'Customer'),
            NavigationDestination(
                icon: Icon(Icons.car_rental_outlined), label: 'Owner'),
            NavigationDestination(
                icon: Icon(Icons.badge_outlined), label: 'Driver')
          ]),
    );
  }

  Widget card(String title, String body) => Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xffdfe4df))),
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 7),
            Text(body,
                style: const TextStyle(fontSize: 12, color: Color(0xff65706a)))
          ])));
}

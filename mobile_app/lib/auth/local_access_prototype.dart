import 'package:flutter/material.dart';

/// A local-only account flow. It intentionally never creates an account or
/// suggests that a user has been verified.
class LocalAccessPrototype extends StatefulWidget {
  const LocalAccessPrototype({super.key});
  @override
  State<LocalAccessPrototype> createState() => _LocalAccessPrototypeState();
}

class _LocalAccessPrototypeState extends State<LocalAccessPrototype> {
  bool registering = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('MOTA',
                style:
                    TextStyle(letterSpacing: 3, fontWeight: FontWeight.w800))),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(registering ? 'Create an account.' : 'Welcome back.',
                  style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 38,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text(
                  'This is a local Phase 1 interface. It does not send details, create accounts, or verify identity.'),
              const SizedBox(height: 28),
              const TextField(
                  enabled: false,
                  decoration: InputDecoration(
                      labelText: 'Email address', hintText: 'Prototype field')),
              const SizedBox(height: 12),
              const TextField(
                  enabled: false,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: 'Password', hintText: 'Prototype field')),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                              title: const Text('Not connected yet'),
                              content: const Text(
                                  'Secure authentication will only be enabled after the backend is configured.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'))
                              ])),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: Text(registering ? 'Create account' : 'Sign in')),
              TextButton(
                  onPressed: () => setState(() => registering = !registering),
                  child: Text(registering
                      ? 'I already have an account'
                      : 'Create an account')),
              const Spacer(),
              const Text(
                  'Customer, owner and driver roles remain separate and require later verification.',
                  style: TextStyle(fontSize: 12, color: Color(0xff65706a))),
            ]),
          ),
        ),
      );
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authState});
  final Stream<User?> authState;

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: authState,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return snapshot.data == null ? const EmailAccessScreen() : SignedInScreen(user: snapshot.data!);
    },
  );
}

class EmailAccessScreen extends StatefulWidget {
  const EmailAccessScreen({super.key});
  @override State<EmailAccessScreen> createState() => _EmailAccessScreenState();
}

class _EmailAccessScreenState extends State<EmailAccessScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool create = false;
  bool busy = false;
  String? error;
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      if (create) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.text.trim(), password: password.text);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.code == 'operation-not-allowed' ? 'Email sign-in is not enabled for this development project yet.' : e.message ?? 'We could not complete that request.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Spacer(), const Text('MOTA', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.w800)), const SizedBox(height: 22),
    Text(create ? 'Create your account.' : 'Welcome back.', style: const TextStyle(fontFamily: 'serif', fontSize: 38, fontWeight: FontWeight.w600)), const SizedBox(height: 10),
    const Text('Your account starts as a customer. Owner and driver access require separate review.'), const SizedBox(height: 28),
    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address')), const SizedBox(height: 12),
    TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')), if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))), const SizedBox(height: 22),
    FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: Text(busy ? 'Please wait…' : create ? 'Create account' : 'Sign in')),
    TextButton(onPressed: busy ? null : () => setState(() => create = !create), child: Text(create ? 'I already have an account' : 'Create an account')),
    const Spacer(),
  ]))));
}

class SignedInScreen extends StatelessWidget {
  const SignedInScreen({super.key, required this.user});
  final User user;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(actions: [TextButton(onPressed: FirebaseAuth.instance.signOut, child: const Text('Sign out'))]), body: Padding(padding: const EdgeInsets.all(28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('You’re signed in.', style: TextStyle(fontFamily: 'serif', fontSize: 38, fontWeight: FontWeight.w600)), const SizedBox(height: 10), Text(user.email ?? user.uid), const SizedBox(height: 25), const Text('Profile creation and role activation are server-controlled. This screen will show the verified multi-role dashboard once the development backend is deployed.')])));
}

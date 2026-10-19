import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/user_profile.dart';
import '../discovery/discovery_screen.dart';
import '../owner/owner_portal.dart';
import '../booking/booking_screens.dart';
import 'profile_repository.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authState});
  final Stream<User?> authState;
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: authState,
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _Loading(label: 'Restoring your session…');
          }
          return snapshot.data == null
              ? const EmailAccessScreen()
              : AccountHome(user: snapshot.data!);
        },
      );
}

class EmailAccessScreen extends StatefulWidget {
  const EmailAccessScreen({super.key});
  @override
  State<EmailAccessScreen> createState() => _EmailAccessScreenState();
}

class _EmailAccessScreenState extends State<EmailAccessScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _setMessage(String message, {bool error = false}) => setState(() {
        _message = message;
        _isError = error;
      });

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_registering) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: _email.text.trim(), password: _password.text);
        await credential.user?.updateDisplayName(_name.text.trim());
        await credential.user?.sendEmailVerification();
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _password.text);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _setMessage(_authMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _setMessage('Enter the email address for the account first.',
          error: true);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        _setMessage(
            'A password-reset link has been sent if this account exists.');
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _setMessage(_authMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
                key: _form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MOTA',
                          style: TextStyle(
                              letterSpacing: 4, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 22),
                      Text(
                          _registering
                              ? 'Create your account.'
                              : 'Welcome back.',
                          style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 38,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      const Text(
                          'Every account begins as a customer. Owner and driver access require administrator review.'),
                      const SizedBox(height: 28),
                      if (_registering) ...[
                        _field(_name, 'Full name',
                            validator: (v) => v == null || v.trim().length < 2
                                ? 'Enter your full name.'
                                : null),
                        const SizedBox(height: 12)
                      ],
                      _field(_email, 'Email address',
                          email: true,
                          validator: (v) => v == null || !v.contains('@')
                              ? 'Enter a valid email address.'
                              : null),
                      const SizedBox(height: 12),
                      _field(_password, 'Password',
                          secret: true,
                          validator: (v) => v == null || v.length < 8
                              ? 'Use at least 8 characters.'
                              : null),
                      if (_registering) ...[
                        const SizedBox(height: 12),
                        _field(_confirm, 'Confirm password',
                            secret: true,
                            validator: (v) => v != _password.text
                                ? 'Passwords do not match.'
                                : null)
                      ],
                      if (_message != null)
                        _Message(message: _message!, error: _isError),
                      const SizedBox(height: 22),
                      FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52)),
                          child: Text(_busy
                              ? 'Please wait…'
                              : _registering
                                  ? 'Create account'
                                  : 'Sign in')),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _registering = !_registering;
                                    _message = null;
                                  }),
                          child: Text(_registering
                              ? 'I already have an account'
                              : 'Create an account')),
                      if (!_registering)
                        TextButton(
                            onPressed: _busy ? null : _resetPassword,
                            child: const Text('Reset password')),
                    ])),
          ),
        ))),
      );

  Widget _field(TextEditingController controller, String label,
          {bool email = false,
          bool secret = false,
          String? Function(String?)? validator}) =>
      TextFormField(
          controller: controller,
          keyboardType: email ? TextInputType.emailAddress : null,
          obscureText: secret,
          autocorrect: false,
          decoration: InputDecoration(labelText: label),
          validator: validator);
}

class AccountHome extends StatelessWidget {
  const AccountHome({super.key, required this.user, this.repository});
  final User user;
  final ProfileRepository? repository;
  @override
  Widget build(BuildContext context) {
    final profiles = repository ?? ProfileRepository();
    return StreamBuilder<UserProfile?>(
      stream: profiles.watchProfile(user.uid),
      builder: (_, snapshot) {
        if (snapshot.hasError) {
          return _Failure(
              message:
                  'We could not load your secure profile. Check the Firebase setup and try again.');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Loading(
              label: 'Creating your secure customer profile…');
        }
        if (snapshot.data == null) {
          return const _Failure(
              message:
                  'Your account has no secure profile yet. Sign out, then create a fresh local account or sign in again.');
        }
        return _AccountContent(
            user: user, profile: snapshot.data!, repository: profiles);
      },
    );
  }
}

class _AccountContent extends StatefulWidget {
  const _AccountContent(
      {required this.user, required this.profile, required this.repository});
  final User user;
  final UserProfile profile;
  final ProfileRepository repository;
  @override
  State<_AccountContent> createState() => _AccountContentState();
}

class _AccountContentState extends State<_AccountContent> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profile.displayName);
  late final TextEditingController _phone =
      TextEditingController(text: widget.profile.phoneNumber ?? '');
  bool _busy = false;
  String? _message;
  bool _isError = false;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _setMessage(String text, {bool error = false}) => setState(() {
        _message = text;
        _isError = error;
      });
  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      _setMessage('Enter a full name before saving.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.updateProfile(
          uid: widget.user.uid,
          displayName: _name.text,
          phoneNumber: _phone.text);
      _setMessage('Profile saved.');
    } catch (_) {
      _setMessage('We could not save those permitted profile fields.',
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _request(AccountRole role) async {
    setState(() => _busy = true);
    try {
      await widget.repository.requestRole(role);
      _setMessage(
          '${role.name[0].toUpperCase()}${role.name.substring(1)} access request submitted for review.');
    } catch (_) {
      _setMessage(
          'We could not submit that request. It may already be pending.',
          error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await widget.user.sendEmailVerification();
      _setMessage(
          'Verification email sent. Open the link, then refresh this screen.');
    } on FirebaseAuthException catch (error) {
      _setMessage(_authMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('MOTA',
                style:
                    TextStyle(letterSpacing: 3, fontWeight: FontWeight.w800)),
            actions: [
              TextButton(
                  onPressed: FirebaseAuth.instance.signOut,
                  child: const Text('Sign out'))
            ]),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(24), children: [
          const Text('Your Mota account.',
              style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 34,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(widget.user.email ?? 'Email unavailable'),
          if (!widget.user.emailVerified) ...[
            _Message(
                message:
                    'Email verification is required before future protected marketplace actions. Your customer account remains signed in.'),
            TextButton(
                onPressed: _busy ? null : _resend,
                child: const Text('Resend verification email'))
          ],
          const SizedBox(height: 16),
          _Card(
              title: 'Booking requests',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'View request status and cancel eligible requests.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => BookingListScreen(
                                    userId: widget.user.uid, owner: false))),
                        child: const Text('Open your bookings'))
                  ])),
          const SizedBox(height: 16),
          _Card(
              title: 'Profile',
              child: Column(children: [
                TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 12),
                TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone number (optional)')),
                const SizedBox(height: 16),
                Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                        onPressed: _busy ? null : _save,
                        child:
                            Text(_busy ? 'Saving…' : 'Save permitted fields'))),
              ])),
          const SizedBox(height: 16),
          _Card(
              title: 'Access',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Active access: ${widget.profile.roles.map((role) => role.name).join(', ')}'),
                    const SizedBox(height: 8),
                    const Text(
                        'Owner and driver requests are reviewed by an administrator. They do not activate listings or trips in this phase.'),
                    const SizedBox(height: 14),
                    Wrap(spacing: 10, runSpacing: 8, children: [
                      if (!widget.profile.hasRole(AccountRole.owner))
                        OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _request(AccountRole.owner),
                            child: const Text('Request owner access')),
                      if (!widget.profile.hasRole(AccountRole.driver))
                        OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _request(AccountRole.driver),
                            child: const Text('Request driver access')),
                    ]),
                    const SizedBox(height: 14),
                    _RoleRequestStatus(
                        userId: widget.user.uid, repository: widget.repository),
                  ])),
          if (widget.profile.hasRole(AccountRole.owner)) ...[
            const SizedBox(height: 16),
            _Card(
                title: 'Owner listings',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Create drafts, prepare required private documents and submit eligible listings for review.'),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      OwnerPortal(user: widget.user))),
                          child: const Text('Open owner portal'))
                    ])),
          ],
          const SizedBox(height: 16),
          _Card(
              title: 'Vehicle discovery',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Browse approved listings when configured, or clearly labelled demo vehicles while local inventory is unavailable.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DiscoveryScreen())),
                        child: const Text('Explore vehicles'))
                  ])),
          if (_message != null) _Message(message: _message!, error: _isError),
        ])),
      );
}

class _RoleRequestStatus extends StatelessWidget {
  const _RoleRequestStatus({required this.userId, required this.repository});
  final String userId;
  final ProfileRepository repository;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<RoleRequest>>(
        stream: repository.watchRoleRequests(userId),
        builder: (_, snapshot) {
          if (snapshot.hasError) {
            return const Text('Request status is unavailable right now.');
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Text('No owner or driver access requests yet.');
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: snapshot.data!
                  .map((request) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                            '${request.role.name}: ${request.status.name}'),
                      ))
                  .toList());
        },
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
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
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 12),
            child
          ])));
}

class _Message extends StatelessWidget {
  const _Message({required this.message, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: DecoratedBox(
          decoration: BoxDecoration(
              color: error ? const Color(0xffffece8) : const Color(0xffe9f5ed),
              borderRadius: BorderRadius.circular(8)),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(message,
                  style: TextStyle(
                      color: error
                          ? const Color(0xff9b2e1d)
                          : const Color(0xff175d3b))))));
}

class _Loading extends StatelessWidget {
  const _Loading({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Scaffold(
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(label)
      ])));
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    const Text('MOTA',
                        style: TextStyle(
                            letterSpacing: 4, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 24),
                    const Text('Account setup needs attention.',
                        style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 32,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(message),
                    const SizedBox(height: 20),
                    FilledButton(
                        onPressed: FirebaseAuth.instance.signOut,
                        child: const Text('Sign out')),
                    const Spacer()
                  ]))));
}

String _authMessage(FirebaseAuthException error) {
  switch (error.code) {
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled for this Firebase project yet.';
    case 'invalid-email':
      return 'Enter a valid email address.';
    case 'email-already-in-use':
      return 'An account already exists for that email. Sign in instead.';
    case 'weak-password':
      return 'Choose a stronger password with at least 8 characters.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'The email or password is incorrect.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    default:
      return error.message ?? 'We could not complete that request.';
  }
}

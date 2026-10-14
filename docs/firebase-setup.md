# Firebase setup — Phase 2

## Current status

The repository is connected to the dedicated development project `mota-abuja-dev-2026`. It has no production configuration, service-account keys, or production secrets. Cloud setup is paused; the Flutter app therefore runs in local demo mode by default.

Run the application locally with `flutter run`. When cloud setup is intentionally resumed, use `flutter run --dart-define=USE_FIREBASE=true` after the Firebase services are enabled.

## Required product-owner decisions

Confirm the Firebase organisation/project owner, approved identity-verification vendor, document-retention period, authorised operations staff, and incident-access process. These are privacy and operational decisions, not safe application defaults.

## Safe setup sequence

1. Create separate Firebase development, staging and production projects in the organisation account.
2. Run `firebase login` and `firebase use --add`; do not commit sensitive configuration.
3. Enable approved Authentication providers. Email/password is the initial baseline; phone authentication needs Nigeria-specific abuse controls and billing review.
4. Create Firestore and Storage in the intended region after reviewing data-residency requirements.
5. Run `flutterfire configure` from `mobile_app` for development. It generates `lib/firebase_options.dart`, intentionally absent until a real project exists.
6. In `functions`, run `npm install`, `npm run build`, then deploy only to development: `firebase deploy --only firestore:rules,storage,functions`.
7. Create the first staff custom claim through a controlled, audited administrator procedure. Never use an editable Firestore role as an admin permission source.

## Enforcement model

- Auth trigger creates a customer profile.
- Client role requests create pending verification requests; they do not activate owner or driver access.
- Only a callable function with a server-verified `admin` custom claim can change activated roles.
- Firestore rules prevent clients from creating profiles, writing roles, bookings, vehicles, payments and audit logs directly.
- Storage limits verification uploads to authenticated private paths, PDFs/images, and 10 MB per object.

Vehicle, booking, payment and live document workflows remain incomplete until a Firebase project and an approved document workflow are available.

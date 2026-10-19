# Phase 2 completion report

## Implemented locally

- Firebase email/password interface in Flutter: registration, sign-in, sign-out,
  password reset, persisted session gate, validation, useful errors and email
  verification notices.
- Server-created shared profile model with customer default role, account status,
  optional phone/image fields and trusted timestamps.
- Customer profile edits limited to permitted fields; owner/driver requests go
  through a callable Function and remain pending until administrator review.
- Admin-only Function for approve/reject decisions, role assignment transaction
  and audit records. Administrator access requires a server-issued custom claim.
- Deny-by-default Firestore rules, a documented Admin SDK provisioning script,
  and safe Web/dashboard account entry states that do not fabricate access.

## Actual validation

- flutter analyze — passed.
- flutter test — passed (4 tests).
- npm run lint in functions — passed.
- npm run build in functions — passed.
- node --check public-site/dist/app.js and node --check
  public-site/dist/auth.js — passed.
- Firestore emulator started with firestore.rules and completed a local parse
  run and the authorization scenario suite successfully.

## Not claimed as working

No Firebase services were deployed or changed. Email/password Authentication,
Firestore, Web app registration, email-action configuration, the Function
trigger and callable endpoints cannot be exercised until the documented console
setup and development deployment occur. The rules suite verifies the client
authorization boundary; it does not invoke the trusted callable approval
endpoint. Vehicles, bookings, payments and identity-document workflows remain
out of scope and inactive.

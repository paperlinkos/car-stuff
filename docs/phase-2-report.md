# Phase 2 report — foundation complete, Firebase deployment blocked

## Objective

Prepare authentication, multi-role user profiles and server-enforced access without inventing a Firebase project, credentials, or a document-retention policy.

## Built

- Firebase project manifest plus deny-by-default Firestore and Storage rules.
- Cloud Functions source for default customer-profile creation, owner/driver role activation requests, and staff-only activated-role updates.
- Audit log writes for privileged role changes and role activation requests.
- Flutter `UserProfile`, `AccountRole`, and verification status domain model with role-based capability helpers.
- Firebase setup instructions and the outstanding decisions required for a real deployment.

## Security decisions

- A client cannot write profiles, assign itself roles, write a booking, vehicle, payment, or audit-log record directly.
- Requesting owner/driver access produces a pending verification request; it does not activate access.
- Staff rights depend on a server-issued Firebase Authentication custom claim, not a mutable Firestore field or hidden UI control.
- Verification documents are private, type-limited to PDFs/images, and capped at 10 MB. Final retention and operational access policy are still decisions for the product owner.

## Validation

- `npm run lint` passed in `functions`.
- `npm run build` passed in `functions`.
- `flutter analyze` passed.
- `flutter test` passed: 4 tests.

## Blocker and next action

There is no selected Firebase development project, so no Firebase configuration was generated and no rules/functions were deployed. The next action is to provide or create the development Firebase project and approve the identity-verification/document-retention approach. After that, configure FlutterFire, deploy to development, and test real sign-up and staff-role flows before starting Phase 3.

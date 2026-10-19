# Firebase setup — Phase 2

## Current state

The development project is mota-abuja-dev-2026. Android and iOS FlutterFire
configuration is present in mobile_app/. It contains client configuration, not
a service-account secret. No rules or Functions have been deployed by this
phase, and Firebase Authentication email/password and Firestore must be enabled
in the Firebase console before a real account flow can succeed.

The Flutter app now starts in the Firebase account flow by default. Use
flutter run --dart-define=USE_LOCAL_DEMO=true only to see the retained Phase 1
catalogue shell without initializing Firebase.

## Console setup still required

1. In Authentication → Sign-in method, enable Email/Password.
2. Create a native-mode Firestore database in the approved region and enable
   Storage only when its document workflow is approved.
3. Register a Firebase Web app before enabling the public site or operations
   dashboard. Put only that Web app's public Firebase config into
   public-site/dist/firebase-config.js; the checked-in file deliberately has
   null configuration.
4. Deploy to development only after a reviewer approves the rules and
   Functions: firebase deploy --project mota-abuja-dev-2026 --only
   firestore:rules,storage,functions. Deployment is outside Phase 2
   implementation and was not run.
5. Configure Firebase Authentication email action settings and the authorized
   domains for password reset and email verification.

## Profile schema

users/{uid} is created by the Authentication trigger, never by a client.

| Field | Source / rule |
|---|---|
| id, email, createdAt, roles, accountStatus | trusted backend only |
| displayName, phoneNumber, profileImageUrl | owner may update only within Security Rules validation |
| updatedAt | client must use Firestore server timestamp |

Every new profile has roles: customer and accountStatus: active. Passwords
never enter Firestore or local application storage.

## Role-request lifecycle

The customer calls requestRoleActivation with owner or driver. The callable
Function checks the authenticated user, profile, existing roles and pending
duplicates, then creates roleRequests/{id} with pending status.

An account with the server-issued admin: true custom claim alone may call
reviewRoleRequest with approved or rejected. Approval appends the requested
role to the profile in the same transaction and writes an audit record. No
client can write a role request, edit its decision, edit roles, set account
status, or grant itself admin.

## First administrator provisioning

Use a secured operator workstation with Application Default Credentials for the
development project. The target user must already exist.

    cd functions
    GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json \
      npm run provision:admin -- admin@example.com

The service-account JSON is never committed. The script sets only the Firebase
Auth custom claim; the user must sign out and back in before it takes effect.
Grant access through a controlled, audited change process and revoke it with
the Admin SDK when no longer required.

## Rules and local checks

firestore.rules is deny-by-default. It permits no unauthenticated private-data
access; a signed-in user reading their own profile and changing only permitted
presentation fields; an administrator identified by Firebase Auth custom claim
reading review queues and audit events; and no client writes to profile
creation, roles, account state, role requests or audit records.

Run firebase emulators:exec --only firestore "npm run test:rules" --project
demo-mota-phase2 from functions/ to run the local authorization suite. It
covers unauthenticated denial, own-profile read/update, role-escalation denial,
self/other request-approval denial, administrator queue read and invalid
profile-update denial. An approval itself is intentionally a callable Function,
not a direct Firestore client write.

## Environment and secrets

- Flutter uses generated lib/firebase_options.dart; do not add passwords or
  service-account keys to Dart defines.
- The static Web config is public client configuration, not a secret. It must
  not include Admin SDK credentials.
- GOOGLE_APPLICATION_CREDENTIALS points outside this repository and is used
  only for operator-run administrator provisioning.

## Phase 3 Storage prerequisite

Before enabling live owner uploads, create protected Storage in the approved
region, deploy the reviewed Storage rules, and configure the Storage emulator
for security testing. Vehicle documents use private paths and must never be
placed in a public download-URL workflow. Manual reviewers must validate
ownership, registration, insurance, roadworthiness and any legal requirements;
an upload does not establish any of those facts.

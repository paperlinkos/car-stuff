# Phase 3 completion report

## Built locally

- Approved-owner-only Flutter portal with onboarding guidance, listing status,
  draft editing and a validated four-step vehicle form.
- Vehicle listing model: owner, core vehicle details, owner-entered indicative
  rate, pickup area, rental option, photo metadata and review status.
- Explicit lifecycle: draft, submitted, underReview, changesRequested,
  approved, rejected and suspended.
- Trusted submit and review callable Functions. Rejection and changes requests
  require an explanation; review identity and timestamps are server-written.
- Firestore rules that allow approved owners to create/edit only their own
  drafts or changes-requested listings, never submit/approve directly.
- Protected Storage paths for vehicle photos and documents; no public private
  document URLs are created.

## Deliberate limitations

Firebase Storage is not configured or deployed, so the mobile form uses clearly
labelled local photo previews only. It does not claim images or documents were
uploaded. Submission will correctly fail until protected document metadata and
the deployed backend exist. The static admin dashboard describes the review
queue but remains disabled until a Firebase Web app and authorized admin session
are configured.

## Validation

Run from mobile_app: flutter analyze and flutter test.

Run from functions: npm run lint, npm run build, then firebase emulators:exec
--only firestore "npm run test:rules" --project demo-mota-phase2.

Storage rules are not emulator-tested in this phase because the local Storage
emulator is not configured. No deployment occurred.

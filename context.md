# Mota Abuja — current context

Last updated: 17 October 2026

## Current product state

Mota is an Abuja-first vehicle rental and car-sharing marketplace under active
local development. Phases 1–5 are implemented locally. Nothing has been
deployed and no Firebase cloud resources were changed for this work.

The iPhone simulator is currently running the Flutter app in **local prototype
mode**. It opens directly without sign-in and shows a bottom role switcher:

- Customer: vehicle discovery and labelled demo catalogue.
- Owner: owner workspace and vehicle-listing workflow preview.
- Driver: verification and trip-assignment workflow preview.

The `LOCAL PROTOTYPE · NO ACCOUNT REQUIRED` banner is intentional. It lets the
team review the app without authentication obstructing progress.

## Authentication mode

The real Firebase-backed authentication and role-access code is retained but is
disabled by default. To run it deliberately:

```sh
cd mobile_app
flutter run --dart-define=ENABLE_AUTH=true --dart-define=USE_FIREBASE_EMULATORS=true
```

It expects local Firebase Auth, Firestore and Functions emulators. Do not claim
that cloud authentication or production account flows are live.

## Completed phases

### Phases 1–4

- Public website and static web admin dashboard prototypes.
- Flutter customer, owner and driver shells.
- Firebase profile/role model with callable role requests and admin review.
- Owner vehicle draft/submission/review model.
- Approved-only discovery, filters, vehicle details, and clearly labelled demo
  inventory fallback.

### Phase 5 — booking foundation

- Callable-only booking requests and transitions.
- Statuses: `requested`, `accepted`, `declined`, `cancelled`; `completed` is
  reserved for a later authorized operational workflow.
- Customer cancellation is only permitted while requested.
- The owning approved vehicle owner can accept or decline only requested
  bookings.
- Accepted requests are transactionally rechecked for time overlap before
  acceptance. Pending requests do not reserve a vehicle.
- An idempotency key prevents retries from creating duplicate bookings.
- Server-generated booking data includes a trusted rate and duration snapshot,
  audit log, customer/owner/vehicle IDs, and Lagos date labels.
- Rental duration is rounded up to full 24-hour days, maximum 31 days.
- Estimate is `dailyRateNgn × durationDays`; it excludes fees, payment,
  deposits, insurance, tax, discounts, refunds, commissions and payouts.
- Self-drive and chauffeur request boundaries are explicit; no verification,
  driver assignment, handover or payment is fabricated.

### Phase 6 — payments, commission, deposits & payouts

- Server-controlled platform pricing engine with configurable commission (15% default),
  fixed fees, deposit policy, rounding rules, and immutable pricing snapshots.
- Provider-independent abstraction (`PaymentProvider`) with local deterministic
  `SandboxPaymentProvider` and official Nigerian `PaystackPaymentProvider`.
- Secure webhook verification via HMAC-SHA512 and idempotent deduplication.
- Late/orphaned payment reconciliation handling for cancelled bookings.
- Double-entry append-only financial ledger (`/financialLedger`) dynamically calculating
  available balances, pending payouts, and net earnings without mutating history.
- Independent security deposits lifecycle in customer escrow (`/securityDeposits`).
- Admin-authorized refund validation (`/refunds`) strictly bounded by refundable balance.
- Owner payout workflow (`/payouts`) with funds hold and admin review/settlement.
- Customer Payments screen, Owner Financial Workspace, and updated Admin Dashboard.

See `docs/phase-6-report.md` and `docs/architecture.md` for details.

## Important files

- `mobile_app/lib/main.dart` — local role-switcher default and optional auth mode.
- `mobile_app/lib/financial/` — financial models, repository, and customer/owner screens.
- `mobile_app/lib/discovery/` — discovery and luxury vehicle-detail UI.
- `mobile_app/lib/booking/` — booking model, repository, request form, and customer/owner booking lists.
- `functions/src/pricing.ts` — server pricing calculations and config validation.
- `functions/src/payment-provider/` — payment provider interface, sandbox, and Paystack implementation.
- `functions/src/financial-ledger.ts` — append-only ledger entries and dynamic balance calculations.
- `functions/src/deposits-refunds.ts` — deposit and refund state machines and eligibility checks.
- `functions/src/payouts.ts` — payout eligibility and state transitions.
- `functions/src/financial-service.ts` — core financial transactions (payments, payouts, refunds).
- `functions/src/index.ts` — trusted profile, vehicle, booking, and financial callables/webhooks.
- `firestore.rules` — deny-by-default client rules, private booking and financial reads.
- `admin-dashboard/index.html` — administrative operations, ledger explorer, and payout/refund review queue.

## Verification already run

All passed after Phase 6:

```sh
cd mobile_app
flutter analyze
flutter test

cd ../functions
npm run build
npm run test:booking
npm run test:financial
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run test:rules
```

The Flutter suite has 14 passing tests (0 analyze issues). The Functions domain test,
financial domain test, and Firestore emulator authorization suite pass with 100% precision.

## Deliberate boundaries / not built

- No production deployment or cloud Firebase change.
- No real payment, deposit, refund, payout or bank transfer was executed.
- No real driver assignment, verification approval, handover, return or completion workflow.
- No automatic completion based on a scheduled return time.
- Demo vehicles are not bookable. Booking requests require an authenticated customer and an approved live listing in the emulator-backed flow.
- Do not begin Phase 7 without explicit approval.

## Workspace caution

The repository has existing work from prior phases across the public site,
admin dashboard, Flutter app, rules, Functions and documentation. Preserve
unrelated changes. `public-site/` is a nested repository and should not be
added to the outer repository by accident.

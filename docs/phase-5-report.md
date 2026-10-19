# Phase 5 completion report

## Built locally

- Callable-only `createBookingRequest` validates the authenticated customer,
  approved vehicle, rental mode, Lagos-aware requested period, minimum rental
  days, 31-day cap and trusted pricing snapshot.
- Callable-only `transitionBooking` permits customer cancellation and owner
  acceptance/decline only from `requested`. It revalidates vehicle approval and
  ownership at decision time and transactionally rejects overlapping accepted
  booking periods.
- Server-written audit entries for request and lifecycle changes, plus an
  idempotency record that returns the original booking for duplicate retries.
- Private booking Firestore reads for only the customer, owning vehicle owner or
  administrator; all direct client booking writes are denied.
- Flutter request form for authenticated customers on approved live vehicle
  details, with a clear non-confirmation notice, rental-mode restriction,
  schedule/notes fields and transparent estimate. Customer and owner request
  dashboards support permitted cancellation and decisions.

## State machine

`requested → accepted | declined | cancelled`. `completed` exists as a reserved
status, but Phase 5 deliberately exposes no automatic or client completion:
scheduled return time is not evidence of completion. Only future authorized
operations may introduce handover/return completion.

## Pricing and availability

Duration is rounded up to a whole 24-hour rental day. Estimate equals the
listing's trusted daily rate snapshot multiplied by duration days. It excludes
payments, fees, deposits, insurance, discounts and final totals. Pending
requests may overlap; accepted requests may not. Accepted overlap is checked
again inside the acceptance transaction.

## Validation to run

From `functions`: `npm run lint`, `npm run build`, `npm run test:booking`, then
`firebase emulators:exec --only firestore "npm run test:rules" --project
mota-abuja-dev-2026`.

From `mobile_app`: `flutter analyze` and `flutter test`.

## Limits

No Firebase cloud resources were deployed or changed. Callable integration
requires local Auth, Firestore and Functions emulators (or a deliberately
configured later environment). The no-login prototype shell remains a visual
walkthrough; it never submits booking requests. No payment, deposit, driver
assignment, verification decision, handover or return workflow was added.

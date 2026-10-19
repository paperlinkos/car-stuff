# Mota Abuja — architecture

## Scope and status

Phase 2 adds a Firebase Authentication/profile/role-access implementation and
typed Flutter profile model. The development Firebase project is selected, but
its Authentication, Firestore, Web app configuration, rules and Functions have
not been deployed or enabled for use. There is no payment provider, vehicle
inventory, insurance integration or production booking workflow. All displayed
vehicles, people, dates, counters and operational items remain demonstrative.

## Structure

- `public-site/`: static public discovery prototype, hosted through Sites.
- `admin-dashboard/`: responsive operations shell (static prototype).
- `mobile_app/`: one Flutter shell with customer, owner and driver navigation prototypes and a typed multi-role profile model.
- `functions/`, `firestore.rules`, `storage.rules`: trusted profile and
  role-request backend source, plus deny-by-default access rules.
- `docs/`: architecture, Firebase setup and phase reports.

## Design tokens

| Token | Value | Use |
|---|---|---|
| Accent | `#008751` | Nigerian-green actions and status |
| Ink | `#171A18` | Primary text and dark surfaces |
| Paper | `#FFFFFF` | Cards and public surfaces |
| Warm base | `#F5F4EF` | Page background |
| Rule | `#D9DED8` | Quiet structural dividers |

Typography: Manrope for interface text, Playfair Display for editorial display text, DM Mono for labels and statuses.

## Core domain model (future backend)

Every record uses an immutable `id`, `createdAt`, `updatedAt`, actor ownership where relevant, and explicit lifecycle `status`.

| Entity | Key responsibility | Ownership / state separation |
|---|---|---|
| User | identity and profile | roles are separate from verification |
| UserRole | activated customer, owner or driver role | backend-managed only |
| VerificationRequest | evidence and review decision | private documents, `pending/review/approved/rejected/expired` |
| Vehicle | owner vehicle listing and review lifecycle | owner drafts; trusted submit/review separate |
| VehicleAvailability | date blocks and availability rules | server validates conflicts |
| Booking | requested rental | booking, payment and deposit statuses independent |
| DriverProfile / DriverAssignment | driver eligibility and trip assignment | driver verification precedes assignment |
| Inspection / Handover / ReturnInspection | physical vehicle condition chain | staff actor and photos/audit required |
| Payment / SecurityDeposit / OwnerPayout / DriverPayout | financial ledger concepts | callback-verified, reconciled server-side |
| Incident / InsurancePolicyReference / Notification / AuditLog / PlatformConfiguration | operations, compliance and policy | auditable operational controls |

Future source of truth: Firebase Authentication, Firestore, Storage and Cloud Functions. Client applications must never grant roles, approve records, calculate authoritative booking availability, or trust payment success on their own.

## Vehicle-listing lifecycle

An approved owner may create a draft. Drafts and changesRequested listings can
be edited by their owner; only a trusted callable operation can submit them.
Staff review through a custom-claim-gated callable operation can set approved,
rejected, changesRequested or suspended, with a reason required for rejection
and change requests. Only approved listings may ever be publicly discoverable.
Private document metadata belongs in vehicleDocuments, not the vehicle record.

## Discovery data flow

Customer discovery queries vehicles constrained to trusted status approved.
When no local/live approved inventory is available, the Flutter client uses a
separate labelled demo source for interface development. It never combines demo
and real records. Search and filter operations are bounded client-side over the
approved result set until an indexed production discovery strategy is approved.

## Booking lifecycle (Phase 5)

`requested → accepted | declined | cancelled`; `completed` is reserved for a
future authorized operations/handover workflow and cannot be inferred from a
return date. A customer creates a `requested` booking and may cancel it while
requested. The owning approved vehicle owner may accept or decline it while
requested. No client may write bookings directly. Every creation and transition
writes an audit log.

The callable backend validates that a vehicle remains approved, that its offered
rental mode permits the request, and that the period is in the future, is not
reversed, meets the listing minimum and is no more than 31 days. At acceptance,
a Firestore transaction rechecks approved listing ownership and checks every
accepted booking for that vehicle using half-open overlap logic
`existing.pickup < requested.return && existing.return > requested.pickup`.
Pending requests do not reserve inventory. An idempotency key maps retry calls
to one server-generated booking ID.

Dates are stored as timestamps and display date labels use Africa/Lagos (WAT,
UTC+1) calendar dates. Duration is `ceil(return - pickup in 24-hour periods)`;
the estimate is trusted `dailyRateNgn × durationDays`, with no platform fee,
tax, deposit, insurance, discount or payment included. The snapshot is written
only by the backend at request creation.

Self-drive requests state that licence eligibility, handover and any deposit
remain future operational policy. Chauffeur requests make no driver assignment
or availability guarantee. Inspection and driver assignment remain outside Phase 6.

## Financial architecture (Phase 6)

Phase 6 implements a comprehensive, provider-independent financial architecture
with double-entry ledgering:

### 1. Pricing and Commission Policy
- **Server calculation**: Pricing breakdown is calculated exclusively in trusted
  Cloud Functions using immutable snapshots:
  - `grossRentalNgn = dailyRateNgn × durationDays`
  - `platformCommissionNgn = round(grossRentalNgn × (commissionPercentage / 100))`
  - `totalPlatformFeeNgn = platformCommissionNgn + fixedFeeNgn`
  - `ownerNetEarningsNgn = max(0, grossRentalNgn - totalPlatformFeeNgn)`
  - `customerTotalNgn = grossRentalNgn + depositNgn`
- Default configuration uses 15% marketplace commission and 0 NGN fixed fee.
- Client cannot supply prices or override server fee calculations.

### 2. Payment-Provider Abstraction
- Provider-independent interface: `PaymentProvider`.
- Default local engine: `SandboxPaymentProvider` for deterministic testing without
  external networks or real money.
- Nigerian provider implementation: `PaystackPaymentProvider` (kobo conversion,
  `x-paystack-signature` HMAC-SHA512 verification, initialization and verification
  APIs).
- Secret keys (`PAYSTACK_SECRET_KEY`, `PAYMENT_PROVIDER_WEBHOOK_SECRET`) reside
  strictly in backend environment configuration and are never exposed to clients.
- Webhook endpoints enforce HMAC signature verification and idempotent deduplication
  via `/processedEvents/{eventId}`.
- Late or orphaned payment callbacks (where customer paid after a booking was
  cancelled) do not revive the booking; they record a `reconciliationRequired` flag
  and trigger operational refund workflows.

### 3. Append-Only Financial Ledger
- Collections: `/financialLedger/{id}`.
- Immutable entries: `rental_charge`, `platform_commission`, `owner_credit`,
  `deposit_collected`, `customer_refund`, `owner_refund_debit`, `commission_reversal`,
  `payout_hold`, `payout_settlement`, `payout_cancellation`.
- Balances are derived dynamically from ledger entries:
  - `availableBalance = netEarned - pendingPayout - paidOut`.
  - Corrections and refunds are recorded as reversing entries, never rewritten.

### 4. Deposits and Refunds
- Security deposits are tracked independently from rental payments under
  `/securityDeposits/{id}` in customer escrow.
- Deposit state machine: `notRequired → pending → authorized | collected → held → released | disputed | refunded`.
- Refunds under `/refunds/{id}` require admin authorization, must be positive, and
  cannot exceed remaining refundable balances (`totalPaid - existingRefunds`).

### 5. Owner Payout Workflow
- Payout state machine: `requested → reviewing → approved → completed | rejected`.
- Owners can request payouts up to verified available balance (minimum ₦5,000).
- Payout requests immediately place a `payout_hold` ledger debit.
- Administrative approval settles the payout (`payout_settlement`); rejection restores
  funds via `payout_cancellation`.

## Development setup

Public site: open `public-site/dist/index.html`, or package through the Sites workflow. No Node dependency is needed.

Admin prototype: open `admin-dashboard/index.html` in a browser.

Flutter app: from `mobile_app`, run `flutter pub get`, `flutter analyze`,
`flutter test`, then `flutter run`. Standard Android and iOS runners and
FlutterFire configuration for the development project are included. Use
`--dart-define=USE_LOCAL_DEMO=true` only for the retained non-auth demo shell.

For the Firebase foundation, see [Firebase setup](firebase-setup.md). Do not deploy the rules or functions to a production project before completing that document's required product-owner decisions.

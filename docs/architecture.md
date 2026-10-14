# Mota Abuja — architecture

## Scope and status

Phase 2 adds deployable Firebase rules and Cloud Functions source, plus a typed Flutter multi-role profile model. The repository still has no selected Firebase project, deployed authentication, payment provider, vehicle inventory, insurance integration, or production booking workflow. All displayed vehicles, people, dates, counters and operational items remain demonstrative.

## Structure

- `public-site/`: static public discovery prototype, hosted through Sites.
- `admin-dashboard/`: responsive operations shell (static prototype).
- `mobile_app/`: one Flutter shell with customer, owner and driver navigation prototypes and a typed multi-role profile model.
- `functions/`, `firestore.rules`, `storage.rules`: Firebase backend foundation, deliberately unconfigured.
- `docs/`: architecture and Phase 1 reporting.

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
| Vehicle / VehicleCategory | listing and configurable classification | owner submits; admin approval separate |
| VehicleAvailability | date blocks and availability rules | server validates conflicts |
| Booking | requested rental | booking, payment and deposit statuses independent |
| DriverProfile / DriverAssignment | driver eligibility and trip assignment | driver verification precedes assignment |
| Inspection / Handover / ReturnInspection | physical vehicle condition chain | staff actor and photos/audit required |
| Payment / SecurityDeposit / OwnerPayout / DriverPayout | financial ledger concepts | callback-verified, reconciled server-side |
| Incident / InsurancePolicyReference / Notification / AuditLog / PlatformConfiguration | operations, compliance and policy | auditable operational controls |

Future source of truth: Firebase Authentication, Firestore, Storage and Cloud Functions. Client applications must never grant roles, approve records, calculate authoritative booking availability, or trust payment success on their own.

## Development setup

Public site: open `public-site/dist/index.html`, or package through the Sites workflow. No Node dependency is needed.

Admin prototype: open `admin-dashboard/index.html` in a browser.

Flutter shell: from `mobile_app`, run `flutter pub get`, `flutter analyze`, `flutter test`, then `flutter run`. Standard Android and iOS runners are included. FlutterFire configuration is intentionally absent until a real Firebase project is selected.

For the Firebase foundation, see [Firebase setup](firebase-setup.md). Do not deploy the rules or functions to a production project before completing that document's required product-owner decisions.

# Phase 6 Completion Report — Payments, Commission, Deposits & Payouts

**Project:** Mota Abuja Car Rental Marketplace  
**Date:** 17 October 2026  
**Scope:** Phase 6 — Financial Architecture, Platform Commissions, Escrow Deposits, Ledger Accounting, and Owner Payouts  

---

## 1. Executive Summary & Boundaries

Phase 6 implements the complete financial data model and server-authoritative accounting infrastructure for Mota Abuja. 

### Enforced Boundary Confirmations:
- **No real money processed:** All workflows operate in sandbox / mock simulation mode.
- **No live deployments:** No remote Firebase cloud resources were modified or deployed (`firebase deploy` was not run).
- **No secrets in client bundles:** Secret keys (`PAYSTACK_SECRET_KEY`, `PAYMENT_PROVIDER_WEBHOOK_SECRET`) reside exclusively in backend environment configuration.
- **No client overrides:** Clients cannot specify pricing, commissions, payment status, or ledger balances.
- **Phase 7 not started:** Physical vehicle inspection, driver assignment, handover/return, and live insurance integration remain outside Phase 6.

---

## 2. Financial Architecture & Pricing Engine

### 2.1 Server-Controlled Pricing & Commission Engine
- **Module:** `functions/src/pricing.ts`
- **Configuration Structure (`PlatformPricingConfig`):**
  - `version`: Version identifier (default `2026.1-dev-default`).
  - `effectiveDate`: Effective ISO date.
  - `currency`: Default `NGN`.
  - `commissionPercentage`: Configurable platform fee (default `15%`).
  - `fixedFeeNgn`: Optional fixed transaction fee (default `0 NGN`).
  - `roundingPolicy`: `'round' | 'ceil' | 'floor'` (default `'round'`).
  - `depositPolicy`: `{ required: boolean, defaultAmountNgn: number }`.
- **Calculation Formulation:**
  - `grossRentalNgn = dailyRateNgn × durationDays`
  - `platformCommissionNgn = round(grossRentalNgn × (commissionPercentage / 100))`
  - `totalPlatformFeeNgn = platformCommissionNgn + fixedFeeNgn`
  - `ownerNetEarningsNgn = max(0, grossRentalNgn - totalPlatformFeeNgn)`
  - `customerTotalNgn = grossRentalNgn + depositNgn`
- **Immutability:** Calculations are preserved as an immutable snapshot in `pricingSnapshot` on both booking and payment documents.

---

## 3. Payment-Provider Abstraction

### 3.1 Interface & Implementations
- **Interface:** `PaymentProvider` (`functions/src/payment-provider/types.ts`)
  - `createPaymentAttempt(params)`
  - `verifyWebhookSignature(payload, signature, secret)`
  - `parseWebhookEvent(payload)`
  - `verifyPayment(reference)`
- **Sandbox Provider (`SandboxPaymentProvider`):**
  - Default deterministic mock engine for local development, emulator runs, and automated testing.
  - Zero external network requests; generates sandbox checkout URLs and simulates success or failure (if reference contains `_fail`).
- **Paystack Provider (`PaystackPaymentProvider`):**
  - Production-ready Nigerian payment gateway integration.
  - Converts NGN amounts to kobo ($1\text{ NGN} = 100\text{ kobo}$).
  - Verifies `x-paystack-signature` using HMAC-SHA512.
  - Initializes transactions via `https://api.paystack.co/transaction/initialize` and verifies via `/transaction/verify/:reference`.

### 3.2 Webhook Signature & Idempotency Strategy
- Webhook endpoint: `handlePaymentWebhook` (`functions/src/index.ts`).
- **Signature Verification:** Requests without a valid HMAC-SHA512 signature are rejected with HTTP 401.
- **Idempotency:** Webhooks check `/processedEvents/{eventId}` in a Firestore transaction. Duplicate event submissions return HTTP 200 with `{ status: 'duplicate_event_ignored' }` without re-executing ledger writes.
- **Late / Orphaned Payments:** When a payment callback confirms success for a booking that was already cancelled or expired:
  - The booking is **not** revived (preventing date conflicts).
  - The payment document records `reconciliationRequired: true` and `reconciliationReason: 'payment_received_after_cancellation'`.
  - An audit log alerts operations to process an administrative refund.

---

## 4. Append-Only Financial Ledger & Payout Workflow

### 4.1 Ledger Data Schema (`/financialLedger/{id}`)
Double-entry accounting principles ensure financial integrity without mutating historical records:

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | String | Unique entry identifier |
| `entryType` | String | `rental_charge`, `platform_commission`, `owner_credit`, `deposit_collected`, `customer_refund`, `owner_refund_debit`, `commission_reversal`, `payout_hold`, `payout_settlement`, `payout_cancellation` |
| `direction` | String | `'credit'` or `'debit'` |
| `amountNgn` | Number | Integer amount in Naira |
| `currency` | String | `'NGN'` |
| `accountId` | String | Target account (e.g. `'platform'`, `'owner_{uid}'`, `'escrow_deposit_{uid}'`) |
| `bookingId` | String | Associated booking reference |
| `referenceId` | String | Payment or payout reference |
| `description`| String | Human-readable audit description |
| `createdAt` | Timestamp | Server-generated timestamp |

### 4.2 Dynamic Balance Derivation
Owner balances are calculated directly from append-only ledger entries via `calculateOwnerBalances()`:
$$\text{Net Earned} = \sum \text{owner\_credit} - \sum \text{owner\_refund\_debit}$$
$$\text{Pending Payout} = \sum \text{payout\_hold} - \sum \text{payout\_settlement} - \sum \text{payout\_cancellation}$$
$$\text{Available for Payout} = \text{Net Earned} - \text{Pending Payout} - \sum \text{payout\_settlement}$$

### 4.3 Owner Payout Lifecycle
- State machine: `requested → reviewing → approved → completed | rejected`.
- **Request:** Owner requests payout up to `availableForPayoutNgn` (minimum ₦5,000). A `payout_hold` ledger debit is created atomically.
- **Review:** Admin reviews via callable `reviewOwnerPayout`:
  - If **approved**: Payout marked `completed` and a `payout_settlement` ledger entry is written.
  - If **rejected**: Payout marked `rejected` and a `payout_cancellation` entry restores funds to available balance.

---

## 5. Security Deposits and Refunds

### 5.1 Security Deposits
- Stored independently under `/securityDeposits/{id}`.
- State machine: `notRequired → pending → authorized | collected → held → released | disputed | refunded`.
- Funds are credited to customer escrow (`escrow_deposit_{uid}`) and never combined with owner earnings.

### 5.2 Refunds
- Stored under `/refunds/{id}`.
- Restricted to trusted administrators via `requestBookingRefund`.
- Validation: Validates that `existingRefunds + requestedRefund <= totalPaidNgn`. Over-refunding is strictly blocked.
- Atomic reversals: Debits platform cash (`customer_refund`), debits owner account (`owner_refund_debit`), and reverses platform commission (`commission_reversal`).

---

## 6. Firestore Security Rules Enforcement

In `firestore.rules`:
- Direct client writes to `/payments`, `/securityDeposits`, `/refunds`, `/payouts`, `/financialLedger`, `/processedEvents` are **strictly forbidden** (`allow write: if false`).
- Private read access:
  - Customers can read only their own payments, deposits, and refunds (`customerId == request.auth.uid`).
  - Owners can read only their own payouts and ledger entries (`accountId == 'owner_' + request.auth.uid`).
  - Administrators have global read access across financial documents.

---

## 7. Verification & Automated Test Results

### 7.1 Backend Test Execution
- **Command:** `npm run test` (in `functions/`)
  - `test:booking`: Passed. Overlap checks, 31-day cap, booking state transitions.
  - `test:financial`: Passed. 15% commission calculations, fixed fees, ceil/floor/round policies, Paystack and Sandbox provider HMAC verification, kobo-to-NGN conversion, ledger balance calculations, deposit state transitions, refund eligibility limits, payout eligibility limits.
- **Command:** `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run test:rules` (in `functions/`)
  - Passed. Verifies that clients cannot write to payments, payouts, deposits, refunds, or ledger collections; verifies private read boundaries and admin-only access.

### 7.2 Mobile App Test Execution
- **Command:** `flutter analyze` (in `mobile_app/`)
  - Result: `No issues found!`.
- **Command:** `flutter test` (in `mobile_app/`)
  - Result: **14/14 tests passed**.
  - `Financial Models & Repository`: Payment parsing, balance summary derivation, prototype defaults, safe handling of uninitialized Firebase.
  - Widget and discovery suites: All customer, owner, and driver prototype walkthroughs verified.

---

## 8. Outstanding Legal, Operational & Provider Decisions

Before transitioning to live production payment processing:
1. **Paystack Merchant Account:** Setup of a corporate Paystack Nigeria merchant account, business registration compliance, and provisioning of live API keys into Google Cloud Secret Manager.
2. **Platform Commission Rate:** Formal commercial approval of the 15% marketplace commission rate and policy on transaction fee absorption.
3. **Security Deposit Policy:** Legal and operational guidelines on self-drive security deposit amounts, hold durations, and dispute resolution procedures.
4. **Owner KYC & Payout Bank Verification:** Integration of Paystack Transfers API with Nigerian NUBAN bank account verification (`/bank/resolve`) prior to live payout disbursement.

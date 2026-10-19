export type LedgerEntryType =
  | 'rental_charge'
  | 'platform_commission'
  | 'owner_credit'
  | 'deposit_collected'
  | 'deposit_released'
  | 'deposit_forfeited'
  | 'customer_refund'
  | 'commission_reversal'
  | 'owner_refund_debit'
  | 'payout_hold'
  | 'payout_settlement'
  | 'payout_cancellation'
  | 'manual_adjustment';

export type LedgerDirection = 'credit' | 'debit';

export interface LedgerEntry {
  readonly id: string;
  readonly entryType: LedgerEntryType;
  readonly direction: LedgerDirection;
  readonly amountNgn: number;
  readonly currency: 'NGN';
  /** Account identifier, e.g. 'platform', 'owner_{uid}', 'escrow_deposit_{uid}' */
  readonly accountId: string;
  readonly bookingId?: string | null;
  readonly paymentId?: string | null;
  readonly payoutId?: string | null;
  readonly refundId?: string | null;
  readonly referenceId: string;
  readonly description: string;
  readonly createdAt: Date;
  readonly metadata?: Record<string, unknown>;
}

export interface OwnerFinancialSummary {
  readonly ownerId: string;
  readonly totalEarnedNgn: number;
  readonly totalRefundedNgn: number;
  readonly netEarnedNgn: number;
  readonly pendingPayoutNgn: number;
  readonly paidOutNgn: number;
  readonly availableForPayoutNgn: number;
  readonly currency: 'NGN';
}

/**
 * Pure function that calculates an owner's financial balances strictly from
 * an append-only set of ledger entries.
 */
export function calculateOwnerBalances(
  ownerId: string,
  entries: readonly LedgerEntry[]
): OwnerFinancialSummary {
  const targetAccount = `owner_${ownerId}`;
  const pendingAccount = `payout_pending_${ownerId}`;
  let totalEarnedNgn = 0;
  let totalRefundedNgn = 0;
  let payoutHoldNgn = 0;
  let payoutSettledNgn = 0;
  let payoutCancelledNgn = 0;
  let adjustmentsNgn = 0;

  for (const entry of entries) {
    if (entry.accountId !== targetAccount && entry.accountId !== pendingAccount) continue;
    if (entry.currency !== 'NGN') continue;

    switch (entry.entryType) {
      case 'owner_credit':
        if (entry.accountId === targetAccount) totalEarnedNgn += entry.amountNgn;
        break;
      case 'owner_refund_debit':
        if (entry.accountId === targetAccount) totalRefundedNgn += entry.amountNgn;
        break;
      case 'payout_hold':
        if (entry.accountId === targetAccount) payoutHoldNgn += entry.amountNgn;
        break;
      case 'payout_settlement':
        if (entry.accountId === pendingAccount || entry.accountId === targetAccount) {
          payoutSettledNgn += entry.amountNgn;
        }
        break;
      case 'payout_cancellation':
        if (entry.accountId === targetAccount) payoutCancelledNgn += entry.amountNgn;
        break;
      case 'manual_adjustment':
        if (entry.accountId === targetAccount) {
          if (entry.direction === 'credit') {
            adjustmentsNgn += entry.amountNgn;
          } else {
            adjustmentsNgn -= entry.amountNgn;
          }
        }
        break;
      default:
        break;
    }
  }

  const netEarnedNgn = Math.max(0, totalEarnedNgn - totalRefundedNgn + adjustmentsNgn);
  const pendingPayoutNgn = Math.max(0, payoutHoldNgn - payoutSettledNgn - payoutCancelledNgn);
  const paidOutNgn = payoutSettledNgn;
  const availableForPayoutNgn = Math.max(0, netEarnedNgn - pendingPayoutNgn - paidOutNgn);

  return {
    ownerId,
    totalEarnedNgn,
    totalRefundedNgn,
    netEarnedNgn,
    pendingPayoutNgn,
    paidOutNgn,
    availableForPayoutNgn,
    currency: 'NGN',
  };
}

/**
 * Invariant verification: Global Double-Entry Balancing.
 * Total Debits must exactly equal Total Credits across all NGN entries.
 */
export function verifyLedgerBalance(entries: readonly LedgerEntry[]): {
  readonly balanced: boolean;
  readonly totalDebitsNgn: number;
  readonly totalCreditsNgn: number;
  readonly differenceNgn: number;
} {
  let totalDebitsNgn = 0;
  let totalCreditsNgn = 0;

  for (const entry of entries) {
    if (entry.currency !== 'NGN') continue;
    if (entry.direction === 'debit') {
      totalDebitsNgn += entry.amountNgn;
    } else if (entry.direction === 'credit') {
      totalCreditsNgn += entry.amountNgn;
    }
  }

  const differenceNgn = Math.abs(totalDebitsNgn - totalCreditsNgn);
  return {
    balanced: differenceNgn === 0,
    totalDebitsNgn,
    totalCreditsNgn,
    differenceNgn,
  };
}

/**
 * Invariant verification: Per-Transaction Double-Entry Balancing.
 * Every unique transaction referenceId must have sum(Debits) === sum(Credits).
 */
export function verifyTransactionsBalanced(entries: readonly LedgerEntry[]): {
  readonly allBalanced: boolean;
  readonly unbalancedReferences: readonly string[];
} {
  const groups = new Map<string, { debits: number; credits: number }>();

  for (const entry of entries) {
    if (entry.currency !== 'NGN') continue;
    const ref = entry.referenceId || 'unknown_ref';
    const current = groups.get(ref) || { debits: 0, credits: 0 };
    if (entry.direction === 'debit') {
      current.debits += entry.amountNgn;
    } else if (entry.direction === 'credit') {
      current.credits += entry.amountNgn;
    }
    groups.set(ref, current);
  }

  const unbalancedReferences: string[] = [];
  for (const [ref, { debits, credits }] of groups.entries()) {
    if (debits !== credits) {
      unbalancedReferences.push(`${ref} (Debits: ${debits}, Credits: ${credits})`);
    }
  }

  return {
    allBalanced: unbalancedReferences.length === 0,
    unbalancedReferences,
  };
}


export const payoutStatuses = [
  'requested',
  'reviewing',
  'approved',
  'rejected',
  'processing',
  'completed',
  'failed',
] as const;

export type PayoutStatus = (typeof payoutStatuses)[number];

export interface PayoutRecord {
  readonly id: string;
  readonly ownerId: string;
  readonly amountNgn: number;
  readonly currency: 'NGN';
  readonly status: PayoutStatus;
  readonly requestedAt: Date;
  readonly reviewedBy?: string | null;
  readonly reviewedAt?: Date | null;
  readonly reviewNote?: string | null;
  readonly completedAt?: Date | null;
  readonly providerTransferId?: string | null;
  readonly failureReason?: string | null;
}

export function validatePayoutEligibility(
  requestedAmountNgn: number,
  availableBalanceNgn: number,
  minimumPayoutNgn = 5000
): { readonly eligible: boolean; readonly reason?: string } {
  if (!Number.isSafeInteger(requestedAmountNgn) || requestedAmountNgn <= 0) {
    return { eligible: false, reason: 'Requested payout amount must be a positive integer.' };
  }
  if (!Number.isSafeInteger(availableBalanceNgn) || availableBalanceNgn < 0) {
    return { eligible: false, reason: 'Available balance is invalid.' };
  }
  if (requestedAmountNgn < minimumPayoutNgn) {
    return {
      eligible: false,
      reason: `Minimum payout request is ₦${minimumPayoutNgn.toLocaleString()}.`,
    };
  }
  if (requestedAmountNgn > availableBalanceNgn) {
    return {
      eligible: false,
      reason: `Requested payout ₦${requestedAmountNgn.toLocaleString()} exceeds available balance ₦${availableBalanceNgn.toLocaleString()}.`,
    };
  }

  return { eligible: true };
}

export function canTransitionPayout(
  current: PayoutStatus,
  action: 'review' | 'approve' | 'reject' | 'process' | 'complete' | 'fail'
): PayoutStatus | null {
  switch (action) {
    case 'review':
      return current === 'requested' ? 'reviewing' : null;
    case 'approve':
      return current === 'requested' || current === 'reviewing' ? 'approved' : null;
    case 'reject':
      return current === 'requested' || current === 'reviewing' ? 'rejected' : null;
    case 'process':
      return current === 'approved' ? 'processing' : null;
    case 'complete':
      return current === 'approved' || current === 'processing' ? 'completed' : null;
    case 'fail':
      return current === 'approved' || current === 'processing' ? 'failed' : null;
    default:
      return null;
  }
}

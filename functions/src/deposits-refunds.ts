export const depositStatuses = [
  'notRequired',
  'pending',
  'authorized',
  'collected',
  'held',
  'partiallyRefunded',
  'refunded',
  'released',
  'disputed',
] as const;

export type DepositStatus = (typeof depositStatuses)[number];

export const refundStatuses = [
  'requested',
  'processing',
  'completed',
  'failed',
] as const;

export type RefundStatus = (typeof refundStatuses)[number];

export interface SecurityDepositRecord {
  readonly id: string;
  readonly bookingId: string;
  readonly customerId: string;
  readonly ownerId: string;
  readonly amountNgn: number;
  readonly currency: 'NGN';
  readonly status: DepositStatus;
  readonly providerReference?: string;
  readonly createdAt: Date;
  readonly updatedAt: Date;
  readonly notes?: string;
}

export interface RefundRecord {
  readonly id: string;
  readonly bookingId: string;
  readonly paymentId: string;
  readonly amountNgn: number;
  readonly currency: 'NGN';
  readonly reason: string;
  readonly requestedBy: string;
  readonly authorizedBy: string;
  readonly providerReference: string;
  readonly status: RefundStatus;
  readonly createdAt: Date;
  readonly updatedAt: Date;
  readonly notes?: string;
}

/**
 * Validates whether a refund can be issued for a payment given its history.
 */
export function validateRefundEligibility(
  totalPaidNgn: number,
  existingRefundedNgn: number,
  requestedRefundNgn: number
): { readonly eligible: boolean; readonly remainingRefundableNgn: number; readonly reason?: string } {
  if (!Number.isSafeInteger(totalPaidNgn) || totalPaidNgn <= 0) {
    return { eligible: false, remainingRefundableNgn: 0, reason: 'Total paid amount is invalid or zero.' };
  }
  if (!Number.isSafeInteger(existingRefundedNgn) || existingRefundedNgn < 0) {
    return { eligible: false, remainingRefundableNgn: 0, reason: 'Existing refunded amount is invalid.' };
  }
  if (!Number.isSafeInteger(requestedRefundNgn) || requestedRefundNgn <= 0) {
    return { eligible: false, remainingRefundableNgn: 0, reason: 'Requested refund amount must be positive.' };
  }

  const remaining = Math.max(0, totalPaidNgn - existingRefundedNgn);
  if (requestedRefundNgn > remaining) {
    return {
      eligible: false,
      remainingRefundableNgn: remaining,
      reason: `Requested refund ₦${requestedRefundNgn} exceeds remaining refundable balance ₦${remaining}.`,
    };
  }

  return { eligible: true, remainingRefundableNgn: remaining - requestedRefundNgn };
}

/**
 * Validates security deposit state transitions.
 */
export function canTransitionDeposit(
  current: DepositStatus,
  action: 'collect' | 'authorize' | 'hold' | 'release' | 'dispute' | 'refund'
): DepositStatus | null {
  switch (action) {
    case 'authorize':
      return current === 'pending' ? 'authorized' : null;
    case 'collect':
      return current === 'pending' || current === 'authorized' ? 'collected' : null;
    case 'hold':
      return current === 'collected' ? 'held' : null;
    case 'release':
      return current === 'collected' || current === 'held' || current === 'authorized' ? 'released' : null;
    case 'dispute':
      return current === 'held' || current === 'collected' ? 'disputed' : null;
    case 'refund':
      return current === 'collected' || current === 'held' || current === 'disputed' ? 'refunded' : null;
    default:
      return null;
  }
}

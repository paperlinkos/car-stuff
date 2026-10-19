import { FieldValue, Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { calculatePricingBreakdown, DEFAULT_PRICING_CONFIG, PlatformPricingConfig } from './pricing';
import { getPaymentProvider } from './payment-provider';
import { calculateOwnerBalances, LedgerEntry } from './financial-ledger';
import { validateRefundEligibility } from './deposits-refunds';
import { canTransitionPayout, validatePayoutEligibility } from './payouts';

export async function initializePaymentTx(
  db: Firestore,
  authUid: string,
  customerEmail: string,
  bookingId: string,
  pricingConfig: PlatformPricingConfig = DEFAULT_PRICING_CONFIG
) {
  const provider = getPaymentProvider();
  const paymentRefDoc = db.collection('payments').doc();
  const paymentRef = `mota_pay_${bookingId}_${Date.now()}`;

  let result: {
    reference: string;
    authorizationUrl: string;
    provider: string;
    amountNgn: number;
    currency: 'NGN';
  } | undefined;

  await db.runTransaction(async (transaction) => {
    const bookingDocRef = db.collection('bookings').doc(bookingId);
    const bookingDoc = await transaction.get(bookingDocRef);
    if (!bookingDoc.exists) {
      throw new HttpsError('not-found', 'Booking not found.');
    }

    const booking = bookingDoc.data()!;
    if (booking.customerId !== authUid) {
      throw new HttpsError('permission-denied', 'Only the customer who created this booking can pay.');
    }

    if (booking.status !== 'accepted') {
      throw new HttpsError(
        'failed-precondition',
        `Payment can only be initiated for accepted bookings. Current status is '${booking.status}'.`
      );
    }

    if (booking.paymentStatus === 'paid') {
      throw new HttpsError('already-exists', 'This booking has already been paid.');
    }

    // Revalidate and compute trusted pricing breakdown
    const dailyRateNgn = Number(booking.pricing?.dailyRateNgn);
    const durationDays = Number(booking.pricing?.durationDays);
    const breakdown = calculatePricingBreakdown(dailyRateNgn, durationDays, pricingConfig);
    if (!breakdown) {
      throw new HttpsError('failed-precondition', 'Pricing breakdown could not be determined.');
    }

    // Create provider attempt
    const attempt = await provider.createPaymentAttempt({
      bookingId,
      customerId: authUid,
      customerEmail: customerEmail || 'customer@mota.ng',
      amountNgn: breakdown.customerTotalNgn,
      currency: 'NGN',
      reference: paymentRef,
      metadata: {
        bookingId,
        ownerId: booking.ownerId,
        vehicleId: booking.vehicleId,
      },
    });

    // Write payment record
    transaction.create(paymentRefDoc, {
      id: paymentRefDoc.id,
      reference: paymentRef,
      bookingId,
      customerId: authUid,
      ownerId: booking.ownerId,
      vehicleId: booking.vehicleId,
      amountNgn: breakdown.customerTotalNgn,
      grossRentalNgn: breakdown.grossRentalNgn,
      platformCommissionNgn: breakdown.platformCommissionNgn,
      platformFixedFeeNgn: breakdown.platformFixedFeeNgn,
      ownerNetEarningsNgn: breakdown.ownerNetEarningsNgn,
      depositNgn: breakdown.depositNgn,
      currency: 'NGN',
      status: 'pending',
      provider: provider.name,
      authorizationUrl: attempt.authorizationUrl,
      pricingSnapshot: breakdown,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // If a deposit is configured, create security deposit record
    if (breakdown.depositNgn > 0) {
      const depositRef = db.collection('securityDeposits').doc();
      transaction.create(depositRef, {
        id: depositRef.id,
        bookingId,
        customerId: authUid,
        ownerId: booking.ownerId,
        amountNgn: breakdown.depositNgn,
        currency: 'NGN',
        status: 'pending',
        providerReference: paymentRef,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // Update booking payment tracking
    transaction.update(bookingDocRef, {
      paymentStatus: 'pending',
      paymentReference: paymentRef,
      pricingBreakdown: breakdown,
      updatedAt: FieldValue.serverTimestamp(),
    });

    transaction.create(db.collection('auditLogs').doc(), {
      action: 'payment_initialized',
      actorId: authUid,
      subjectId: bookingId,
      metadata: {
        paymentRef,
        amountNgn: breakdown.customerTotalNgn,
        provider: provider.name,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    result = {
      reference: paymentRef,
      authorizationUrl: attempt.authorizationUrl,
      provider: provider.name,
      amountNgn: breakdown.customerTotalNgn,
      currency: 'NGN',
    };
  });

  return result!;
}

export async function processVerifiedPaymentTx(
  db: Firestore,
  reference: string,
  amountPaidNgn: number,
  currency: string = 'NGN',
  providerTransactionId?: string,
  gatewayResponse?: string
) {
  let outcome: 'processed' | 'duplicate' | 'orphaned' | 'underpaid' | 'currency_mismatch' = 'processed';

  await db.runTransaction(async (transaction) => {
    const paymentQuery = await transaction.get(
      db.collection('payments').where('reference', '==', reference).limit(1)
    );

    if (paymentQuery.empty) {
      // Payment record not found in system
      outcome = 'orphaned';
      return;
    }

    const paymentDoc = paymentQuery.docs[0];
    const payment = paymentDoc.data();

    if (payment.status === 'successful') {
      outcome = 'duplicate';
      return;
    }

    // Currency verification: must match expected NGN
    if (currency !== 'NGN' || payment.currency !== 'NGN') {
      transaction.update(paymentDoc.ref, {
        status: 'failed',
        reconciliationRequired: true,
        reconciliationReason: `currency_mismatch: received ${currency}, expected NGN`,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(db.collection('auditLogs').doc(), {
        action: 'payment_currency_mismatch_flagged',
        actorId: 'system',
        subjectId: payment.bookingId,
        metadata: { paymentReference: reference, receivedCurrency: currency },
        createdAt: FieldValue.serverTimestamp(),
      });
      outcome = 'currency_mismatch';
      return;
    }

    // Amount verification: underpayment cannot be marked successful
    if (amountPaidNgn < payment.amountNgn) {
      transaction.update(paymentDoc.ref, {
        status: 'failed',
        amountPaidNgn,
        providerTransactionId: providerTransactionId || null,
        reconciliationRequired: true,
        reconciliationReason: `amount_mismatch_underpaid: received ${amountPaidNgn}, expected ${payment.amountNgn}`,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(db.collection('auditLogs').doc(), {
        action: 'payment_underpaid_flagged',
        actorId: 'system',
        subjectId: payment.bookingId,
        metadata: { paymentReference: reference, amountPaidNgn, expectedAmountNgn: payment.amountNgn },
        createdAt: FieldValue.serverTimestamp(),
      });
      outcome = 'underpaid';
      return;
    }

    const bookingDocRef = db.collection('bookings').doc(payment.bookingId);
    const bookingDoc = await transaction.get(bookingDocRef);

    const isBookingCancelledOrDeclined =
      !bookingDoc.exists ||
      bookingDoc.data()?.status === 'cancelled' ||
      bookingDoc.data()?.status === 'declined';

    if (isBookingCancelledOrDeclined) {
      // Late / orphaned payment: Customer paid, but booking was cancelled or declined
      transaction.update(paymentDoc.ref, {
        status: 'successful',
        amountPaidNgn,
        providerTransactionId: providerTransactionId || null,
        gatewayResponse: gatewayResponse || 'Success',
        reconciliationRequired: true,
        reconciliationReason: 'payment_received_after_cancellation',
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.create(db.collection('auditLogs').doc(), {
        action: 'payment_orphaned_late_callback',
        actorId: 'system',
        subjectId: payment.bookingId,
        metadata: {
          paymentReference: reference,
          amountPaidNgn,
          note: 'Booking cancelled before payment confirmed. Refund required.',
        },
        createdAt: FieldValue.serverTimestamp(),
      });

      outcome = 'orphaned';
      return;
    }

    // Normal happy path: update payment to successful
    transaction.update(paymentDoc.ref, {
      status: 'successful',
      amountPaidNgn,
      providerTransactionId: providerTransactionId || null,
      gatewayResponse: gatewayResponse || 'Success',
      paidAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Update booking payment status
    transaction.update(bookingDocRef, {
      paymentStatus: 'paid',
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Append-only balanced double-entry ledger entries
    const rentalAmount = Number(payment.grossRentalNgn ?? amountPaidNgn);
    const commissionAmount = Number(payment.platformCommissionNgn ?? 0);
    const ownerNetAmount = Number(payment.ownerNetEarningsNgn ?? (rentalAmount - commissionAmount));
    const depositAmount = Number(payment.depositNgn ?? 0);

    // 1. Debit platform clearing asset (cash received into platform bank account)
    // Debits = amountPaidNgn
    transaction.create(db.collection('financialLedger').doc(), {
      entryType: 'rental_charge',
      direction: 'debit',
      amountNgn: amountPaidNgn,
      currency: 'NGN',
      accountId: 'platform_clearing',
      bookingId: payment.bookingId,
      paymentId: paymentDoc.id,
      referenceId: reference,
      description: `Rental payment received into clearing for booking ${payment.bookingId}`,
      createdAt: FieldValue.serverTimestamp(),
    });

    // 2. Credit owner account (net earnings liability)
    transaction.create(db.collection('financialLedger').doc(), {
      entryType: 'owner_credit',
      direction: 'credit',
      amountNgn: ownerNetAmount,
      currency: 'NGN',
      accountId: `owner_${payment.ownerId}`,
      bookingId: payment.bookingId,
      paymentId: paymentDoc.id,
      referenceId: reference,
      description: `Net rental earnings for booking ${payment.bookingId}`,
      createdAt: FieldValue.serverTimestamp(),
    });

    // 3. Credit platform revenue (commission)
    if (commissionAmount > 0) {
      transaction.create(db.collection('financialLedger').doc(), {
        entryType: 'platform_commission',
        direction: 'credit',
        amountNgn: commissionAmount,
        currency: 'NGN',
        accountId: 'platform_revenue',
        bookingId: payment.bookingId,
        paymentId: paymentDoc.id,
        referenceId: reference,
        description: `Platform fee earned for booking ${payment.bookingId}`,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    // 4. Credit deposit escrow account if applicable
    if (depositAmount > 0) {
      transaction.create(db.collection('financialLedger').doc(), {
        entryType: 'deposit_collected',
        direction: 'credit',
        amountNgn: depositAmount,
        currency: 'NGN',
        accountId: `escrow_deposit_${payment.customerId}`,
        bookingId: payment.bookingId,
        paymentId: paymentDoc.id,
        referenceId: reference,
        description: `Security deposit held in escrow for booking ${payment.bookingId}`,
        createdAt: FieldValue.serverTimestamp(),
      });

      const depositQuery = await transaction.get(
        db.collection('securityDeposits').where('bookingId', '==', payment.bookingId).limit(1)
      );
      if (!depositQuery.empty) {
        transaction.update(depositQuery.docs[0].ref, {
          status: 'collected',
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }

    transaction.create(db.collection('auditLogs').doc(), {
      action: 'payment_verified_and_settled',
      actorId: 'system',
      subjectId: payment.bookingId,
      metadata: {
        paymentReference: reference,
        amountPaidNgn,
        rentalAmount,
        commissionAmount,
        ownerNetAmount,
      },
      createdAt: FieldValue.serverTimestamp(),
    });
  });

  return outcome;
}

export async function requestOwnerPayoutTx(
  db: Firestore,
  ownerId: string,
  requestedAmountNgn: number
) {
  let result: { payoutId: string; amountNgn: number; status: string } | undefined;

  await db.runTransaction(async (transaction) => {
    // 0. Explicit read of the user document to ensure transaction write-locking
    // Prevents concurrent payout requests from race-conditions reserving the same balance twice.
    const userRef = db.collection('users').doc(ownerId);
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      throw new HttpsError('not-found', 'Owner account not found.');
    }

    // 1. Fetch all ledger entries for owner
    const ledgerSnap = await transaction.get(
      db.collection('financialLedger').where('accountId', '==', `owner_${ownerId}`)
    );

    const entries: LedgerEntry[] = ledgerSnap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        entryType: data.entryType,
        direction: data.direction,
        amountNgn: Number(data.amountNgn),
        currency: data.currency ?? 'NGN',
        accountId: data.accountId,
        createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : new Date(),
        referenceId: data.referenceId ?? '',
        description: data.description ?? '',
      };
    });

    const summary = calculateOwnerBalances(ownerId, entries);

    const eligibility = validatePayoutEligibility(requestedAmountNgn, summary.availableForPayoutNgn);
    if (!eligibility.eligible) {
      throw new HttpsError('failed-precondition', eligibility.reason || 'Payout not eligible.');
    }

    const payoutDocRef = db.collection('payouts').doc();

    transaction.create(payoutDocRef, {
      id: payoutDocRef.id,
      ownerId,
      amountNgn: requestedAmountNgn,
      currency: 'NGN',
      status: 'requested',
      requestedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Balanced double-entry payout hold:
    // 1. Debit owner account (reserves available funds)
    transaction.create(db.collection('financialLedger').doc(), {
      entryType: 'payout_hold',
      direction: 'debit',
      amountNgn: requestedAmountNgn,
      currency: 'NGN',
      accountId: `owner_${ownerId}`,
      payoutId: payoutDocRef.id,
      referenceId: payoutDocRef.id,
      description: `Payout requested (ID: ${payoutDocRef.id}) - funds held`,
      createdAt: FieldValue.serverTimestamp(),
    });

    // 2. Credit pending payout escrow account
    transaction.create(db.collection('financialLedger').doc(), {
      entryType: 'payout_hold',
      direction: 'credit',
      amountNgn: requestedAmountNgn,
      currency: 'NGN',
      accountId: `payout_pending_${ownerId}`,
      payoutId: payoutDocRef.id,
      referenceId: payoutDocRef.id,
      description: `Payout hold reserved for ${payoutDocRef.id}`,
      createdAt: FieldValue.serverTimestamp(),
    });

    // Update user doc timestamp to force concurrency conflict detection
    transaction.update(userRef, {
      lastPayoutRequestedAt: FieldValue.serverTimestamp(),
    });

    transaction.create(db.collection('auditLogs').doc(), {
      action: 'owner_payout_requested',
      actorId: ownerId,
      subjectId: payoutDocRef.id,
      metadata: {
        amountNgn: requestedAmountNgn,
        availableBefore: summary.availableForPayoutNgn,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    result = {
      payoutId: payoutDocRef.id,
      amountNgn: requestedAmountNgn,
      status: 'requested',
    };
  });

  return result!;
}

export async function reviewOwnerPayoutTx(
  db: Firestore,
  adminUid: string,
  payoutId: string,
  action: 'approve' | 'reject',
  reviewNote?: string
) {
  let result: { payoutId: string; status: string } | undefined;

  await db.runTransaction(async (transaction) => {
    const payoutRef = db.collection('payouts').doc(payoutId);
    const payoutDoc = await transaction.get(payoutRef);
    if (!payoutDoc.exists) {
      throw new HttpsError('not-found', 'Payout not found.');
    }

    const payout = payoutDoc.data()!;
    const nextStatus = canTransitionPayout(payout.status, action);
    if (!nextStatus) {
      throw new HttpsError('failed-precondition', `Cannot ${action} payout currently in '${payout.status}' status.`);
    }

    const amountNgn = Number(payout.amountNgn);
    const ownerId = payout.ownerId;

    if (action === 'approve') {
      // Admin approval sets status to 'approved'. Funds remain held in payout_pending.
      // Must NOT report as completed until provider transfer is confirmed!
      transaction.update(payoutRef, {
        status: 'approved',
        reviewedBy: adminUid,
        reviewedAt: FieldValue.serverTimestamp(),
        reviewNote: reviewNote || 'Approved by administrator. Awaiting provider transfer settlement.',
        settlementMode: 'pending_provider_transfer',
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      // Rejection: releases hold back to owner exactly once
      transaction.update(payoutRef, {
        status: 'rejected',
        reviewedBy: adminUid,
        reviewedAt: FieldValue.serverTimestamp(),
        reviewNote: reviewNote || 'Rejected by administrator',
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Balanced reversing entry:
      // 1. Debit pending payout escrow (clears hold)
      transaction.create(db.collection('financialLedger').doc(), {
        entryType: 'payout_cancellation',
        direction: 'debit',
        amountNgn,
        currency: 'NGN',
        accountId: `payout_pending_${ownerId}`,
        payoutId,
        referenceId: payoutId,
        description: `Payout hold cleared for rejected payout ${payoutId}`,
        createdAt: FieldValue.serverTimestamp(),
      });

      // 2. Credit owner account (restores available funds)
      transaction.create(db.collection('financialLedger').doc(), {
        entryType: 'payout_cancellation',
        direction: 'credit',
        amountNgn,
        currency: 'NGN',
        accountId: `owner_${ownerId}`,
        payoutId,
        referenceId: payoutId,
        description: `Payout rejected for ${payoutId} - funds restored`,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    transaction.create(db.collection('auditLogs').doc(), {
      action: `owner_payout_${action}d`,
      actorId: adminUid,
      subjectId: payoutId,
      metadata: {
        ownerId,
        amountNgn,
        action,
        reviewNote,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    result = { payoutId, status: nextStatus };
  });

  return result!;
}

export async function settleOwnerPayoutTx(
  db: Firestore,
  adminUid: string,
  payoutId: string,
  opts?: {
    providerTransferId?: string;
    settlementMode?: 'sandbox_simulation' | 'provider_confirmed';
    failureReason?: string;
    isFailure?: boolean;
  }
) {
  let result: { payoutId: string; status: string; settlementMode: string } | undefined;

  await db.runTransaction(async (transaction) => {
    const payoutRef = db.collection('payouts').doc(payoutId);
    const payoutDoc = await transaction.get(payoutRef);
    if (!payoutDoc.exists) {
      throw new HttpsError('not-found', 'Payout not found.');
    }

    const payout = payoutDoc.data()!;
    const ownerId = payout.ownerId;
    const amountNgn = Number(payout.amountNgn);

    if (opts?.isFailure) {
      const nextStatus = canTransitionPayout(payout.status, 'fail');
      if (!nextStatus) {
        throw new HttpsError('failed-precondition', `Cannot fail payout in '${payout.status}' status.`);
      }

      transaction.update(payoutRef, {
        status: 'failed',
        failureReason: opts.failureReason || 'Provider transfer failed.',
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Reversing entry releases funds back to owner
      transaction.create(db.collection('financialLedger').doc(), {
        entryType: 'payout_cancellation',
        direction: 'debit',
        amountNgn,
        currency: 'NGN',
        accountId: `payout_pending_${ownerId}`,
        payoutId,
        referenceId: payoutId,
        description: `Payout failed for ${payoutId} - pending hold released`,
        createdAt: FieldValue.serverTimestamp(),
      });

      transaction.create(db.collection('financialLedger').doc(), {
        entryType: 'payout_cancellation',
        direction: 'credit',
        amountNgn,
        currency: 'NGN',
        accountId: `owner_${ownerId}`,
        payoutId,
        referenceId: payoutId,
        description: `Payout failed for ${payoutId} - funds restored to owner`,
        createdAt: FieldValue.serverTimestamp(),
      });

      result = { payoutId, status: 'failed', settlementMode: opts.settlementMode || 'sandbox_simulation' };
      return;
    }

    const nextStatus = canTransitionPayout(payout.status, 'complete');
    if (!nextStatus) {
      throw new HttpsError('failed-precondition', `Cannot settle payout currently in '${payout.status}' status.`);
    }

    const settlementMode = opts?.settlementMode || 'sandbox_simulation';

    transaction.update(payoutRef, {
      status: 'completed',
      completedAt: FieldValue.serverTimestamp(),
      providerTransferId: opts?.providerTransferId || `sim_trf_${payoutId}`,
      settlementMode,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Balanced settlement entries:
    // 1. Debit pending payout escrow
    transaction.create(db.collection('financialLedger').doc(), {
      entryType: 'payout_settlement',
      direction: 'debit',
      amountNgn,
      currency: 'NGN',
      accountId: `payout_pending_${ownerId}`,
      payoutId,
      referenceId: payoutId,
      description: `Payout settlement completed for ${payoutId}`,
      createdAt: FieldValue.serverTimestamp(),
    });

    // 2. Credit platform clearing (cash leaves platform clearing)
    transaction.create(db.collection('financialLedger').doc(), {
      entryType: 'payout_settlement',
      direction: 'credit',
      amountNgn,
      currency: 'NGN',
      accountId: 'platform_clearing',
      payoutId,
      referenceId: payoutId,
      description: `Transfer dispatched to owner bank account for ${payoutId}`,
      createdAt: FieldValue.serverTimestamp(),
    });

    transaction.create(db.collection('auditLogs').doc(), {
      action: 'owner_payout_settled',
      actorId: adminUid,
      subjectId: payoutId,
      metadata: {
        ownerId,
        amountNgn,
        settlementMode,
        providerTransferId: opts?.providerTransferId,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    result = { payoutId, status: 'completed', settlementMode };
  });

  return result!;
}

export async function requestBookingRefundTx(
  db: Firestore,
  adminUid: string,
  paymentId: string,
  refundAmountNgn: number,
  reason: string
) {
  let result: { refundId: string; amountNgn: number; status: string } | undefined;

  await db.runTransaction(async (transaction) => {
    const paymentRef = db.collection('payments').doc(paymentId);
    const paymentDoc = await transaction.get(paymentRef);
    if (!paymentDoc.exists) {
      throw new HttpsError('not-found', 'Payment not found.');
    }

    const payment = paymentDoc.data()!;
    if (payment.status !== 'successful') {
      throw new HttpsError('failed-precondition', 'Only successful payments can be refunded.');
    }

    // Cumulative refund tracking with optimistic concurrency lock on paymentRef
    const existingTotalRefundedNgn = Number(payment.totalRefundedNgn ?? 0);
    const totalPaid = Number(payment.amountNgn);

    const check = validateRefundEligibility(totalPaid, existingTotalRefundedNgn, refundAmountNgn);
    if (!check.eligible) {
      throw new HttpsError('failed-precondition', check.reason || 'Refund not eligible.');
    }

    const newTotalRefunded = existingTotalRefundedNgn + refundAmountNgn;
    const newPaymentStatus = newTotalRefunded >= totalPaid ? 'refunded' : 'partially_refunded';

    const refundDocRef = db.collection('refunds').doc();

    transaction.create(refundDocRef, {
      id: refundDocRef.id,
      bookingId: payment.bookingId,
      paymentId,
      amountNgn: refundAmountNgn,
      currency: 'NGN',
      reason,
      requestedBy: adminUid,
      authorizedBy: adminUid,
      providerReference: payment.reference,
      status: 'completed', // Sandbox simulation mode
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Update payment record with cumulative refund total (locks paymentRef against race conditions)
    transaction.update(paymentRef, {
      totalRefundedNgn: newTotalRefunded,
      paymentStatus: newPaymentStatus,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Proportional ledger reversals:
    const grossRental = Number(payment.grossRentalNgn ?? totalPaid);
    const commission = Number(payment.platformCommissionNgn ?? 0);
    const commissionRatio = grossRental > 0 ? commission / grossRental : 0;
    const commissionRefundShare = Math.round(refundAmountNgn * commissionRatio);
    const ownerRefundShare = refundAmountNgn - commissionRefundShare;

    // 1. Debit owner account (reversal of owner net earnings)
    if (ownerRefundShare > 0) {
      transaction.create(db.collection('financialLedger').doc(), {
        entryType: 'owner_refund_debit',
        direction: 'debit',
        amountNgn: ownerRefundShare,
        currency: 'NGN',
        accountId: `owner_${payment.ownerId}`,
        bookingId: payment.bookingId,
        paymentId,
        refundId: refundDocRef.id,
        referenceId: refundDocRef.id,
        description: `Owner refund deduction for booking ${payment.bookingId}`,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    // 2. Debit platform revenue (reversal of commission)
    if (commissionRefundShare > 0) {
      transaction.create(db.collection('financialLedger').doc(), {
        entryType: 'commission_reversal',
        direction: 'debit',
        amountNgn: commissionRefundShare,
        currency: 'NGN',
        accountId: 'platform_revenue',
        bookingId: payment.bookingId,
        paymentId,
        refundId: refundDocRef.id,
        referenceId: refundDocRef.id,
        description: `Platform commission reversed on refund for booking ${payment.bookingId}`,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    // 3. Credit platform clearing (cash refunded to customer from clearing)
    transaction.create(db.collection('financialLedger').doc(), {
      entryType: 'customer_refund',
      direction: 'credit',
      amountNgn: refundAmountNgn,
      currency: 'NGN',
      accountId: 'platform_clearing',
      bookingId: payment.bookingId,
      paymentId,
      refundId: refundDocRef.id,
      referenceId: refundDocRef.id,
      description: `Refund issued to customer for booking ${payment.bookingId}: ${reason}`,
      createdAt: FieldValue.serverTimestamp(),
    });

    transaction.update(db.collection('bookings').doc(payment.bookingId), {
      paymentStatus: newPaymentStatus,
      updatedAt: FieldValue.serverTimestamp(),
    });

    transaction.create(db.collection('auditLogs').doc(), {
      action: 'booking_refund_issued',
      actorId: adminUid,
      subjectId: payment.bookingId,
      metadata: {
        paymentId,
        refundId: refundDocRef.id,
        amountNgn: refundAmountNgn,
        newPaymentStatus,
        reason,
      },
      createdAt: FieldValue.serverTimestamp(),
    });

    result = {
      refundId: refundDocRef.id,
      amountNgn: refundAmountNgn,
      status: 'completed',
    };
  });

  return result!;
}


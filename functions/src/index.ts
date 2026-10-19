import {initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {auth} from 'firebase-functions/v1';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import {
  BookingStatus,
  RentalMode,
  bookingDurationDays,
  canTransition,
  estimateNgn,
  hasDateOverlap,
  isSupportedRentalMode,
  isValidIdempotencyKey,
  lagosDate,
  validateBookingPeriod,
} from './booking';
import {
  initializePaymentTx,
  processVerifiedPaymentTx,
  requestBookingRefundTx,
  requestOwnerPayoutTx,
  reviewOwnerPayoutTx,
  settleOwnerPayoutTx,
} from './financial-service';
import { getPaymentProvider } from './payment-provider';
import { calculateOwnerBalances, LedgerEntry } from './financial-ledger';
import { DEFAULT_PRICING_CONFIG } from './pricing';

initializeApp();
const db = getFirestore();
type RequestedRole = 'owner' | 'driver';
type RequestDecision = 'approved' | 'rejected';
const requestedRoles: readonly RequestedRole[] = ['owner', 'driver'];
const decisions: readonly RequestDecision[] = ['approved', 'rejected'];

export const createUserProfile = auth.user().onCreate(async (user) => {
  await db.collection('users').doc(user.uid).create({
    id: user.uid, displayName: user.displayName ?? '', email: user.email ?? null,
    phoneNumber: user.phoneNumber ?? null, profileImageUrl: user.photoURL ?? null,
    accountStatus: 'active', roles: ['customer'],
    createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  });
});

// The function, rather than the client, creates the role request and prevents
// concurrent duplicate pending requests.
export const requestRoleActivation = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const requestedRole = request.data?.requestedRole as RequestedRole | undefined;
  if (!requestedRole || !requestedRoles.includes(requestedRole)) {
    throw new HttpsError('invalid-argument', 'requestedRole must be owner or driver.');
  }
  const requestRef = db.collection('roleRequests').doc();
  await db.runTransaction(async (transaction) => {
    const profileRef = db.collection('users').doc(request.auth!.uid);
    const profile = await transaction.get(profileRef);
    if (!profile.exists) throw new HttpsError('failed-precondition', 'Your profile is still being created. Try again shortly.');
    const activeRoles = profile.data()?.roles as string[] | undefined;
    if (activeRoles?.includes(requestedRole)) throw new HttpsError('already-exists', 'This role is already active.');
    const duplicate = await transaction.get(db.collection('roleRequests')
      .where('userId', '==', request.auth!.uid).where('requestedRole', '==', requestedRole)
      .where('status', '==', 'pending').limit(1));
    if (!duplicate.empty) throw new HttpsError('already-exists', 'A request for this role is already pending.');
    transaction.create(requestRef, {
      id: requestRef.id, userId: request.auth!.uid, requestedRole, status: 'pending',
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(db.collection('auditLogs').doc(), {
      action: 'role_requested', actorId: request.auth!.uid, subjectId: requestRef.id,
      metadata: {requestedRole}, createdAt: FieldValue.serverTimestamp(),
    });
  });
  return {requestId: requestRef.id, status: 'pending'};
});

// Only an Admin SDK-issued admin custom claim can decide a role request.
export const reviewRoleRequest = onCall(async (request) => {
  if (!request.auth?.token.admin) throw new HttpsError('permission-denied', 'Administrator access required.');
  const requestId = request.data?.requestId;
  const decision = request.data?.decision as RequestDecision | undefined;
  if (typeof requestId !== 'string' || !decision || !decisions.includes(decision)) {
    throw new HttpsError('invalid-argument', 'A requestId and approved or rejected decision are required.');
  }
  await db.runTransaction(async (transaction) => {
    const roleRequestRef = db.collection('roleRequests').doc(requestId);
    const roleRequest = await transaction.get(roleRequestRef);
    if (!roleRequest.exists) throw new HttpsError('not-found', 'Role request not found.');
    const data = roleRequest.data()!;
    if (data.status !== 'pending') throw new HttpsError('failed-precondition', 'This role request has already been decided.');
    const requestedRole = data.requestedRole as RequestedRole;
    if (!requestedRoles.includes(requestedRole)) throw new HttpsError('failed-precondition', 'Role request contains an invalid role.');
    const profileRef = db.collection('users').doc(data.userId as string);
    const profile = await transaction.get(profileRef);
    if (!profile.exists) throw new HttpsError('failed-precondition', 'Applicant profile not found.');
    const existingRoles = (profile.data()?.roles as string[] | undefined) ?? ['customer'];
    const roles = decision === 'approved' && !existingRoles.includes(requestedRole) ? [...existingRoles, requestedRole] : existingRoles;
    transaction.update(roleRequestRef, {
      status: decision, reviewedBy: request.auth!.uid, reviewedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(profileRef, {roles, updatedAt: FieldValue.serverTimestamp()});
    transaction.create(db.collection('auditLogs').doc(), {
      action: 'role_request_reviewed', actorId: request.auth!.uid, subjectId: requestId,
      metadata: {decision, requestedRole, userId: data.userId}, createdAt: FieldValue.serverTimestamp(),
    });
  });
  return {requestId, decision};
});

// Reserved for controlled support migrations. It cannot assign administrator
// access and uses the same trusted custom-claim gate as reviewRoleRequest.
export const setActivatedRoles = onCall(async (request) => {
  if (!request.auth?.token.admin) throw new HttpsError('permission-denied', 'Administrator access required.');
  const {userId, roles} = request.data ?? {};
  if (typeof userId !== 'string' || !Array.isArray(roles) ||
      !roles.every((role) => ['customer', 'owner', 'driver'].includes(role)) || !roles.includes('customer')) {
    throw new HttpsError('invalid-argument', 'Invalid userId or activated roles.');
  }
  const activatedRoles = [...new Set(roles)];
  await db.collection('users').doc(userId).update({roles: activatedRoles, updatedAt: FieldValue.serverTimestamp()});
  await db.collection('auditLogs').add({
    action: 'roles_migrated', actorId: request.auth.uid, subjectId: userId,
    metadata: {roles: activatedRoles}, createdAt: FieldValue.serverTimestamp(),
  });
  return {userId, roles: activatedRoles};
});

const reviewStatuses = ['approved', 'rejected', 'changesRequested', 'suspended'] as const;
type ListingReviewStatus = typeof reviewStatuses[number];

export const submitVehicleListing = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const listingId = request.data?.listingId;
  if (typeof listingId !== 'string') throw new HttpsError('invalid-argument', 'listingId is required.');
  await db.runTransaction(async (transaction) => {
    const profile = await transaction.get(db.collection('users').doc(request.auth!.uid));
    if (!profile.data()?.roles?.includes('owner')) throw new HttpsError('permission-denied', 'Approved owner access is required.');
    const listingRef = db.collection('vehicles').doc(listingId);
    const listing = await transaction.get(listingRef);
    if (!listing.exists || listing.data()?.ownerId !== request.auth!.uid) throw new HttpsError('not-found', 'Vehicle draft not found.');
    if (!['draft', 'changesRequested'].includes(listing.data()?.status)) throw new HttpsError('failed-precondition', 'This listing cannot be submitted.');
    const documents = await transaction.get(db.collection('vehicleDocuments').where('listingId', '==', listingId));
    const types = documents.docs.map((doc) => doc.data().type);
    if (!types.includes('ownership') || !types.includes('registration')) {
      throw new HttpsError('failed-precondition', 'Ownership and registration documents are required before review.');
    }
    transaction.update(listingRef, {status: 'submitted', submittedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
    transaction.create(db.collection('auditLogs').doc(), {action:'vehicle_listing_submitted', actorId:request.auth!.uid, subjectId:listingId, createdAt:FieldValue.serverTimestamp()});
  });
  return {listingId, status:'submitted'};
});

export const reviewVehicleListing = onCall(async (request) => {
  if (!request.auth?.token.admin) throw new HttpsError('permission-denied', 'Administrator access required.');
  const {listingId, status, note} = request.data ?? {};
  if (typeof listingId !== 'string' || !reviewStatuses.includes(status as ListingReviewStatus) ||
      (['rejected', 'changesRequested'].includes(status) && (typeof note !== 'string' || note.trim().length < 3))) {
    throw new HttpsError('invalid-argument', 'A listing, valid review status and required review note are needed.');
  }
  const ref = db.collection('vehicles').doc(listingId);
  await db.runTransaction(async (transaction) => {
    const listing = await transaction.get(ref);
    if (!listing.exists) throw new HttpsError('not-found', 'Vehicle listing not found.');
    if (!['submitted', 'underReview', 'approved'].includes(listing.data()?.status)) throw new HttpsError('failed-precondition', 'Listing is not available for review.');
    transaction.update(ref, {status, reviewNote: typeof note === 'string' ? note.trim() : null, reviewedBy:request.auth!.uid, reviewedAt:FieldValue.serverTimestamp(), updatedAt:FieldValue.serverTimestamp()});
    transaction.create(db.collection('auditLogs').doc(), {action:'vehicle_listing_reviewed', actorId:request.auth!.uid, subjectId:listingId, metadata:{status}, createdAt:FieldValue.serverTimestamp()});
  });
  return {listingId, status};
});

type BookingAction = 'accept' | 'decline' | 'cancel';
const bookingActions: readonly BookingAction[] = ['accept', 'decline', 'cancel'];

function requiredString(value: unknown, name: string, maximum: number): string {
  if (typeof value !== 'string' || !value.trim() || value.trim().length > maximum) {
    throw new HttpsError('invalid-argument', `${name} is required and too long.`);
  }
  return value.trim();
}

function boundedOptionalString(value: unknown, name: string, maximum: number): string | null {
  if (value == null || value === '') return null;
  if (typeof value !== 'string' || value.trim().length > maximum) {
    throw new HttpsError('invalid-argument', `${name} is invalid.`);
  }
  return value.trim() || null;
}

// Callable-only booking creation. Prices, ownership and lifecycle fields are
// calculated from trusted records rather than supplied by the customer.
export const createBookingRequest = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const data = request.data ?? {};
  const vehicleId = requiredString(data.vehicleId, 'vehicleId', 200);
  const pickupArea = requiredString(data.pickupArea, 'pickupArea', 120);
  const idempotencyKey = requiredString(data.idempotencyKey, 'idempotencyKey', 120);
  if (!isValidIdempotencyKey(idempotencyKey)) {
    throw new HttpsError('invalid-argument', 'idempotencyKey has invalid characters.');
  }
  const rentalMode = data.rentalMode as RentalMode;
  const pickupAt = new Date(data.pickupAt);
  const returnAt = new Date(data.returnAt);
  const pickupNotes = boundedOptionalString(data.pickupNotes, 'pickupNotes', 500);
  const customerMessage = boundedOptionalString(data.customerMessage, 'customerMessage', 1000);
  const idempotencyRef = db.collection('bookingIdempotency')
    .doc(`${request.auth.uid}_${idempotencyKey}`);
  const bookingRef = db.collection('bookings').doc();
  let result: {bookingId: string; status: BookingStatus; duplicate: boolean} | undefined;
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(idempotencyRef);
    if (existing.exists) {
      const bookingId = existing.data()?.bookingId;
      if (typeof bookingId !== 'string') throw new HttpsError('internal', 'Invalid idempotency record.');
      const booking = await transaction.get(db.collection('bookings').doc(bookingId));
      if (!booking.exists) throw new HttpsError('internal', 'Booking retry record is incomplete.');
      result = {bookingId, status: booking.data()?.status as BookingStatus, duplicate: true};
      return;
    }
    const profile = await transaction.get(db.collection('users').doc(request.auth!.uid));
    if (!profile.exists || !profile.data()?.roles?.includes('customer')) {
      throw new HttpsError('permission-denied', 'Customer access is required.');
    }
    const vehicle = await transaction.get(db.collection('vehicles').doc(vehicleId));
    if (!vehicle.exists || vehicle.data()?.status !== 'approved') {
      throw new HttpsError('failed-precondition', 'This vehicle is not available for booking requests.');
    }
    const listing = vehicle.data()!;
    if (!isSupportedRentalMode(listing.rentalMode, rentalMode)) {
      throw new HttpsError('invalid-argument', 'This vehicle does not offer that rental mode.');
    }
    const durationDays = validateBookingPeriod(pickupAt, returnAt, Number(listing.minimumRentalDays ?? 1));
    if (durationDays == null) {
      throw new HttpsError('invalid-argument', 'Choose a future period from the minimum rental length up to 31 days.');
    }
    const dailyRateNgn = Number(listing.dailyRateNgn);
    const estimate = estimateNgn(dailyRateNgn, durationDays);
    if (estimate == null || typeof listing.ownerId !== 'string') {
      throw new HttpsError('failed-precondition', 'This listing has incomplete pricing information.');
    }
    transaction.create(bookingRef, {
      id: bookingRef.id, status: 'requested', customerId: request.auth!.uid,
      ownerId: listing.ownerId, vehicleId, rentalMode, pickupArea, pickupNotes,
      customerMessage, pickupAt, returnAt, pickupDateLagos: lagosDate(pickupAt),
      returnDateLagos: lagosDate(returnAt), durationDays,
      pricing: {dailyRateNgn, durationDays, estimateNgn: estimate, currency: 'NGN'},
      vehicleSnapshot: {make: listing.make, model: listing.model, year: listing.year},
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(idempotencyRef, {bookingId: bookingRef.id, customerId: request.auth!.uid, createdAt: FieldValue.serverTimestamp()});
    transaction.create(db.collection('auditLogs').doc(), {
      action: 'booking_requested', actorId: request.auth!.uid, subjectId: bookingRef.id,
      metadata: {vehicleId, rentalMode, durationDays}, createdAt: FieldValue.serverTimestamp(),
    });
    result = {bookingId: bookingRef.id, status: 'requested', duplicate: false};
  });
  return result!;
});

export const transitionBooking = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const bookingId = requiredString(request.data?.bookingId, 'bookingId', 200);
  const action = request.data?.action as BookingAction;
  if (!bookingActions.includes(action)) throw new HttpsError('invalid-argument', 'Invalid booking action.');
  let status: BookingStatus | undefined;
  await db.runTransaction(async (transaction) => {
    const bookingRef = db.collection('bookings').doc(bookingId);
    const booking = await transaction.get(bookingRef);
    if (!booking.exists) throw new HttpsError('not-found', 'Booking not found.');
    const data = booking.data()!;
    const next = canTransition(data.status as BookingStatus, action);
    if (next == null) throw new HttpsError('failed-precondition', 'This booking can no longer be changed.');
    if (action === 'cancel') {
      if (data.customerId !== request.auth!.uid) throw new HttpsError('permission-denied', 'Only the requesting customer can cancel this booking.');
    } else {
      const profile = await transaction.get(db.collection('users').doc(request.auth!.uid));
      if (!profile.data()?.roles?.includes('owner') || data.ownerId !== request.auth!.uid) {
        throw new HttpsError('permission-denied', 'Only the vehicle owner can decide this request.');
      }
      const vehicle = await transaction.get(db.collection('vehicles').doc(data.vehicleId));
      if (!vehicle.exists || vehicle.data()?.status !== 'approved' || vehicle.data()?.ownerId !== request.auth!.uid) {
        throw new HttpsError('failed-precondition', 'The vehicle is no longer eligible for booking decisions.');
      }
      if (action === 'accept') {
        const activeOrAccepted = await transaction.get(
          db.collection('bookings')
            .where('vehicleId', '==', data.vehicleId)
            .where('status', 'in', ['accepted', 'active'])
        );
        const conflict = activeOrAccepted.docs.some((candidate) => {
          if (candidate.id === bookingId) return false;
          const item = candidate.data();
          return hasDateOverlap(
            item.pickupAt.toDate(),
            item.returnAt.toDate(),
            data.pickupAt.toDate(),
            data.returnAt.toDate(),
          );
        });
        if (conflict) {
          throw new HttpsError(
            'failed-precondition',
            'This vehicle already has an accepted or active booking for those dates.'
          );
        }
        transaction.update(vehicle.ref, {
          lastBookingAcceptedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
    transaction.update(bookingRef, {
      status: next, decisionBy: action === 'cancel' ? null : request.auth!.uid,
      decisionAt: action === 'cancel' ? null : FieldValue.serverTimestamp(),
      cancelledBy: action === 'cancel' ? request.auth!.uid : null,
      cancelledAt: action === 'cancel' ? FieldValue.serverTimestamp() : null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(db.collection('auditLogs').doc(), {
      action: `booking_${next}`, actorId: request.auth!.uid, subjectId: bookingId,
      metadata: {previousStatus: data.status, nextStatus: next}, createdAt: FieldValue.serverTimestamp(),
    });
    status = next;
  });
  return {bookingId, status};
});

// ==========================================
// PHASE 6: FINANCIAL, PAYMENTS, PAYOUTS
// ==========================================

export const initializeBookingPayment = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const bookingId = requiredString(request.data?.bookingId, 'bookingId', 200);
  const email = typeof request.auth.token.email === 'string' ? request.auth.token.email : 'customer@mota.ng';

  return initializePaymentTx(db, request.auth.uid, email, bookingId, DEFAULT_PRICING_CONFIG);
});

export const verifyPaymentStatus = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const reference = requiredString(request.data?.reference, 'reference', 200);

  const provider = getPaymentProvider();
  const verified = await provider.verifyPayment(reference);

  if (verified.status === 'successful') {
    await processVerifiedPaymentTx(
      db,
      reference,
      verified.amountPaidNgn,
      verified.currency,
      verified.providerTransactionId,
      verified.gatewayResponse
    );
  }

  return {
    reference,
    status: verified.status,
    amountPaidNgn: verified.amountPaidNgn,
    currency: verified.currency,
  };
});

export const handlePaymentWebhook = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const provider = getPaymentProvider();
  const signature = (req.headers['x-paystack-signature'] ||
    req.headers['x-webhook-signature'] ||
    req.headers['signature']) as string | undefined;

  const webhookSecret =
    process.env.PAYMENT_PROVIDER_WEBHOOK_SECRET ||
    process.env.PAYSTACK_SECRET_KEY ||
    'sandbox_test_webhook_secret';

  const rawBody = (req as unknown as { rawBody?: Buffer }).rawBody || JSON.stringify(req.body);
  const isValid = provider.verifyWebhookSignature(rawBody, signature || '', webhookSecret);

  if (!isValid) {
    res.status(401).json({ error: 'Invalid webhook signature' });
    return;
  }

  const event = provider.parseWebhookEvent(req.body);
  if (!event || !event.reference) {
    res.status(400).json({ error: 'Malformed webhook payload' });
    return;
  }

  // Idempotent event deduplication
  const eventId = (req.headers['x-event-id'] as string) || `evt_${event.reference}_${event.status}`;
  const eventRef = db.collection('processedEvents').doc(eventId);

  const alreadyProcessed = await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(eventRef);
    if (doc.exists) return true;
    transaction.create(eventRef, {
      id: eventId,
      reference: event.reference,
      status: event.status,
      processedAt: FieldValue.serverTimestamp(),
    });
    return false;
  });

  if (alreadyProcessed) {
    res.status(200).json({ status: 'duplicate_event_ignored' });
    return;
  }

  if (event.status === 'successful') {
    await processVerifiedPaymentTx(
      db,
      event.reference,
      event.amountNgn,
      event.currency,
      event.providerTransactionId
    );
  }

  res.status(200).json({ status: 'processed', reference: event.reference });
});

export const requestOwnerPayout = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const profile = await db.collection('users').doc(request.auth.uid).get();
  if (!profile.data()?.roles?.includes('owner')) {
    throw new HttpsError('permission-denied', 'Approved owner access is required.');
  }

  const amountNgn = Number(request.data?.amountNgn);
  if (!Number.isSafeInteger(amountNgn) || amountNgn <= 0) {
    throw new HttpsError('invalid-argument', 'Valid positive amountNgn is required.');
  }

  return requestOwnerPayoutTx(db, request.auth.uid, amountNgn);
});

export const reviewOwnerPayout = onCall(async (request) => {
  if (!request.auth?.token.admin) throw new HttpsError('permission-denied', 'Administrator access required.');
  const payoutId = requiredString(request.data?.payoutId, 'payoutId', 200);
  const action = request.data?.action as 'approve' | 'reject';
  if (action !== 'approve' && action !== 'reject') {
    throw new HttpsError('invalid-argument', 'Action must be approve or reject.');
  }
  const reviewNote = boundedOptionalString(request.data?.reviewNote, 'reviewNote', 500) || undefined;

  return reviewOwnerPayoutTx(db, request.auth.uid, payoutId, action, reviewNote);
});

export const settleOwnerPayout = onCall(async (request) => {
  if (!request.auth?.token.admin) throw new HttpsError('permission-denied', 'Administrator access required.');
  const payoutId = requiredString(request.data?.payoutId, 'payoutId', 200);
  const providerTransferId = boundedOptionalString(request.data?.providerTransferId, 'providerTransferId', 200);
  const isFailure = Boolean(request.data?.isFailure);
  const failureReason = boundedOptionalString(request.data?.failureReason, 'failureReason', 500);

  return settleOwnerPayoutTx(db, request.auth.uid, payoutId, {
    providerTransferId: providerTransferId || `sim_trf_${Date.now()}`,
    settlementMode: 'sandbox_simulation',
    isFailure,
    failureReason: failureReason || undefined,
  });
});

export const requestBookingRefund = onCall(async (request) => {
  if (!request.auth?.token.admin) throw new HttpsError('permission-denied', 'Administrator access required.');
  const paymentId = requiredString(request.data?.paymentId, 'paymentId', 200);
  const amountNgn = Number(request.data?.amountNgn);
  const reason = requiredString(request.data?.reason, 'reason', 500);

  if (!Number.isSafeInteger(amountNgn) || amountNgn <= 0) {
    throw new HttpsError('invalid-argument', 'Valid refund amount is required.');
  }

  return requestBookingRefundTx(db, request.auth.uid, paymentId, amountNgn, reason);
});

export const getOwnerFinancialSummary = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const requestedOwnerId = request.data?.ownerId as string | undefined;

  let targetOwnerId = request.auth.uid;
  if (requestedOwnerId && requestedOwnerId !== request.auth.uid) {
    if (!request.auth.token.admin) {
      throw new HttpsError('permission-denied', 'Only administrators can inspect other owners.');
    }
    targetOwnerId = requestedOwnerId;
  }

  const ledgerSnap = await db
    .collection('financialLedger')
    .where('accountId', 'in', [`owner_${targetOwnerId}`, `payout_pending_${targetOwnerId}`])
    .get();

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

  return calculateOwnerBalances(targetOwnerId, entries);
});
